import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/game_snapshot.dart';
import '../infrastructure/game_store.dart';

String newGameId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.title,
    required this.created,
    required this.updated,
    required this.favorite,
    required this.snapshot,
  });

  factory LibraryEntry.fromJson(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        (value['id'] as String).length > 100 ||
        value['title'] is! String ||
        (value['title'] as String).trim().isEmpty ||
        (value['title'] as String).length > 80 ||
        value['favorite'] is! bool ||
        value['created'] is! String ||
        value['updated'] is! String) {
      throw const FormatException('棋谱信息损坏');
    }
    return LibraryEntry(
      id: value['id'],
      title: value['title'],
      created: DateTime.parse(value['created']),
      updated: DateTime.parse(value['updated']),
      favorite: value['favorite'],
      snapshot: GameSnapshot.fromJson(value['game']),
    );
  }

  final String id, title;
  final DateTime created, updated;
  final bool favorite;
  final GameSnapshot snapshot;
}

/// Commits memory only after storage succeeds. Unreadable entries remain intact.
class GameLibrary extends ChangeNotifier {
  GameLibrary(this.store);
  final GameStore store;
  Future<void>? _initialization;
  Future<void> _queue = Future.value();
  Map<String, dynamic> _data = {'version': 1, 'entries': <dynamic>[]};
  List<LibraryEntry> _entries = const [];
  bool ready = false, writable = false, _disposed = false, _conflict = false;
  int unreadable = 0, _pending = 0;
  bool _capacityWarning = false;
  bool get saving => _pending > 0;
  List<LibraryEntry> get entries => _entries;
  String? get notice => !ready
      ? null
      : _conflict
      ? '棋局库已在另一个窗口中改变，为避免覆盖，请关闭本窗口后重新打开。'
      : !writable
      ? '棋局库暂时无法读取，原数据已保留。请关闭后重新打开再试。'
      : _capacityWarning
      ? '棋局库空间不足，请先删除不需要的棋谱，再重试保存。原棋谱没有被自动删除。'
      : unreadable > 0
      ? '有 $unreadable 份棋谱暂时无法读取，原数据已保留；其他棋谱仍可使用。'
      : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    try {
      final raw = await store.read();
      if (raw != null) {
        if (raw.length > 4 * 1024 * 1024) throw const FormatException('棋局库过大');
        final data = jsonDecode(raw);
        if (data is! Map<String, dynamic> ||
            data['version'] != 1 ||
            data['entries'] is! List) {
          throw const FormatException('未知棋局库');
        }
        _data = data;
      }
      _index();
      writable = true;
    } catch (_) {
      writable = false;
    }
    ready = true;
    _notify();
  }

  void _index() {
    final counts = <String, int>{};
    final rows = _data['entries'] as List;
    for (final row in rows) {
      if (row is Map && row['id'] is String) {
        counts.update(row['id'], (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final entries = <LibraryEntry>[];
    unreadable = 0;
    for (final row in rows) {
      try {
        final entry = LibraryEntry.fromJson(row);
        if (counts[entry.id] != 1) throw const FormatException('重复棋局身份');
        entries.add(entry);
      } catch (_) {
        unreadable++;
      }
    }
    entries.sort((a, b) => b.updated.compareTo(a.updated));
    _entries = List.unmodifiable(entries);
  }

  Future<void> _change(void Function(List<dynamic>) edit) {
    _pending++;
    _notify();
    final work = _queue.then((_) async {
      await initialize();
      if (!writable) throw StateError('原棋局库已保留，暂不写入');
      final rows = List<dynamic>.of(_data['entries']);
      edit(rows);
      final next = {..._data, 'entries': rows};
      final encoded = jsonEncode(next);
      // Bound library parsing and writing without silently evicting games.
      if (encoded.length > 4 * 1024 * 1024) {
        _capacityWarning = true;
        throw StateError('棋局库空间不足，请先整理旧棋谱');
      }
      try {
        await store.write(encoded);
      } on GameStoreConflict {
        writable = false;
        _conflict = true;
        rethrow;
      }
      _data = next;
      _capacityWarning = false;
      _index();
    });
    _queue = work.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return work.whenComplete(() {
      _pending--;
      _notify();
    });
  }

  Future<void> save(String id, GameSnapshot snapshot) => _change((rows) {
    final found = _entries.where((e) => e.id == id).firstOrNull;
    final at = rows.indexWhere((r) => r is Map && r['id'] == id);
    if (at >= 0 && found == null) throw StateError('原棋谱身份无法确认，已保留');
    final now = DateTime.now().toUtc();
    final old = at < 0
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rows[at]);
    final date = now.toLocal();
    final row = {
      ...old,
      'id': id,
      'title': found?.title ?? '${date.year}年${date.month}月${date.day}日的棋局',
      'created': found?.created.toIso8601String() ?? now.toIso8601String(),
      'updated': now.toIso8601String(),
      'favorite': found?.favorite ?? false,
      'game': snapshot.toJson(),
    };
    LibraryEntry.fromJson(row);
    if (at < 0) {
      rows.add(row);
    } else {
      rows[at] = row;
    }
  });

  Future<void> rename(String id, String title) {
    title = title.trim();
    if (title.isEmpty || title.length > 80) {
      throw const FormatException('名称请填一至八十个字');
    }
    return _edit(id, (row) => row['title'] = title);
  }

  Future<void> favorite(String id, bool value) =>
      _edit(id, (row) => row['favorite'] = value);
  Future<void> remove(String id) => _edit(id, null);

  Future<void> _edit(String id, void Function(Map<String, dynamic>)? edit) =>
      _change((rows) {
        if (!_entries.any((e) => e.id == id)) throw StateError('未找到这盘棋');
        final at = rows.indexWhere((r) => r is Map && r['id'] == id);
        if (edit == null) {
          rows.removeAt(at);
        } else {
          final row = Map<String, dynamic>.from(rows[at]);
          edit(row);
          rows[at] = row;
        }
      });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
