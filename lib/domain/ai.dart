import 'xiangqi.dart';

abstract interface class AiEngine {
  Future<Move?> choose(Position position, int level);
}

class _Deadline implements Exception {}

/// Pure Dart, deterministic, bounded companion engine. Positive scores favor Red.
class LocalSearch {
  LocalSearch({
    this.maxDepth = 2,
    this.budget = const Duration(milliseconds: 700),
  });
  final int maxDepth;
  final Duration budget;
  final _clock = Stopwatch();
  var nodes = 0;
  static const values = [100000, 120, 120, 300, 600, 320, 70];

  int _evaluation(Position position) {
    var value = 0;
    for (var i = 0; i < 90; i++) {
      final p = position.board[i];
      if (p == null) continue;
      final progress = p.side == Side.red ? 9 - i ~/ 9 : i ~/ 9;
      var score = values[p.kind.index];
      if (p.kind == Kind.pawn) score += progress * 7 + (progress >= 5 ? 45 : 0);
      if (p.kind == Kind.horse || p.kind == Kind.cannon) {
        score += 4 - (i % 9 - 4).abs();
      }
      value += p.side == Side.red ? score : -score;
    }
    return position.turn == Side.red ? value : -value;
  }

  List<Move> _ordered(Position p) => p.legalMoves()
    ..sort((a, b) {
      int priority(Move m) => p.board[m.to] == null
          ? 0
          : values[p.board[m.to]!.kind.index] * 10 -
                values[p.board[m.from]!.kind.index];
      return priority(b).compareTo(priority(a));
    });

  int _search(Position p, int depth, int alpha, int beta, int ply) {
    nodes++;
    if (_clock.elapsed >= budget) throw _Deadline();
    final moves = _ordered(p);
    if (moves.isEmpty) return -1000000 + ply;
    if (p.quietPly >= 120) return 0;
    if (depth == 0) return _evaluation(p);
    for (final move in moves) {
      final value = -_search(
        p.applyUnchecked(move),
        depth - 1,
        -beta,
        -alpha,
        ply + 1,
      );
      if (value > alpha) alpha = value;
      if (alpha >= beta) break;
    }
    return alpha;
  }

  Move? choose(Position position) {
    _clock.reset();
    _clock.start();
    nodes = 0;
    final moves = _ordered(position);
    if (moves.isEmpty) return null;
    var best = moves.first;
    for (var depth = 1; depth <= maxDepth; depth++) {
      var candidate = best, score = -2000000;
      try {
        final ordered = [best, ...moves.where((m) => m != best)];
        for (final move in ordered) {
          final value = -_search(
            position.applyUnchecked(move),
            depth - 1,
            -2000000,
            -score,
            1,
          );
          if (value > score) {
            score = value;
            candidate = move;
          }
        }
        best = candidate;
      } on _Deadline {
        break;
      }
    }
    _clock.stop();
    return best;
  }
}
