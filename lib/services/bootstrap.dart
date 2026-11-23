import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:flutter/widgets.dart';

import 'notifications.dart';

bool _ready = false;

/// Initializes the plugins every isolate (app or background) needs.
Future<void> ensureServices() async {
  if (_ready) return;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Alarm.init();
  await Notifs.init();
  _ready = true;
}
