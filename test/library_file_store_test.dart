import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/game_library.dart';
import 'package:anxin_xiangqi/application/study_notebook.dart';
import 'package:anxin_xiangqi/domain/study.dart';
import 'package:anxin_xiangqi/domain/rules.dart';
import 'package:anxin_xiangqi/domain/game_snapshot.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/infrastructure/game_store.dart';
import 'package:anxin_xiangqi/infrastructure/library_file_store.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anxin-library-test-');
  });
  tearDown(() async {
    final target = await directory.resolveSymbolicLinks();
    final parent = await Directory.systemTemp.resolveSymbolicLinks();
    if (!target.startsWith(
      '$parent${Platform.pathSeparator}anxin-library-test-',
    )) {
      throw StateError('Unexpected cleanup target');
    }
    await directory.delete(recursive: true);
  });

  test('真实文件保存、重开、上一份备份和多窗口冲突保护', () async {
    final first = GameLibrary(LibraryFileStore(directory: directory));
    final stale = GameLibrary(LibraryFileStore(directory: directory));
    addTearDown(first.dispose);
    addTearDown(stale.dispose);
    await first.initialize();
    await stale.initialize();
    final snapshot = GameSnapshot(
      moves: [const Move(54, 45)],
      side: Side.red,
      level: 2,
    );
    await first.save('one', snapshot);
    final initial = await File('${directory.path}/games.json').readAsString();
    await first.rename('one', '落盘后的棋局');
    expect(
      await File('${directory.path}/games.previous.json').readAsString(),
      initial,
    );
    await expectLater(
      stale.save('two', snapshot),
      throwsA(isA<GameStoreConflict>()),
    );
    expect(stale.writable, false);
    expect(stale.notice, contains('另一个窗口'));
    final reopened = GameLibrary(LibraryFileStore(directory: directory));
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.entries.single.id, 'one');
    expect(reopened.entries.single.title, '落盘后的棋局');
    expect(directory.listSync().whereType<Directory>(), isEmpty);
  });

  test('练习笔记真实落盘、备份、重开与外部修改拒绝覆盖', () async {
    final first = StudyNotebook(LibraryFileStore.study(directory: directory));
    final stale = StudyNotebook(LibraryFileStore.study(directory: directory));
    addTearDown(first.dispose);
    addTearDown(stale.dispose);
    await first.initialize();
    await stale.initialize();
    final tree = importStudy('a3a4 a6a5', BasicRules());
    await first.saveDraft(tree);
    final original = await File('${directory.path}/games.json').readAsString();
    await first.record('learn-rook', success: true);
    expect(
      await File('${directory.path}/games.previous.json').readAsString(),
      original,
    );
    await expectLater(
      stale.record('learn-rook', success: false),
      throwsA(isA<GameStoreConflict>()),
    );
    expect(stale.writable, false);
    expect(stale.notice, contains('另一个窗口'));
    final reopened = StudyNotebook(
      LibraryFileStore.study(directory: directory),
    );
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.completed, {'learn-rook'});
    expect(
      StudyTree.fromJson(reopened.draft, BasicRules()).toJson(),
      tree.toJson(),
    );
  });

  test('主文件缺失时读上一份备份，后续成功保存恢复主文件', () async {
    final store = LibraryFileStore(directory: directory);
    await store.write('first');
    await store.write('second');
    await File('${directory.path}/games.json').delete();
    final recovered = LibraryFileStore(directory: directory);
    expect(await recovered.read(), 'first');
    await recovered.write('third');
    expect(await LibraryFileStore(directory: directory).read(), 'third');
    expect(
      await File('${directory.path}/games.previous.json').readAsString(),
      'first',
    );
  });

  test('主文件损坏时不静默采用旧备份或写空库', () async {
    final store = LibraryFileStore(directory: directory);
    final valid = jsonEncode({'version': 1, 'entries': []});
    await store.write(valid);
    await store.write(valid);
    await File('${directory.path}/games.json').writeAsString('{damaged');
    final library = GameLibrary(LibraryFileStore(directory: directory));
    addTearDown(library.dispose);
    await library.initialize();
    expect(library.writable, false);
    await expectLater(
      library.save('no', GameSnapshot(moves: [], side: Side.red, level: 1)),
      throwsStateError,
    );
    expect(
      await File('${directory.path}/games.json').readAsString(),
      '{damaged',
    );
    expect(
      await File('${directory.path}/games.previous.json').readAsString(),
      valid,
    );
  });

  test('主路径被目录占用时，替换失败仍保留备份并清理自己的临时目录', () async {
    await Directory('${directory.path}/games.json').create();
    await File('${directory.path}/games.previous.json')
        .writeAsString('retained');
    final store = LibraryFileStore(directory: directory);
    expect(await store.read(), 'retained');
    await expectLater(
      store.write('candidate'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await Directory('${directory.path}/games.json').exists(), true);
    expect(await store.read(), 'retained');
    expect(directory.listSync().whereType<Directory>().length, 1);
  });
}
