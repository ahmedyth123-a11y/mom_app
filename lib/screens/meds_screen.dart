import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/scheduler.dart';
import '../services/storage.dart';
import '../utils.dart';
import '../widgets/section_card.dart';
import 'med_edit_screen.dart';

class MedsScreen extends StatelessWidget {
  const MedsScreen({super.key});

  void _edit(BuildContext context, [Medication? med]) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => MedEditScreen(med: med)));
  }

  Future<void> _delete(BuildContext context, Medication med) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تمسحي ${med.name}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لأ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('أيوه امسح')),
        ],
      ),
    );
    if (ok != true) return;
    final meds = await Storage.meds();
    meds.removeWhere((m) => m.id == med.id);
    await Storage.saveMeds(meds);
    await Scheduler.rescheduleAll();
  }

  String _days(Medication m) => m.weekdays.isEmpty
      ? 'كل يوم'
      : [for (final d in m.weekdays) weekdayNames[d]].join('، ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأدوية')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add, size: 30),
        label: const Text('إضافة دوا', style: TextStyle(fontSize: 21)),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: Storage.changes,
        builder: (context, _, __) => FutureBuilder<List<Medication>>(
          future: Storage.meds(),
          builder: (context, snap) {
            final meds = snap.data;
            if (meds == null) return const Center(child: CircularProgressIndicator());
            if (meds.isEmpty) {
              return const Center(child: Text('لسه مفيش أدوية.\nدوسي على "إضافة دوا"',
                  textAlign: TextAlign.center));
            }
            return ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              children: [
                for (final m in meds)
                  SectionCard(
                    title: m.name,
                    icon: Icons.medication,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (m.dose.isNotEmpty) Text(m.dose),
                      Text('المواعيد: ${m.times.map(formatMinutes).join('، ')}'),
                      Text('الأيام: ${_days(m)}'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _edit(context, m),
                            icon: const Icon(Icons.edit),
                            label: const Text('تعديل'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                            onPressed: () => _delete(context, m),
                            icon: const Icon(Icons.delete),
                            label: const Text('مسح'),
                          ),
                        ),
                      ]),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
