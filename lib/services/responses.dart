import 'dart:convert';

import 'package:alarm/alarm.dart';

import '../models/day_record.dart';
import 'ids.dart';
import 'notifications.dart';
import 'scheduler.dart';
import 'storage.dart';
import 'sync.dart';

/// Applies her answer (from a notification button, the ringing screen or
/// the app) to the day record, silences related alerts and syncs.
class Responses {
  static Future<void> handle(String action, String payload) async {
    if (action == NoteActions.notYet) return; // next reminder is already scheduled
    final p = jsonDecode(payload) as Map<String, dynamic>;
    final type = p['type'] as String;
    final date = p['date'] as String;
    final key = p['key'] as String;

    final record = await Storage.day(date);
    if (record == null) return;
    final now = DateTime.now();

    switch (type) {
      case 'med':
        final item = record.meds[key];
        if (item == null) return;
        for (var n = 0; n < Ids.medRepeats; n++) {
          await Alarm.stop(Ids.medAlarm(date, key, n));
          await Notifs.cancel(Ids.medNote(date, key, n));
        }
        if (action == NoteActions.took) {
          item.status = ItemStatus.done;
          item.at = now;
        } else if (action == NoteActions.snooze) {
          final next = now.add(Scheduler.snooze);
          item.alertAt = next;
          item.deadline = next.add(Scheduler.medWindow);
        }
      case 'prayer':
        final item = record.prayers[key];
        if (item == null || action != NoteActions.prayed) return;
        item.status = now.isAfter(item.time.add(Scheduler.prayerOnTime))
            ? ItemStatus.late
            : ItemStatus.done;
        item.at = now;
        await Alarm.stop(Ids.adhan(date, key));
        for (var n = 0; n < Ids.maxPrayerAsks; n++) {
          await Notifs.cancel(Ids.prayerNote(date, key, n));
        }
      case 'qiyam':
        final item = record.qiyam;
        if (item == null) return;
        item.status = action == NoteActions.woke ? ItemStatus.done : ItemStatus.missed;
        item.at = now;
        await Alarm.stop(Ids.qiyamAlarm(date));
        await Notifs.cancel(Ids.qiyamNote(date));
      default:
        return;
    }

    await Storage.saveDay(record);
    await Sync.pushDay(record);
    if (action == NoteActions.snooze) await Scheduler.rescheduleAll();
  }
}
