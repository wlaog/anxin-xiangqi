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
import 'package:anxin_xiangqi/application/user_preferences.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';

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
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    Future<void> capture(GlobalKey key, String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${output.path}/$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final entry in {'windows': const Size(1280, 800)}.entries) {
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
      await capture(key, entry.key);
      if (entry.key == 'windows') {
        await tester.ensureVisible(find.text('使用设置'));
        await tester.tap(find.text('使用设置'));
        await tester.pumpAndSettle();
        await capture(key, 'windows-settings');
        await tester.tap(find.text('设置好了'));
        await tester.pumpAndSettle();
        await game.setPreferences(const UserPreferences(confirmMoves: true));
        await tester.ensureVisible(find.byType(ChessBoard));
        await tester.pumpAndSettle();
        final board = tester.getRect(find.byType(ChessBoard));
        final cell = board.width / 9;
        await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 6.5));
        await tester.pump();
        await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 5.5));
        await tester.pumpAndSettle();
        await capture(key, 'windows-confirmation');
        await tester.tap(find.text('再想想'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('人机对弈'));
        await tester.pumpAndSettle();
        await capture(key, 'windows-selected');
        await tester.ensureVisible(find.text('放大棋盘'));
        await tester.tap(find.text('放大棋盘'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('放大'));
        await tester.pumpAndSettle();
        await capture(key, 'windows-large-board');
        await tester.tap(find.text('回到棋桌'));
        await tester.pumpAndSettle();
        await game.setPreferences(const UserPreferences());
        await game.play(const Move(54, 45));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('人机对弈'));
        await tester.pumpAndSettle();
        await capture(key, 'windows-response');
        await tester.ensureVisible(find.text('回看棋局'));
        await tester.tap(find.text('回看棋局'));
        await tester.pumpAndSettle();
        await capture(key, 'windows-review');
        await tester.tap(find.text('回到棋桌'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(360, 800);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await game.setPreferences(const UserPreferences(textScale: 1.4));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('回看棋局'));
        await tester.tap(find.text('回看棋局'));
        await tester.pumpAndSettle();
        await capture(key, 'windows-review-narrow-large-text');
        await tester.tap(find.text('返回'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
