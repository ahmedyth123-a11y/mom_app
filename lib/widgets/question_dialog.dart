import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/notifications.dart';
import '../services/responses.dart';

/// Asks the same question as the notification, inside the app
/// (after tapping a notification body or an item on the Today screen).
Future<void> askQuestion(BuildContext context, String payload) async {
  final p = jsonDecode(payload) as Map<String, dynamic>;
  final title = p['title'] as String;
  final (question, options) = switch (p['type']) {
    'med' => (
        'خدتي $title؟',
        const [(NoteActions.took, 'أخدته'), (NoteActions.snooze, 'أجّل ربع ساعة')]
      ),
    'prayer' => (
        'صلّيتي $title؟',
        const [(NoteActions.prayed, 'صلّيت'), (NoteActions.notYet, 'لسه')]
      ),
    'qiyam' => ('قمتي للقيام؟', const [(NoteActions.woke, 'قمت'), (NoteActions.slept, 'لأ')]),
    _ => ('', const <(String, String)>[]),
  };
  if (options.isEmpty) return;

  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(question, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (id, label)) in options.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: i == 0
                  ? FilledButton(onPressed: () => Navigator.pop(ctx, id), child: Text(label))
                  : OutlinedButton(onPressed: () => Navigator.pop(ctx, id), child: Text(label)),
            ),
        ],
      ),
    ),
  );
  if (action != null) await Responses.handle(action, payload);
}
