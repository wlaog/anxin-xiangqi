import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/xiangqi.dart';
import '../domain/ai.dart';
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
  GameController({required this.store, required this.engine});
  final GameStore store;
  final AiEngine engine;
  final _history = [Position.initial()];
  final _moves = <Move>[];
  Position get position => _history.last;
  Move? get lastMove => _moves.isEmpty ? null : _moves.last;
  int get ply => _moves.length;
  int level = 2;
  bool ready = false, busy = false;
  bool _disposed = false, _allowSave = true;
  int _generation = 0;
  String? notice;
  Outcome result = Outcome.playing;
  Future<void> _writes = Future.value();

  String get status => switch (result) {
    Outcome.redWins => '您赢了！再来一盘也可以',
    Outcome.blackWins => '这盘电脑赢了，下次再试试',
    Outcome.repetitionDraw => '局面重复，这盘和棋',
    Outcome.quietDraw => '久未吃子，这盘和棋',
    Outcome.playing =>
      busy
          ? '电脑正在想，请稍等'
          : position.inCheck(Side.red)
          ? '您被将军了，请先应将'
          : '轮到您了，您执红棋',
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
            data['version'] != 1 ||
            data['moves'] is! List ||
            data['level'] is! int ||
            data['level'] < 1 ||
            data['level'] > 3 ||
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
          if (outcome(restored) != Outcome.playing) {
            throw const FormatException('终局后仍有走法');
          }
          final move = Move(item[0], item[1]);
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
        notice = moves.isEmpty ? null : '已接着上次的棋局';
      }
    } catch (_) {
      _allowSave = false;
      notice = '上次棋局暂时无法读取，原存档已保留。点“重新开始”后可保存新棋局。';
    }
    if (_disposed) return;
    ready = true;
    result = outcome(_history);
    _notify();
    await _computerTurn();
  }

  List<Move> get legalMoves =>
      result == Outcome.playing ? position.legalMoves() : [];

  Future<void> play(Move move) async {
    if (!ready ||
        busy ||
        position.turn != Side.red ||
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
    result = outcome(_history);
  }

  Future<void> _computerTurn() async {
    if (_disposed || result != Outcome.playing || position.turn != Side.black) {
      return;
    }
    final ticket = ++_generation;
    busy = true;
    _notify();
    try {
      final move = await engine.choose(position, level);
      if (_disposed || ticket != _generation) return;
      if (move == null || !position.legalMoves().contains(move)) {
        throw StateError('电脑未返回有效走法');
      }
      _append(move);
    } catch (_) {
      if (_disposed || ticket != _generation) return;
      final fallback = position.legalMoves();
      if (fallback.isNotEmpty) _append(fallback.first);
      notice = '电脑刚才没想好，已使用备用走法，可以继续下棋。';
    }
    if (_disposed || ticket != _generation) return;
    busy = false;
    _notify();
    await _persist();
  }

  Future<void> undo() async {
    if (!ready || _moves.isEmpty) return;
    _generation++;
    busy = false;
    final count = position.turn == Side.black ? 1 : 2;
    for (var i = 0; i < count && _moves.isNotEmpty; i++) {
      _moves.removeLast();
      _history.removeLast();
    }
    result = outcome(_history);
    _notify();
    await _persist();
  }

  Future<void> newGame() async {
    if (!ready) return;
    _generation++;
    busy = false;
    _moves.clear();
    _history
      ..clear()
      ..add(Position.initial());
    result = Outcome.playing;
    notice = null;
    _allowSave = true;
    _notify();
    await _persist();
  }

  Future<void> setLevel(int value) async {
    if (value < 1 || value > 3 || !ready) return;
    level = value;
    _notify();
    await _persist();
  }

  Future<void> _persist() {
    if (!ready || !_allowSave) return Future.value();
    final snapshot = jsonEncode({
      'version': 1,
      'level': level,
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
    _generation++;
    super.dispose();
  }
}
