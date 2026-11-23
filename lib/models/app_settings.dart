enum AppMode { mother, son }

/// Sound folders under assets/sounds/. Every file in a folder is selectable.
enum SoundCategory {
  adhan('default_adhan.wav'),
  alarm('default_rising.wav'),
  med('default_chime.wav');

  const SoundCategory(this._defaultFile);

  final String _defaultFile;

  String get folder => 'assets/sounds/$name/';

  /// Bundled copyright-free sound, used until she picks another.
  String get defaultPath => '$folder$_defaultFile';
}

/// Mother-phone preferences. Mutable: the settings screen edits then saves it.
class AppSettings {
  /// Asset paths of the chosen sounds (null = the bundled default).
  String? adhanSound;
  String? alarmSound;
  String? medSound;

  double fontScale = 1.0;

  bool meds = true;
  bool prayers = true;
  bool azkar = true;
  bool fasting = true;

  bool qiyam = false;

  /// true: start of the last third of the night; false: [qiyamFixed].
  bool qiyamAuto = true;
  int qiyamFixed = 3 * 60 + 30;

  bool tasbeeh = false;
  int tasbeehInterval = 60;
  int tasbeehStart = 8 * 60;
  int tasbeehEnd = 22 * 60;

  AppSettings();

  String soundPath(SoundCategory c) =>
      switch (c) {
        SoundCategory.adhan => adhanSound,
        SoundCategory.alarm => alarmSound,
        SoundCategory.med => medSound,
      } ??
      c.defaultPath;

  void setSound(SoundCategory c, String path) {
    switch (c) {
      case SoundCategory.adhan:
        adhanSound = path;
      case SoundCategory.alarm:
        alarmSound = path;
      case SoundCategory.med:
        medSound = path;
    }
  }

  Map<String, dynamic> toJson() => {
        'adhanSound': adhanSound,
        'alarmSound': alarmSound,
        'medSound': medSound,
        'fontScale': fontScale,
        'meds': meds,
        'prayers': prayers,
        'azkar': azkar,
        'fasting': fasting,
        'qiyam': qiyam,
        'qiyamAuto': qiyamAuto,
        'qiyamFixed': qiyamFixed,
        'tasbeeh': tasbeeh,
        'tasbeehInterval': tasbeehInterval,
        'tasbeehStart': tasbeehStart,
        'tasbeehEnd': tasbeehEnd,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final s = AppSettings();
    s.adhanSound = j['adhanSound'] as String?;
    s.alarmSound = j['alarmSound'] as String?;
    s.medSound = j['medSound'] as String?;
    s.fontScale = (j['fontScale'] as num?)?.toDouble() ?? s.fontScale;
    s.meds = j['meds'] as bool? ?? s.meds;
    s.prayers = j['prayers'] as bool? ?? s.prayers;
    s.azkar = j['azkar'] as bool? ?? s.azkar;
    s.fasting = j['fasting'] as bool? ?? s.fasting;
    s.qiyam = j['qiyam'] as bool? ?? s.qiyam;
    s.qiyamAuto = j['qiyamAuto'] as bool? ?? s.qiyamAuto;
    s.qiyamFixed = j['qiyamFixed'] as int? ?? s.qiyamFixed;
    s.tasbeeh = j['tasbeeh'] as bool? ?? s.tasbeeh;
    s.tasbeehInterval = j['tasbeehInterval'] as int? ?? s.tasbeehInterval;
    s.tasbeehStart = j['tasbeehStart'] as int? ?? s.tasbeehStart;
    s.tasbeehEnd = j['tasbeehEnd'] as int? ?? s.tasbeehEnd;
    return s;
  }
}
