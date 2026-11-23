/// Date/time helpers and Arabic formatting.
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-dd` key used for storage and Firestore documents.
String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// [day] at [minutes] after midnight, in device local time.
DateTime atMinutes(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, 0, minutes);

/// Parses `HH:mm` (anything after is ignored) into minutes after midnight.
int parseHm(String s) {
  final parts = s.trim().substring(0, 5).split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Converts western digits in [value] to Arabic-Indic digits.
String arNum(Object value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\d'), (m) => _arabicDigits[int.parse(m[0]!)]);

/// Converts Arabic-Indic digits (as typed on an Arabic keyboard) to western.
String westernDigits(String s) => s.replaceAllMapped(
    RegExp('[٠-٩]'), (m) => '${_arabicDigits.indexOf(m[0]!)}');

/// e.g. ٤:٣٠ م
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return arNum('$h12:${_two(m)} ${h < 12 ? 'ص' : 'م'}');
}

String formatTime(DateTime t) => formatMinutes(t.hour * 60 + t.minute);

const weekdayNames = {
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الحد',
  DateTime.monday: 'الاتنين',
  DateTime.tuesday: 'التلات',
  DateTime.wednesday: 'الأربع',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
};

const _monthNames = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// e.g. الاتنين ٢٣ نوفمبر
String formatDate(DateTime d) =>
    '${weekdayNames[d.weekday]} ${arNum(d.day)} ${_monthNames[d.month - 1]}';
