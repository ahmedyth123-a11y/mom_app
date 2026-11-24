import 'package:alarm/alarm.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../models/app_settings.dart';
import '../models/day_record.dart';
import '../utils.dart';
import 'bootstrap.dart';
import 'ids.dart';
import 'notifications.dart';
import 'prayer_service.dart';
import 'scheduler.dart';
import 'storage.dart';
import 'sync.dart';
import 'tts.dart';

/// Periodic background jobs (survive app close and reboot).
class Background {
  static const _maintenanceId = 1;
  static const _tasbeehId = 2;
  static const _sonCheckId = 3;

  /// (Re)registers the jobs for the current mode and settings.
  static Future<void> register() async {
    final mode = await Storage.mode();
    final s = await Storage.settings();

    if (mode == AppMode.mother) {
      await AndroidAlarmManager.periodic(
          const Duration(hours: 2), _maintenanceId, maintenanceCallback,
          wakeup: true, rescheduleOnReboot: true);
    } else {
      await AndroidAlarmManager.cancel(_maintenanceId);
    }

    if (mode == AppMode.mother && s.tasbeeh) {
      await AndroidAlarmManager.periodic(
          Duration(minutes: s.tasbeehInterval), _tasbeehId, tasbeehCallback,
          startAt: _nextTasbeeh(s), exact: true, wakeup: true, rescheduleOnReboot: true);
    } else {
      await AndroidAlarmManager.cancel(_tasbeehId);
    }

    if (mode == AppMode.son && await Storage.linkedCode() != null) {
      await AndroidAlarmManager.periodic(
          const Duration(minutes: 15), _sonCheckId, sonCheckCallback,
          wakeup: true, rescheduleOnReboot: true);
    } else {
      await AndroidAlarmManager.cancel(_sonCheckId);
    }
  }

  /// First tasbeeh slot after now, aligned to the window start.
  static DateTime _nextTasbeeh(AppSettings s) {
    final now = DateTime.now();
    final today = dayStart(now);
    var t = atMinutes(today, s.tasbeehStart);
    while (!t.isAfter(now)) {
      t = t.add(Duration(minutes: s.tasbeehInterval));
    }
    return t.isAfter(atMinutes(today, s.tasbeehEnd))
        ? atMinutes(addDays(today, 1), s.tasbeehStart)
        : t;
  }
}

/// Mother phone, every 2 hours: refresh prayer times, top up the rolling
/// window of alarms, heartbeat to the son.
@pragma('vm:entry-point')
Future<void> maintenanceCallback() async {
  await ensureServices();
  await PrayerService.refresh();
  await Scheduler.rescheduleAll();
}

/// Ends a play-only alarm (azkar recording) at its scheduled stop time, so it
/// stops blocking later alarms (see [Scheduler.azkarMaxPlay]).
@pragma('vm:entry-point')
Future<void> stopPlayedAlarm(int id) async {
  await ensureServices();
  if (await Alarm.isRinging(id)) await Alarm.stop(id);
}

@pragma('vm:entry-point')
Future<void> tasbeehCallback() async {
  await ensureServices();
  if (await Storage.mode() != AppMode.mother) return;
  final s = await Storage.settings();
  final now = DateTime.now();
  final minutes = now.hour * 60 + now.minute;
  if (!s.tasbeeh || minutes < s.tasbeehStart || minutes > s.tasbeehEnd) return;
  final index = await Storage.nextTasbeehIndex();
  if (!await playTasbeeh(s, index)) {
    await Notifs.show(
        id: Ids.tasbeeh,
        title: 'ذكر',
        body: tasbeehPhrases[index % tasbeehPhrases.length],
        kind: NoteKind.reminder);
  }
}

/// Son phone, every 15 minutes: alert once per missed item and when the
/// mother's phone has been silent for more than 6 hours.
@pragma('vm:entry-point')
Future<void> sonCheckCallback() async {
  await ensureServices();
  if (await Storage.mode() != AppMode.son) return;
  final code = await Storage.linkedCode();
  if (code == null || !await Sync.ensure()) return;

  final now = DateTime.now();
  final today = dateKey(now);
  final yesterday = dateKey(addDays(now, -1));
  final notified = await Storage.sonNotified();
  final fresh = <String>{};

  Future<void> alert(String key, String title, String body) async {
    fresh.add(key);
    if (notified.contains(key)) return;
    await Notifs.show(id: Ids.son(key), title: title, body: body, kind: NoteKind.family);
  }

  try {
    final seen = await Sync.lastSeen(code);
    if (seen != null && now.difference(seen) > const Duration(hours: 6)) {
      await alert('seen|${seen.toIso8601String()}', 'تليفون الوالدة',
          'تليفون الوالدة ما بعتش أي حاجة من أكتر من ٦ ساعات — اطمّن عليها');
    }
    for (final date in [yesterday, today]) {
      final record = await Sync.fetchDay(code, date);
      if (record == null) continue;
      for (final m in record.meds.values) {
        if (m.effective(now) == ItemStatus.missed) {
          await alert('$date|med|${m.key}', 'دوا فات', 'الوالدة ما أكدتش إنها خدت ${m.title}');
        }
      }
      for (final p in record.prayers.values) {
        if (p.effective(now) == ItemStatus.missed) {
          await alert('$date|prayer|${p.key}', 'صلاة فاتت',
              'الوالدة ما أكدتش إنها صلّت ${p.title}');
        }
      }
    }
    // Remember only what is still relevant, so the list stays small.
    await Storage.saveSonNotified(fresh);
  } catch (_) {
    // Offline: try again next time without forgetting what was already shown.
    await Storage.saveSonNotified({...notified, ...fresh});
  }
}
