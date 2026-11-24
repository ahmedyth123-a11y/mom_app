import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import 'system_settings.dart';

/// Sounds of each category: files bundled in assets/sounds/<category>/ (read
/// from the asset manifest, so dropping a file in the folder is enough) plus
/// files she added from the phone, copied into the app's documents folder.
class Sounds {
  static const _audioExtensions = {
    'mp3', 'wav', 'ogg', 'oga', 'opus', 'm4a', 'aac', 'flac', 'amr', '3gp',
  };

  static List<String>? _assets;

  static bool _isAudio(String path) =>
      _audioExtensions.contains(path.split('.').last.toLowerCase());

  static String _fileName(String path) => path.split('/').last;

  static bool isUserFile(String path) => path.startsWith('/');

  static Future<List<String>> bundled(SoundCategory c) async {
    final assets =
        _assets ??= (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
    return assets.where((a) => a.startsWith(c.folder) && _isAudio(a)).toList()..sort();
  }

  static Future<Directory> _userDir(SoundCategory c) async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}/sounds/${c.name}');

  static Future<List<String>> userFiles(SoundCategory c) async {
    final dir = await _userDir(c);
    if (!await dir.exists()) return [];
    final files = await dir.list().where((e) => e is File).map((e) => e.path).toList();
    return files..sort();
  }

  /// Bundled sounds first, then hers.
  static Future<List<String>> list(SoundCategory c) async =>
      [...await bundled(c), ...await userFiles(c)];

  /// A bundled `main_*` file if there is one, else the generated fallback.
  static Future<String?> defaultFor(SoundCategory c) async {
    final main = (await bundled(c)).where((a) => _fileName(a).startsWith('main_'));
    return main.isNotEmpty ? main.first : c.generatedPath;
  }

  /// The sound to play: her [chosen] one while it still exists, else the default.
  static Future<String> resolve(SoundCategory c, String? chosen) async {
    if (chosen != null &&
        (isUserFile(chosen)
            ? await File(chosen).exists()
            : (await bundled(c)).contains(chosen))) {
      return chosen;
    }
    return (await defaultFor(c))!;
  }

  static Future<bool> useTasbeehRecordings(AppSettings s) async =>
      s.useTasbeehRecordings(bundled: (await bundled(SoundCategory.tasbeeh)).isNotEmpty);

  /// Friendly names of bundled files whose file name isn't readable Arabic.
  static const _bundledLabels = {
    'assets/sounds/azkar_morning/main_azkar_morning.mp3': 'أذكار الصباح',
    'assets/sounds/azkar_evening/main_azkar_evening.mp3': 'أذكار المساء',
  };

  static String label(String path) {
    for (final c in SoundCategory.values) {
      if (c.generatedPath == path) return c.generatedLabel!;
    }
    final named = _bundledLabels[path];
    if (named != null) return named;
    return _fileName(path)
        .replaceFirst(RegExp(r'^main_'), '')
        .replaceFirst(RegExp(r'\.[^.]+$'), '')
        .replaceAll('_', ' ');
  }

  static Source source(String path) => isUserFile(path)
      ? DeviceFileSource(path)
      // AssetSource paths are relative to the assets/ folder.
      : AssetSource(path.replaceFirst('assets/', ''));

  /// Opens the phone's file picker and copies the chosen audio file into the
  /// app. Returns its path, or null if she cancelled.
  static Future<String?> addFromPhone(SoundCategory c) async =>
      SystemSettings.pickAudio((await _userDir(c)).path);

  static Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
