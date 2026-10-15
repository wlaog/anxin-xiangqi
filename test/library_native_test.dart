import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/application/game_library.dart';
import 'package:anxin_xiangqi/infrastructure/pikafish.dart';

import 'controller_test.dart' show MemoryStore;

void main() {
  if (!Platform.isWindows) return;
  test('真实 Pikafish 对弈自动保存、重放裁决与继续旧盘', () async {
    final native = PikafishRuntime(
      libraryPath:
          '${Directory.current.path}/native/bin/windows/anxin_pikafish.dll',
      networkPath: '${Directory.current.path}/assets/engine/pikafish.nnue',
    );
    final library = GameLibrary(MemoryStore());
    final game = GameController(
      store: MemoryStore(),
      engine: native,
      rules: native,
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    await game.setLevel(1);
    await game.play(game.legalMoves.first);
    expect(game.ply, 2);
    final id = game.gameId, before = game.position;
    await game.newGame();
    final record = game.readRecord(library.entries.single.snapshot);
    expect(record.positions.last.key, before.key);
    expect(await game.continueGame(library.entries.single), true);
    expect(game.gameId, id);
    expect(game.position.key, before.key);
    expect(game.legalMoves, native.judge(game.history, game.moves).legal);
  });
}
