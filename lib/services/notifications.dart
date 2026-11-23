import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'bootstrap.dart';
import 'responses.dart';

enum NoteKind { med, prayer, qiyam, reminder, family }

/// Action ids on question notifications.
class NoteActions {
  static const took = 'took';
  static const snooze = 'snooze';
  static const prayed = 'prayed';
  static const notYet = 'notyet';
  static const woke = 'woke';
  static const slept = 'slept';
}

/// Runs in a background isolate when an action button is pressed while the
/// app isn't running.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  await ensureServices();
  await Notifs.handleResponse(response);
}

class Notifs {
  static final plugin = FlutterLocalNotificationsPlugin();

  /// Set by the UI: called when she taps a notification body (not a button).
  static void Function(String payload)? onTap;

  static Future<void> init() async {
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
  }

  static Future<void> handleResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final action = response.actionId;
    if (action != null && action.isNotEmpty) {
      await Responses.handle(action, payload);
    } else {
      onTap?.call(payload);
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<bool> enabled() async => await _android?.areNotificationsEnabled() ?? false;

  static Future<void> requestPermission() async {
    await _android?.requestNotificationsPermission();
  }

  /// Payload of the notification that launched the app, if any.
  static Future<String?> launchPayload() async {
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  static NotificationDetails _details(NoteKind kind, String body) {
    final actions = switch (kind) {
      NoteKind.med => const [
          AndroidNotificationAction(NoteActions.took, 'أخدته'),
          AndroidNotificationAction(NoteActions.snooze, 'أجّل ربع ساعة'),
        ],
      NoteKind.prayer => const [
          AndroidNotificationAction(NoteActions.prayed, 'صلّيت'),
          AndroidNotificationAction(NoteActions.notYet, 'لسه'),
        ],
      NoteKind.qiyam => const [
          AndroidNotificationAction(NoteActions.woke, 'قمت'),
          AndroidNotificationAction(NoteActions.slept, 'لأ'),
        ],
      NoteKind.reminder || NoteKind.family => const <AndroidNotificationAction>[],
    };
    final (channelId, channelName) = switch (kind) {
      NoteKind.med || NoteKind.prayer || NoteKind.qiyam => ('questions', 'أسئلة المتابعة'),
      NoteKind.reminder => ('reminders', 'تذكيرات'),
      NoteKind.family => ('family', 'متابعة الوالدة'),
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(body),
        actions: actions,
      ),
    );
  }

  static Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required NoteKind kind,
    String? payload,
  }) async {
    Future<void> zoned(AndroidScheduleMode mode) => plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(at, tz.UTC),
          _details(kind, body),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
    try {
      await zoned(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Exact alarms not permitted on this phone: still deliver, a bit late.
      await zoned(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    required NoteKind kind,
  }) =>
      plugin.show(id, title, body, _details(kind, body));

  static Future<void> cancel(int id) => plugin.cancel(id);

  static Future<Set<int>> pendingIds() async =>
      {for (final p in await plugin.pendingNotificationRequests()) p.id};
}
