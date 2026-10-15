import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anxin_xiangqi/application/user_preferences.dart';
import 'package:anxin_xiangqi/domain/lessons.dart';
import 'package:anxin_xiangqi/domain/xiangqi.dart';
import 'package:anxin_xiangqi/infrastructure/audio_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('声音默认关闭，选项往返且吃子/将军选择相应提示；通道失败可见', () async {
    final calls = <MethodCall>[];
    testerBindingHandler((call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() => testerBindingHandler(null));
    final audio = AudioFeedback();
    final before = Position.initial(), move = const Move(54, 45);
    expect(
      await audio.move(
        before,
        move,
        before.play(move),
        const UserPreferences(),
      ),
      isNull,
    );
    expect(calls, isEmpty);
    final prefs = UserPreferences.fromJson(
      const UserPreferences(sound: true, speech: true).toJson(),
    );
    await audio.move(before, move, before.play(move), prefs);
    expect(calls.single.arguments['cue'], 'move');
    expect(calls.single.arguments['speech'], true);
    final cannon = lessons[3].position;
    final capture = cannon.legalMoves().firstWhere((m) => m.to == 18);
    await audio.move(cannon, capture, cannon.play(capture), prefs);
    expect(calls.last.arguments['cue'], 'capture');
    final mate = lessons.first.position;
    final check = mate.legalMoves().firstWhere(
      (m) => mate.play(m).inCheck(Side.black),
    );
    await audio.move(mate, check, mate.play(check), prefs);
    expect(calls.last.arguments['cue'], 'check');
    await audio.stop();
    expect(calls.last.method, 'stop');
    testerBindingHandler((call) async => false);
    expect(
      await audio.move(before, move, before.play(move), prefs),
      contains('未能播放'),
    );
    testerBindingHandler(
      (call) async => throw PlatformException(code: 'audio'),
    );
    expect(
      await audio.move(before, move, before.play(move), prefs),
      contains('未能播放'),
    );
    await audio.stop();
    testerBindingHandler(null);
    expect(
      await audio.move(before, move, before.play(move), prefs),
      contains('尚未接通'),
    );
  });
}

void testerBindingHandler(Future<Object?> Function(MethodCall)? handler) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AudioFeedback.channel, handler);
