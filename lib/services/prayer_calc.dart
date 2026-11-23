import 'dart:math' as math;

import '../models/prayer_day.dart';

/// Offline prayer-time calculation (Egyptian General Authority of Survey:
/// Fajr 19.5°, Isha 17.5°, Shafi Asr). Used only when the downloaded
/// calendar doesn't cover a day. Times are in the device's local time zone,
/// including daylight saving.
class PrayerCalc {
  static const _fajrAngle = 19.5;
  static const _ishaAngle = 17.5;
  static const _riseSetAngle = 0.833;

  static PrayerDay compute(DateTime date, double lat, double lng) {
    final tz = DateTime(date.year, date.month, date.day, 12).timeZoneOffset.inMinutes / 60.0;
    final jDate = _julian(date.year, date.month, date.day) - lng / (15 * 24);

    // Initial guesses in hours, refined twice.
    var t = [5.0, 6.0, 12.0, 13.0, 18.0, 18.0];
    for (var i = 0; i < 2; i++) {
      final p = [for (final h in t) h / 24];
      t = [
        _sunAngleTime(jDate, lat, _fajrAngle, p[0], ccw: true),
        _sunAngleTime(jDate, lat, _riseSetAngle, p[1], ccw: true),
        _midDay(jDate, p[2]),
        _asrTime(jDate, lat, 1, p[3]),
        _sunAngleTime(jDate, lat, _riseSetAngle, p[4]),
        _sunAngleTime(jDate, lat, _ishaAngle, p[5]),
      ];
    }

    final adjust = tz - lng / 15;
    DateTime at(double hours) => DateTime(
        date.year, date.month, date.day, 0, ((hours + adjust) * 60).round());

    return PrayerDay(
      fajr: at(t[0]),
      sunrise: at(t[1]),
      dhuhr: at(t[2]),
      asr: at(t[3]),
      maghrib: at(t[4]),
      isha: at(t[5]),
    );
  }

  static double _julian(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  /// Returns (declination, equation of time) for julian day [jd].
  static (double, double) _sunPosition(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
    final e = 23.439 - 0.00000036 * d;
    final ra = _fixHour(_atan2(_cos(e) * _sin(l), _cos(l)) / 15);
    final eqt = q / 15 - ra;
    final decl = _asin(_sin(e) * _sin(l));
    return (decl, eqt);
  }

  static double _midDay(double jDate, double t) {
    final (_, eqt) = _sunPosition(jDate + t);
    return _fixHour(12 - eqt);
  }

  static double _sunAngleTime(double jDate, double lat, double angle, double t,
      {bool ccw = false}) {
    final (decl, _) = _sunPosition(jDate + t);
    final noon = _midDay(jDate, t);
    final x = (-_sin(angle) - _sin(decl) * _sin(lat)) / (_cos(decl) * _cos(lat));
    final diff = _acos(x.clamp(-1.0, 1.0)) / 15;
    return noon + (ccw ? -diff : diff);
  }

  static double _asrTime(double jDate, double lat, double factor, double t) {
    final (decl, _) = _sunPosition(jDate + t);
    final angle = -_acot(factor + _tan((lat - decl).abs()));
    return _sunAngleTime(jDate, lat, angle, t);
  }

  static const _rad = math.pi / 180;
  static double _sin(double d) => math.sin(d * _rad);
  static double _cos(double d) => math.cos(d * _rad);
  static double _tan(double d) => math.tan(d * _rad);
  static double _asin(double x) => math.asin(x) / _rad;
  static double _acos(double x) => math.acos(x) / _rad;
  static double _atan2(double y, double x) => math.atan2(y, x) / _rad;
  static double _acot(double x) => math.atan(1 / x) / _rad;
  static double _fixAngle(double a) => a - 360 * (a / 360).floor();
  static double _fixHour(double a) => a - 24 * (a / 24).floor();
}
