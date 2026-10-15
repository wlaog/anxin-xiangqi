enum Side {
  red,
  black;

  Side get opposite => this == red ? black : red;
}

enum Kind { king, advisor, elephant, horse, rook, cannon, pawn }

class Piece {
  const Piece(this.side, this.kind);
  final Side side;
  final Kind kind;
  String get label => (side == Side.red
      ? ['帅', '仕', '相', '马', '车', '炮', '兵']
      : ['将', '士', '象', '馬', '車', '砲', '卒'])[kind.index];
}

class Move {
  const Move(this.from, this.to);
  final int from;
  final int to;
  @override
  bool operator ==(Object other) =>
      other is Move && from == other.from && to == other.to;
  @override
  int get hashCode => Object.hash(from, to);
  List<int> toJson() => [from, to];
}

/// Row 0 is Black's home rank. Red moves toward decreasing row indices.
class Position {
  Position(List<Piece?> board, {this.turn = Side.red, this.quietPly = 0})
    : board = List.unmodifiable(board) {
    if (board.length != 90) throw ArgumentError('棋盘必须有 90 个位置');
  }
  final List<Piece?> board;
  final Side turn;
  final int quietPly;

  factory Position.initial() {
    final board = List<Piece?>.filled(90, null);
    const back = [
      Kind.rook,
      Kind.horse,
      Kind.elephant,
      Kind.advisor,
      Kind.king,
      Kind.advisor,
      Kind.elephant,
      Kind.horse,
      Kind.rook,
    ];
    for (var col = 0; col < 9; col++) {
      board[col] = Piece(Side.black, back[col]);
      board[81 + col] = Piece(Side.red, back[col]);
    }
    for (final col in [1, 7]) {
      board[18 + col] = const Piece(Side.black, Kind.cannon);
      board[63 + col] = const Piece(Side.red, Kind.cannon);
    }
    for (final col in [0, 2, 4, 6, 8]) {
      board[27 + col] = const Piece(Side.black, Kind.pawn);
      board[54 + col] = const Piece(Side.red, Kind.pawn);
    }
    return Position(board);
  }

  String get key =>
      '${turn.index}:${board.map((p) => p == null ? '.' : String.fromCharCode(65 + p.kind.index + p.side.index * 7)).join()}';

  bool _palace(int row, int col, Side side) =>
      col >= 3 &&
      col <= 5 &&
      (side == Side.red ? row >= 7 && row <= 9 : row >= 0 && row <= 2);

  Iterable<int> _targets(int from) sync* {
    final piece = board[from];
    if (piece == null) return;
    final row = from ~/ 9, col = from % 9;
    if (piece.kind == Kind.rook || piece.kind == Kind.cannon) {
      for (final d in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        var screened = false;
        for (
          var r = row + d.$1, c = col + d.$2;
          r >= 0 && r < 10 && c >= 0 && c < 9;
          r += d.$1, c += d.$2
        ) {
          final to = r * 9 + c, occupant = board[to];
          if (piece.kind == Kind.rook) {
            if (occupant?.side != piece.side) yield to;
            if (occupant != null) break;
          } else if (!screened) {
            if (occupant == null) {
              yield to;
            } else {
              screened = true;
            }
          } else if (occupant != null) {
            if (occupant.side != piece.side) yield to;
            break;
          }
        }
      }
      return;
    }
    final offsets = switch (piece.kind) {
      Kind.king => [(1, 0), (-1, 0), (0, 1), (0, -1)],
      Kind.advisor => [(1, 1), (1, -1), (-1, 1), (-1, -1)],
      Kind.elephant => [(2, 2), (2, -2), (-2, 2), (-2, -2)],
      Kind.horse => [
        (2, 1),
        (2, -1),
        (-2, 1),
        (-2, -1),
        (1, 2),
        (-1, 2),
        (1, -2),
        (-1, -2),
      ],
      Kind.pawn => [
        if (piece.side == Side.red) (-1, 0) else (1, 0),
        if (piece.side == Side.red ? row <= 4 : row >= 5) ...[(0, 1), (0, -1)],
      ],
      _ => <(int, int)>[],
    };
    for (final d in offsets) {
      final r = row + d.$1, c = col + d.$2;
      if (r < 0 || r > 9 || c < 0 || c > 8) continue;
      if (board[r * 9 + c]?.side == piece.side) continue;
      if ((piece.kind == Kind.king || piece.kind == Kind.advisor) &&
          !_palace(r, c, piece.side)) {
        continue;
      }
      if (piece.kind == Kind.elephant) {
        if (piece.side == Side.red ? r < 5 : r > 4) continue;
        if (board[(row + d.$1 ~/ 2) * 9 + col + d.$2 ~/ 2] != null) continue;
      }
      if (piece.kind == Kind.horse) {
        final leg = d.$1.abs() == 2
            ? (row + d.$1.sign) * 9 + col
            : row * 9 + col + d.$2.sign;
        if (board[leg] != null) continue;
      }
      yield r * 9 + c;
    }
    // Flying generals attack one another across an otherwise empty file.
    if (piece.kind == Kind.king) {
      final step = piece.side == Side.red ? -1 : 1;
      for (var r = row + step; r >= 0 && r <= 9; r += step) {
        final target = board[r * 9 + col];
        if (target == null) continue;
        if (target.kind == Kind.king && target.side != piece.side) {
          yield r * 9 + col;
        }
        break;
      }
    }
  }

  bool inCheck(Side side) {
    final king = board.indexWhere(
      (p) => p?.side == side && p?.kind == Kind.king,
    );
    if (king == -1) return true;
    for (var from = 0; from < 90; from++) {
      if (board[from]?.side == side.opposite && _targets(from).contains(king)) {
        return true;
      }
    }
    return false;
  }

  List<Move> legalMoves() {
    if (!board.any((p) => p?.kind == Kind.king && p?.side == turn)) return [];
    final moves = <Move>[];
    for (var from = 0; from < 90; from++) {
      if (board[from]?.side != turn) continue;
      for (final to in _targets(from)) {
        final move = Move(from, to);
        if (!applyUnchecked(move).inCheck(turn)) moves.add(move);
      }
    }
    return moves;
  }

  Position play(Move move) {
    if (!legalMoves().contains(move)) throw ArgumentError('不合法的走法');
    return applyUnchecked(move);
  }

  /// Only for already-generated legal moves and internal search.
  Position applyUnchecked(Move move) {
    final next = List<Piece?>.of(board);
    final capture = next[move.to] != null;
    next[move.to] = next[move.from];
    next[move.from] = null;
    return Position(
      next,
      turn: turn.opposite,
      quietPly: capture ? 0 : quietPly + 1,
    );
  }
}

enum Outcome { playing, redWins, blackWins, repetitionDraw, quietDraw }

Outcome outcome(List<Position> history) {
  final current = history.last;
  // No legal move is a loss, including stalemate; it takes precedence over draws.
  if (current.legalMoves().isEmpty) {
    return current.turn == Side.red ? Outcome.blackWins : Outcome.redWins;
  }
  if (history.where((p) => p.key == current.key).length >= 3) {
    return Outcome.repetitionDraw;
  }
  if (current.quietPly >= 120) return Outcome.quietDraw;
  return Outcome.playing;
}
