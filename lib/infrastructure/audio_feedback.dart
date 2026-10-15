import 'package:flutter/services.dart';

import '../application/user_preferences.dart';
import '../domain/game_record.dart';
import '../domain/xiangqi.dart';

/// Local Windows synthesis; absence/failure is visible and never affects chess.
class AudioFeedback {
  static const channel = MethodChannel('anxin/audio');
  Future<String?> play({
    required String cue,
    required String text,
    required bool sound,
    required bool speech,
  }) async {
    if (!sound && !speech) return null;
    try {
      final ok = await channel.invokeMethod<bool>('play', {
        'cue': cue,
        'text': text,
        'sound': sound,
        'speech': speech,
      });
      return ok == true ? null : '声音未能播放，请检查系统音量、输出设备和本机中文语音。';
    } on MissingPluginException {
      return '当前平台尚未接通声音辅助；Windows 演示版可使用。';
    } on PlatformException {
      return '声音未能播放，请检查系统声音和本机中文语音。';
    }
  }

  Future<String?> move(
    Position before,
    Move move,
    Position after,
    UserPreferences preferences,
  ) {
    final entry = GameRecordEntry.fromMove(before: before, move: move, ply: 1);
    final check = after.inCheck(after.turn);
    return play(
      cue: check
          ? 'check'
          : entry.captured != null
          ? 'capture'
          : 'move',
      text: '${entry.description}${check ? '将军。' : ''}',
      sound: preferences.sound,
      speech: preferences.speech,
    );
  }

  Future<void> stop() async {
    try {
      await channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      /* Platform not enabled. */
    } on PlatformException {
      /* Stopping must not block preference changes. */
    }
  }
}
