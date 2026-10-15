import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/application/user_preferences.dart';
import 'package:anxin_xiangqi/domain/game_record.dart';
import 'package:anxin_xiangqi/domain/rules.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/main.dart';
import 'package:anxin_xiangqi/presentation/game_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_test.dart' show MemoryStore, ImmediateAi, DelayedAi;

class DelayedThenImmediateAi extends DelayedAi {
  bool requested = false;
  @override
  Future<Move?> choose(Position position, int level) {
    if (requested) return Future.value(position.legalMoves().first);
    requested = true;
    return super.choose(position, level);
  }
}

class RestartFailureRules extends BasicRules {
  bool failRestart = false;
  @override
  RuleVerdict judge(List<Position> history, List<Move> moves) {
    if (failRestart && moves.isEmpty) throw StateError('referee unavailable');
    return super.judge(history, moves);
  }
}

void desktop(WidgetTester tester, {Size size = const Size(1280, 900)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

String? cursorLabel(WidgetTester tester) => tester
    .widgetList<Semantics>(
      find.descendant(
        of: find.byType(ChessBoard).last,
        matching: find.byType(Semantics),
      ),
    )
    .singleWhere(
      (w) => w.properties.focused == true && w.properties.label != null,
    )
    .properties
    .label;

Future<void> tapVisible(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    label = switch (label) {
      '回到棋桌' => '返回',
      '复制完整棋谱' => '复制',
      _ => label,
    };
  }
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(360, 800), const Size(640, 360)]) {
    testWidgets('回看在 $size 系统两倍大字叠加应用更大文字下可导航和返回', (tester) async {
      desktop(tester, size: size);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final game = GameController(store: MemoryStore(), engine: ImmediateAi());
      await game.initialize();
      await game.play(const Move(54, 45));
      await game.setPreferences(const UserPreferences(textScale: 1.4));
      await tester.pumpWidget(AnxinApp(controller: game));
      await tester.pumpAndSettle();
      await tapVisible(tester, '回看棋局');
      final viewport = tester.getRect(
        find.byKey(const ValueKey('review-content')),
      );
      final board = tester.getRect(find.byType(ChessBoard).last);
      final visibleFraction = board.intersect(viewport).height / board.height;
      expect(
        visibleFraction,
        greaterThanOrEqualTo(size.width == 360 ? .99 : .75),
      );
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('回看'))).scale(22),
        closeTo(61.6, .001),
      );
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('返回'), findsOneWidget);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tapVisible(tester, '复制');
      expect(copied, contains('第 2 步'));
      await tapVisible(tester, '开局');
      expect(find.text('0 / 2 步'), findsOneWidget);
      await tapVisible(tester, '最后一步');
      expect(find.text('2 / 2 步'), findsOneWidget);
      await tapVisible(tester, '回到棋桌');
      expect(game.ply, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets('棋盘只有一个Tab入口，方向键走棋、取消和翻转保持格子身份', (tester) async {
    desktop(tester);
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    await game.initialize();
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '棋盘');
    expect(cursorLabel(tester), startsWith('7行1列'));
    await press(tester, LogicalKeyboardKey.enter);
    expect(tester.widget<ChessBoard>(find.byType(ChessBoard)).selected, 54);
    await press(tester, LogicalKeyboardKey.escape);
    expect(tester.widget<ChessBoard>(find.byType(ChessBoard)).selected, isNull);
    await press(tester, LogicalKeyboardKey.space);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.enter);
    expect(game.ply, 2);
    await press(tester, LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('棋盘'));
    await tapVisible(tester, '翻转棋盘');
    // Re-enter the existing board focus without changing its logical cursor.
    final boardFocus = tester
        .widgetList<Focus>(
          find.descendant(
            of: find.byType(ChessBoard),
            matching: find.byType(Focus),
          ),
        )
        .singleWhere((w) => w.focusNode?.debugLabel == '棋盘')
        .focusNode!;
    boardFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(cursorLabel(tester), startsWith('6行1列'));
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(cursorLabel(tester), startsWith('7行1列'));
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('键盘确认取消后焦点回到棋盘，放大棋盘共用走棋入口', (tester) async {
    desktop(tester);
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    await game.initialize();
    await game.setPreferences(const UserPreferences(confirmMoves: true));
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.text('这步确定走吗？'), findsOneWidget);
    expect(game.ply, 0);
    final previewFocus = tester
        .widgetList<Focus>(
          find.descendant(
            of: find.byType(ChessBoard).last,
            matching: find.byType(Focus),
          ),
        )
        .singleWhere((w) => w.focusNode?.debugLabel == '棋盘')
        .focusNode!;
    previewFocus.requestFocus();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.text('这步确定走吗？'), findsNothing);
    expect(game.ply, 0);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '棋盘');
    await press(tester, LogicalKeyboardKey.enter);
    await tapVisible(tester, '确定落子');
    expect(game.ply, 2);
    await game.setPreferences(const UserPreferences());
    await tapVisible(tester, '放大棋盘');
    final focus = tester
        .widgetList<Focus>(
          find.descendant(
            of: find.byType(ChessBoard).last,
            matching: find.byType(Focus),
          ),
        )
        .singleWhere((w) => w.focusNode?.debugLabel == '棋盘')
        .focusNode!;
    focus.requestFocus();
    await tester.pumpAndSettle();
    // The advanced pawn is still the first red pawn (index 45).
    await press(tester, LogicalKeyboardKey.enter);
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard).last).selected,
      45,
    );
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.space);
    expect(game.ply, 4);
    await tapVisible(tester, '回到棋桌');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('回看保留打开时快照，电脑应手不改快照，复制由点击触发且完整', (tester) async {
    desktop(tester);
    final engine = DelayedAi();
    final game = GameController(store: MemoryStore(), engine: engine);
    await game.initialize();
    final pending = game.play(const Move(54, 45));
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tapVisible(tester, '回看棋局');
    expect(find.byKey(const ValueKey('review-two-columns')), findsOneWidget);
    final review = tester.widget<GameReviewDialog>(
      find.byType(GameReviewDialog),
    );
    expect(review.record.moves.length, 1);
    engine.answer.complete(engine.received!.legalMoves().first);
    await pending;
    await tester.pumpAndSettle();
    expect(game.ply, 2);
    expect(find.text('回看棋局 · 第 1 步 / 共 1 步'), findsOneWidget);
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard).last).position.key,
      review.record.positions.last.key,
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    expect(copied, isNull);
    await tapVisible(tester, '复制完整棋谱');
    expect(copied, review.record.toText());
    expect(copied, contains('第 1 步'));
    expect(copied, isNot(contains('第 2 步')));
    await tapVisible(tester, '开局');
    expect(find.text('回看棋局 · 第 0 步 / 共 1 步'), findsOneWidget);
    await tapVisible(tester, '最后一步');
    await tester.ensureVisible(find.byKey(const ValueKey('review-step-1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('review-step-1')))
          .selected,
      isTrue,
    );
    await tapVisible(tester, '回到棋桌');
    expect(game.ply, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('棋盘思考中仍可导航但不能落子；建议与实际上一着分开', (tester) async {
    desktop(tester);
    final engine = DelayedThenImmediateAi();
    final game = GameController(store: MemoryStore(), engine: engine);
    await game.initialize();
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.enter);
    expect(game.busy, isTrue);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(cursorLabel(tester), startsWith('6行2列'));
    await press(tester, LogicalKeyboardKey.enter);
    expect(game.ply, 1);
    engine.answer.complete(engine.received!.legalMoves().first);
    await tester.pumpAndSettle();
    await tapVisible(tester, '帮我想想');
    final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(board.lastMove, game.lastMove);
    expect(board.suggestionMove, isNotNull);
    expect(find.textContaining('电脑刚走：'), findsOneWidget);
    expect(find.textContaining('建议：'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('窄屏大字回看与复制失败可恢复，长棋谱按需构建并任意跳转', (tester) async {
    desktop(tester, size: const Size(360, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final positions = [Position.initial()], moves = <Move>[];
    const cycle = [Move(82, 63), Move(1, 18), Move(63, 82), Move(18, 1)];
    for (var i = 0; i < 200; i++) {
      final move = cycle[i % cycle.length];
      moves.add(move);
      positions.add(positions.last.play(move));
    }
    final record = GameRecord.fromHistory(
      positions: positions,
      moves: moves,
      playerSide: Side.red,
      level: 2,
      outcome: Outcome.playing,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => GameReviewDialog(
                  record: record,
                  boardBuilder: (position, lastMove) => ChessBoard(
                    position: position,
                    selected: null,
                    targets: const {},
                    lastMove: lastMove,
                    onTap: (_) => fail('只读棋盘不得落子'),
                    enabled: false,
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tapVisible(tester, '打开');
    expect(find.text('200 / 200 步'), findsOneWidget);
    expect(find.byType(ListTile).evaluate().length, lessThan(20));
    await tester.ensureVisible(find.byKey(const ValueKey('review-move-list')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('review-step-196')),
      -100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('review-move-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('review-step-196'))),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('review-move-list')),
    );
    final listOffset = list.controller!.offset;
    await tester.tap(find.byKey(const ValueKey('review-step-196')));
    await tester.pumpAndSettle();
    expect(find.text('196 / 200 步'), findsOneWidget);
    expect(list.controller!.offset, listOffset);
    final reviewViewport = tester.getRect(
      find.byKey(const ValueKey('review-content')),
    );
    final reviewedBoard = tester.getRect(find.byType(ChessBoard).last);
    expect(reviewedBoard.top, greaterThanOrEqualTo(reviewViewport.top));
    expect(reviewedBoard.bottom, lessThanOrEqualTo(reviewViewport.bottom));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tapVisible(tester, '复制完整棋谱');
    expect(find.text('暂时无法复制棋谱，请稍后再试。'), findsOneWidget);
    await tapVisible(tester, '回到棋桌');
    expect(find.byType(GameReviewDialog), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('新局裁决失败保留翻转和建议；同一步数新局成功清除旧建议', (tester) async {
    desktop(tester);
    final rules = RestartFailureRules();
    final game = GameController(
      store: MemoryStore(),
      engine: ImmediateAi(),
      rules: rules,
    );
    await game.initialize();
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tapVisible(tester, '帮我想想');
    await tapVisible(tester, '翻转棋盘');
    final boardBefore = tester.widget<ChessBoard>(find.byType(ChessBoard));
    final positionBefore = game.position;
    expect(boardBefore.flipped, isTrue);
    expect(boardBefore.suggestionMove, isNotNull);
    await tapVisible(tester, '重新开始');
    await tapVisible(tester, '我执黑，后走');
    rules.failRestart = true;
    await tester.tap(find.widgetWithText(FilledButton, '重新开始').last);
    await tester.pumpAndSettle();
    final failedBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(identical(game.position, positionBefore), isTrue);
    expect(game.playerSide, Side.red);
    expect(failedBoard.flipped, boardBefore.flipped);
    expect(failedBoard.selected, boardBefore.selected);
    expect(failedBoard.suggestionMove, boardBefore.suggestionMove);
    rules.failRestart = false;
    await tapVisible(tester, '重新开始');
    await tester.tap(find.widgetWithText(FilledButton, '重新开始').last);
    await tester.pumpAndSettle();
    final freshBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(game.ply, 0);
    expect(identical(game.position, positionBefore), isFalse);
    expect(freshBoard.flipped, isFalse);
    expect(freshBoard.selected, isNull);
    expect(freshBoard.suggestionMove, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
