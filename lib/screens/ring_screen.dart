import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import '../services/notifications.dart';
import '../services/responses.dart';
import '../widgets/question_dialog.dart';

/// Full-screen view while an alarm rings (also shown over the lock screen).
class RingScreen extends StatelessWidget {
  const RingScreen({super.key, required this.alarmId, this.info});

  final int alarmId;

  /// Notification payload of the alarm (type/date/key/title), if known.
  final Map<String, dynamic>? info;

  Future<void> _answer(BuildContext context, String action) async {
    await Alarm.stop(alarmId);
    final info = this.info;
    if (info != null) await Responses.handle(action, jsonEncode(info));
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _stop(BuildContext context, {bool askQiyam = false}) async {
    await Alarm.stop(alarmId);
    final info = this.info;
    if (askQiyam && info != null && context.mounted) {
      await askQuestion(context, jsonEncode(info));
    }
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = info?['type'] as String?;
    final title = info?['title'] as String? ?? '';
    final (icon, heading) = switch (type) {
      'med' => (Icons.medication, 'معاد الدوا'),
      'prayer' => (Icons.mosque, 'أذان $title'),
      'qiyam' => (Icons.nightlight_round, 'قيام الليل'),
      _ => (Icons.alarm, 'منبّه'),
    };
    final onPrimary = theme.colorScheme.onPrimary;
    final light = FilledButton.styleFrom(
        backgroundColor: onPrimary, foregroundColor: theme.colorScheme.primary);
    final outline = OutlinedButton.styleFrom(
        foregroundColor: onPrimary, side: BorderSide(color: onPrimary, width: 2));

    final buttons = switch (type) {
      'med' => <Widget>[
          FilledButton(
              style: light,
              onPressed: () => _answer(context, NoteActions.took),
              child: const Text('أخدته')),
          OutlinedButton(
              style: outline,
              onPressed: () => _answer(context, NoteActions.snooze),
              child: const Text('أجّل ربع ساعة')),
        ],
      'qiyam' => <Widget>[
          FilledButton(
              style: light,
              onPressed: () => _stop(context, askQiyam: true),
              child: const Text('إيقاف المنبّه')),
        ],
      _ => <Widget>[
          FilledButton(
              style: light, onPressed: () => _stop(context), child: const Text('إيقاف')),
        ],
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(icon, size: 120, color: onPrimary),
                const SizedBox(height: 24),
                Text(heading,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(color: onPrimary)),
                if (type == 'med')
                  Text(title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(color: onPrimary)),
                const Spacer(),
                for (final b in buttons)
                  Padding(padding: const EdgeInsets.only(top: 16), child: b),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
