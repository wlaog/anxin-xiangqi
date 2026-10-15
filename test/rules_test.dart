import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/domain/ai.dart';

Position setup(Map<int, Piece> pieces, {Side turn = Side.red, int quiet = 0}) {
  final board = List<Piece?>.filled(90, null);
  for (final entry in pieces.entries) {
    board[entry.key] = entry.value;
  }
  return Position(board, turn: turn, quietPly: quiet);
}

const rk = Piece(Side.red, Kind.king), bk = Piece(Side.black, Kind.king);
const rp = Piece(Side.red, Kind.pawn), bp = Piece(Side.black, Kind.pawn);
const rr = Piece(Side.red, Kind.rook);
int perft(Position p, int depth) => depth == 0
    ? 1
    : p.legalMoves().fold(
        0,
        (n, m) => n + perft(p.applyUnchecked(m), depth - 1),
      );

void main() {
  test('初始布局与公开 perft 计数一致（1–3 层）', () {
    final p = Position.initial();
    expect(p.board.whereType<Piece>().length, 32);
    expect(p.board[19]?.kind, Kind.cannon);
    expect(p.board[70]?.kind, Kind.cannon);
    expect(perft(p, 1), 44);
    expect(perft(p, 2), 1920);
    expect(perft(p, 3), 79666);
  });
  test('兵过河前只进，过河后可以平移但不能后退', () {
    final a = Position.initial()
        .legalMoves()
        .where((m) => m.from == 54)
        .map((m) => m.to);
    expect(a, [45]);
    final p = setup({4: bk, 85: rk, 40: rp, 49: rp});
    expect(p.legalMoves().where((m) => m.from == 40).map((m) => m.to).toSet(), {
      31,
      39,
      41,
    });
  });
  test('马腿与象眼，象不能过河', () {
    final horse = setup({
      4: bk,
      85: rk,
      49: rp,
      76: const Piece(Side.red, Kind.horse),
      67: rp,
    });
    expect(horse.legalMoves(), isNot(contains(const Move(76, 57))));
    expect(horse.legalMoves(), contains(const Move(76, 65)));
    final elephant = setup({
      4: bk,
      85: rk,
      49: rp,
      47: const Piece(Side.red, Kind.elephant),
      55: rp,
    });
    expect(elephant.legalMoves(), isNot(contains(const Move(47, 63))));
    expect(elephant.legalMoves(), isNot(contains(const Move(47, 31))));
    expect(elephant.legalMoves(), contains(const Move(47, 67)));
  });
  test('炮吃子必须恰好隔一个炮架', () {
    Position cannon(Map<int, Piece> extra) => setup({
      4: bk,
      85: rk,
      49: rp,
      64: const Piece(Side.red, Kind.cannon),
      19: bp,
      ...extra,
    });
    expect(cannon({}).legalMoves(), isNot(contains(const Move(64, 19))));
    expect(cannon({46: rp}).legalMoves(), contains(const Move(64, 19)));
    expect(cannon({46: rp}).legalMoves(), isNot(contains(const Move(64, 28))));
    expect(
      cannon({46: rp, 37: rp}).legalMoves(),
      isNot(contains(const Move(64, 19))),
    );
  });
  test('不能送将或使将帅照面', () {
    final p = setup({4: bk, 85: rk, 76: rr});
    expect(p.inCheck(Side.red), false);
    expect(p.legalMoves(), isNot(contains(const Move(76, 75))));
    expect(setup({4: bk, 85: rk}).inCheck(Side.red), true);
    final attacked = setup({
      4: bk,
      85: rk,
      49: rp,
      81: const Piece(Side.black, Kind.rook),
    });
    expect(attacked.inCheck(Side.red), true);
    expect(attacked.legalMoves(), isNot(contains(const Move(85, 84))));
  });
  test('九宫限制与仕斜行', () {
    final p = setup({
      4: bk,
      85: rk,
      49: rp,
      75: const Piece(Side.red, Kind.advisor),
    });
    expect(p.legalMoves(), contains(const Move(75, 67)));
    expect(p.legalMoves(), isNot(contains(const Move(75, 65))));
    expect(
      p
          .legalMoves()
          .where((m) => m.from == 85)
          .every((m) => m.to ~/ 9 >= 7 && m.to % 9 >= 3 && m.to % 9 <= 5),
      true,
    );
  });
  test('困毙也判负，将死在未吃将时结束', () {
    final stalemate = setup({
      4: bk,
      85: rk,
      49: rp,
      12: rr,
      14: rr,
    }, turn: Side.black);
    expect(stalemate.inCheck(Side.black), false);
    expect(stalemate.legalMoves(), isEmpty);
    expect(outcome([stalemate]), Outcome.redWins);
    final mate = setup({
      4: bk,
      85: rk,
      49: rp,
      12: rr,
      14: rr,
      22: rr,
    }, turn: Side.black);
    expect(mate.inCheck(Side.black), true);
    expect(outcome([mate]), Outcome.redWins);
    expect(LocalSearch().choose(mate), isNull);
  });
  test('基础规则不再仅凭重复棋盘判和，无吃子计数', () {
    final p = Position.initial();
    expect(outcome([p, p, p]), Outcome.playing);
    expect(outcome([Position(p.board, quietPly: 120)]), Outcome.quietDraw);
    final capture = setup({
      4: bk,
      85: rk,
      49: rp,
      64: rr,
      55: bp,
    }, quiet: 119).play(const Move(64, 55));
    expect(capture.quietPly, 0);
  });
  test('AI 返回合法走法，零预算也有合法备选', () {
    final p = Position.initial().play(const Move(54, 45));
    final clock = Stopwatch()..start();
    final engine = LocalSearch(
      maxDepth: 8,
      budget: const Duration(milliseconds: 100),
    );
    expect(p.legalMoves(), contains(engine.choose(p)));
    expect(clock.elapsedMilliseconds, lessThan(2000));
    expect(
      p.legalMoves(),
      contains(LocalSearch(budget: Duration.zero).choose(p)),
    );
  });
}
