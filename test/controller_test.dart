import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/domain/ai.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/infrastructure/game_store.dart';

class MemoryStore implements GameStore {
  String? data;
  bool fail = false;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('disk');
    data = value;
  }
}

class ImmediateAi implements AiEngine {
  @override
  Future<Move?> choose(Position position, int level) async =>
      position.legalMoves().firstOrNull;
}

class DelayedAi implements AiEngine {
  final answer = Completer<Move?>();
  Position? received;
  @override
  Future<Move?> choose(Position p, int level) {
    received = p;
    return answer.future;
  }
}

void main() {
  test('一轮对弈、成对悔棋与存档重放', () async {
    final store = MemoryStore();
    final game = GameController(store: store, engine: ImmediateAi());
    await game.initialize();
    await game.play(const Move(54, 45));
    expect(game.ply, 2);
    expect(game.position.turn, Side.red);
    final restored = GameController(store: store, engine: ImmediateAi());
    await restored.initialize();
    expect(restored.position.key, game.position.key);
    await game.undo();
    expect(game.ply, 0);
    expect(game.position.key, Position.initial().key);
    expect((jsonDecode(store.data!)['moves'] as List), isEmpty);
    game.dispose();
    restored.dispose();
  });
  for (final restart in [false, true]) {
    test('AI 思考中${restart ? '重开' : '悔棋'}使旧结果失效', () async {
      final engine = DelayedAi();
      final store = MemoryStore();
      final game = GameController(store: store, engine: engine);
      await game.initialize();
      final pending = game.play(const Move(54, 45));
      expect(game.busy, true);
      final move = engine.received!.legalMoves().first;
      if (restart) {
        await game.newGame();
      } else {
        await game.undo();
      }
      engine.answer.complete(move);
      await pending;
      expect(game.position.key, Position.initial().key);
      expect(game.ply, 0);
      expect(game.busy, false);
      game.dispose();
    });
  }
  test('恢复轮到电脑的中断局会继续走棋', () async {
    final store = MemoryStore()
      ..data = jsonEncode({
        'version': 1,
        'level': 1,
        'moves': [
          [54, 45],
        ],
      });
    final game = GameController(store: store, engine: ImmediateAi());
    await game.initialize();
    expect(game.ply, 2);
    expect(game.busy, false);
    game.dispose();
  });
  test('坏档完整保留，只有明确新局后才替换', () async {
    final store = MemoryStore()..data = 'bad data';
    final game = GameController(store: store, engine: ImmediateAi());
    await game.initialize();
    expect(game.ready, true);
    expect(game.notice, contains('保留'));
    await game.play(const Move(54, 45));
    expect(store.data, 'bad data');
    await game.newGame();
    expect(jsonDecode(store.data!)['version'], 1);
    game.dispose();
  });
  test('保存失败不阻止对弈，非法存档走法不被采用', () async {
    final store = MemoryStore()
      ..data = jsonEncode({
        'version': 1,
        'level': 2,
        'moves': [
          [54, 0],
        ],
      });
    final game = GameController(store: store, engine: ImmediateAi());
    await game.initialize();
    expect(game.ply, 0);
    store.fail = true;
    await game.newGame();
    await game.play(const Move(54, 45));
    expect(game.ply, 2);
    expect(game.notice, contains('不能保存'));
    game.dispose();
  });
  test('真实 isolate AI 也能完成一轮对弈', () async {
    final game = GameController(
      store: MemoryStore(),
      engine: IsolateAiEngine(),
    );
    await game.initialize();
    await game.setLevel(1);
    await game.play(const Move(54, 45));
    expect(game.ply, 2);
    expect(game.position.turn, Side.red);
    game.dispose();
  });
}
