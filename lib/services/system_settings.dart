import 'package:flutter/services.dart';

/// Native helpers in MainActivity.kt for the reliability screen.
class SystemSettings {
  static const _channel = MethodChannel('mom_app/system');

  /// Keys: battery, exactAlarm, fullScreen.
  static Future<Map<String, bool>> status() async =>
      await _channel.invokeMapMethod<String, bool>('status') ?? const {};

  static Future<void> openBattery() => _channel.invokeMethod<void>('openBattery');
  static Future<void> openExactAlarm() => _channel.invokeMethod<void>('openExactAlarm');
  static Future<void> openFullScreen() => _channel.invokeMethod<void>('openFullScreen');
  static Future<void> openAutostart() => _channel.invokeMethod<void>('openAutostart');
}
