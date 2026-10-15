// Optional local preview: flutter test tool/preview_test.dart --no-pub
// Uses a local Windows font for inspection; the font is never bundled.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/main.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';

import '../test/controller_test.dart' show MemoryStore, ImmediateAi;

void main() {
  testWidgets('render native-size previews', (tester) async {
    final fontPath = Platform.environment['ANXIN_PREVIEW_FONT'];
    if (fontPath == null) {
      throw StateError('Set ANXIN_PREVIEW_FONT to a local Chinese font path.');
    }
    final loader = FontLoader('Microsoft YaHei');
    loader.addFont(
      Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
    );
    await loader.load();
    final output = Directory('artifacts/previews')..createSync(recursive: true);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (final entry in {
      'windows': const Size(1280, 800),
      'android': const Size(412, 915),
    }.entries) {
      tester.view.physicalSize = entry.value;
      final game = GameController(store: MemoryStore(), engine: ImmediateAi());
      await game.initialize();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: AnxinApp(controller: game),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/art/elm-wood.png'),
          key.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${output.path}/${entry.key}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    }
  });
}
