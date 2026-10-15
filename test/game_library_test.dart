import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/game_library.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/domain/game_snapshot.dart';
import 'package:anxin_xiangqi/domain/rules.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';

import 'controller_test.dart' show MemoryStore, ImmediateAi, DelayedAi;
import 'controller_transaction_test.dart' show ControlledStore;

GameSnapshot sample([List<Move> moves = const [Move(54, 45)]]) =>
    GameSnapshot(moves: moves, side: Side.red, level: 2);

class EndAfterTwo extends BasicRules {
  EndAfterTwo([this.end = 2]);
  final int end;
  @override
  RuleVerdict judge(List<Position> history, List<Move> moves) =>
      moves.length == end
      ? const RuleVerdict(Outcome.redWins, [])
      : super.judge(history, moves);
}

void main() {
  test('并发保存和改名串行提交，重开库仍保留多盘、收藏及修改后的名称', () async {
    final store = MemoryStore();
    final active = GameLibrary(store);
    addTearDown(active.dispose);
    await Future.wait([
      active.save('one', sample()),
      active.save('two', sample()),
    ]);
    await Future.wait([
      active.rename('one', '第一次好棋'),
      active.favorite('one', true),
    ]);
    await active.save('one', sample([const Move(54, 45), const Move(27, 36)]));
    final reopened = GameLibrary(store);
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.entries.length, 2);
    final one = reopened.entries.singleWhere((e) => e.id == 'one');
    expect(one.title, '第一次好棋');
    expect(one.favorite, true);
    expect(one.snapshot.moves.length, 2);
    expect(
      one.created,
      active.entries.singleWhere((e) => e.id == 'one').created,
    );
  });

  test('单份坏棋谱和重复身份隔离保留，整理正常棋谱不重写坏条目', () async {
    final store = MemoryStore();
    final library = GameLibrary(store);
    addTearDown(library.dispose);
    await library.save('good', sample());
    final decoded = jsonDecode(store.data!);
    final bad = {
      'id': 'broken',
      'game': 'unreadable',
      'extra': [42],
    };
    decoded['entries'].addAll([
      bad,
      {'id': 'duplicate'},
      {'id': 'duplicate'},
    ]);
    decoded['futureField'] = 'keep';
    store.data = jsonEncode(decoded);
    final reopened = GameLibrary(store);
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.entries.single.id, 'good');
    expect(reopened.unreadable, 3);
    await reopened.rename('good', '保留的棋');
    final saved = jsonDecode(store.data!);
    expect(
      saved['entries'].skip(1).toList(),
      decoded['entries'].skip(1).toList(),
    );
    expect(saved['futureField'], 'keep');
    await expectLater(reopened.save('broken', sample()), throwsStateError);
  });

  test('整个库损坏或读取失败时不以空库覆盖，正常续局仍可打开', () async {
    final store = MemoryStore()..data = '{bad library';
    final library = GameLibrary(store);
    final game = GameController(
      store: MemoryStore(),
      engine: ImmediateAi(),
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    expect(game.ready, true);
    expect(library.writable, false);
    await expectLater(library.save('one', sample()), throwsStateError);
    expect(store.data, '{bad library');
  });

  test('写入失败不改变列表、名称或收藏，随后可以重试删除', () async {
    final store = MemoryStore();
    final active = GameLibrary(store);
    addTearDown(active.dispose);
    await active.save('one', sample());
    final before = store.data, entry = active.entries.single;
    store.fail = true;
    await expectLater(active.rename('one', '未落盘'), throwsStateError);
    await expectLater(active.favorite('one', true), throwsStateError);
    await expectLater(active.remove('one'), throwsStateError);
    expect(store.data, before);
    expect(active.entries.single, same(entry));
    store.fail = false;
    await active.remove('one');
    expect(active.entries, isEmpty);
    expect(jsonDecode(store.data!)['entries'], isEmpty);
  });

  test('新开局先保存旧盘，失败保留棋盘和当前存档，重试后可回看和继续', () async {
    final store = MemoryStore(), archive = MemoryStore();
    final library = GameLibrary(archive);
    final game = GameController(
      store: store,
      engine: ImmediateAi(),
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    await game.play(const Move(54, 45));
    await game.saved;
    final id = game.gameId, before = game.position, data = store.data;
    archive.fail = true;
    await game.newGame(side: Side.black);
    expect(game.position, same(before));
    expect(game.playerSide, Side.red);
    expect(game.gameId, id);
    expect(store.data, data);
    expect(game.notice, contains('棋盘已保留'));
    archive.fail = false;
    await game.newGame();
    expect(game.ply, 0);
    expect(game.gameId, isNot(id));
    final entry = library.entries.single;
    expect(entry.id, id);
    final record = game.readRecord(entry.snapshot);
    expect(record.positions.last.key, before.key);
    expect(game.ply, 0);
    expect(await game.continueGame(entry), true);
    expect(game.position.key, before.key);
    expect(game.gameId, id);
    final reopened = GameController(
      store: store,
      engine: ImmediateAi(),
      library: library,
    );
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.gameId, id);
    await reopened.saveToLibrary();
    expect(library.entries.length, 1);
  });

  test('保存旧局期间禁止其他棋局变更，取消的电脑结果不会污染新盘', () async {
    final archive = ControlledStore(), ai = DelayedAi();
    final library = GameLibrary(archive);
    final game = GameController(
      store: MemoryStore(),
      engine: ai,
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    final playing = game.play(const Move(54, 45));
    await game.saved;
    archive.writeGate = Completer<void>();
    final changing = game.newGame();
    await Future<void>.delayed(Duration.zero);
    expect(game.busy, true);
    ai.answer.complete(ai.received!.legalMoves().first);
    await playing;
    await game.undo();
    await game.setLevel(5);
    await game.play(const Move(45, 36));
    expect(game.ply, 1);
    expect(game.level, 2);
    archive.writeGate!.complete();
    await changing;
    expect(game.ply, 0);
    expect(game.busy, false);
    expect(library.entries.single.snapshot.moves, [const Move(54, 45)]);
  });

  test('语法合法而棋规非法的旧棋谱不能继续，当前盘与原棋谱保留', () async {
    final library = GameLibrary(MemoryStore());
    final game = GameController(
      store: MemoryStore(),
      engine: ImmediateAi(),
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    await game.play(const Move(54, 45));
    await library.save('illegal', sample([const Move(0, 89)]));
    final before = game.position;
    expect(
      () => game.readRecord(library.entries.single.snapshot),
      throwsFormatException,
    );
    expect(await game.continueGame(library.entries.single), false);
    expect(game.position, same(before));
    expect(library.entries.single.id, 'illegal');
  });

  test('终局自动入库，与当前续局分开保存', () async {
    final library = GameLibrary(MemoryStore());
    final game = GameController(
      store: MemoryStore(),
      engine: ImmediateAi(),
      rules: EndAfterTwo(),
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    await game.play(const Move(54, 45));
    await game.saved;
    expect(game.result, Outcome.redWins);
    expect(library.entries.single.snapshot.moves, game.moves);
    await game.newGame();
    expect(library.entries.length, 1);
  });

  test('旧版续局在首次保存棋谱后保留稳定身份，不产生重复副本', () async {
    final store = MemoryStore()
      ..data = jsonEncode({
        'version': 1,
        'level': 2,
        'moves': [
          [54, 45],
          [27, 36],
        ],
      });
    final library = GameLibrary(MemoryStore());
    final game = GameController(
      store: store,
      engine: ImmediateAi(),
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    await game.saveToLibrary();
    final id = game.gameId;
    final reopened = GameController(
      store: store,
      engine: ImmediateAi(),
      library: library,
    );
    addTearDown(reopened.dispose);
    await reopened.initialize();
    await reopened.saveToLibrary();
    expect(reopened.gameId, id);
    expect(library.entries.length, 1);
  });

  test('延迟终局自动保存不会覆盖随后悔棋再新开局的最终记录', () async {
    final store = ControlledStore();
    final library = GameLibrary(MemoryStore());
    final game = GameController(
      store: store,
      engine: ImmediateAi(),
      rules: EndAfterTwo(4),
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    await game.play(game.legalMoves.first);
    final expected = game.moves;
    store.writeGate = Completer<void>();
    final playing = game.play(game.legalMoves.first);
    await Future<void>.delayed(Duration.zero);
    expect(game.ply, 4);
    final undoing = game.undo();
    expect(game.ply, 2);
    final changing = game.newGame();
    store.writeGate!.complete();
    await Future.wait([playing, undoing, changing]);
    expect(game.ply, 0);
    expect(library.entries.single.snapshot.moves, expected);
  });

  test('当前续局写入失败时，终局仍可单独保存到棋谱库', () async {
    final store = MemoryStore()..fail = true;
    final library = GameLibrary(MemoryStore());
    final game = GameController(
      store: store,
      engine: ImmediateAi(),
      rules: EndAfterTwo(),
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    await game.play(game.legalMoves.first);
    await game.saved;
    expect(game.notice, contains('不能保存'));
    expect(library.entries.single.snapshot.moves.length, 2);
  });
}
