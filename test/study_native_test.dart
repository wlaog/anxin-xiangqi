import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/domain/lessons.dart';
import 'package:anxin_xiangqi/domain/notation.dart';
import 'package:anxin_xiangqi/domain/study.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/infrastructure/pikafish.dart';

void main() {
  if (!Platform.isWindows) return;
  test('真实 Pikafish 校验全部原创小题、分支往返和自定义局面建议', () async {
    final native = PikafishRuntime(
      libraryPath:
          '${Directory.current.path}/native/bin/windows/anxin_pikafish.dll',
      networkPath: '${Directory.current.path}/assets/engine/pikafish.nnue',
    );
    for (final lesson in lessons) {
      final tree = StudyTree(lesson.position, native);
      expect(tree.session.verdict.result, Outcome.playing, reason: lesson.id);
      final answers = tree.session.verdict.legal
          .where((m) => lesson.accepts(lesson.position, m))
          .toList();
      expect(answers, isNotEmpty, reason: lesson.id);
      for (final move in answers) {
        tree.jump(0);
        tree.play(move);
        if (lesson.group == LessonGroup.endgame) {
          expect(
            tree.session.verdict.result,
            lesson.position.turn == Side.red
                ? Outcome.redWins
                : Outcome.blackWins,
            reason: lesson.id,
          );
        }
      }
      final copy = importStudy(exportCoordinateLine(tree), native);
      expect(copy.session.history.last.key, tree.session.history.last.key);
    }
    final tree = StudyTree(lessons.first.position, native);
    final suggestion = await native.chooseGame(
      tree.session.history,
      tree.session.moves,
      1,
    );
    expect(tree.session.verdict.legal, contains(suggestion));
    tree.play(suggestion!);
    tree.jump(0);
    final other = tree.session.verdict.legal.firstWhere((m) => m != suggestion);
    tree.play(other);
    expect(tree.children(0), hasLength(2));
    final standard = importStudy('a3a4 a6a5', native);
    standard.jump(1);
    standard.play(parseMove('c6c5'));
    expect(standard.children(1), hasLength(2));
  });
}
