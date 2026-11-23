class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.times,
    this.weekdays = const [],
  });

  final String id;
  final String name;
  final String dose;

  /// Minutes after midnight, sorted.
  final List<int> times;

  /// `DateTime.monday`..`DateTime.sunday`; empty means every day.
  final List<int> weekdays;

  bool activeOn(DateTime day) => weekdays.isEmpty || weekdays.contains(day.weekday);

  String get label => dose.isEmpty ? name : '$name — $dose';

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'dose': dose, 'times': times, 'weekdays': weekdays};

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as String,
        name: j['name'] as String,
        dose: j['dose'] as String? ?? '',
        times: (j['times'] as List).cast<int>(),
        weekdays: (j['weekdays'] as List? ?? const []).cast<int>(),
      );
}
