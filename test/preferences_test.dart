import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/application/user_preferences.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';

import 'controller_test.dart' show MemoryStore, ImmediateAi;

void main() {
  test('设置与棋局一起保存，重开和恢复都保留偏好', () async {
    final store = MemoryStore();
    final game = GameController(store: store, engine: ImmediateAi());
    await game.initialize();
    await game.play(const Move(54, 45));
    await game.setPreferences(
      const UserPreferences(
        showTargets: false,
        confirmMoves: true,
        reduceMotion: true,
        textScale: 1.4,
      ),
    );
    final restored = GameController(store: store, engine: ImmediateAi());
    await restored.initialize();
    expect(restored.position.key, game.position.key);
    expect(restored.preferences.toJson(), game.preferences.toJson());
    await restored.newGame();
    expect(restored.preferences.confirmMoves, true);
    expect(restored.preferences.textScale, 1.4);
    expect(jsonDecode(store.data!)['moves'], isEmpty);
    game.dispose();
    restored.dispose();
  });

  test('旧档缺少设置或设置局部损坏，不丢弃有效棋局', () async {
    for (final settings in [
      null,
      'bad',
      {
        'confirmMoves': true,
        'reduceMotion': 'true',
        'showTargets': false,
        'textScale': 900,
      },
    ]) {
      final store = MemoryStore()
        ..data = jsonEncode({
          'version': 2,
          'level': 3,
          'side': 'red',
          'moves': [
            [54, 45],
          ],
          'preferences': ?settings,
        });
      final game = GameController(store: store, engine: ImmediateAi());
      await game.initialize();
      expect(game.ply, 2);
      expect(game.level, 3);
      expect(game.preferences.textScale, 1);
      expect(game.preferences.reduceMotion, false);
      expect(game.preferences.confirmMoves, settings is Map);
      expect(game.preferences.showTargets, settings is! Map);
      expect(game.notice, isNot(contains('无法读取')));
      game.dispose();
    }
  });
}
