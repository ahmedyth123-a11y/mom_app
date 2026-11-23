import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import 'storage.dart';

/// Lists the sound files bundled in each folder (read from the asset
/// manifest, so dropping a file in the folder is enough to add it).
class Sounds {
  static Future<List<String>> list(SoundCategory c) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().where((a) => a.startsWith(c.folder)).toList()..sort();
  }

  static String label(String path) =>
      path.split('/').last.replaceFirst(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');

  /// Resets a choice whose file is no longer bundled (e.g. renamed).
  static Future<void> validate() async {
    final s = await Storage.settings();
    var changed = false;
    for (final c in SoundCategory.values) {
      final files = await list(c);
      if (files.isNotEmpty && !files.contains(s.soundPath(c))) {
        s.setSound(c, files.first);
        changed = true;
      }
    }
    if (changed) await Storage.saveSettings(s);
  }
}
