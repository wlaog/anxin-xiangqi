import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/domain/game_record.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';

Position board(Map<int, Piece> pieces, {Side turn = Side.red}) {
  final cells = List<Piece?>.filled(90, null);
  for (final entry in <int, Piece>{
    4: const Piece(Side.black, Kind.king),
    85: const Piece(Side.red, Kind.king),
    49: const Piece(Side.red, Kind.pawn),
    ...pieces,
  }.entries) {
    cells[entry.key] = entry.value;
  }
  return Position(cells, turn: turn);
}

GameRecord record(
  List<Position> positions,
  List<Move> moves, {
  Side playerSide = Side.red,
  int level = 2,
  Outcome outcome = Outcome.playing,
}) => GameRecord.fromHistory(
  positions: positions,
  moves: moves,
  playerSide: playerSide,
  level: level,
  outcome: outcome,
);

GameRecordEntry entry(Position p, Move move) =>
    record([p, p.play(move)], [move]).entries.single;

void main() {
  test('红黑各自朝向、平进退和斜行棋子使用正确路数', () {
    final red = Position.initial();
    final black = Position(red.board, turn: Side.black);
    expect(entry(red, const Move(70, 67)).notation, '炮二平五');
    expect(entry(black, const Move(19, 22)).notation, '砲2平5');
    expect(entry(red, const Move(81, 72)).notation, '车九进一');
    expect(entry(black, const Move(0, 9)).notation, '車1进1');
    expect(
      entry(
        board({72: const Piece(Side.red, Kind.rook)}),
        const Move(72, 81),
      ).notation,
      '车九退一',
    );
    expect(
      entry(
        board({9: const Piece(Side.black, Kind.rook)}, turn: Side.black),
        const Move(9, 0),
      ).notation,
      '車1退1',
    );
    expect(entry(red, const Move(82, 65)).notation, '马八进七');
    expect(entry(black, const Move(1, 20)).notation, '馬2进3');
    expect(entry(red, const Move(84, 76)).notation, '仕六进五');
    expect(entry(red, const Move(83, 63)).notation, '相七进九');
  });

  test('同路前后按走棋方朝向区分', () {
    final red = board({
      63: const Piece(Side.red, Kind.rook),
      81: const Piece(Side.red, Kind.rook),
    });
    expect(entry(red, const Move(63, 54)).notation, '前车进一');
    expect(entry(red, const Move(81, 72)).notation, '后车进一');
    final black = board({
      0: const Piece(Side.black, Kind.rook),
      18: const Piece(Side.black, Kind.rook),
    }, turn: Side.black);
    expect(entry(black, const Move(18, 27)).notation, '前車进1');
    expect(entry(black, const Move(0, 9)).notation, '后車进1');
  });

  test('同路多兵或多路叠兵保留完整起终点，避免含混的前兵', () {
    final three = board({
      18: const Piece(Side.red, Kind.pawn),
      27: const Piece(Side.red, Kind.pawn),
      36: const Piece(Side.red, Kind.pawn),
    });
    final first = entry(three, const Move(18, 9));
    expect(first.notation, contains('己方右起第9路、底线起第8行'));
    expect(first.notation, contains('己方右起第9路、底线起第9行'));
    final stacks = board({
      18: const Piece(Side.red, Kind.pawn),
      27: const Piece(Side.red, Kind.pawn),
      20: const Piece(Side.red, Kind.pawn),
      29: const Piece(Side.red, Kind.pawn),
    });
    final left = entry(stacks, const Move(18, 9));
    final right = entry(stacks, const Move(20, 11));
    expect(left.notation, isNot(right.notation));
    expect(right.notation, contains('己方右起第7路'));
    final black = board({
      45: const Piece(Side.black, Kind.pawn),
      54: const Piece(Side.black, Kind.pawn),
      63: const Piece(Side.black, Kind.pawn),
    }, turn: Side.black);
    expect(
      entry(black, const Move(63, 72)).notation,
      contains('己方右起第1路、底线起第8行'),
    );
  });

  test('吃子说明保留双方身份与具体位置', () {
    final p = board({
      63: const Piece(Side.red, Kind.rook),
      27: const Piece(Side.black, Kind.pawn),
    });
    final captured = entry(p, const Move(63, 27));
    expect(captured.ply, 1);
    expect(captured.side, Side.red);
    expect(captured.move, const Move(63, 27));
    expect(captured.notation, '车九进四');
    expect(captured.captured?.kind, Kind.pawn);
    expect(captured.captured?.side, Side.black);
    expect(captured.description, contains('第9路、底线起第3行'));
    expect(captured.description, contains('第9路、底线起第7行'));
    expect(captured.description, contains('吃掉黑方卒'));
    expect(entry(Position.initial(), const Move(54, 45)).captured, isNull);
  });

  test('无着法可读，保留调用者提供的执棋方难度结果', () {
    final text = record(
      [Position.initial()],
      [],
      playerSide: Side.black,
      level: 5,
      outcome: Outcome.blackWins,
    ).toText();
    expect(text, contains('您执黑棋；电脑执红棋'));
    expect(text, contains('高手（第 5 档）'));
    expect(text, contains('结果：黑方胜'));
    expect(text, contains('尚未走棋'));
    for (final outcome in Outcome.values) {
      expect(
        record([Position.initial()], [], outcome: outcome).outcome,
        outcome,
      );
    }
  });

  test('长谱不截断，按每个半回合列出双方全部着法', () {
    final positions = [Position.initial()];
    final moves = <Move>[];
    // Deliberately repeated movement exercises export length, not adjudication.
    const cycle = [Move(82, 65), Move(1, 20), Move(65, 82), Move(20, 1)];
    for (var i = 0; i < 1024; i++) {
      final move = cycle[i % cycle.length];
      positions.add(positions.last.play(move));
      moves.add(move);
    }
    final game = record(positions, moves);
    final text = game.toText();
    expect(game.entries, hasLength(1024));
    expect(text, contains('第 1 步　红方：马八进七'));
    expect(text, contains('第 1024 步　黑方：馬3退2'));
    expect(RegExp('第 [0-9]+ 步　').allMatches(text), hasLength(1024));
    expect(game.outcome, Outcome.playing);
  });

  test('快照不随来源列表变化，所有公开集合不可修改', () {
    final positions = [Position.initial()];
    final moves = <Move>[];
    final game = record(positions, moves);
    moves.add(const Move(54, 45));
    positions.add(positions.last.play(moves.last));
    expect(game.positions, hasLength(1));
    expect(game.moves, isEmpty);
    expect(game.entries, isEmpty);
    expect(() => game.positions.clear(), throwsUnsupportedError);
    expect(() => game.moves.add(const Move(54, 45)), throwsUnsupportedError);
    final played = record(positions, moves);
    expect(() => played.entries.clear(), throwsUnsupportedError);
  });

  test('拒绝缺少配对局面、错误着法及伪造后的棋盘状态', () {
    final start = Position.initial();
    const move = Move(54, 45);
    final after = start.play(move);
    expect(() => record([], []), throwsArgumentError);
    expect(() => record([start], [move]), throwsArgumentError);
    expect(() => record([start, start], [move]), throwsArgumentError);
    expect(
      () => record([start, Position(after.board, turn: Side.red)], [move]),
      throwsArgumentError,
    );
    expect(
      () => record([start, Position(after.board, turn: Side.black)], [move]),
      throwsArgumentError,
    );
    final changed = List<Piece?>.of(after.board)..[0] = null;
    expect(
      () => record(
        [start, Position(changed, turn: Side.black, quietPly: after.quietPly)],
        [move],
      ),
      throwsArgumentError,
    );
    const illegal = Move(54, 0);
    expect(
      () => record([start, start.applyUnchecked(illegal)], [illegal]),
      throwsArgumentError,
    );
    expect(
      () => record([start, after], [const Move(-1, 45)]),
      throwsArgumentError,
    );
    expect(() => record([start], [], level: 0), throwsArgumentError);
    expect(() => record([start], [], level: 6), throwsArgumentError);
  });

  test('单步反馈与全谱共用记谱边界并验证步数和走法', () {
    final start = Position.initial();
    const move = Move(54, 45);
    final single = GameRecordEntry.fromMove(before: start, move: move, ply: 7);
    final whole = entry(start, move);
    expect(single.ply, 7);
    expect(single.notation, whole.notation);
    expect(single.description, whole.description);
    expect(
      () => GameRecordEntry.fromMove(before: start, move: move, ply: 0),
      throwsArgumentError,
    );
    expect(
      () => GameRecordEntry.fromMove(
        before: start,
        move: const Move(54, 0),
        ply: 1,
      ),
      throwsArgumentError,
    );
  });
}
