import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'models/app_settings.dart';
import 'screens/mode_select_screen.dart';
import 'screens/mother_shell.dart';
import 'screens/son_dashboard_screen.dart';
import 'screens/son_link_screen.dart';
import 'services/bootstrap.dart';
import 'services/storage.dart';
import 'services/sync.dart';
import 'theme.dart';

Future<void> main() async {
  await ensureServices();
  await AndroidAlarmManager.initialize();
  fontScale.value = (await Storage.settings()).fontScale;

  final mode = await Storage.mode();
  final linked = await Storage.linkedCode();
  // The son's screens read Firestore directly.
  if (mode == AppMode.son && linked != null) await Sync.ensure();

  final Widget home = switch (mode) {
    null => const ModeSelectScreen(),
    AppMode.mother => const MotherShell(),
    AppMode.son => linked == null ? const SonLinkScreen() : SonDashboardScreen(code: linked),
  };
  runApp(MomApp(home: home));
}
