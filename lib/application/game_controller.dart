import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/xiangqi.dart';
import '../domain/ai.dart';
import '../domain/rules.dart';
import '../infrastructure/game_store.dart';

Move? _search((Position, int) request) => LocalSearch(
  maxDepth: request.$2,
  budget: Duration(
    milliseconds: request.$2 == 1
        ? 250
        : request.$2 == 2
        ? 700
        : 1500,
  ),
).choose(request.$1);

class IsolateAiEngine implements AiEngine {
  @override
  Future<Move?> choose(Position position, int level) =>
      compute(_search, (position, level));
}

class GameController extends ChangeNotifier {
  GameController({required this.store, required this.engine, RuleBook? rules})
    : rules = rules ?? BasicRules();
  final GameStore store;
  final AiEngine engine;
  final RuleBook rules;
  RuleVerdict _verdict = const RuleVerdict(Outcome.playing, []);
  Side playerSide = Side.red;
  final _history = [Position.initial()];
  final _moves = <Move>[];
  Position get position => _history.last;
  Move? get lastMove => _moves.isEmpty ? null : _moves.last;
  int get ply => _moves.length;
  bool get canUndo => ready && ply > (playerSide == Side.black ? 1 : 0);
  List<Position> get history => List.unmodifiable(_history);
  List<Move> get moves => List.unmodifiable(_moves);
  List<Move> get forbiddenMoves => _verdict.forbidden;
  int level = 2;
  bool ready = false, busy = false;
  bool _disposed = false, _allowSave = true;
  int _generation = 0;
  String? notice;
  Outcome result = Outcome.playing;
  Future<void> _writes = Future.value();

  String get status => switch (result) {
    Outcome.redWins => playerSide == Side.red ? '您赢了！再来一盘也可以' : '这盘电脑赢了，下次再试试',
    Outcome.blackWins =>
      playerSide == Side.black ? '您赢了！再来一盘也可以' : '这盘电脑赢了，下次再试试',
    Outcome.repetitionDraw => '这盘和棋，可以再来一盘',
    Outcome.quietDraw => '久未吃子，这盘和棋',
    Outcome.playing =>
      busy
          ? '电脑正在想，请稍等'
          : position.turn != playerSide
          ? '电脑暂停了，请点“继续思考”'
          : position.inCheck(playerSide)
          ? '您被将军了，请先应将'
          : '轮到您了，您执${playerSide == Side.red ? '红' : '黑'}棋',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final raw = await store.read();
      if (_disposed) return;
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is! Map ||
            ![1, 2].contains(data['version']) ||
            data['moves'] is! List ||
            data['level'] is! int ||
            data['level'] < 1 ||
            data['level'] > 5 ||
            (data['moves'] as List).length > 4096) {
          throw const FormatException('未知存档');
        }
        final restored = [Position.initial()];
        final moves = <Move>[];
        for (final item in data['moves']) {
          if (item is! List ||
              item.length != 2 ||
              item.any((v) => v is! int || v < 0 || v >= 90)) {
            throw const FormatException('损坏的走法');
          }
          final verdict = rules.judge(restored, moves);
          if (verdict.result != Outcome.playing) {
            throw const FormatException('终局后仍有走法');
          }
          final move = Move(item[0], item[1]);
          if (!verdict.legal.contains(move)) {
            throw const FormatException('存档包含禁着');
          }
          restored.add(restored.last.play(move));
          moves.add(move);
        }
        _history
          ..clear()
          ..addAll(restored);
        _moves
          ..clear()
          ..addAll(moves);
        level = data['level'];
        playerSide = data['side'] == 'black' ? Side.black : Side.red;
        notice = moves.isEmpty ? null : '已接着上次的棋局';
      }
    } catch (_) {
      _allowSave = false;
      notice = '上次棋局暂时无法读取，原存档已保留。点“重新开始”后可保存新棋局。';
    }
    if (_disposed) return;
    ready = true;
    _judge();
    _notify();
    await _computerTurn();
  }

  List<Move> get legalMoves => result == Outcome.playing ? _verdict.legal : [];

  void _judge() {
    _verdict = rules.judge(_history, _moves);
    result = _verdict.result;
  }

  void _cancel() {
    _generation++;
    if (engine case final HistoryAiEngine native) {
      native.stop();
    }
    busy = false;
  }

  Future<void> play(Move move) async {
    if (!ready ||
        busy ||
        position.turn != playerSide ||
        result != Outcome.playing ||
        !legalMoves.contains(move)) {
      return;
    }
    _append(move);
    _notify();
    _persist();
    await _computerTurn();
  }

  void _append(Move move) {
    _moves.add(move);
    _history.add(position.applyUnchecked(move));
    _judge();
  }

  Future<void> _computerTurn() async {
    if (_disposed ||
        busy ||
        result != Outcome.playing ||
        position.turn == playerSide) {
      return;
    }
    final ticket = ++_generation;
    busy = true;
    _notify();
    try {
      final move = engine is HistoryAiEngine
          ? await (engine as HistoryAiEngine).chooseGame(history, moves, level)
          : await engine.choose(position, level);
      if (_disposed || ticket != _generation) return;
      if (move == null || !legalMoves.contains(move)) {
        throw StateError('电脑未返回有效走法');
      }
      _append(move);
    } catch (_) {
      if (_disposed || ticket != _generation) return;
      notice = '电脑暂时无法落子。可以点“继续思考”重试，或悔棋。';
    }
    if (_disposed || ticket != _generation) return;
    busy = false;
    _notify();
    await _persist();
  }

  Future<void> undo() async {
    if (!canUndo) return;
    _cancel();
    final count = position.turn != playerSide ? 1 : 2;
    for (var i = 0; i < count && _moves.isNotEmpty; i++) {
      _moves.removeLast();
      _history.removeLast();
    }
    _judge();
    _notify();
    await _persist();
  }

  Future<void> newGame({Side? side}) async {
    if (!ready) return;
    _cancel();
    if (side != null) playerSide = side;
    _moves.clear();
    _history
      ..clear()
      ..add(Position.initial());
    _judge();
    notice = null;
    _allowSave = true;
    _notify();
    await _persist();
    await _computerTurn();
  }

  Future<void> retryComputer() => _computerTurn();

  Future<Move?> hint() async {
    if (!ready ||
        busy ||
        position.turn != playerSide ||
        result != Outcome.playing) {
      return null;
    }
    final ticket = ++_generation;
    busy = true;
    _notify();
    try {
      final move = engine is HistoryAiEngine
          ? await (engine as HistoryAiEngine).chooseGame(history, moves, 5)
          : await engine.choose(position, level);
      if (_disposed || ticket != _generation) return null;
      if (move == null || !legalMoves.contains(move)) throw StateError('无有效提示');
      return move;
    } catch (_) {
      if (!_disposed && ticket == _generation) notice = '暂时没有想好提示，请稍后重试。';
      return null;
    } finally {
      if (!_disposed && ticket == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> setLevel(int value) async {
    if (value < 1 || value > 5 || !ready) return;
    level = value;
    _notify();
    await _persist();
  }

  Future<void> _persist() {
    if (!ready || !_allowSave) return Future.value();
    final snapshot = jsonEncode({
      'version': 2,
      'level': level,
      'side': playerSide.name,
      'moves': _moves.map((m) => m.toJson()).toList(),
    });
    _writes = _writes.then((_) async {
      try {
        await store.write(snapshot);
      } catch (_) {
        notice = '这盘棋暂时不能保存，您仍可以继续下棋。';
        _notify();
      }
    });
    return _writes;
  }

  Future<void> get saved => _writes;

  @override
  void dispose() {
    _disposed = true;
    _cancel();
    super.dispose();
  }
}
