import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_config.dart';
import '../models/day_record.dart';
import 'storage.dart';

/// Firebase link between the mother's and the son's phones.
/// Data: families/{code} (lastSeen) and families/{code}/days/{yyyy-MM-dd}.
/// Without Firebase settings every method is a no-op.
class Sync {
  /// Initializes Firebase and signs in anonymously. Returns false when not
  /// configured or (on very first use) offline; callers simply skip syncing.
  static Future<bool> ensure() async {
    if (!FirebaseConfig.isConfigured) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: FirebaseConfig.apiKey,
            appId: FirebaseConfig.appId,
            messagingSenderId: FirebaseConfig.messagingSenderId,
            projectId: FirebaseConfig.projectId,
          ),
        );
      }
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();
      return true;
    } catch (_) {
      return false;
    }
  }

  static DocumentReference<Map<String, dynamic>> _family(String code) =>
      FirebaseFirestore.instance.collection('families').doc(code);

  // ---- mother phone ----
  // Writes are not awaited: Firestore queues them offline and sends later.

  static Future<void> pushDay(DayRecord record) async {
    final code = await Storage.pairCode();
    if (code == null || !await ensure()) return;
    _family(code).collection('days').doc(record.date).set(record.toJson()).ignore();
  }

  static Future<void> heartbeat() async {
    final code = await Storage.pairCode();
    if (code == null || !await ensure()) return;
    _family(code)
        .set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true))
        .ignore();
  }

  // ---- son phone ----

  /// Throws when offline, so the link screen can say so.
  static Future<bool> familyExists(String code) async {
    final snap = await _family(code).get(const GetOptions(source: Source.server));
    return snap.exists;
  }

  static DateTime? _lastSeenOf(DocumentSnapshot<Map<String, dynamic>> snap) {
    final ts = snap.data()?['lastSeen'];
    return ts is Timestamp ? ts.toDate() : null;
  }

  static DayRecord? _recordOf(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    return data == null ? null : DayRecord.fromJson(data);
  }

  static Future<DateTime?> lastSeen(String code) async => _lastSeenOf(await _family(code).get());

  static Stream<DateTime?> watchLastSeen(String code) =>
      _family(code).snapshots().map(_lastSeenOf);

  static Future<DayRecord?> fetchDay(String code, String date) async =>
      _recordOf(await _family(code).collection('days').doc(date).get());

  static Stream<DayRecord?> watchDay(String code, String date) =>
      _family(code).collection('days').doc(date).snapshots().map(_recordOf);

  /// Newest first.
  static Future<List<DayRecord>> recentDays(String code, int count) async {
    final q = await _family(code)
        .collection('days')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(count)
        .get();
    return [for (final d in q.docs) DayRecord.fromJson(d.data())];
  }
}
