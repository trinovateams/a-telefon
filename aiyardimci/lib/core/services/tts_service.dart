import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  Function()? onStart;
  Function()? onComplete;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.1);

    // Daha iyi Türkçe ses arayışı
    final voices = await _tts.getVoices;
    if (voices is List) {
      for (final voice in voices) {
        if (voice is Map) {
          final name = (voice['name'] ?? '').toString().toLowerCase();
          final locale = (voice['locale'] ?? '').toString().toLowerCase();
          if (locale.contains('tr') && name.contains('female')) {
            await _tts.setVoice({'name': voice['name'], 'locale': voice['locale']});
            break;
          }
        }
      }
    }

    _tts.setStartHandler(() {
      _isSpeaking = true;
      onStart?.call();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      onComplete?.call();
    });
  }

  /// Kısa onay sesi (wake word sonrası "hıhı")
  Future<void> speakAck() async {
    await _tts.setSpeechRate(0.5);
    await _tts.speak('hı hı');
    // Kısa bekle ama onComplete'i bekle
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  bool get isSpeaking => _isSpeaking;

  Future<void> dispose() async {
    await _tts.stop();
  }
}
