import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/domain/notation.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/infrastructure/pikafish.dart';

void main() {
  // Mandatory in the Windows development/release workflow; never replaced by a mock.
  if (!Platform.isWindows) return;
  late PikafishRuntime native;
  setUpAll(() {
    native = PikafishRuntime(
      libraryPath:
          '${Directory.current.path}/native/bin/windows/anxin_pikafish.dll',
      networkPath: '${Directory.current.path}/assets/engine/pikafish.nnue',
    );
  });
  (List<Position>, List<Move>) replay(String fen, String record) {
    final history = [fromFen(fen)], moves = <Move>[];
    for (final text in record.split(' ').where((s) => s.isNotEmpty)) {
      final move = parseMove(text);
      expect(native.judge(history, moves).legal, contains(move), reason: text);
      history.add(history.last.play(move));
      moves.add(move);
    }
    return (history, moves);
  }

  test('FEN/UCI 双向对应，原生初始走法与二层 perft 一致', () {
    final p = Position.initial();
    expect(toFen(p), initialFen);
    expect(fromFen(initialFen).key, p.key);
    final legal = native.judge([p], []).legal;
    expect(legal.toSet(), p.legalMoves().toSet());
    expect(legal.length, 44);
    var nodes = 0;
    for (final move in legal) {
      nodes += native.judge([p, p.play(move)], [move]).legal.length;
      expect(parseMove(moveName(move)), move);
    }
    expect(nodes, 1920);
  });
  test('红方长将需变着，黑方正常应将不被禁', () {
    const fen = '4k4/3R5/9/9/4P4/9/9/9/9/4K4 w - - 0 1';
    final (h, m) = replay(fen, 'd8e8 e9d9 e8d8 d9e9');
    final verdict = native.judge(h, m);
    expect(verdict.result, Outcome.playing);
    expect(verdict.forbidden, contains(parseMove('d8e8')));
    expect(verdict.legal, isNot(contains(parseMove('d8e8'))));
    expect(verdict.legal, isNotEmpty);
    final (respond, record) = replay(fen, 'd8e8');
    expect(native.judge(respond, record).legal, contains(parseMove('e9d9')));
  });
  test('单方长捉需变着，双方允许的循环可以和棋', () {
    final (h, m) = replay(
      '5k3/9/4n4/9/3R5/4P4/9/9/9/4K4 w - - 0 1',
      'd5e5 e7d9 e5d5 d9e7',
    );
    expect(native.judge(h, m).forbidden, contains(parseMove('d5e5')));
    final (quiet, record) = replay(
      initialFen,
      'b0c2 b9c7 c2b0 c7b9 b0c2 b9c7 c2b0 c7b9',
    );
    expect(native.judge(quiet, record).result, Outcome.repetitionDraw);
  });
  test('跨多个真实行棋历史与 Dart 合法走法一致，裁决可重复调用', () {
    final random = Random(2048);
    for (var game = 0; game < 3; game++) {
      final history = [Position.initial()], moves = <Move>[];
      for (var ply = 0; ply < 90; ply++) {
        final verdict = native.judge(history, moves);
        if (verdict.result != Outcome.playing) break;
        expect({
          ...verdict.legal,
          ...verdict.forbidden,
        }, history.last.legalMoves().toSet());
        expect(native.judge(history, moves).legal, verdict.legal);
        final move = verdict.legal[random.nextInt(verdict.legal.length)];
        history.add(history.last.play(move));
        moves.add(move);
      }
    }
  });
  test('实际 NNUE 五档都返回合法着法，强档可将死，思考不阻塞事件循环', () async {
    final p = Position.initial();
    for (var level = 1; level <= 5; level++) {
      var yielded = false;
      final pending = native.chooseGame([p], [], level);
      await Future<void>.delayed(
        const Duration(milliseconds: 10),
        () => yielded = true,
      );
      final move = await pending;
      expect(yielded, true);
      expect(p.legalMoves(), contains(move));
    }
    final mate = fromFen('3k5/2R1R4/9/9/4P4/9/9/9/9/4K4 w - - 0 1');
    final winning = await native.choose(mate, 5);
    expect(winning, isNotNull);
    expect(
      native.judge([mate, mate.play(winning!)], [winning]).result,
      Outcome.redWins,
    );
  }, timeout: const Timeout(Duration(seconds: 40)));
}
