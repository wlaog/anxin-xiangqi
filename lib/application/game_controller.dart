import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/xiangqi.dart';
import '../domain/ai.dart';
import '../domain/rules.dart';
import '../domain/game_snapshot.dart';
import '../domain/game_record.dart';
import '../infrastructure/game_store.dart';
import 'user_preferences.dart';
import 'game_library.dart';

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

enum _ActionNotice {
  resumed,
  moveFailed,
  computerFailed,
  undoFailed,
  newGameFailed,
  hintFailed,
  archiveFailed,
  restoreFailed,
}

enum _StorageNotice { retainedGame, writeFailed }

class GameController extends ChangeNotifier {
  GameController({
    required this.store,
    required this.engine,
    RuleBook? rules,
    this.library,
  }) : rules = rules ?? BasicRules();
  final GameStore store;
  final AiEngine engine;
  final RuleBook rules;
  final GameLibrary? library;
  String gameId = newGameId();
  bool _switching = false;
  GameSession _state = GameSession(
    List.unmodifiable([Position.initial()]),
    const [],
    const RuleVerdict(Outcome.playing, []),
  );
  Side playerSide = Side.red;
  Position get position => _state.history.last;
  Move? get lastMove => _state.moves.lastOrNull;
  int get ply => _state.moves.length;
  bool get canUndo =>
      ready && !_switching && ply > (playerSide == Side.black ? 1 : 0);
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
  bool _archiveWarning = false;
  String? get notice {
    final action = switch (_actionNotice) {
      _ActionNotice.resumed => '已接着上次的棋局',
      _ActionNotice.moveFailed => '这步棋暂时无法确认，棋盘未改变。请再试一次。',
      _ActionNotice.computerFailed => '电脑暂时无法落子。可以点“继续思考”重试，或悔棋。',
      _ActionNotice.undoFailed => '暂时无法悔棋，棋盘未改变。请再试一次。',
      _ActionNotice.newGameFailed => '暂时无法重新开始，棋盘未改变。请再试一次。',
      _ActionNotice.hintFailed => '暂时没有想好提示，请稍后重试。',
      _ActionNotice.archiveFailed => '旧棋局暂时无法存入棋局库，棋盘已保留。请稍后再试。',
      _ActionNotice.restoreFailed => '这份棋谱暂时无法继续，当前棋局和原棋谱均已保留。',
      null => null,
    };
    final storage = switch (_storageNotice) {
      _StorageNotice.retainedGame => '棋局暂时无法准备，原存档已保留；当前走棋和设置不会保存。请点“重新开始”重试。',
      _StorageNotice.writeFailed => '这盘棋暂时不能保存，您仍可以继续下棋。',
      null => null,
    };
    final messages = [
      storage,
      action,
      if (_archiveWarning) '本盘暂时无法存入棋局库，请在“我的棋局”中重试保存。',
    ].whereType<String>().toList();
    return messages.isEmpty ? null : messages.join('\n');
  }

  Outcome get result => _state.verdict.result;
  Future<void> _writes = Future.value();
  Future<void>? _initialization;

  String get status => _switching
      ? '正在保存棋局，请稍等'
      : switch (result) {
          Outcome.redWins =>
            playerSide == Side.red ? '您赢了！再来一盘也可以' : '这盘电脑赢了，下次再试试',
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
    unawaited(library?.initialize());
    var fallback = _state;
    try {
      final raw = await store.read();
      if (_disposed) return;
      var restored = _prepare([Position.initial()], []);
      fallback = restored;
      if (raw != null) {
        final data = jsonDecode(raw);
        final snapshot = GameSnapshot.fromJson(data);
        restored = restored.replay(snapshot.moves, rules);
        final restoredPreferences = UserPreferences.fromJson(
          data['preferences'],
        );
        level = snapshot.level;
        playerSide = snapshot.side;
        final id = data['gameId'];
        if (id is String && id.isNotEmpty && id.length <= 100) gameId = id;
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
    if (library != null && result != Outcome.playing) {
      await _persist();
    } else {
      await _computerTurn();
    }
  }

  List<Move> get legalMoves =>
      result == Outcome.playing ? _state.verdict.legal : const [];

  GameSession _prepare(List<Position> positions, List<Move> moves) =>
      GameSession.prepare(positions, moves, rules);

  GameSnapshot get snapshot =>
      GameSnapshot(moves: moves, side: playerSide, level: level);

  GameRecord readRecord(GameSnapshot snapshot) {
    final state = GameSession.restore(snapshot, rules);
    return GameRecord.fromHistory(
      positions: state.history,
      moves: state.moves,
      playerSide: snapshot.side,
      level: snapshot.level,
      outcome: state.verdict.result,
    );
  }

  Future<void> saveToLibrary() async {
    if (!ready || _disposed || _switching || ply == 0 || library == null) {
      return;
    }
    final captured = snapshot, id = gameId;
    await library!.save(id, captured);
    _archiveWarning = false;
    // Also persist a newly assigned legacy-session identity for the next launch.
    await _persist();
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
    if (_disposed || !ready || _switching) return;
    GameSession replacement;
    try {
      replacement = _prepare([Position.initial()], []);
    } catch (_) {
      _actionNotice = _ActionNotice.newGameFailed;
      _cancel();
      _notify();
      return;
    }
    await _replace(replacement, side ?? playerSide, level, newGameId());
  }

  Future<bool> continueGame(LibraryEntry entry) async {
    if (_disposed || !ready || _switching) return false;
    GameSession replacement;
    try {
      replacement = GameSession.restore(entry.snapshot, rules);
    } catch (_) {
      _actionNotice = _ActionNotice.restoreFailed;
      _notify();
      return false;
    }
    return _replace(
      replacement,
      entry.snapshot.side,
      entry.snapshot.level,
      entry.id,
    );
  }

  Future<bool> _replace(
    GameSession replacement,
    Side side,
    int difficulty,
    String id,
  ) async {
    _cancel();
    _switching = true;
    busy = true;
    _notify();
    try {
      if (library != null && ply > 0) {
        // Drain older auto-archive work before committing the final snapshot.
        // A delayed terminal write must not replace a later undo/save.
        await saved;
        await library!.save(gameId, snapshot);
      }
      if (_disposed) return false;
      _state = replacement;
      playerSide = side;
      level = difficulty;
      gameId = id;
      _actionNotice = null;
      _archiveWarning = false;
      if (_storageNotice == _StorageNotice.retainedGame) _storageNotice = null;
    } catch (_) {
      _actionNotice = _ActionNotice.archiveFailed;
      return false;
    } finally {
      _switching = false;
      busy = false;
      _notify();
    }
    await _persist();
    await _computerTurn();
    return true;
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
    if (_disposed || value < 1 || value > 5 || !ready || _switching) return;
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
      'gameId': gameId,
      'level': level,
      'side': playerSide.name,
      'preferences': preferences.toJson(),
      'moves': moves.map((m) => m.toJson()).toList(),
    });
    final finished = result != Outcome.playing;
    final capturedGame = this.snapshot, capturedId = gameId;
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
      if (finished && library != null) {
        try {
          await library!.save(capturedId, capturedGame);
          if (capturedId == gameId) _archiveWarning = false;
        } catch (_) {
          if (capturedId == gameId) _archiveWarning = true;
        }
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
