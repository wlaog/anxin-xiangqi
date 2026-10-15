import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/study.dart';
import '../infrastructure/game_store.dart';

/// Separate from the live game and its library; failed/corrupt data is retained.
class StudyNotebook extends ChangeNotifier {
  StudyNotebook(this.store);
  final GameStore store;
  Map<String, dynamic> _data = {'version': 1, 'results': <String, dynamic>{}};
  bool ready = false, writable = false, _disposed = false;
  String? notice;
  Future<void>? _initialization;
  Future<void> _queue = Future.value();
  Object? get draft => _data['draft'];
  Set<String> get completed => _results.entries
      .where((e) => (e.value as Map)['done'] == true)
      .map((e) => e.key as String)
      .toSet();
  Set<String> get retry => _results.entries
      .where((e) => (e.value as Map)['retry'] == true)
      .map((e) => e.key as String)
      .toSet();
  Map get _results => _data['results'] as Map;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initialization ??= _load();
  Future<void> _load() async {
    try {
      final raw = await store.read();
      if (raw != null) {
        if (raw.length > 256 * 1024) throw const FormatException('练习记录过大');
        final data = jsonDecode(raw);
        if (data is! Map<String, dynamic> ||
            data['version'] != 1 ||
            data['results'] is! Map) {
          throw const FormatException('练习记录格式不正确');
        }
        for (final row in (data['results'] as Map).values) {
          if (row is! Map || row['done'] is! bool || row['retry'] is! bool) {
            throw const FormatException('练习进度不正确');
          }
        }
        _data = data;
      }
      writable = true;
    } catch (_) {
      notice = '练习记录暂时读不出，原数据已保留。本次仍可练习和导出，暂不能保存。';
    }
    ready = true;
    _notify();
  }

  Future<void> _change(void Function(Map<String, dynamic>) edit) {
    final pending = _queue.then((_) async {
      await initialize();
      if (!writable) throw StateError('练习记录暂不能保存');
      final next = Map<String, dynamic>.from(_data);
      next['results'] = Map<String, dynamic>.from(_results);
      edit(next);
      final encoded = jsonEncode(next);
      if (encoded.length > 256 * 1024) throw StateError('练习记录过大，请先导出');
      try {
        await store.write(encoded);
        _data = next;
        notice = null;
      } on GameStoreConflict {
        writable = false;
        notice = '练习记录已在另一个窗口中改变，为避免覆盖，请关闭后重新打开。';
        rethrow;
      } catch (_) {
        notice = '这次练习记录未保存，可以稍后重试；原记录仍保留。';
        rethrow;
      } finally {
        _notify();
      }
    });
    _queue = pending.catchError((Object _) {});
    return pending;
  }

  Future<void> record(String id, {required bool success}) => _change((next) {
    final results = next['results'] as Map;
    final old = results[id] as Map?;
    results[id] = {'done': success || old?['done'] == true, 'retry': !success};
  });
  Future<void> saveDraft(StudyTree tree) {
    final captured = tree.toJson();
    return _change((next) => next['draft'] = captured);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
