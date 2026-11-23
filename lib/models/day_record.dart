enum ItemStatus { pending, done, late, missed }

/// One tracked thing on a day: a medication dose, a prayer, or qiyam.
class TrackedItem {
  TrackedItem({
    required this.key,
    required this.title,
    required this.time,
    required this.deadline,
    this.alertAt,
    this.status = ItemStatus.pending,
    this.at,
  });

  final String key;
  final String title;

  /// When it is due.
  final DateTime time;

  /// After this, an unanswered item counts as missed.
  DateTime deadline;

  /// Medication only: start of the current (snoozed) alert chain.
  DateTime? alertAt;

  ItemStatus status;

  /// When she answered.
  DateTime? at;

  bool get answered => status != ItemStatus.pending;

  /// Status as of [now]; "missed" is derived, so both phones agree on it
  /// without any background job having to write it.
  ItemStatus effective(DateTime now) =>
      status == ItemStatus.pending && now.isAfter(deadline) ? ItemStatus.missed : status;

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'time': _iso(time),
        'deadline': _iso(deadline),
        if (alertAt != null) 'alertAt': _iso(alertAt!),
        'status': status.name,
        if (at != null) 'at': _iso(at!),
      };

  factory TrackedItem.fromJson(Map<String, dynamic> j) => TrackedItem(
        key: j['key'] as String,
        title: j['title'] as String,
        time: _parse(j['time']),
        deadline: _parse(j['deadline']),
        alertAt: j['alertAt'] == null ? null : _parse(j['alertAt']),
        status: ItemStatus.values.byName(j['status'] as String),
        at: j['at'] == null ? null : _parse(j['at']),
      );
}

/// Everything tracked on one calendar day. Same JSON locally and in Firestore.
class DayRecord {
  DayRecord({
    required this.date,
    Map<String, TrackedItem>? meds,
    Map<String, TrackedItem>? prayers,
    this.qiyam,
  })  : meds = meds ?? {},
        prayers = prayers ?? {};

  /// `yyyy-MM-dd`
  final String date;

  /// Keyed by `medId@minutes`.
  final Map<String, TrackedItem> meds;

  /// Keyed by `Prayer.name`.
  final Map<String, TrackedItem> prayers;

  TrackedItem? qiyam;

  bool get isEmpty => meds.isEmpty && prayers.isEmpty && qiyam == null;

  List<TrackedItem> get medsByTime =>
      meds.values.toList()..sort((a, b) => a.time.compareTo(b.time));

  List<TrackedItem> get prayersByTime =>
      prayers.values.toList()..sort((a, b) => a.time.compareTo(b.time));

  Map<String, dynamic> toJson() => {
        'date': date,
        'meds': {for (final e in meds.entries) e.key: e.value.toJson()},
        'prayers': {for (final e in prayers.entries) e.key: e.value.toJson()},
        'qiyam': qiyam?.toJson(),
      };

  factory DayRecord.fromJson(Map<String, dynamic> j) => DayRecord(
        date: j['date'] as String,
        meds: _items(j['meds']),
        prayers: _items(j['prayers']),
        qiyam: j['qiyam'] == null
            ? null
            : TrackedItem.fromJson(Map<String, dynamic>.from(j['qiyam'] as Map)),
      );

  static Map<String, TrackedItem> _items(Object? raw) => {
        for (final e in (raw as Map? ?? const {}).entries)
          e.key as String: TrackedItem.fromJson(Map<String, dynamic>.from(e.value as Map)),
      };
}

String _iso(DateTime t) => t.toUtc().toIso8601String();

DateTime _parse(Object? s) => DateTime.parse(s as String).toLocal();
