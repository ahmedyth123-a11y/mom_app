import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/app_settings.dart';
import 'screens/ring_screen.dart';
import 'services/background.dart';
import 'services/notifications.dart';
import 'services/prayer_service.dart';
import 'services/scheduler.dart';
import 'services/storage.dart';
import 'theme.dart';
import 'widgets/question_dialog.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Brings everything up to date: prayer times, alarms, background jobs.
Future<void> refreshAppData() async {
  if (await Storage.mode() == AppMode.mother) {
    await PrayerService.refresh();
    await Scheduler.rescheduleAll();
  }
  await Background.register();
}

class MomApp extends StatefulWidget {
  const MomApp({super.key, required this.home});

  final Widget home;

  @override
  State<MomApp> createState() => _MomAppState();
}

class _MomAppState extends State<MomApp> with WidgetsBindingObserver {
  late final StreamSubscription<AlarmSettings> _rings;
  int? _shownAlarm;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Notifs.onTap = _ask;
    _rings = Alarm.ringStream.stream.listen(_showRing);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStart());
  }

  @override
  void dispose() {
    _rings.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    Storage.changes.value++; // answers given from notifications while away
    _showRingingAlarm();
    _refresh();
  }

  Future<void> _onStart() async {
    final payload = await Notifs.launchPayload();
    if (payload != null) _ask(payload);
    await _showRingingAlarm();
    await _refresh();
  }

  /// An alarm may have started ringing while the app was closed or in the
  /// background (opened by the full-screen alarm or by tapping its notification).
  Future<void> _showRingingAlarm() async {
    final now = DateTime.now();
    for (final a in await Alarm.getAlarms()) {
      final recent = a.dateTime.isBefore(now) &&
          now.difference(a.dateTime) < const Duration(minutes: 30);
      if (recent && await Alarm.isRinging(a.id)) {
        unawaited(_showRing(a));
        return;
      }
    }
  }

  Future<void> _refresh() async {
    final now = DateTime.now();
    final last = _lastRefresh;
    if (last != null && now.difference(last) < const Duration(minutes: 5)) return;
    _lastRefresh = now;
    await refreshAppData();
  }

  void _ask(String payload) {
    final context = navigatorKey.currentContext;
    if (context != null) askQuestion(context, payload);
  }

  Future<void> _showRing(AlarmSettings alarm) async {
    if (_shownAlarm == alarm.id) return;
    _shownAlarm = alarm.id;
    final info = (await Storage.alarmIndex())[alarm.id];
    await navigatorKey.currentState?.push(MaterialPageRoute<void>(
        builder: (_) => RingScreen(alarmId: alarm.id, info: info)));
    _shownAlarm = null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'منبّه الوالدة',
      theme: buildTheme(),
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: fontScale,
        builder: (context, scale, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: widget.home,
    );
  }
}
