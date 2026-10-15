import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/domain/ai.dart';
import 'package:anxin_xiangqi/domain/rules.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/infrastructure/game_store.dart';

class ControlledRules implements RuleBook {
  int? failAtPly;
  int calls = 0;
  @override
  RuleVerdict judge(List<Position> history, List<Move> moves) {
    calls++;
    if (moves.length == failAtPly) {
      throw StateError('temporary referee failure');
    }
    return BasicRules().judge(history, moves);
  }
}

class ControlledStore implements GameStore {
  String? data;
  int reads = 0, writes = 0;
  Completer<void>? readGate;
  Completer<void>? writeGate;
  bool failWrites = false;
  @override
  Future<String?> read() async {
    reads++;
    final snapshot = data;
    await readGate?.future;
    return snapshot;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    await writeGate?.future;
    if (failWrites) throw StateError('temporary storage failure');
    data = value;
  }
}

class CountingAi implements AiEngine {
  int calls = 0;
  Completer<Move?>? gate;
  Position? received;
  @override
  Future<Move?> choose(Position position, int level) async {
    calls++;
    received = position;
    return gate == null ? position.legalMoves().first : await gate!.future;
  }
}

String savedGame(List<Move> moves, {Side side = Side.red, int level = 2}) =>
    jsonEncode({
      'version': 2,
      'moves': moves.map((move) => move.toJson()).toList(),
      'side': side.name,
      'level': level,
    });

void expectSameGame(
  GameController game,
  List<Position> positions,
  List<Move> moves,
  List<Move> legal,
  Outcome result,
) {
  expect(game.history, positions);
  expect(game.moves, moves);
  expect(game.legalMoves, legal);
  expect(game.result, result);
}

void main() {
  test('坏档保留警告经正常走棋、提示失败及重试仍可见，明确新局才解除', () async {
    const original = 'malformed saved game';
    final store = ControlledStore()..data = original;
    final ai = CountingAi();
    final game = GameController(store: store, engine: ai);
    addTearDown(game.dispose);
    await game.initialize();
    await game.play(const Move(54, 45));
    expect(game.ply, 2);
    expect(game.notice, contains('原存档已保留'));
    expect(game.notice, contains('不会保存'));
    ai.gate = Completer<Move?>();
    final failedHint = game.hint();
    ai.gate!.completeError(StateError('temporary hint failure'));
    expect(await failedHint, isNull);
    expect(game.notice, contains('原存档已保留'));
    expect(game.notice, contains('提示'));
    ai.gate = Completer<Move?>();
    final retryHint = game.hint();
    ai.gate!.complete(ai.received!.legalMoves().first);
    expect(await retryHint, isNotNull);
    expect(game.notice, contains('原存档已保留'));
    expect(game.notice, isNot(contains('没有想好提示')));
    await game.setLevel(3);
    expect(store.writes, 0);
    expect(store.data, original);
    await game.newGame();
    expect(game.notice, isNull);
    expect(jsonDecode(store.data!)['moves'], isEmpty);
    expect(jsonDecode(store.data!)['level'], 3);
  });

  test('保存失败警告在电脑成功应手的通知中仍存在', () async {
    final store = ControlledStore()..failWrites = true;
    final ai = CountingAi()..gate = Completer<Move?>();
    final game = GameController(store: store, engine: ai);
    addTearDown(game.dispose);
    await game.initialize();
    final playing = game.play(const Move(54, 45));
    await game.saved;
    expect(game.notice, contains('不能保存'));
    final afterReply = <String?>[];
    game.addListener(() {
      if (game.ply == 2 && !game.busy) afterReply.add(game.notice);
    });
    ai.gate!.complete(ai.received!.legalMoves().first);
    await playing;
    expect(game.ply, 2);
    expect(afterReply, isNotEmpty);
    expect(afterReply, everyElement(contains('不能保存')));
    expect(game.notice, contains('不能保存'));
    expect(store.data, isNull);
  });

  test('保存重试成功落盘后才清除警告，完整内容对应当前棋局', () async {
    final store = ControlledStore()..failWrites = true;
    final game = GameController(store: store, engine: CountingAi());
    addTearDown(game.dispose);
    await game.initialize();
    await game.setLevel(3);
    expect(game.notice, contains('不能保存'));
    store
      ..failWrites = false
      ..writeGate = Completer<void>();
    final saving = game.setLevel(4);
    await Future<void>.delayed(Duration.zero);
    expect(store.writes, 2);
    expect(store.data, isNull);
    expect(game.notice, contains('不能保存'));
    expect(await game.hint(), isNotNull);
    expect(game.notice, contains('不能保存'));
    store.writeGate!.complete();
    await saving;
    expect(game.notice, isNull);
    expect(jsonDecode(store.data!), {
      'version': 2,
      'gameId': game.gameId,
      'level': 4,
      'side': 'red',
      'preferences': game.preferences.toJson(),
      'moves': [],
    });
  });

  test('玩家走法裁决失败不提交棋盘、历史或存档，可重试', () async {
    final rules = ControlledRules();
    final store = ControlledStore()..data = savedGame([]);
    final ai = CountingAi();
    final game = GameController(store: store, engine: ai, rules: rules);
    addTearDown(game.dispose);
    await game.initialize();
    final positions = game.history, moves = game.moves, legal = game.legalMoves;
    final oldData = store.data;
    rules.failAtPly = 1;
    await game.play(const Move(54, 45));
    await game.saved;
    expectSameGame(game, positions, moves, legal, Outcome.playing);
    expect(store.data, oldData);
    expect(store.writes, 0);
    expect(ai.calls, 0);
    expect(game.notice, contains('再试一次'));
    rules.failAtPly = null;
    await game.play(const Move(54, 45));
    expect(game.ply, 2);
    expect(game.notice, isNull);
  });

  test('电脑走法裁决失败只保留已确认的玩家一步，可继续思考', () async {
    final rules = ControlledRules();
    final store = ControlledStore();
    final ai = CountingAi();
    final game = GameController(store: store, engine: ai, rules: rules);
    addTearDown(game.dispose);
    await game.initialize();
    rules.failAtPly = 2;
    await game.play(const Move(54, 45));
    await game.saved;
    expect(game.ply, 1);
    expect(game.position.key, Position.initial().play(const Move(54, 45)).key);
    expect(game.legalMoves, game.position.legalMoves());
    expect(game.result, Outcome.playing);
    expect(game.busy, isFalse);
    expect(game.notice, contains('继续思考'));
    expect(jsonDecode(store.data!)['moves'], [const Move(54, 45).toJson()]);
    // The successful human move is saved once; rejected AI work adds no write.
    expect(store.writes, 1);
    rules.failAtPly = null;
    await game.retryComputer();
    expect(game.ply, 2);
    expect(game.notice, isNull);
    expect(store.writes, 2);
  });

  for (final restart in [false, true]) {
    test('${restart ? '新局' : '悔棋'}裁决失败保留整局与执棋方，随后重试可成功', () async {
      final rules = ControlledRules();
      final store = ControlledStore();
      final game = GameController(
        store: store,
        engine: CountingAi(),
        rules: rules,
      );
      addTearDown(game.dispose);
      await game.initialize();
      await game.play(const Move(54, 45));
      final positions = game.history,
          moves = game.moves,
          legal = game.legalMoves;
      final result = game.result, data = store.data, writes = store.writes;
      rules.failAtPly = 0;
      if (restart) {
        await game.newGame(side: Side.black);
      } else {
        await game.undo();
      }
      expectSameGame(game, positions, moves, legal, result);
      expect(game.playerSide, Side.red);
      expect(store.data, data);
      expect(store.writes, writes);
      expect(game.notice, contains('再试一次'));
      rules.failAtPly = null;
      if (restart) {
        await game.newGame(side: Side.black);
        expect(game.playerSide, Side.black);
        expect(game.ply, 1);
      } else {
        await game.undo();
        expect(game.ply, 0);
      }
      expect(game.notice, isNull);
    });
  }

  test('恢复最终局面裁决失败不采用部分走法和设置，也不覆盖原档', () async {
    final first = Position.initial().play(const Move(54, 45));
    final source = savedGame(
      [const Move(54, 45), first.legalMoves().first],
      side: Side.black,
      level: 5,
    );
    final store = ControlledStore()..data = source;
    final rules = ControlledRules()..failAtPly = 2;
    final ai = CountingAi();
    final game = GameController(store: store, engine: ai, rules: rules);
    addTearDown(game.dispose);
    await game.initialize();
    expect(game.ready, isTrue);
    expect(game.ply, 0);
    expect(game.position.key, Position.initial().key);
    expect(game.legalMoves, game.position.legalMoves());
    expect(game.playerSide, Side.red);
    expect(game.level, 2);
    expect(store.data, source);
    expect(store.writes, 0);
    expect(ai.calls, 0);
    expect(game.notice, contains('保留'));
    await game.setLevel(3);
    expect(store.data, source);
    rules.failAtPly = null;
    await game.newGame();
    expect(jsonDecode(store.data!)['moves'], isEmpty);
  });

  test('初始裁决失败不向界面抛错，明确新局重试后可下棋', () async {
    final rules = ControlledRules()..failAtPly = 0;
    final store = ControlledStore()..data = savedGame([]);
    final source = store.data;
    final game = GameController(
      store: store,
      engine: CountingAi(),
      rules: rules,
    );
    addTearDown(game.dispose);
    await game.initialize();
    expect(game.ready, isTrue);
    expect(game.legalMoves, isEmpty);
    expect(game.ply, 0);
    expect(game.notice, contains('重试'));
    expect(store.data, source);
    rules.failAtPly = null;
    await game.newGame();
    expect(game.legalMoves, isNotEmpty);
    await game.play(const Move(54, 45));
    expect(game.ply, 2);
  });

  test('并发与完成后重复初始化共享一次读取及一次电脑应手', () async {
    final store = ControlledStore()
      ..data = savedGame([const Move(54, 45)])
      ..readGate = Completer<void>();
    final ai = CountingAi()..gate = Completer<Move?>();
    final game = GameController(store: store, engine: ai);
    addTearDown(game.dispose);
    final first = game.initialize(), second = game.initialize();
    expect(identical(first, second), isTrue);
    expect(store.reads, 1);
    expect(game.ready, isFalse);
    await game.retryComputer();
    expect(ai.calls, 0);
    store.readGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(game.ready, isTrue);
    expect(ai.calls, 1);
    final third = game.initialize();
    expect(identical(first, third), isTrue);
    ai.gate!.complete(ai.received!.legalMoves().first);
    await Future.wait([first, second, third]);
    expect(game.ply, 2);
    final latest = game.position;
    await game.initialize();
    expect(store.reads, 1);
    expect(ai.calls, 1);
    expect(identical(game.position, latest), isTrue);
  });

  test('读取中释放不采用存档、不裁决、不启动电脑', () async {
    final store = ControlledStore()
      ..data = savedGame([const Move(54, 45)])
      ..readGate = Completer<void>();
    final ai = CountingAi();
    final rules = ControlledRules();
    final game = GameController(store: store, engine: ai, rules: rules);
    final initializing = game.initialize();
    game.dispose();
    store.readGate!.complete();
    await initializing;
    await game.initialize();
    expect(game.ready, isFalse);
    expect(game.ply, 0);
    expect(store.reads, 1);
    expect(rules.calls, 0);
    expect(ai.calls, 0);
    expect(store.writes, 0);
  });

  test('思考中操作裁决失败也使旧电脑结果失效，保留原棋局', () async {
    final rules = ControlledRules();
    final ai = CountingAi()..gate = Completer<Move?>();
    final store = ControlledStore();
    final game = GameController(store: store, engine: ai, rules: rules);
    addTearDown(game.dispose);
    await game.initialize();
    final thinking = game.play(const Move(54, 45));
    expect(game.busy, isTrue);
    final positions = game.history, moves = game.moves, legal = game.legalMoves;
    rules.failAtPly = 0;
    await game.undo();
    expect(game.busy, isFalse);
    expectSameGame(game, positions, moves, legal, Outcome.playing);
    ai.gate!.complete(ai.received!.legalMoves().first);
    await thinking;
    await game.saved;
    expectSameGame(game, positions, moves, legal, Outcome.playing);
    expect((jsonDecode(store.data!)['moves'] as List), hasLength(1));
  });
}
