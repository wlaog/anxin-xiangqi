import 'ai.dart';
import 'xiangqi.dart';

class RuleVerdict {
  const RuleVerdict(this.result, this.legal, {this.forbidden = const []});
  final Outcome result;
  final List<Move> legal, forbidden;
}

abstract interface class RuleBook {
  RuleVerdict judge(List<Position> history, List<Move> moves);
}

/// Simple test/development referee. Production uses the native referee.
class BasicRules implements RuleBook {
  @override
  RuleVerdict judge(List<Position> history, List<Move> moves) =>
      RuleVerdict(outcome(history), history.last.legalMoves());
}

abstract interface class HistoryAiEngine implements AiEngine {
  Future<Move?> chooseGame(List<Position> history, List<Move> moves, int level);
  void stop();
}
