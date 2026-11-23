import 'package:flutter/material.dart';

import '../models/day_record.dart';
import '../services/storage.dart';
import '../utils.dart';
import '../widgets/history_list.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static Future<List<DayRecord>> _load() async {
    final today = dayStart(DateTime.now());
    final records = <DayRecord>[];
    for (var i = 0; i < 30; i++) {
      final r = await Storage.day(dateKey(addDays(today, -i)));
      if (r != null && !r.isEmpty) records.add(r);
    }
    return records;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('السجل (آخر ٣٠ يوم)')),
      body: ValueListenableBuilder<int>(
        valueListenable: Storage.changes,
        builder: (context, _, __) => FutureBuilder<List<DayRecord>>(
          future: _load(),
          builder: (context, snap) {
            final records = snap.data;
            if (records == null) return const Center(child: CircularProgressIndicator());
            return HistoryList(records: records, now: DateTime.now());
          },
        ),
      ),
    );
  }
}
