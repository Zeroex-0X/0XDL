import 'package:flutter/services.dart';

/// Screen brightness and media volume (talks to the Android side).
class PlayerNative {
  static const _m = MethodChannel('oxdl/ytdlp');

  static Future<double> brightness() async =>
      (await _m.invokeMethod<double>('getBrightness')) ?? 0.5;

  static Future<void> setBrightness(double v) =>
      _m.invokeMethod('setBrightness', {'value': v});

  static Future<void> resetBrightness() =>
      _m.invokeMethod('setBrightness', {'value': -1.0});

  static Future<double> volume() async =>
      (await _m.invokeMethod<double>('getVolume')) ?? 0.5;

  static Future<void> setVolume(double v) =>
      _m.invokeMethod('setVolume', {'value': v});
}
