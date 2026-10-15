import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/notation.dart';
import '../domain/rules.dart';
import '../domain/xiangqi.dart';

typedef _RulesNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _RulesDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _SearchNative = Pointer<Utf8> Function(
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Int32,
  Int32,
);
typedef _SearchDart = Pointer<Utf8> Function(
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  int,
  int,
);

class _Bridge {
  _Bridge(String path) : library = DynamicLibrary.open(path);
  final DynamicLibrary library;
  Map<String, dynamic> rules(String fen, String moves) => using((arena) {
    final fn = library.lookupFunction<_RulesNative, _RulesDart>('ax_rules');
    return _decode(
      fn(
        fen.toNativeUtf8(allocator: arena),
        moves.toNativeUtf8(allocator: arena),
      ),
    );
  });
  Map<String, dynamic> search(
    String fen,
    String moves,
    String network,
    int level,
    int seed,
  ) => using((arena) {
    final fn = library.lookupFunction<_SearchNative, _SearchDart>('ax_search');
    return _decode(
      fn(
        fen.toNativeUtf8(allocator: arena),
        moves.toNativeUtf8(allocator: arena),
        network.toNativeUtf8(allocator: arena),
        level,
        seed,
      ),
    );
  });
  void stop() =>
      library.lookupFunction<Void Function(), void Function()>('ax_stop')();
  static Map<String, dynamic> _decode(Pointer<Utf8> value) {
    final data = jsonDecode(value.toDartString()) as Map<String, dynamic>;
    if (data['error'] != null) throw StateError(data['error'] as String);
    return data;
  }
}

/// The NNUE and all searches stay on the device. Searches use a worker isolate.
class PikafishRuntime implements HistoryAiEngine, RuleBook {
  PikafishRuntime({required this.libraryPath, required this.networkPath})
    : _bridge = _Bridge(libraryPath);
  final String libraryPath, networkPath;
  final _Bridge _bridge;
  final _random = Random.secure();

  static Future<PikafishRuntime> open() async {
    final String library, network;
    if (Platform.isWindows) {
      final executable = File(Platform.resolvedExecutable).parent.path;
      library = File('$executable/anxin_pikafish.dll').existsSync()
          ? '$executable/anxin_pikafish.dll'
          : '${Directory.current.path}/native/bin/windows/anxin_pikafish.dll';
      final bundled =
          '$executable/data/flutter_assets/assets/engine/pikafish.nnue';
      network = File(bundled).existsSync()
          ? bundled
          : '${Directory.current.path}/assets/engine/pikafish.nnue';
    } else if (Platform.isAndroid) {
      library = 'libanxin_pikafish.so';
      final directory = await getApplicationSupportDirectory();
      network = '${directory.path}/pikafish-bf398271.nnue';
      final file = File(network);
      if (!await file.exists() || await file.length() != 50241100) {
        final data = await rootBundle.load('assets/engine/pikafish.nnue');
        final temporary = File('$network.tmp');
        await temporary.writeAsBytes(data.buffer.asUint8List(), flush: true);
        await temporary.rename(network);
      }
    } else {
      throw UnsupportedError('目前支持 Windows 和 Android');
    }
    if (!File(network).existsSync()) throw StateError('缺少本地棋力文件，请运行模型准备脚本');
    return PikafishRuntime(libraryPath: library, networkPath: network);
  }

  @override
  RuleVerdict judge(List<Position> history, List<Move> moves) {
    final data = _bridge.rules(
      toFen(history.first),
      moves.map(moveName).join(' '),
    );
    final result = switch (data['result']) {
      'redWins' => Outcome.redWins,
      'blackWins' => Outcome.blackWins,
      'draw' => Outcome.repetitionDraw,
      _ => Outcome.playing,
    };
    return RuleVerdict(
      result,
      (data['legal'] as List).cast<String>().map(parseMove).toList(),
      forbidden: (data['forbidden'] as List)
          .cast<String>()
          .map(parseMove)
          .toList(),
    );
  }

  @override
  Future<Move?> choose(Position position, int level) =>
      chooseGame([position], [], level);

  @override
  Future<Move?> chooseGame(
    List<Position> history,
    List<Move> moves,
    int level,
  ) async {
    final library = libraryPath, network = networkPath;
    final fen = toFen(history.first),
        record = moves.map(moveName).join(' '),
        seed = _random.nextInt(0x7fffffff);
    final data = await Isolate.run(
      () => _Bridge(library).search(fen, record, network, level, seed),
    );
    return data['move'] == null ? null : parseMove(data['move'] as String);
  }

  @override
  void stop() => _bridge.stop();
}
