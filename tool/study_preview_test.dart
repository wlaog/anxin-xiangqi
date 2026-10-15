// Local visual QA; installed font never ships with the application.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/study_notebook.dart';
import 'package:anxin_xiangqi/application/game_controller.dart';
import 'package:anxin_xiangqi/application/user_preferences.dart';
import 'package:anxin_xiangqi/main.dart';

import '../test/controller_test.dart' show MemoryStore, ImmediateAi;
import '../test/study_widget_test.dart' show tapVisible, tapStudySquare;

void main() {
  testWidgets('练习区原生字号与大字预览', (tester) async {
    final fontPath = Platform.environment['ANXIN_PREVIEW_FONT'];
    if (fontPath == null) throw StateError('Set ANXIN_PREVIEW_FONT');
    final font = FontLoader('Microsoft YaHei')
      ..addFont(
        Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
      );
    await font.load();
    final notebook = StudyNotebook(MemoryStore());
    addTearDown(notebook.dispose);
    final game = GameController(store: MemoryStore(), engine: ImmediateAi());
    addTearDown(game.dispose);
    await game.initialize();
    final key = GlobalKey();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: AnxinApp(controller: game, notebook: notebook),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/art/elm-wood.png'),
        key.currentContext!,
      ),
    );
    final output = Directory('artifacts/previews')..createSync(recursive: true);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${output.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await tapVisible(tester, '练习与研究');
    await tapVisible(tester, '原创残局');
    await tapVisible(tester, '双车封住宫门');
    await capture('windows-study-puzzle');
    await tapVisible(tester, '摆棋');
    await capture('windows-study-editor');
    await tapVisible(tester, '标准摆法');
    await tapVisible(tester, '开始试走');
    await tapStudySquare(tester, 54);
    await tapStudySquare(tester, 45);
    await tapStudySquare(tester, 27);
    await tapStudySquare(tester, 36);
    await tapVisible(tester, '回退一步');
    await tapStudySquare(tester, 29);
    await tapStudySquare(tester, 38);
    await tapVisible(tester, '回退一步');
    await capture('windows-study-branches');
    await tapVisible(tester, '互动教程');
    await tapVisible(tester, '兵：向前不过退');
    await tapVisible(tester, '换一份');
    for (final spec in [
      ('windows-study-narrow', const Size(360, 800)),
      ('windows-study-landscape', const Size(640, 360)),
    ]) {
      tester.view.physicalSize = spec.$2;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await game.setPreferences(const UserPreferences(textScale: 1.4));
      await tester.pumpAndSettle();
      if (spec.$2.height < 500) await tester.ensureVisible(find.text('看提示'));
      await capture(spec.$1);
    }
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
