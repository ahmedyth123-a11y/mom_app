import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/day_record.dart';
import '../models/medication.dart';
import '../utils.dart';

/// Local persistence. Uses [SharedPreferencesAsync] (no in-memory cache) so
/// the app and its background isolates always see each other's writes.
class Storage {
  static final _prefs = SharedPreferencesAsync();

  /// Bumped on every local data change so open screens reload.
  static final changes = ValueNotifier<int>(0);

  static void _changed() => changes.value++;

  static Future<Map<String, dynamic>?> _json(String key) async {
    final raw = await _prefs.getString(key);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> _setJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  // ---- mode & codes ----

  static Future<AppMode?> mode() async {
    final raw = await _prefs.getString('mode');
    return raw == null ? null : AppMode.values.byName(raw);
  }

  static Future<void> setMode(AppMode mode) => _prefs.setString('mode', mode.name);

  /// Mother phone: the family code shown to the son.
  static Future<String?> pairCode() => _prefs.getString('pairCode');

  static Future<void> setPairCode(String code) => _prefs.setString('pairCode', code);

  /// Son phone: the family code he linked to.
  static Future<String?> linkedCode() => _prefs.getString('linkedCode');

  static Future<void> setLinkedCode(String? code) =>
      code == null ? _prefs.remove('linkedCode') : _prefs.setString('linkedCode', code);

  // ---- settings & medications ----

  static Future<AppSettings> settings() async {
    final j = await _json('settings');
    return j == null ? AppSettings() : AppSettings.fromJson(j);
  }

  static Future<void> saveSettings(AppSettings s) async {
    await _setJson('settings', s.toJson());
    _changed();
  }

  static Future<List<Medication>> meds() async {
    final raw = await _prefs.getString('meds');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Medication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveMeds(List<Medication> meds) async {
    await _setJson('meds', meds.map((m) => m.toJson()).toList());
    _changed();
  }

  // ---- day records ----

  static Future<DayRecord?> day(String date) async {
    final j = await _json('day:$date');
    return j == null ? null : DayRecord.fromJson(j);
  }

  static Future<void> saveDay(DayRecord record) async {
    await _setJson('day:${record.date}', record.toJson());
    _changed();
  }

  /// Deletes day records older than [keepFrom].
  static Future<void> pruneDays(DateTime keepFrom) async {
    final oldest = dateKey(keepFrom);
    for (final key in await _prefs.getKeys()) {
      if (key.startsWith('day:') && key.substring(4).compareTo(oldest) < 0) {
        await _prefs.remove(key);
      }
    }
  }

  // ---- prayer times cache: dateKey -> day json ----

  static Future<Map<String, dynamic>> prayerCache() async =>
      await _json('prayerCache') ?? {};

  static Future<void> savePrayerCache(Map<String, dynamic> cache) =>
      _setJson('prayerCache', cache);

  // ---- alarm id -> notification payload (for the ringing screen) ----

  static Future<Map<int, Map<String, dynamic>>> alarmIndex() async {
    final j = await _json('alarmIndex') ?? {};
    return {
      for (final e in j.entries) int.parse(e.key): e.value as Map<String, dynamic>,
    };
  }

  static Future<void> saveAlarmIndex(Map<int, Map<String, dynamic>> index) =>
      _setJson('alarmIndex', {for (final e in index.entries) '${e.key}': e.value});

  // ---- tasbeeh rotation ----

  static Future<int> nextTasbeehIndex() async {
    final i = await _prefs.getInt('tasbeehIndex') ?? 0;
    await _prefs.setInt('tasbeehIndex', i + 1);
    return i;
  }

  // ---- son phone: alerts already shown ----

  static Future<Set<String>> sonNotified() async =>
      (await _prefs.getStringList('sonNotified') ?? const <String>[]).toSet();

  static Future<void> saveSonNotified(Set<String> keys) =>
      _prefs.setStringList('sonNotified', keys.toList());
}
