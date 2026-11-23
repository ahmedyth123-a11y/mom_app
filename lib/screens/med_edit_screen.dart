import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/scheduler.dart';
import '../services/storage.dart';
import '../utils.dart';

class MedEditScreen extends StatefulWidget {
  const MedEditScreen({super.key, this.med});

  final Medication? med;

  @override
  State<MedEditScreen> createState() => _MedEditScreenState();
}

class _MedEditScreenState extends State<MedEditScreen> {
  late final _name = TextEditingController(text: widget.med?.name);
  late final _dose = TextEditingController(text: widget.med?.dose);
  late final Set<int> _times = {...?widget.med?.times};
  late final Set<int> _days = {...?widget.med?.weekdays};

  static const _weekOrder = [
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  Future<int?> _pickTime(int initial) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _addTime() async {
    final m = await _pickTime(9 * 60);
    if (m != null) setState(() => _times.add(m));
  }

  Future<void> _changeTime(int old) async {
    final m = await _pickTime(old);
    if (m == null) return;
    setState(() {
      _times.remove(old);
      _times.add(m);
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    String? problem;
    if (name.isEmpty) problem = 'اكتبي اسم الدوا';
    if (_times.isEmpty) problem = 'ضيفي ميعاد واحد على الأقل';
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final med = Medication(
      id: widget.med?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      dose: _dose.text.trim(),
      times: _times.toList()..sort(),
      weekdays: _weekOrder.where(_days.contains).toList(),
    );
    final meds = await Storage.meds();
    final i = meds.indexWhere((m) => m.id == med.id);
    if (i >= 0) {
      meds[i] = med;
    } else {
      meds.add(med);
    }
    await Storage.saveMeds(meds);
    if (mounted) Navigator.pop(context);
    await Scheduler.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final times = _times.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text(widget.med == null ? 'دوا جديد' : 'تعديل الدوا')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(labelText: 'اسم الدوا'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dose,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(labelText: 'الجرعة (مثلاً: قرص بعد الأكل)'),
          ),
          const SizedBox(height: 24),
          Text('المواعيد', style: theme.textTheme.titleLarge),
          for (final t in times)
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.alarm, size: 32),
                title: Text(formatMinutes(t)),
                onTap: () => _changeTime(t),
                trailing: IconButton(
                  iconSize: 30,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _times.remove(t)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addTime,
            icon: const Icon(Icons.add_alarm),
            label: const Text('إضافة ميعاد'),
          ),
          const SizedBox(height: 24),
          Text('الأيام', style: theme.textTheme.titleLarge),
          Text('لو ما اخترتيش أيام، الدوا هيبقى كل يوم', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _weekOrder)
                FilterChip(
                  label: Text(weekdayNames[d]!, style: theme.textTheme.bodyLarge),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _days.add(d);
                    } else {
                      _days.remove(d);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
    );
  }
}
