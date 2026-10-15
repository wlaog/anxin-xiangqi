// Local visual QA only. The installed font is not distributed.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/application/game_library.dart';
import 'package:anxin_xiangqi/application/user_preferences.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/main.dart';
import 'package:anxin_xiangqi/presentation/game_library_dialog.dart';

import '../test/controller_test.dart' show MemoryStore, ImmediateAi;
import '../test/experience_test.dart' show tapVisible;

void main() {
  testWidgets('棋局库桌面和大字预览', (tester) async {
    final fontPath = Platform.environment['ANXIN_PREVIEW_FONT'];
    if (fontPath == null) throw StateError('Set ANXIN_PREVIEW_FONT');
    final font = FontLoader('Microsoft YaHei')
      ..addFont(
        Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
      );
    await font.load();
    final output = Directory('artifacts/previews')..createSync(recursive: true);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final library = GameLibrary(MemoryStore());
    final game = GameController(
      store: MemoryStore(),
      engine: ImmediateAi(),
      library: library,
    );
    addTearDown(game.dispose);
    addTearDown(library.dispose);
    await game.initialize();
    await game.play(const Move(54, 45));
    await game.newGame();
    await library.rename(library.entries.single.id, '今天想再研究的棋');
    await library.favorite(library.entries.single.id, true);
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: AnxinApp(controller: game),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, '我的棋局');
    for (final spec in [
      ('windows-library', const Size(1280, 800), false),
      ('windows-library-narrow', const Size(360, 800), true),
      ('windows-library-landscape', const Size(640, 360), true),
    ]) {
      tester.view.physicalSize = spec.$2;
      tester.platformDispatcher.textScaleFactorTestValue = spec.$3 ? 2 : 1;
      await game.setPreferences(UserPreferences(textScale: spec.$3 ? 1.4 : 1));
      await tester.pumpAndSettle();
      if (spec.$3) {
        await tester.scrollUntilVisible(
          find.text('查看棋谱'),
          260,
          scrollable: find.descendant(
            of: find.byType(GameLibraryDialog),
            matching: find.byType(Scrollable),
          ),
        );
      }
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${output.path}/${spec.$1}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
