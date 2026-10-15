import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/application/game_library.dart';
import 'package:anxin_xiangqi/application/user_preferences.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/main.dart';
import 'package:anxin_xiangqi/presentation/game_library_dialog.dart';
import 'package:anxin_xiangqi/presentation/game_review.dart';

import 'controller_test.dart' show MemoryStore, ImmediateAi;
import 'experience_test.dart' show desktop, tapVisible;

void main() {
  testWidgets('从真实棋桌打开棋局库，回看不动实盘，改名收藏与删除取消可用', (tester) async {
    desktop(tester);
    final archive = MemoryStore();
    final active = GameLibrary(archive);
    final game = GameController(
      store: MemoryStore(),
      engine: ImmediateAi(),
      library: active,
    );
    addTearDown(game.dispose);
    addTearDown(active.dispose);
    await game.initialize();
    await game.play(const Move(54, 45));
    await game.newGame();
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tapVisible(tester, '我的棋局');
    expect(find.byType(GameLibraryDialog), findsOneWidget);
    final before = game.position;
    await tapVisible(tester, '查看棋谱');
    expect(find.byType(GameReviewDialog), findsOneWidget);
    expect(game.position, same(before));
    await tester.tap(
      find.descendant(
        of: find.byType(GameReviewDialog),
        matching: find.text('回到棋桌'),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, '改名');
    await tester.enterText(find.byType(TextField), '和家人研究的棋');
    await tapVisible(tester, '保存名称');
    expect(active.entries.single.title, '和家人研究的棋');
    await tapVisible(tester, '收藏');
    expect(active.entries.single.favorite, true);
    await tapVisible(tester, '删除');
    await tapVisible(tester, '保留');
    expect(active.entries, hasLength(1));
    await tapVisible(tester, '删除');
    await tapVisible(tester, '确认删除');
    expect(active.entries, isEmpty);
    expect(game.position, same(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('继续旧盘前保存当前盘，确认后回到棋桌显示旧局', (tester) async {
    desktop(tester);
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
    final old = game.position, oldId = game.gameId;
    await game.newGame();
    await game.play(const Move(56, 47));
    final recentId = game.gameId, recentMoves = game.moves;
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tapVisible(tester, '我的棋局');
    await tapVisible(tester, '继续这盘');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('继续这盘'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GameLibraryDialog), findsNothing);
    expect(game.position.key, old.key);
    expect(game.gameId, oldId);
    expect(
      library.entries.singleWhere((e) => e.id == recentId).snapshot.moves,
      recentMoves,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 800), const Size(640, 360)]) {
    testWidgets('棋局库在 $size 系统两倍和应用更大文字下可滚动与返回', (tester) async {
      desktop(tester, size: size);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
      await game.newGame();
      await game.setPreferences(const UserPreferences(textScale: 1.4));
      await tester.pumpWidget(AnxinApp(controller: game));
      await tester.pumpAndSettle();
      await tapVisible(tester, '我的棋局');
      final exit = tester.getRect(find.text('回到棋桌'));
      expect(exit.bottom, lessThanOrEqualTo(size.height));
      expect(exit.left, greaterThanOrEqualTo(0));
      final list = find.descendant(
        of: find.byType(GameLibraryDialog),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(find.text('查看棋谱'), 260, scrollable: list);
      expect(find.text('查看棋谱'), findsOneWidget);
      await tapVisible(tester, '改名');
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '大字下改的名字');
      await tapVisible(tester, '保存名称');
      expect(library.entries.single.title, '大字下改的名字');
      await tester.scrollUntilVisible(find.text('删除'), 260, scrollable: list);
      await tapVisible(tester, '删除');
      await tapVisible(tester, '保留');
      await tapVisible(tester, '回到棋桌');
      expect(find.byType(GameLibraryDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('大量棋局按可见范围构建，手动保存失败可重试', (tester) async {
    desktop(tester);
    final store = MemoryStore(), seedStore = MemoryStore();
    final seed = GameLibrary(seedStore);
    final seeded = GameController(
      store: MemoryStore(),
      engine: ImmediateAi(),
      library: seed,
    );
    await seeded.initialize();
    await seeded.play(const Move(54, 45));
    await seeded.saveToLibrary();
    final row = jsonDecode(seedStore.data!)['entries'][0] as Map;
    store.data = jsonEncode({
      'version': 1,
      'entries': List.generate(
        120,
        (i) => {...row, 'id': 'old-$i', 'title': '第 $i 盘'},
      ),
    });
    seeded.dispose();
    seed.dispose();
    final library = GameLibrary(store);
    final game = GameController(
      store: MemoryStore(),
      engine: ImmediateAi(),
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    await game.play(const Move(54, 45));
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tapVisible(tester, '我的棋局');
    expect(find.byType(Card).evaluate().length, lessThan(10));
    store.fail = true;
    await tapVisible(tester, '保存本局');
    expect(find.textContaining('暂时无法保存这次修改'), findsOneWidget);
    expect(library.entries.length, 120);
    store.fail = false;
    await tapVisible(tester, '保存本局');
    expect(library.entries.length, 121);
    expect(tester.takeException(), isNull);
  });
}
