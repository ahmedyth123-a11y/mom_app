import 'package:flutter/material.dart';

import '../models/day_record.dart';
import '../utils.dart';
import 'day_record_view.dart';

/// Expandable list of past days, newest first.
class HistoryList extends StatelessWidget {
  const HistoryList({super.key, required this.records, required this.now});

  final List<DayRecord> records;
  final DateTime now;

  String _summary(DayRecord r) {
    int done(Iterable<TrackedItem> items) => items
        .where((i) => i.effective(now) == ItemStatus.done || i.effective(now) == ItemStatus.late)
        .length;
    final parts = <String>[
      if (r.meds.isNotEmpty) 'الدوا ${arNum(done(r.meds.values))}/${arNum(r.meds.length)}',
      if (r.prayers.isNotEmpty)
        'الصلاة ${arNum(done(r.prayers.values))}/${arNum(r.prayers.length)}',
      if (r.qiyam != null) 'القيام: ${statusLook(r.qiyam!.effective(now)).$3}',
    ];
    return parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('لسه مفيش سجل'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(formatDate(parseDateKey(r.date)),
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(_summary(r)),
            children: [DayRecordView(record: r, now: now)],
          ),
        );
      },
    );
  }
}
