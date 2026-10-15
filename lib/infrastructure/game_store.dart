import 'package:shared_preferences/shared_preferences.dart';

abstract interface class GameStore {
  Future<String?> read();
  Future<void> write(String data);
}

class PreferencesGameStore implements GameStore {
  static const key = 'anxin.game.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String data) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, data)) {
      throw StateError('保存未成功');
    }
  }
}
