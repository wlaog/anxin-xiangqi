import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/xiangqi.dart';
import '../domain/ai.dart';
import '../domain/rules.dart';
import '../infrastructure/game_store.dart';
import 'user_preferences.dart';

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

/// A single committed game: its history and verdict always describe one state.
class _GameState {
  _GameState(this.history, this.moves, this.verdict);
  final List<Position> history;
  final List<Move> moves;
  final RuleVerdict verdict;
}

enum _ActionNotice {
  resumed,
  moveFailed,
  computerFailed,
  undoFailed,
  newGameFailed,
  hintFailed,
}

enum _StorageNotice { retainedGame, writeFailed }

class GameController extends ChangeNotifier {
  GameController({required this.store, required this.engine, RuleBook? rules})
    : rules = rules ?? BasicRules();
  final GameStore store;
  final AiEngine engine;
  final RuleBook rules;
  _GameState _state = _GameState(
    List.unmodifiable([Position.initial()]),
    const [],
    const RuleVerdict(Outcome.playing, []),
  );
  Side playerSide = Side.red;
  Position get position => _state.history.last;
  Move? get lastMove => _state.moves.lastOrNull;
  int get ply => _state.moves.length;
  bool get canUndo => ready && ply > (playerSide == Side.black ? 1 : 0);
  List<Position> get history => _state.history;
  List<Move> get moves => _state.moves;
  List<Move> get forbiddenMoves => _state.verdict.forbidden;
  int level = 2;
  UserPreferences preferences = const UserPreferences();
  bool ready = false, busy = false;
  bool _disposed = false;
  int _generation = 0;
  _ActionNotice? _actionNotice;
  _StorageNotice? _storageNotice;
  String? get notice {
    final action = switch (_actionNotice) {
      _ActionNotice.resumed => '已接着上次的棋局',
      _ActionNotice.moveFailed => '这步棋暂时无法确认，棋盘未改变。请再试一次。',
      _ActionNotice.computerFailed => '电脑暂时无法落子。可以点“继续思考”重试，或悔棋。',
      _ActionNotice.undoFailed => '暂时无法悔棋，棋盘未改变。请再试一次。',
      _ActionNotice.newGameFailed => '暂时无法重新开始，棋盘未改变。请再试一次。',
      _ActionNotice.hintFailed => '暂时没有想好提示，请稍后重试。',
      null => null,
    };
    final storage = switch (_storageNotice) {
      _StorageNotice.retainedGame => '棋局暂时无法准备，原存档已保留；当前走棋和设置不会保存。请点“重新开始”重试。',
      _StorageNotice.writeFailed => '这盘棋暂时不能保存，您仍可以继续下棋。',
      null => null,
    };
    return storage == null
        ? action
        : action == null
        ? storage
        : '$storage\n$action';
  }

  Outcome get result => _state.verdict.result;
  Future<void> _writes = Future.value();
  Future<void>? _initialization;

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

  Future<void> initialize() {
    if (_disposed) return Future.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    var fallback = _state;
    try {
      final raw = await store.read();
      if (_disposed) return;
      var restored = _prepare([Position.initial()], []);
      fallback = restored;
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
        for (final item in data['moves']) {
          if (item is! List ||
              item.length != 2 ||
              item.any((v) => v is! int || v < 0 || v >= 90)) {
            throw const FormatException('损坏的走法');
          }
          final verdict = restored.verdict;
          if (verdict.result != Outcome.playing) {
            throw const FormatException('终局后仍有走法');
          }
          final move = Move(item[0], item[1]);
          if (!verdict.legal.contains(move)) {
            throw const FormatException('存档包含禁着');
          }
          restored = _prepare(
            [...restored.history, restored.history.last.play(move)],
            [...restored.moves, move],
          );
        }
        final restoredLevel = data['level'] as int;
        final restoredSide = data['side'] == 'black' ? Side.black : Side.red;
        final restoredPreferences = UserPreferences.fromJson(
          data['preferences'],
        );
        level = restoredLevel;
        playerSide = restoredSide;
        preferences = restoredPreferences;
        _actionNotice = restored.moves.isEmpty ? null : _ActionNotice.resumed;
      }
      _state = restored;
    } catch (_) {
      _state = fallback;
      _storageNotice = _StorageNotice.retainedGame;
    }
    if (_disposed) return;
    ready = true;
    _notify();
    await _computerTurn();
  }

  List<Move> get legalMoves =>
      result == Outcome.playing ? _state.verdict.legal : const [];

  _GameState _prepare(List<Position> positions, List<Move> moves) {
    final boards = List<Position>.unmodifiable(positions);
    final steps = List<Move>.unmodifiable(moves);
    final verdict = rules.judge(boards, steps);
    return _GameState(
      boards,
      steps,
      RuleVerdict(
        verdict.result,
        List.unmodifiable(verdict.legal),
        forbidden: List.unmodifiable(verdict.forbidden),
      ),
    );
  }

  void _cancel() {
    _generation++;
    if (engine case final HistoryAiEngine native) {
      native.stop();
    }
    busy = false;
  }

  Future<void> play(Move move) async {
    if (_disposed ||
        !ready ||
        busy ||
        position.turn != playerSide ||
        result != Outcome.playing ||
        !legalMoves.contains(move)) {
      return;
    }
    try {
      _append(move);
    } catch (_) {
      _actionNotice = _ActionNotice.moveFailed;
      _notify();
      return;
    }
    _actionNotice = null;
    _notify();
    _persist();
    await _computerTurn();
  }

  void _append(Move move) {
    _state = _prepare(
      [...history, position.applyUnchecked(move)],
      [...moves, move],
    );
  }

  Future<void> _computerTurn() async {
    if (_disposed ||
        !ready ||
        busy ||
        result != Outcome.playing ||
        position.turn == playerSide) {
      return;
    }
    final ticket = ++_generation;
    busy = true;
    _notify();
    var changed = false;
    try {
      final move = engine is HistoryAiEngine
          ? await (engine as HistoryAiEngine).chooseGame(history, moves, level)
          : await engine.choose(position, level);
      if (_disposed || ticket != _generation) return;
      if (move == null || !legalMoves.contains(move)) {
        throw StateError('电脑未返回有效走法');
      }
      _append(move);
      _actionNotice = null;
      changed = true;
    } catch (_) {
      if (_disposed || ticket != _generation) return;
      _actionNotice = _ActionNotice.computerFailed;
    }
    if (_disposed || ticket != _generation) return;
    busy = false;
    _notify();
    if (changed) await _persist();
  }

  Future<void> undo() async {
    if (_disposed || !canUndo) return;
    _cancel();
    final count = position.turn != playerSide ? 1 : 2;
    final remaining = (ply - count).clamp(0, ply);
    try {
      _state = _prepare(
        history.sublist(0, remaining + 1),
        moves.sublist(0, remaining),
      );
    } catch (_) {
      _actionNotice = _ActionNotice.undoFailed;
      _notify();
      return;
    }
    _actionNotice = null;
    _notify();
    await _persist();
  }

  Future<void> newGame({Side? side}) async {
    if (_disposed || !ready) return;
    _cancel();
    try {
      _state = _prepare([Position.initial()], []);
    } catch (_) {
      _actionNotice = _ActionNotice.newGameFailed;
      _notify();
      return;
    }
    if (side != null) playerSide = side;
    _actionNotice = null;
    if (_storageNotice == _StorageNotice.retainedGame) _storageNotice = null;
    _notify();
    await _persist();
    await _computerTurn();
  }

  Future<void> retryComputer() => _computerTurn();

  Future<Move?> hint() async {
    if (_disposed ||
        !ready ||
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
      if (_actionNotice == _ActionNotice.hintFailed) _actionNotice = null;
      return move;
    } catch (_) {
      if (!_disposed && ticket == _generation) {
        _actionNotice = _ActionNotice.hintFailed;
      }
      return null;
    } finally {
      if (!_disposed && ticket == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> setLevel(int value) async {
    if (_disposed || value < 1 || value > 5 || !ready) return;
    level = value;
    _notify();
    await _persist();
  }

  Future<void> setPreferences(UserPreferences value) async {
    if (!ready || _disposed) return;
    preferences = UserPreferences.fromJson(value.toJson());
    _notify();
    await _persist();
  }

  Future<void> _persist() {
    if (_disposed || !ready || _storageNotice == _StorageNotice.retainedGame) {
      return Future.value();
    }
    final snapshot = jsonEncode({
      'version': 2,
      'level': level,
      'side': playerSide.name,
      'preferences': preferences.toJson(),
      'moves': moves.map((m) => m.toJson()).toList(),
    });
    _writes = _writes.then((_) async {
      try {
        await store.write(snapshot);
        if (_storageNotice == _StorageNotice.writeFailed) {
          _storageNotice = null;
          _notify();
        }
      } catch (_) {
        _storageNotice = _StorageNotice.writeFailed;
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
