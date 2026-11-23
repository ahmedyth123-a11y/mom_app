import 'package:flutter_tts/flutter_tts.dart';

const tasbeehPhrases = [
  'سبحان الله',
  'الحمد لله',
  'لا إله إلا الله',
  'الله أكبر',
  'سبحان الله وبحمده، سبحان الله العظيم',
];

/// Speaks [text] in Arabic. Returns false if no Arabic voice is installed.
Future<bool> speakArabic(String text) async {
  final tts = FlutterTts();
  try {
    if (await tts.isLanguageAvailable('ar') != true) return false;
    await tts.setLanguage('ar');
    await tts.setSpeechRate(0.4);
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);
    return await tts.speak(text) == 1;
  } catch (_) {
    return false;
  }
}
