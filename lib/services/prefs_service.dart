import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _kHideTelegram = 'hide_telegram_dialog';

  static Future<bool> hideTelegram() async =>
      (await SharedPreferences.getInstance()).getBool(_kHideTelegram) ?? false;

  static Future<void> setHideTelegram(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kHideTelegram, v);
}
