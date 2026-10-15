import 'xiangqi.dart';

/// A captured game for reading and exporting, not another rules referee.
class GameRecord {
  GameRecord._({
    required this.positions,
    required this.moves,
    required this.playerSide,
    required this.level,
    required this.outcome,
    required this.entries,
  });

  factory GameRecord.fromHistory({
    required List<Position> positions,
    required List<Move> moves,
    required Side playerSide,
    required int level,
    required Outcome outcome,
  }) {
    if (level < 1 || level > 5) {
      throw ArgumentError.value(level, 'level', '难度须为一至五档');
    }
    if (positions.length != moves.length + 1) {
      throw ArgumentError('每步走法须有走前与走后的棋盘');
    }
    final boards = List<Position>.unmodifiable(positions);
    final steps = List<Move>.unmodifiable(moves);
    final entries = <GameRecordEntry>[];
    for (var i = 0; i < steps.length; i++) {
      final before = boards[i], after = boards[i + 1], move = steps[i];
      if (move.from < 0 || move.from >= 90 || move.to < 0 || move.to >= 90) {
        throw ArgumentError('第 ${i + 1} 步的位置超出棋盘');
      }
      // Use the existing board-movement rules; historical adjudication remains
      // the controller's RuleBook responsibility, including check/chase cycles.
      if (!before.legalMoves().contains(move)) {
        throw ArgumentError('第 ${i + 1} 步不是该棋盘的合法走法');
      }
      final expected = before.applyUnchecked(move);
      if (!_samePosition(expected, after)) {
        throw ArgumentError('第 ${i + 1} 步与对应棋盘不一致');
      }
      entries.add(GameRecordEntry._fromValidated(before, move, i + 1));
    }
    return GameRecord._(
      positions: boards,
      moves: steps,
      playerSide: playerSide,
      level: level,
      outcome: outcome,
      entries: List.unmodifiable(entries),
    );
  }

  final List<Position> positions;
  final List<Move> moves;
  final Side playerSide;
  final int level;
  final Outcome outcome;
  final List<GameRecordEntry> entries;

  /// Human-readable text; no interchange-format compatibility is implied.
  String toText() {
    final result = switch (outcome) {
      Outcome.playing => '棋局尚未结束',
      Outcome.redWins => '红方胜',
      Outcome.blackWins => '黑方胜',
      Outcome.repetitionDraw => '和棋',
      Outcome.quietDraw => '久未吃子，和棋',
    };
    final text = StringBuffer('安心象棋棋谱\n')
      ..writeln(
        '您执${playerSide == Side.red ? '红' : '黑'}棋；电脑执${playerSide == Side.red ? '黑' : '红'}棋。',
      )
      ..writeln('陪练难度：${['入门', '轻松', '日常', '挑战', '高手'][level - 1]}（第 $level 档）')
      ..writeln('结果：$result')
      ..writeln('位置均按走棋一方看：从右向左数路，从己方底线向前数行。');
    if (entries.isEmpty) {
      text.writeln('尚未走棋。');
    } else {
      for (final entry in entries) {
        text
          ..writeln(
            '第 ${entry.ply} 步　${_sideName(entry.side)}：${entry.notation}',
          )
          ..writeln(entry.description);
      }
    }
    return text.toString();
  }
}

class GameRecordEntry {
  const GameRecordEntry._({
    required this.ply,
    required this.side,
    required this.move,
    required this.notation,
    required this.description,
    required this.captured,
  });

  factory GameRecordEntry.fromMove({
    required Position before,
    required Move move,
    required int ply,
  }) {
    if (ply < 1) throw ArgumentError.value(ply, 'ply', '步数须从一开始');
    if (!before.legalMoves().contains(move)) {
      throw ArgumentError('该棋盘没有这步合法走法');
    }
    return GameRecordEntry._fromValidated(before, move, ply);
  }

  factory GameRecordEntry._fromValidated(Position before, Move move, int ply) {
    final piece = before.board[move.from]!;
    final captured = before.board[move.to];
    return GameRecordEntry._(
      ply: ply,
      side: piece.side,
      move: move,
      notation: _notation(before, move, piece),
      description:
          '${_sideName(piece.side)}${piece.label}从${_point(move.from, piece.side)}，'
          '走到${_point(move.to, piece.side)}'
          '${captured == null ? '。' : '，吃掉${_sideName(captured.side)}${captured.label}。'}',
      captured: captured,
    );
  }

  final int ply;
  final Side side;
  final Move move;
  final String notation;
  final String description;
  final Piece? captured;
}

bool _samePosition(Position a, Position b) {
  if (a.turn != b.turn || a.quietPly != b.quietPly) return false;
  for (var i = 0; i < 90; i++) {
    if (a.board[i]?.side != b.board[i]?.side ||
        a.board[i]?.kind != b.board[i]?.kind) {
      return false;
    }
  }
  return true;
}

String _sideName(Side side) => side == Side.red ? '红方' : '黑方';
int _file(int square, Side side) =>
    side == Side.red ? 9 - square % 9 : square % 9 + 1;
String _number(int number, Side side) =>
    side == Side.red ? '一二三四五六七八九'[number - 1] : '$number';
String _point(int square, Side side) =>
    '己方右起第${_file(square, side)}路、底线起第${side == Side.red ? 10 - square ~/ 9 : square ~/ 9 + 1}行';

String _notation(Position before, Move move, Piece piece) {
  final peers = <int>[];
  final fileCounts = <int, int>{};
  for (var i = 0; i < 90; i++) {
    if (before.board[i]?.side == piece.side &&
        before.board[i]?.kind == piece.kind) {
      fileCounts.update(i % 9, (count) => count + 1, ifAbsent: () => 1);
      if (i % 9 == move.from % 9) peers.add(i);
    }
  }
  String subject;
  if (peers.length == 1) {
    subject =
        '${piece.label}${_number(_file(move.from, piece.side), piece.side)}';
  } else if (peers.length == 2 &&
      fileCounts.values.where((count) => count > 1).length == 1) {
    // Row zero is toward Red's front and Black's rear.
    final front = piece.side == Side.red ? peers.first : peers.last;
    subject = '${move.from == front ? '前' : '后'}${piece.label}';
  } else {
    // Multiple stacked pawns and unusual custom positions have several
    // competing notation conventions. Keep every source square explicit.
    return '${piece.label}（从${_point(move.from, piece.side)}至${_point(move.to, piece.side)}）';
  }
  final rowDifference = move.to ~/ 9 - move.from ~/ 9;
  if (rowDifference == 0) {
    return '$subject平${_number(_file(move.to, piece.side), piece.side)}';
  }
  final forward = piece.side == Side.red
      ? rowDifference < 0
      : rowDifference > 0;
  final destination = switch (piece.kind) {
    Kind.horse || Kind.advisor || Kind.elephant => _file(move.to, piece.side),
    _ => rowDifference.abs(),
  };
  return '$subject${forward ? '进' : '退'}${_number(destination, piece.side)}';
}
