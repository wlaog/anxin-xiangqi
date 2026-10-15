import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/application/study_notebook.dart';
import 'package:anxin_xiangqi/application/user_preferences.dart';
import 'package:anxin_xiangqi/domain/notation.dart';
import 'package:anxin_xiangqi/domain/study.dart';
import 'package:anxin_xiangqi/main.dart';
import 'package:anxin_xiangqi/presentation/study_dialog.dart';
import 'package:anxin_xiangqi/presentation/game_review.dart';
import 'package:anxin_xiangqi/infrastructure/audio_feedback.dart';

import 'controller_test.dart' show MemoryStore, ImmediateAi, DelayedAi;
import 'experience_test.dart' show desktop;

Future<void> tapVisible(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapStudySquare(WidgetTester tester, int square) async {
  final finder = find.byType(ChessBoard).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final widget = tester.widget<ChessBoard>(finder);
  final rect = tester.getRect(finder), cell = rect.width / 9;
  final visual = widget.flipped ? 89 - square : square;
  await tester.tapAt(
    rect.topLeft + Offset((visual % 9 + .5) * cell, (visual ~/ 9 + .5) * cell),
  );
  await tester.pumpAndSettle();
}

Future<void> studyHarness(
  WidgetTester tester,
  GameController game,
  StudyNotebook notebook, {
  double scale = 1,
}) async {
  await notebook.initialize();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 22),
          titleLarge: TextStyle(fontSize: 28),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(56, 60),
            textStyle: const TextStyle(fontSize: 22),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(56, 60),
            textStyle: const TextStyle(fontSize: 22),
          ),
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => StudyDialog(game: game, notebook: notebook),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('实盘入口可到练习区，教程答错再练/答对保存；不改变实盘', (tester) async {
    desktop(tester);
    final progress = MemoryStore();
    final notebook = StudyNotebook(progress);
    addTearDown(notebook.dispose);
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    addTearDown(game.dispose);
    await game.initialize();
    await tester.pumpWidget(AnxinApp(controller: game, notebook: notebook));
    await tester.pumpAndSettle();
    await tapVisible(tester, '练习与研究');
    await tapVisible(tester, '互动教程');
    await tapVisible(tester, '兵：向前不过退');
    await tapStudySquare(tester, 56);
    await tapStudySquare(tester, 47);
    expect(find.textContaining('还没有达到题目目标'), findsOneWidget);
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard).last).position.key,
      game.position.key,
    );
    await tapVisible(tester, '错题再练');
    expect(find.text('兵：向前不过退'), findsWidgets);
    await tapVisible(tester, '兵：向前不过退');
    await tapStudySquare(tester, 54);
    await tapStudySquare(tester, 45);
    expect(find.textContaining('完成了！'), findsOneWidget);
    expect(game.ply, 0);
    await tapVisible(tester, '再做一次');
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard).last).position.key,
      game.position.key,
    );
    await tapVisible(tester, '返回');
    expect(find.byType(StudyDialog), findsNothing);
    final data = progress.data;
    expect(data, contains('"done":true'));
    expect(data, contains('"retry":false'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('真实棋盘分支试走、保存、继续、导出导入与简洁复盘', (tester) async {
    desktop(tester);
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    final notebook = StudyNotebook(MemoryStore());
    addTearDown(game.dispose);
    addTearDown(notebook.dispose);
    await game.initialize();
    await studyHarness(tester, game, notebook);
    await tapStudySquare(tester, 54);
    await tapStudySquare(tester, 45);
    await tapVisible(tester, '回退一步');
    await tapStudySquare(tester, 56);
    await tapStudySquare(tester, 47);
    await tapVisible(tester, '保存研究');
    var stored = StudyTree.fromJson(notebook.draft, game.rules);
    expect(stored.children(0), hasLength(2));
    final original = stored.session.history.last.key;
    await tapVisible(tester, '回到开头');
    expect(find.textContaining('路线 1：'), findsOneWidget);
    expect(find.textContaining('路线 2：'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('路线 1：'));
    await tester.tap(find.textContaining('路线 1：'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChessBoard>(find.byType(ChessBoard).last)
          .position
          .board[45],
      isNotNull,
    );
    await tapVisible(tester, '继续研究');
    await tapVisible(tester, '换一份');
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard).last).position.key,
      original,
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = call.arguments['text'];
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tapVisible(tester, '导出棋谱');
    await tapVisible(tester, '复制完整研究');
    expect(importStudy(copied!, game.rules).children(0), hasLength(2));
    await tapVisible(tester, '返回');
    await tapVisible(tester, '导入棋谱');
    await tester.enterText(
      find.byKey(const ValueKey('study-import-text')),
      'a3a9',
    );
    await tapVisible(tester, '检查并导入');
    expect(find.textContaining('未导入'), findsOneWidget);
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard).last).position.key,
      original,
    );
    await tapVisible(tester, '导入棋谱');
    await tester.enterText(
      find.byKey(const ValueKey('study-import-text')),
      copied!,
    );
    await tapVisible(tester, '检查并导入');
    await tapVisible(tester, '换一份');
    await tapVisible(tester, '简洁复盘');
    expect(find.textContaining('只看当前这条路线'), findsOneWidget);
    await tapVisible(tester, '开局');
    expect(find.textContaining('起始局面，红方先走'), findsOneWidget);
    await tapVisible(tester, '返回研究');
    expect(find.byType(GameReviewDialog), findsNothing);
    expect(game.ply, 0);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(360, 800), const Size(640, 360)]) {
    testWidgets('大字 $size 下选题、摆棋、错误提示、导入取消与返回可达', (tester) async {
      desktop(tester, size: size);
      final game = GameController(store: MemoryStore(), engine: ImmediateAi());
      final notebook = StudyNotebook(MemoryStore());
      addTearDown(game.dispose);
      addTearDown(notebook.dispose);
      await game.initialize();
      await studyHarness(tester, game, notebook, scale: 2.8);
      await tapVisible(tester, '原创残局');
      await tapVisible(tester, '双车封住宫门');
      await tapVisible(tester, '看提示');
      expect(find.textContaining('一辆车封住退路'), findsOneWidget);
      await tapVisible(tester, '摆棋');
      await tapVisible(tester, '只留将帅');
      await tapVisible(tester, '开始试走');
      expect(find.textContaining('将帅是否照面'), findsOneWidget);
      await tapVisible(tester, '标准摆法');
      await tapVisible(tester, '开始试走');
      expect(find.textContaining('局面检查通过'), findsOneWidget);
      await tapVisible(tester, '导入棋谱');
      await tapVisible(tester, '取消');
      await tapVisible(tester, '返回');
      expect(find.byType(StudyDialog), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
  testWidgets('关闭研究后迟到的建议不改实盘', (tester) async {
    desktop(tester);
    final ai = DelayedAi();
    final game = GameController(store: MemoryStore(), engine: ai);
    final notebook = StudyNotebook(MemoryStore());
    addTearDown(game.dispose);
    addTearDown(notebook.dispose);
    await game.initialize();
    await studyHarness(tester, game, notebook);
    await tester.ensureVisible(find.text('电脑建议'));
    await tester.tap(find.text('电脑建议'));
    await tester.pump();
    await tapVisible(tester, '返回');
    ai.answer.complete(parseMove('a3a4'));
    await tester.pumpAndSettle();
    expect(game.ply, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('研究保存失败可重试，替换旧研究可取消', (tester) async {
    desktop(tester);
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    final store = MemoryStore();
    final notebook = StudyNotebook(store);
    addTearDown(game.dispose);
    addTearDown(notebook.dispose);
    await game.initialize();
    await notebook.initialize();
    final original = importStudy('a3a4', game.rules);
    await notebook.saveDraft(original);
    await studyHarness(tester, game, notebook);
    await tapStudySquare(tester, 56);
    await tapStudySquare(tester, 47);
    await tapVisible(tester, '保存研究');
    await tapVisible(tester, '取消');
    expect(
      StudyTree.fromJson(notebook.draft, game.rules).session.moves,
      original.session.moves,
    );
    store.fail = true;
    await tapVisible(tester, '保存研究');
    await tapVisible(tester, '替换');
    expect(find.textContaining('暂时未能完成'), findsOneWidget);
    expect(
      StudyTree.fromJson(notebook.draft, game.rules).session.moves,
      original.session.moves,
    );
    store.fail = false;
    await tapVisible(tester, '保存研究');
    await tapVisible(tester, '替换');
    expect(
      StudyTree.fromJson(notebook.draft, game.rules).session.moves.single,
      parseMove('c3c4'),
    );
    expect(game.ply, 0);
  });
  testWidgets('声音偏好保存并提供试听入口，故障仍可继续下棋', (tester) async {
    desktop(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AudioFeedback.channel,
      (_) async => false,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AudioFeedback.channel,
        null,
      ),
    );
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    addTearDown(game.dispose);
    await game.initialize();
    await tester.pumpWidget(AnxinApp(controller: game));
    await tester.pumpAndSettle();
    await tapVisible(tester, '使用设置');
    await tapVisible(tester, '走棋提示音');
    await tapVisible(tester, '语音报棋');
    expect(game.preferences.sound, true);
    expect(game.preferences.speech, true);
    await tapVisible(tester, '试听声音');
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('声音未能播放'),
      ),
      findsOneWidget,
    );
    await tapVisible(tester, '设置好了');
    await game.play(parseMove('a3a4'));
    await tester.pumpAndSettle();
    expect(game.ply, 2);
    expect(find.textContaining('声音未能播放'), findsWidgets);
    await game.setPreferences(const UserPreferences());
  });
}
