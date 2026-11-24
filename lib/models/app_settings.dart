enum AppMode { mother, son }

/// Sound folders: bundled files under assets/sounds/<name>/ plus files she
/// added from the phone (see Sounds).
enum SoundCategory {
  adhan('default_adhan.wav', 'جرس هادي (بدّله بأذان من التليفون)'),
  alarm('default_rising.wav', 'لحن هادي متصاعد'),
  med('default_chime.wav', 'جرس لطيف'),
  tasbeeh(null, null),
  azkarMorning(null, null, dir: 'azkar_morning'),
  azkarEvening(null, null, dir: 'azkar_evening');

  const SoundCategory(this._generated, this.generatedLabel, {String? dir}) : _dir = dir;

  final String? _generated;

  /// Asset folder name when it differs from the enum name.
  final String? _dir;

  /// Friendly name of the generated fallback sound.
  final String? generatedLabel;

  String get folder => 'assets/sounds/${_dir ?? name}/';

  /// Generated copyright-free fallback (none for tasbeeh, which uses TTS, nor
  /// for azkar, which always ship a main_ recording).
  String? get generatedPath => _generated == null ? null : '$folder$_generated';
}

/// Mother-phone preferences. Mutable: the settings screen edits then saves it.
class AppSettings {
  /// Chosen sound per category: an asset path or an absolute file path.
  /// Missing = the bundled default (see Sounds.resolve).
  final Map<SoundCategory, String> sounds = {};

  double fontScale = 1.0;

  bool meds = true;
  bool prayers = true;
  bool azkar = true;

  /// Azkar times play the chosen recording; false: a text notification.
  bool azkarAudio = true;
  bool fasting = true;

  bool qiyam = false;

  /// true: start of the last third of the night; false: [qiyamFixed].
  bool qiyamAuto = true;
  int qiyamFixed = 3 * 60 + 30;

  bool tasbeeh = false;
  int tasbeehInterval = 60;
  int tasbeehStart = 8 * 60;
  int tasbeehEnd = 22 * 60;

  /// true: play recordings; false: TTS; null: recordings only if some are
  /// bundled in the APK.
  bool? tasbeehRecordings;

  AppSettings();

  bool useTasbeehRecordings({required bool bundled}) => tasbeehRecordings ?? bundled;

  Map<String, dynamic> toJson() => {
        for (final e in sounds.entries) '${e.key.name}Sound': e.value,
        'fontScale': fontScale,
        'meds': meds,
        'prayers': prayers,
        'azkar': azkar,
        'azkarAudio': azkarAudio,
        'fasting': fasting,
        'qiyam': qiyam,
        'qiyamAuto': qiyamAuto,
        'qiyamFixed': qiyamFixed,
        'tasbeeh': tasbeeh,
        'tasbeehInterval': tasbeehInterval,
        'tasbeehStart': tasbeehStart,
        'tasbeehEnd': tasbeehEnd,
        'tasbeehRecordings': tasbeehRecordings,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final s = AppSettings();
    // Older versions stored the generated default as an explicit choice; drop
    // it so a bundled main_* default applies (that format lacks this key).
    final legacy = !j.containsKey('tasbeehRecordings');
    for (final c in SoundCategory.values) {
      final path = j['${c.name}Sound'] as String?;
      if (path != null && !(legacy && path == c.generatedPath)) s.sounds[c] = path;
    }
    s.fontScale = (j['fontScale'] as num?)?.toDouble() ?? s.fontScale;
    s.meds = j['meds'] as bool? ?? s.meds;
    s.prayers = j['prayers'] as bool? ?? s.prayers;
    s.azkar = j['azkar'] as bool? ?? s.azkar;
    s.azkarAudio = j['azkarAudio'] as bool? ?? s.azkarAudio;
    s.fasting = j['fasting'] as bool? ?? s.fasting;
    s.qiyam = j['qiyam'] as bool? ?? s.qiyam;
    s.qiyamAuto = j['qiyamAuto'] as bool? ?? s.qiyamAuto;
    s.qiyamFixed = j['qiyamFixed'] as int? ?? s.qiyamFixed;
    s.tasbeeh = j['tasbeeh'] as bool? ?? s.tasbeeh;
    s.tasbeehInterval = j['tasbeehInterval'] as int? ?? s.tasbeehInterval;
    s.tasbeehStart = j['tasbeehStart'] as int? ?? s.tasbeehStart;
    s.tasbeehEnd = j['tasbeehEnd'] as int? ?? s.tasbeehEnd;
    s.tasbeehRecordings = j['tasbeehRecordings'] as bool?;
    return s;
  }
}
