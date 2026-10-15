import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'game_store.dart';

/// Owns a separate library file, a previous copy, and its temporary writes.
/// Replacements stay on one volume. A missing primary can use the backup.
class LibraryFileStore implements GameStore {
  LibraryFileStore({this.directory});
  final Directory? directory;
  Future<Directory>? _root;
  bool _readOnce = false;
  String? _baseline;
  final _cleanup = <Directory>{};

  Future<Directory> _location() => _root ??= directory == null
      ? getApplicationSupportDirectory().then(
          (base) => Directory('${base.path}/chess-library'),
        )
      : Future.value(directory);

  Future<T> _locked<T>(Future<T> Function(Directory) action) async {
    final directory = await _location();
    await directory.create(recursive: true);
    final lock = await File('${directory.path}/games.lock')
        .open(mode: FileMode.append);
    var acquired = false;
    try {
      await lock.lock(FileLock.exclusive);
      acquired = true;
      return await action(directory);
    } finally {
      try {
        if (acquired) await lock.unlock();
      } finally {
        await lock.close();
      }
    }
  }

  Future<String?> _contents(Directory directory) async {
    final primary = File('${directory.path}/games.json');
    if (await primary.exists()) return primary.readAsString();
    final backup = File('${directory.path}/games.previous.json');
    return await backup.exists() ? backup.readAsString() : null;
  }

  @override
  Future<String?> read() => _locked((directory) async {
    _baseline = await _contents(directory);
    _readOnce = true;
    return _baseline;
  });

  Future<void> _cleanOwned() async {
    for (final directory in _cleanup.toList()) {
      try {
        if (await directory.exists()) await directory.delete(recursive: true);
        _cleanup.remove(directory);
      } on FileSystemException {
        /* Retain ownership for a later cleanup retry. */
      }
    }
  }

  @override
  Future<void> write(String data) => _locked((directory) async {
    final actual = await _contents(directory);
    if (_readOnce && actual != _baseline) throw GameStoreConflict();
    await _cleanOwned();
    final temporaryDirectory = await directory.createTemp('write-');
    _cleanup.add(temporaryDirectory);
    final temporary = File('${temporaryDirectory.path}/games.json');
    final primary = File('${directory.path}/games.json');
    final backup = File('${directory.path}/games.previous.json');
    try {
      await temporary.writeAsString(data, flush: true);
      if (await primary.exists()) {
        await primary.copy(backup.path);
        final handle = await backup.open(mode: FileMode.append);
        try {
          await handle.flush();
        } finally {
          await handle.close();
        }
      }
      await temporary.rename(primary.path);
      _baseline = data;
      _readOnce = true;
    } finally {
      await _cleanOwned();
    }
  });
}
