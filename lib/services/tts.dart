import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/app_settings.dart';
import 'sounds.dart';

const tasbeehPhrases = [
  'سبحان الله',
  'الحمد لله',
  'لا إله إلا الله',
  'الله أكبر',
  'سبحان الله وبحمده، سبحان الله العظيم',
];

/// Plays tasbeeh number [index]: the next recording in rotation, or the
/// phone's Arabic voice. Returns false if nothing could be played.
Future<bool> playTasbeeh(AppSettings s, int index) async {
  if (await Sounds.useTasbeehRecordings(s)) {
    final files = await Sounds.list(SoundCategory.tasbeeh);
    if (files.isNotEmpty && await _playToEnd(files[index % files.length])) return true;
  }
  return _speakArabic(tasbeehPhrases[index % tasbeehPhrases.length]);
}

Future<bool> _playToEnd(String path) async {
  final player = AudioPlayer();
  final done = Completer<void>();
  final sub = player.onPlayerComplete.listen((_) {
    if (!done.isCompleted) done.complete();
  });
  try {
    await player.play(Sounds.source(path));
    await done.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    return true;
  } catch (_) {
    return false;
  } finally {
    await sub.cancel();
    await player.dispose();
  }
}

/// Speaks [text] slowly in Arabic, preferring an Egyptian then Saudi voice.
/// Returns false if no Arabic voice is installed.
Future<bool> _speakArabic(String text) async {
  final tts = FlutterTts();
  try {
    String? language;
    for (final l in const ['ar-EG', 'ar-SA', 'ar']) {
      if (await tts.isLanguageAvailable(l) == true) {
        language = l;
        break;
      }
    }
    if (language == null) return false;
    await tts.setLanguage(language);
    await tts.setSpeechRate(0.4);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);
    return await tts.speak(text) == 1;
  } catch (_) {
    return false;
  }
}
