import 'package:flutter/material.dart';

import '../models/day_record.dart';
import '../utils.dart';
import 'section_card.dart';

(IconData, Color, String) statusLook(ItemStatus s) => switch (s) {
      ItemStatus.done => (Icons.check_circle, const Color(0xFF2E7D32), 'تمّ'),
      ItemStatus.late => (Icons.watch_later, const Color(0xFFEF6C00), 'متأخر'),
      ItemStatus.missed => (Icons.cancel, const Color(0xFFC62828), 'فات'),
      ItemStatus.pending => (Icons.hourglass_empty, Colors.blueGrey, 'لسه'),
    };

class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item, required this.now, this.onTap});

  final TrackedItem item;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = statusLook(item.effective(now));
    final answeredAt = item.at;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 36),
      title: Text(item.title),
      subtitle: Text(answeredAt == null
          ? formatTime(item.time)
          : '${formatTime(item.time)} — الرد ${formatTime(answeredAt)}'),
      trailing: Text(label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
      onTap: onTap,
    );
  }
}

/// Prayers, medications and qiyam of one day with their statuses.
class DayRecordView extends StatelessWidget {
  const DayRecordView({super.key, required this.record, required this.now, this.onItemTap});

  final DayRecord record;
  final DateTime now;

  /// When set, due unanswered items can be tapped to answer them.
  final void Function(String type, TrackedItem item)? onItemTap;

  VoidCallback? _tap(String type, TrackedItem item) {
    final cb = onItemTap;
    if (cb == null || item.answered || item.time.isAfter(now)) return null;
    return () => cb(type, item);
  }

  @override
  Widget build(BuildContext context) {
    final qiyam = record.qiyam;
    return Column(children: [
      if (record.prayers.isNotEmpty)
        SectionCard(
          title: 'الصلاة',
          icon: Icons.mosque,
          child: Column(children: [
            for (final p in record.prayersByTime)
              ItemTile(item: p, now: now, onTap: _tap('prayer', p)),
          ]),
        ),
      SectionCard(
        title: 'الأدوية',
        icon: Icons.medication,
        child: record.meds.isEmpty
            ? const Text('مفيش أدوية في اليوم ده')
            : Column(children: [
                for (final m in record.medsByTime)
                  ItemTile(item: m, now: now, onTap: _tap('med', m)),
              ]),
      ),
      if (qiyam != null)
        SectionCard(
          title: 'قيام الليل',
          icon: Icons.nightlight_round,
          child: ItemTile(item: qiyam, now: now, onTap: _tap('qiyam', qiyam)),
        ),
    ]);
  }
}
