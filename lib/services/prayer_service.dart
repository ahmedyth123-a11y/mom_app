import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/prayer_day.dart';
import '../utils.dart';
import 'prayer_calc.dart';
import 'storage.dart';

/// Alexandria prayer times: downloaded monthly calendar (Aladhan, Egyptian
/// authority method) cached locally, with offline calculation as fallback.
class PrayerService {
  static const lat = 31.2001;
  static const lng = 29.9187;

  /// Downloads this month and next month. Silently keeps the cache when offline.
  static Future<void> refresh() async {
    final now = DateTime.now();
    final cache = await Storage.prayerCache();
    var changed = false;
    for (final month in [DateTime(now.year, now.month), DateTime(now.year, now.month + 1)]) {
      try {
        final uri = Uri.https(
          'api.aladhan.com',
          '/v1/calendarByCity/${month.year}/${month.month}',
          {'city': 'Alexandria', 'country': 'Egypt', 'method': '5'},
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) continue;
        final days = (jsonDecode(res.body) as Map<String, dynamic>)['data'] as List;
        for (final d in days) {
          final (key, value) = _parseDay(d as Map<String, dynamic>);
          cache[key] = value;
        }
        changed = true;
      } catch (_) {
        // Offline or unexpected response: keep using the cache.
      }
    }
    if (!changed) return;
    final oldest = dateKey(addDays(now, -3));
    cache.removeWhere((key, _) => key.compareTo(oldest) < 0);
    await Storage.savePrayerCache(cache);
  }

  static (String, Map<String, dynamic>) _parseDay(Map<String, dynamic> d) {
    final timings = d['timings'] as Map<String, dynamic>;
    final date = d['date'] as Map<String, dynamic>;
    final g = (date['gregorian'] as Map<String, dynamic>)['date'] as String; // DD-MM-YYYY
    final gp = g.split('-');
    final key = '${gp[2]}-${gp[1]}-${gp[0]}';
    final hijri = date['hijri'] as Map<String, dynamic>;
    final hMonth = hijri['month'] as Map<String, dynamic>;
    String hm(String name) => (timings[name] as String).substring(0, 5);
    return (
      key,
      {
        'fajr': hm('Fajr'),
        'sunrise': hm('Sunrise'),
        'dhuhr': hm('Dhuhr'),
        'asr': hm('Asr'),
        'maghrib': hm('Maghrib'),
        'isha': hm('Isha'),
        'hijri': HijriDate(
          int.parse('${hijri['day']}'),
          int.parse('${hMonth['number']}'),
          int.parse('${hijri['year']}'),
          hMonth['ar'] as String,
        ).toJson(),
      }
    );
  }

  static Future<PrayerTable> table() async => PrayerTable(await Storage.prayerCache());
}

/// Lookup over a loaded cache snapshot.
class PrayerTable {
  PrayerTable(this._cache);

  final Map<String, dynamic> _cache;

  PrayerDay day(DateTime date) {
    final j = _cache[dateKey(date)];
    if (j is Map<String, dynamic>) {
      DateTime at(String name) => atMinutes(date, parseHm(j[name] as String));
      return PrayerDay(
        fajr: at('fajr'),
        sunrise: at('sunrise'),
        dhuhr: at('dhuhr'),
        asr: at('asr'),
        maghrib: at('maghrib'),
        isha: at('isha'),
        hijri: HijriDate.fromJson(j['hijri'] as Map<String, dynamic>),
      );
    }
    return PrayerCalc.compute(date, PrayerService.lat, PrayerService.lng);
  }
}
