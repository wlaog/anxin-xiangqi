import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/study_notebook.dart';
import 'package:anxin_xiangqi/domain/lessons.dart';
import 'package:anxin_xiangqi/domain/notation.dart';
import 'package:anxin_xiangqi/domain/rules.dart';
import 'package:anxin_xiangqi/domain/study.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';

import 'controller_test.dart' show MemoryStore;

void main() {
  test('全部原创小题有合法解，残局确实结束且战术目标有棋子', () {
    expect(lessons.length, 13);
    expect(lessons.map((l) => l.id).toSet().length, 13);
    for (final lesson in lessons) {
      final tree = StudyTree(lesson.position, BasicRules());
      expect(tree.session.verdict.result, Outcome.playing, reason: lesson.id);
      final answers = tree.session.verdict.legal
          .where((m) => lesson.accepts(lesson.position, m))
          .toList();
      expect(answers, isNotEmpty, reason: lesson.id);
      if (lesson.group == LessonGroup.endgame) {
        for (final move in answers) {
          tree.jump(0);
          tree.play(move);
          expect(
            tree.session.verdict.result,
            lesson.position.turn == Side.red
                ? Outcome.redWins
                : Outcome.blackWins,
          );
        }
      }
    }
  });
  test('非法摆棋在原生调用前拒绝：将帅、仕相、兵卒、数量与照面', () {
    for (final fen in [
      '9/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
      '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1',
      '4k4/9/9/9/4P4/9/9/9/9/A3K4 w - - 0 1',
      '4k4/9/9/9/4P4/9/9/9/9/1B2K4 w - - 0 1',
      '4k4/9/9/9/4P4/9/9/1P7/9/4K4 w - - 0 1',
      '4k4/9/9/9/4P4/9/9/RRR6/9/4K4 w - - 0 1',
      '4k4/9/9/9/4P4/9/9/9/9/4K4 w - - -1 1',
      '4k4/9/9/9/4P4/9/9/9/9/4K4 w - - 121 1',
    ]) {
      expect(() => parseStudyPosition(fen), throwsFormatException, reason: fen);
    }
    expect(parseStudyPosition('  $initialFen  ').key, Position.initial().key);
    // The side to move may be in check; the other side may not.
    expect(() => parseStudyPosition(lessons[5].fen), returnsNormally);
  });
  test('回退另走保留多层分支；完整研究与当前路线分别往返', () {
    final tree = importStudy('a3a4 a6a5 b2e2', BasicRules());
    final original = tree.session.history.last.key;
    tree.jump(1);
    tree.play(parseMove('c6c5'));
    tree.play(parseMove('b2e2'));
    final branch = tree.session.history.last.key;
    expect(tree.nodes.length, 5);
    expect(tree.children(1), [2, 4]);
    tree.jump(3);
    expect(tree.session.history.last.key, original);
    tree.jump(5);
    expect(tree.session.history.last.key, branch);
    final full = importStudy(jsonEncode(tree.toJson()), BasicRules());
    expect(full.toJson(), tree.toJson());
    final line = importStudy(exportCoordinateLine(tree), BasicRules());
    expect(line.session.history.last.key, branch);
    expect(line.nodes.length, 3);
    expect(tree.nodes, hasLength(5));
  });
  test('导入拒绝无效后续、分支环、重复节点、未知格式且原研究不变', () {
    final original = importStudy('a3a4', BasicRules());
    final before = jsonEncode(original.toJson());
    for (final text in [
      'a3a4 a6a5 a4a9',
      '炮二平五',
      '1. 7747',
      'a3a4 {comment}',
      'a3a4 * a6a5',
      '[SetUp "1"]\na3a4',
      '[Format "WXF"]\na3a4',
      '[SetUp "0"]\n[FEN "$initialFen"]\na3a4',
      '[FEN "$initialFen"]\n[FEN "$initialFen"]\na3a4',
      jsonEncode({
        ...original.toJson(),
        'nodes': [
          [1, 54, 45],
        ],
      }),
      jsonEncode({
        ...original.toJson(),
        'nodes': [
          [0, 54, 45],
          [0, 54, 45],
        ],
      }),
      jsonEncode({...original.toJson(), 'cursor': 2}),
      ' ' * (256 * 1024 + 1),
    ]) {
      expect(
        () => importStudy(text, BasicRules()),
        throwsA(isA<Exception>()),
        reason: text.length > 300 ? 'large input' : text,
      );
      expect(jsonEncode(original.toJson()), before);
    }
  });
  test('残局的自定义起始局面可导入导出，回看说明吃子和将军', () {
    final tree = StudyTree(lessons[2].position, BasicRules());
    final move = tree.session.verdict.legal.firstWhere(
      (m) => lessons[2].accepts(lessons[2].position, m),
    );
    tree.play(move);
    final copy = importStudy(exportCoordinateLine(tree), BasicRules());
    expect(copy.session.history.last.key, tree.session.history.last.key);
    expect(studySummary(copy.record, 0), contains('黑方先走'));
    expect(studySummary(copy.record, 1), contains('无合法走法'));
    final capture = StudyTree(lessons[3].position, BasicRules());
    capture.play(capture.session.verdict.legal.firstWhere((m) => m.to == 18));
    expect(studySummary(capture.record, 1), contains('吃掉黑方車'));
  });
  test('进度与完整分支保存、重开；失败不提交，损坏原档不覆盖', () async {
    final store = MemoryStore();
    final notebook = StudyNotebook(store);
    addTearDown(notebook.dispose);
    await notebook.initialize();
    await Future.wait([
      notebook.record('learn-rook', success: false),
      notebook.record('learn-horse', success: true),
    ]);
    expect(notebook.retry, {'learn-rook'});
    expect(notebook.completed, {'learn-horse'});
    final tree = importStudy('a3a4 a6a5', BasicRules());
    tree.jump(0);
    tree.play(parseMove('c3c4'));
    await notebook.saveDraft(tree);
    final reopened = StudyNotebook(store);
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(
      StudyTree.fromJson(reopened.draft, BasicRules()).toJson(),
      tree.toJson(),
    );
    store.fail = true;
    await expectLater(
      notebook.record('learn-rook', success: true),
      throwsStateError,
    );
    expect(notebook.retry, {'learn-rook'});
    store.fail = false;
    await notebook.record('learn-rook', success: true);
    expect(notebook.retry, isEmpty);
    expect(notebook.completed, {'learn-horse', 'learn-rook'});
    final bad = MemoryStore()..data = '{bad';
    final retained = StudyNotebook(bad);
    addTearDown(retained.dispose);
    await retained.initialize();
    await expectLater(retained.saveDraft(tree), throwsStateError);
    expect(bad.data, '{bad');
  });
}
