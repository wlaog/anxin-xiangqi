import 'rules.dart';
import 'xiangqi.dart';

/// Portable game data. Preferences belong to the application, not a chess record.
class GameSnapshot {
  GameSnapshot({
    required List<Move> moves,
    required this.side,
    required this.level,
  }) : moves = List.unmodifiable(moves) {
    if (level < 1 || level > 5 || moves.length > 4096) {
      throw const FormatException('棋局难度或长度不正确');
    }
  }

  factory GameSnapshot.fromJson(Object? value) {
    if (value is! Map ||
        ![1, 2].contains(value['version']) ||
        value['level'] is! int ||
        value['moves'] is! List) {
      throw const FormatException('未知棋局格式');
    }
    final rawMoves = value['moves'] as List;
    if (rawMoves.length > 4096) throw const FormatException('棋局过长');
    final moves = <Move>[];
    for (final item in rawMoves) {
      if (item is! List ||
          item.length != 2 ||
          item.any((v) => v is! int || v < 0 || v >= 90)) {
        throw const FormatException('损坏的走法');
      }
      moves.add(Move(item[0], item[1]));
    }
    // Version one did not store a side; preserve its red-side default.
    if (value['side'] != null && !['red', 'black'].contains(value['side'])) {
      throw const FormatException('未知执棋方');
    }
    return GameSnapshot(
      moves: moves,
      side: value['side'] == 'black' ? Side.black : Side.red,
      level: value['level'],
    );
  }

  final List<Move> moves;
  final Side side;
  final int level;

  Map<String, Object> toJson() => {
    'version': 2,
    'moves': moves.map((m) => m.toJson()).toList(),
    'side': side.name,
    'level': level,
  };
}

/// One owner for replay and adjudication, shared by resume and the library.
class GameSession {
  factory GameSession(
    List<Position> history,
    List<Move> moves,
    RuleVerdict verdict,
  ) => GameSession._(
    List.unmodifiable(history),
    List.unmodifiable(moves),
    _freeze(verdict),
  );

  const GameSession._(this.history, this.moves, this.verdict);

  static RuleVerdict _freeze(RuleVerdict verdict) => RuleVerdict(
    verdict.result,
    List.unmodifiable(verdict.legal),
    forbidden: List.unmodifiable(verdict.forbidden),
  );

  factory GameSession.prepare(
    List<Position> history,
    List<Move> moves,
    RuleBook rules,
  ) {
    final boards = List<Position>.unmodifiable(history);
    final steps = List<Move>.unmodifiable(moves);
    return GameSession._(boards, steps, _freeze(rules.judge(boards, steps)));
  }

  factory GameSession.restore(GameSnapshot snapshot, RuleBook rules) =>
      GameSession.prepare(
        [Position.initial()],
        [],
        rules,
      ).replay(snapshot.moves, rules);

  final List<Position> history;
  final List<Move> moves;
  final RuleVerdict verdict;

  GameSession replay(List<Move> steps, RuleBook rules) {
    var state = this;
    for (final move in steps) {
      if (state.verdict.result != Outcome.playing ||
          !state.verdict.legal.contains(move)) {
        throw const FormatException('棋局包含禁着或终局后的走法');
      }
      state = GameSession.prepare(
        [...state.history, state.history.last.play(move)],
        [...state.moves, move],
        rules,
      );
    }
    return state;
  }
}
