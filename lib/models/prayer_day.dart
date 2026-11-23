import '../utils.dart';

enum Prayer {
  fajr,
  dhuhr,
  asr,
  maghrib,
  isha;

  String get arabic => switch (this) {
        Prayer.fajr => 'الفجر',
        Prayer.dhuhr => 'الظهر',
        Prayer.asr => 'العصر',
        Prayer.maghrib => 'المغرب',
        Prayer.isha => 'العشاء',
      };
}

class HijriDate {
  const HijriDate(this.day, this.month, this.year, this.monthName);

  final int day;
  final int month;
  final int year;
  final String monthName;

  String get label => '${arNum(day)} $monthName ${arNum(year)} هـ';

  Map<String, dynamic> toJson() =>
      {'d': day, 'm': month, 'y': year, 'n': monthName};

  factory HijriDate.fromJson(Map<String, dynamic> j) => HijriDate(
      j['d'] as int, j['m'] as int, j['y'] as int, j['n'] as String);
}

/// Prayer times of one day, in device local time.
class PrayerDay {
  const PrayerDay({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.hijri,
  });

  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  /// Only known when the day came from the online calendar.
  final HijriDate? hijri;

  DateTime timeOf(Prayer p) => switch (p) {
        Prayer.fajr => fajr,
        Prayer.dhuhr => dhuhr,
        Prayer.asr => asr,
        Prayer.maghrib => maghrib,
        Prayer.isha => isha,
      };
}
