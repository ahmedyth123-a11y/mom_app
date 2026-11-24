import 'dart:convert';

import 'package:alarm/alarm.dart';

import '../models/app_settings.dart';
import '../models/day_record.dart';
import '../models/medication.dart';
import '../models/prayer_day.dart';
import '../utils.dart';
import 'ids.dart';
import 'notifications.dart';
import 'prayer_service.dart';
import 'sounds.dart';
import 'storage.dart';
import 'sync.dart';

class _AlarmJob {
  _AlarmJob(this.id, this.at, this.sound, this.title, this.body, this.payload,
      {this.loop = false, this.volume = 0.9, this.fadeSeconds = 0});

  final int id;
  final DateTime at;
  final String sound;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final bool loop;
  final double volume;
  final double fadeSeconds;

  AlarmSettings toSettings() => AlarmSettings(
        id: id,
        dateTime: at,
        // alarm plays 'assets/...' from the APK and an absolute path from disk.
        assetAudioPath: sound,
        loopAudio: loop,
        vibrate: true,
        volume: volume,
        fadeDuration: fadeSeconds,
        warningNotificationOnKill: false,
        androidFullScreenIntent: true,
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          stopButton: 'إيقاف',
        ),
      );
}

class _NoteJob {
  _NoteJob(this.id, this.at, this.title, this.body, this.kind, [this.payload]);

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final NoteKind kind;
  final Map<String, dynamic>? payload;
}

/// Builds each day's plan and schedules every alarm/notification for a
/// rolling window. Safe to call any time: it diffs against what is already
/// scheduled and never touches alarms that are ringing right now.
class Scheduler {
  static const windowDays = 2;
  static const medRepeatGap = Duration(minutes: 10);

  /// First alert + 3 re-alerts 10 minutes apart, then missed.
  static const medWindow = Duration(minutes: 40);
  static const snooze = Duration(minutes: 15);
  static const prayerAskDelay = Duration(minutes: 20);
  static const prayerAskGap = Duration(minutes: 20);

  /// Answering "prayed" later than this after the adhan counts as late.
  static const prayerOnTime = Duration(minutes: 40);
  static const qiyamAskDelay = Duration(minutes: 3);

  /// Notification payload / ringing-screen info for a tracked item.
  static Map<String, dynamic> payload(String type, String date, TrackedItem item) =>
      {'type': type, 'date': date, 'key': item.key, 'title': item.title};

  static Future<void> _running = Future.value();

  /// Runs are queued so two callers (e.g. app resume and a settings change)
  /// never interleave their cancel/schedule calls.
  static Future<void> rescheduleAll() {
    final run = _running.then((_) => _reschedule());
    _running = run.catchError((Object _) {});
    return run;
  }

  static Future<void> _reschedule() async {
    if (await Storage.mode() != AppMode.mother) return;
    final settings = await Storage.settings();
    final meds = await Storage.meds();
    final table = await PrayerService.table();
    final sounds = {
      for (final c in [SoundCategory.adhan, SoundCategory.alarm, SoundCategory.med])
        c: await Sounds.resolve(c, settings.sounds[c]),
    };
    final now = DateTime.now();
    final today = dayStart(now);

    final alarms = <_AlarmJob>[];
    final notes = <_NoteJob>[];
    for (var i = 0; i < windowDays; i++) {
      final day = addDays(today, i);
      final date = dateKey(day);
      final record = _buildRecord(await Storage.day(date), day, settings, meds, table, now);
      await Storage.saveDay(record);
      await Sync.pushDay(record);
      _plan(record, day, settings, sounds, table, now, alarms, notes);
    }
    // Re-send yesterday too: answers given while sync was unavailable
    // (e.g. before the first sign-in succeeded) still reach the son.
    final yesterday = await Storage.day(dateKey(addDays(today, -1)));
    if (yesterday != null) await Sync.pushDay(yesterday);

    await _apply(alarms, notes, now);
    await Storage.pruneDays(addDays(today, -35));
    await Sync.heartbeat();
  }

  /// Today's plan from the current settings. Items already answered or
  /// already due are kept as they were, so history never changes.
  static DayRecord _buildRecord(DayRecord? old, DateTime day, AppSettings s,
      List<Medication> meds, PrayerTable table, DateTime now) {
    final record = DayRecord(date: dateKey(day));
    final pd = table.day(day);

    if (s.meds) {
      for (final m in meds.where((m) => m.activeOn(day))) {
        for (final minutes in m.times) {
          final key = '${m.id}@$minutes';
          final time = atMinutes(day, minutes);
          record.meds[key] = TrackedItem(
              key: key, title: m.label, time: time, deadline: time.add(medWindow));
        }
      }
    }

    if (s.prayers) {
      for (final p in Prayer.values) {
        record.prayers[p.name] = TrackedItem(
          key: p.name,
          title: p.arabic,
          time: pd.timeOf(p),
          deadline: _prayerDeadline(p, pd, day),
        );
      }
    }

    if (s.qiyam) {
      final DateTime time;
      if (s.qiyamAuto) {
        // Start of the last third of the night (previous Maghrib -> Fajr).
        final maghrib = table.day(addDays(day, -1)).maghrib;
        final start = maghrib.add(pd.fajr.difference(maghrib) * (2 / 3));
        time = DateTime(start.year, start.month, start.day, start.hour, start.minute);
      } else {
        time = atMinutes(day, s.qiyamFixed);
      }
      record.qiyam = TrackedItem(
        key: 'qiyam',
        title: 'قيام الليل',
        time: time,
        deadline: time.isBefore(pd.fajr) ? pd.fajr : time.add(const Duration(hours: 1)),
      );
    }

    if (old != null) {
      bool keep(TrackedItem item) => item.answered || !item.time.isAfter(now);
      for (final e in old.meds.entries) {
        if (keep(e.value)) record.meds[e.key] = e.value;
      }
      for (final e in old.prayers.entries) {
        if (keep(e.value)) record.prayers[e.key] = e.value;
      }
      if (old.qiyam != null && keep(old.qiyam!)) record.qiyam = old.qiyam;
    }
    return record;
  }

  /// Reminders stop 15 minutes before the next prayer; Fajr's end is
  /// sunrise, Isha's is midnight.
  static DateTime _prayerDeadline(Prayer p, PrayerDay pd, DateTime day) {
    const margin = Duration(minutes: 15);
    return switch (p) {
      Prayer.fajr => pd.sunrise.subtract(margin),
      Prayer.dhuhr => pd.asr.subtract(margin),
      Prayer.asr => pd.maghrib.subtract(margin),
      Prayer.maghrib => pd.isha.subtract(margin),
      Prayer.isha => addDays(day, 1),
    };
  }

  static void _plan(DayRecord record, DateTime day, AppSettings s,
      Map<SoundCategory, String> sounds, PrayerTable table, DateTime now,
      List<_AlarmJob> alarms, List<_NoteJob> notes) {
    final date = record.date;
    final pd = table.day(day);

    for (final item in record.meds.values.where((m) => !m.answered)) {
      final start = item.alertAt ?? item.time;
      final info = payload('med', date, item);
      for (var n = 0; n < Ids.medRepeats; n++) {
        final at = start.add(medRepeatGap * n);
        if (!at.isAfter(now)) continue;
        alarms.add(_AlarmJob(Ids.medAlarm(date, item.key, n), at,
            sounds[SoundCategory.med]!, 'معاد الدوا', item.title, info));
        notes.add(_NoteJob(Ids.medNote(date, item.key, n), at, 'معاد الدوا',
            'خدتي ${item.title}؟', NoteKind.med, info));
      }
    }

    for (final item in record.prayers.values.where((p) => !p.answered)) {
      final info = payload('prayer', date, item);
      if (item.time.isAfter(now)) {
        alarms.add(_AlarmJob(Ids.adhan(date, item.key), item.time,
            sounds[SoundCategory.adhan]!, 'أذان ${item.title}', 'حان الآن موعد صلاة ${item.title}', info,
            volume: 0.8));
      }
      var at = item.time.add(prayerAskDelay);
      for (var n = 0; n < Ids.maxPrayerAsks && !at.isAfter(item.deadline); n++) {
        if (at.isAfter(now)) {
          notes.add(_NoteJob(Ids.prayerNote(date, item.key, n), at, 'صلاة ${item.title}',
              'صلّيتي ${item.title}؟', NoteKind.prayer, info));
        }
        at = at.add(prayerAskGap);
      }
    }

    final qiyam = record.qiyam;
    if (qiyam != null && !qiyam.answered) {
      final info = payload('qiyam', date, qiyam);
      if (qiyam.time.isAfter(now)) {
        alarms.add(_AlarmJob(Ids.qiyamAlarm(date), qiyam.time, sounds[SoundCategory.alarm]!,
            'قيام الليل', 'قومي يا أمي، ربنا يتقبّل', info,
            loop: true, volume: 1.0, fadeSeconds: 30));
      }
      final ask = qiyam.time.add(qiyamAskDelay);
      if (ask.isAfter(now)) {
        notes.add(_NoteJob(Ids.qiyamNote(date), ask, 'قيام الليل', 'قمتي للقيام؟',
            NoteKind.qiyam, info));
      }
    }

    if (s.azkar) {
      const delay = Duration(minutes: 30);
      notes.add(_NoteJob(Ids.azkar(date, true), pd.fajr.add(delay), 'أذكار الصباح',
          'وقت أذكار الصباح، ربنا يحفظك', NoteKind.reminder));
      notes.add(_NoteJob(Ids.azkar(date, false), pd.asr.add(delay), 'أذكار المسا',
          'وقت أذكار المسا، ربنا يحفظك', NoteKind.reminder));
    }

    if (s.fasting) {
      final reasons = <String>[
        if (day.weekday == DateTime.sunday) 'بكرة الاتنين',
        if (day.weekday == DateTime.wednesday) 'بكرة الخميس',
      ];
      final hijriTomorrow = table.day(addDays(day, 1)).hijri;
      if (hijriTomorrow != null && hijriTomorrow.day >= 13 && hijriTomorrow.day <= 15) {
        reasons.add('بكرة من الأيام البيض');
      }
      if (reasons.isNotEmpty) {
        notes.add(_NoteJob(Ids.fasting(date), atMinutes(day, 21 * 60), 'صيام بكرة',
            '${reasons.join(' و')} — لو ناوية تصومي متنسيش السحور والنية', NoteKind.reminder));
      }
    }
  }

  static Future<void> _apply(List<_AlarmJob> alarms, List<_NoteJob> notes, DateTime now) async {
    final wantedAlarms = {for (final a in alarms) a.id};
    final staleBefore = now.subtract(const Duration(minutes: 90));
    for (final a in await Alarm.getAlarms()) {
      final obsolete = a.dateTime.isAfter(now) && !wantedAlarms.contains(a.id);
      final stale = a.dateTime.isBefore(staleBefore);
      if (obsolete || stale) await Alarm.stop(a.id);
    }
    for (final a in alarms) {
      await Alarm.set(alarmSettings: a.toSettings());
    }

    // Keep info for alarms still alive (e.g. ringing now) plus the new ones.
    final alive = {for (final a in await Alarm.getAlarms()) a.id};
    final index = await Storage.alarmIndex();
    index.removeWhere((id, _) => !alive.contains(id));
    for (final a in alarms) {
      index[a.id] = a.payload;
    }
    await Storage.saveAlarmIndex(index);

    final wantedNotes = {for (final n in notes) n.id};
    for (final id in await Notifs.pendingIds()) {
      if (!wantedNotes.contains(id)) await Notifs.cancel(id);
    }
    for (final n in notes) {
      // zonedSchedule throws for a past time, which would abort the rest;
      // the plan's `now` is seconds old by here (sync/alarm calls ran since).
      if (!n.at.isAfter(DateTime.now())) continue;
      await Notifs.schedule(
        id: n.id,
        at: n.at,
        title: n.title,
        body: n.body,
        kind: n.kind,
        payload: n.payload == null ? null : jsonEncode(n.payload),
      );
    }
  }
}
