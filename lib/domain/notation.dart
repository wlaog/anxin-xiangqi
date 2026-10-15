import 'xiangqi.dart';

const initialFen =
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

Position fromFen(String text) {
  final fields = text.split(' '), rows = text.split(' ').first.split('/');
  if (rows.length != 10 ||
      fields.length < 2 ||
      !['w', 'b'].contains(fields[1])) {
    throw const FormatException('棋盘格式错误');
  }
  const names = {
    'k': Kind.king,
    'a': Kind.advisor,
    'b': Kind.elephant,
    'n': Kind.horse,
    'r': Kind.rook,
    'c': Kind.cannon,
    'p': Kind.pawn,
  };
  final board = <Piece?>[];
  for (final row in rows) {
    final start = board.length;
    for (final symbol in row.split('')) {
      final count = int.tryParse(symbol);
      if (count != null && count > 0 && count <= 9) {
        board.addAll(List.filled(count, null));
      } else if (names.containsKey(symbol.toLowerCase())) {
        board.add(
          Piece(
            symbol == symbol.toUpperCase() ? Side.red : Side.black,
            names[symbol.toLowerCase()]!,
          ),
        );
      } else {
        throw const FormatException('未知棋子');
      }
    }
    if (board.length - start != 9) throw const FormatException('棋盘宽度错误');
  }
  return Position(
    board,
    turn: fields[1] == 'w' ? Side.red : Side.black,
    quietPly: fields.length >= 5 ? int.parse(fields[4]) : 0,
  );
}

String squareName(int square) =>
    '${String.fromCharCode(97 + square % 9)}${9 - square ~/ 9}';
String moveName(Move move) => '${squareName(move.from)}${squareName(move.to)}';
Move parseMove(String text) {
  if (!RegExp(r'^[a-i][0-9][a-i][0-9]$').hasMatch(text)) {
    throw const FormatException('无效走法');
  }
  int at(int offset) =>
      (9 - int.parse(text[offset + 1])) * 9 + text.codeUnitAt(offset) - 97;
  return Move(at(0), at(2));
}

String toFen(Position position) {
  const names = {
    Kind.king: 'k',
    Kind.advisor: 'a',
    Kind.elephant: 'b',
    Kind.horse: 'n',
    Kind.rook: 'r',
    Kind.cannon: 'c',
    Kind.pawn: 'p',
  };
  final rows = <String>[];
  for (var row = 0; row < 10; row++) {
    var line = '', empty = 0;
    for (var col = 0; col < 9; col++) {
      final piece = position.board[row * 9 + col];
      if (piece == null) {
        empty++;
        continue;
      }
      if (empty > 0) {
        line += '$empty';
        empty = 0;
      }
      final name = names[piece.kind]!;
      line += piece.side == Side.red ? name.toUpperCase() : name;
    }
    if (empty > 0) line += '$empty';
    rows.add(line);
  }
  return '${rows.join('/')} ${position.turn == Side.red ? 'w' : 'b'} - - ${position.quietPly} 1';
}
