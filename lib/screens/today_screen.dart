import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/day_record.dart';
import '../models/prayer_day.dart';
import '../services/prayer_service.dart';
import '../services/scheduler.dart';
import '../services/storage.dart';
import '../utils.dart';
import '../widgets/day_record_view.dart';
import '../widgets/question_dialog.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static Future<(DayRecord?, PrayerDay)> _load() async {
    final now = DateTime.now();
    final table = await PrayerService.table();
    return (await Storage.day(dateKey(now)), table.day(now));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('السلام عليكم')),
      body: ValueListenableBuilder<int>(
        valueListenable: Storage.changes,
        builder: (context, _, __) => FutureBuilder<(DayRecord?, PrayerDay)>(
          future: _load(),
          builder: (context, snap) {
            final data = snap.data;
            if (data == null) return const Center(child: CircularProgressIndicator());
            final (record, prayers) = data;
            final now = DateTime.now();
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _Header(now: now, prayers: prayers),
                if (record == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('بنجهّز مواعيد النهارده...', textAlign: TextAlign.center),
                  )
                else
                  DayRecordView(
                    record: record,
                    now: now,
                    onItemTap: (type, item) => askQuestion(
                        context, jsonEncode(Scheduler.payload(type, record.date, item))),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.prayers});

  final DateTime now;
  final PrayerDay prayers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final next = Prayer.values.where((p) => prayers.timeOf(p).isAfter(now)).firstOrNull;
    final hijri = prayers.hijri;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF2A9D8F)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(formatDate(now), style: theme.textTheme.headlineSmall?.copyWith(color: onPrimary)),
        if (hijri != null)
          Text(hijri.label, style: theme.textTheme.titleMedium?.copyWith(color: onPrimary)),
        const SizedBox(height: 12),
        Text(
          next == null
              ? 'الصلاة الجاية: الفجر بكرة'
              : 'الصلاة الجاية: ${next.arabic} ${formatTime(prayers.timeOf(next))}',
          style: theme.textTheme.titleLarge?.copyWith(color: onPrimary),
        ),
      ]),
    );
  }
}
