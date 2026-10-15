import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/main.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/application/user_preferences.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';

import 'controller_test.dart' show MemoryStore, ImmediateAi;

void main() {
  testWidgets('放大棋盘可选子对弈，缩放和返回不改变棋局', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    await game.initialize();
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('放大棋盘'));
    await tester.tap(find.text('放大棋盘'));
    await tester.pumpAndSettle();
    final board = tester.getRect(find.byType(ChessBoard).last);
    final cell = board.width / 9;
    expect(cell, greaterThanOrEqualTo(60));
    await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 6.5));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard).last).selected,
      54,
    );
    await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 5.5));
    await tester.pumpAndSettle();
    expect(game.ply, 2);
    final key = game.position.key;
    await tester.tap(find.text('放大'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(ChessBoard).last).width,
      greaterThan(board.width),
    );
    expect(game.position.key, key);
    await tester.tap(find.text('缩小'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回到棋桌'));
    await tester.pumpAndSettle();
    expect(find.byType(ChessBoard), findsOneWidget);
    expect(game.position.key, key);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('矮窗口大字下放大棋盘保持大格子，滚动条和返回可用', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    await game.initialize();
    await game.setPreferences(const UserPreferences(textScale: 1.4));
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('放大棋盘'));
    await tester.tap(find.text('放大棋盘'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(ChessBoard).last).width,
      greaterThanOrEqualTo(540),
    );
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Scrollbar),
      ),
      findsNWidgets(2),
    );
    await tester.tap(find.text('回到棋桌'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('确认前不落子，取消保留选择，确认后才轮到电脑', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    await game.initialize();
    await game.setPreferences(const UserPreferences(confirmMoves: true));
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    final board = tester.getRect(find.byType(ChessBoard));
    final cell = board.width / 9;
    final destination = board.topLeft + Offset(cell * 0.5, cell * 5.5);
    await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 6.5));
    await tester.pump();
    await tester.tapAt(destination);
    await tester.pumpAndSettle();
    expect(find.text('这步确定走吗？'), findsOneWidget);
    expect(game.ply, 0);
    expect(game.busy, false);
    expect(
      tester
          .widget<ChessBoard>(find.byType(ChessBoard).last)
          .position
          .board[45]
          ?.kind,
      Kind.pawn,
    );
    await tester.tap(find.text('再想想'));
    await tester.pumpAndSettle();
    expect(game.ply, 0);
    expect(tester.widget<ChessBoard>(find.byType(ChessBoard)).selected, 54);
    await tester.tapAt(destination);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定落子'));
    await tester.pumpAndSettle();
    expect(game.ply, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });

  testWidgets('确认期间棋局被替换，旧的待确认着法失效', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    await game.initialize();
    await game.setPreferences(const UserPreferences(confirmMoves: true));
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    final board = tester.getRect(find.byType(ChessBoard));
    final cell = board.width / 9;
    await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 6.5));
    await tester.pump();
    await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 5.5));
    await tester.pumpAndSettle();
    await game.newGame();
    await tester.tap(find.text('确定落子'));
    await tester.pumpAndSettle();
    expect(game.ply, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });

  testWidgets('窄窗口系统大字叠加更大文字，设置与确认仍可完成', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    await game.initialize();
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('使用设置'));
    await tester.tap(find.text('使用设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('更大文字'));
    await tester.tap(find.text('更大文字'));
    await tester.pumpAndSettle();
    expect(game.preferences.textScale, 1.4);
    await tester.ensureVisible(find.text('落子前再确认'));
    await tester.tap(find.text('落子前再确认'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('减少动效'));
    await tester.tap(find.text('减少动效'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置好了'));
    await tester.pumpAndSettle();
    expect(game.preferences.confirmMoves, true);
    expect(game.preferences.reduceMotion, true);
    await tester.ensureVisible(find.byType(ChessBoard));
    await tester.pumpAndSettle();
    final board = tester.getRect(find.byType(ChessBoard));
    final cell = board.width / 9;
    await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 6.5));
    await tester.pump();
    await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 5.5));
    await tester.pumpAndSettle();
    expect(find.text('这步确定走吗？'), findsOneWidget);
    await tester.tap(find.text('确定落子'));
    await tester.pumpAndSettle();
    expect(game.ply, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
  testWidgets('提示不代走，翻转后可回看且不修改棋局', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    await game.initialize();
    await game.play(const Move(54, 45));
    final before = game.position.key;
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tester.tap(find.text('帮我想想'));
    await tester.pumpAndSettle();
    expect(game.position.key, before);
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).selected,
      isNotNull,
    );
    await tester.ensureVisible(find.text('翻转棋盘'));
    await tester.tap(find.text('翻转棋盘'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChessBoard>(find.byType(ChessBoard)).flipped, true);
    await tester.tap(find.text('回看棋局'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上一步'));
    await tester.pumpAndSettle();
    expect(find.text('回看棋局 · 第 1 步'), findsOneWidget);
    expect(game.position.key, before);
    await tester.tap(find.text('回到棋桌'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
  for (final size in [
    const Size(360, 800),
    const Size(1280, 800),
    const Size(640, 360),
  ]) {
    testWidgets('棋桌在 $size 与 200% 文字下不溢出', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final game = GameController(store: MemoryStore(), engine: ImmediateAi());
      await game.initialize();
      await tester.pumpWidget(AnxinApp(controller: game));
      await tester.pumpAndSettle();
      expect(find.text('安心象棋'), findsOneWidget);
      expect(find.byType(ChessBoard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    });
  }
  testWidgets('点选落子、悔棋、新局取消和确认', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    await game.initialize();
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    final board = tester.getRect(find.byType(ChessBoard));
    final cell = board.width / 9;
    await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 6.5));
    await tester.pump();
    await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 5.5));
    await tester.pumpAndSettle();
    expect(game.ply, 2);
    await tester.tap(find.text('悔一步'));
    await tester.pumpAndSettle();
    expect(game.ply, 0);
    await tester.tap(find.text('重新开始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接着下'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('重新开始'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '重新开始').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
}
