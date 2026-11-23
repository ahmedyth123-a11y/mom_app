/// Stable notification/alarm ids derived from what they are for, so the same
/// reminder always gets the same id across reschedules and isolates.
class Ids {
  static const medRepeats = 4; // first alert + 3 re-alerts
  static const maxPrayerAsks = 40;

  static int medAlarm(String date, String key, int n) => _hash('mA|$date|$key|$n');
  static int medNote(String date, String key, int n) => _hash('mN|$date|$key|$n');
  static int adhan(String date, String prayer) => _hash('pA|$date|$prayer');
  static int prayerNote(String date, String prayer, int n) => _hash('pN|$date|$prayer|$n');
  static int qiyamAlarm(String date) => _hash('qA|$date');
  static int qiyamNote(String date) => _hash('qN|$date');
  static int azkar(String date, bool morning) => _hash('az|$date|$morning');
  static int fasting(String date) => _hash('fa|$date');
  static final tasbeeh = _hash('tasbeeh');
  static int son(String key) => _hash('son|$key');

  /// FNV-1a, folded to a positive 31-bit int (valid Android id, never 0).
  static int _hash(String key) {
    var h = 0x811c9dc5;
    for (final c in key.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    final id = h & 0x7fffffff;
    return id == 0 ? 1 : id;
  }
}
