import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;

  Function()? onStart;
  Function()? onComplete;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    // Fallback flutter_tts ayarları
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.1);

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

    // Gemini audio player tamamlandığında
    _audioPlayer.onPlayerComplete.listen((_) {
      debugPrint('[TTS] Gemini audio tamamlandı');
      _isSpeaking = false;
      onComplete?.call();
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Önce Gemini doğal ses dene
    final success = await _speakWithGemini(text);
    if (!success) {
      // Başarısızsa fallback: cihaz TTS
      debugPrint('[TTS] Gemini başarısız, flutter_tts kullanılıyor');
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    }
  }

  Future<bool> _speakWithGemini(String text) async {
    final apiKey = AppConstants.geminiApiKey;
    if (apiKey.isEmpty) return false;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
      );

      final body = {
        'contents': [
          {
            'parts': [
              {'text': 'Şu metni aynen, doğal bir Türkçe tonlamayla oku. Hiçbir şey ekleme, sadece oku: $text'}
            ],
          }
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': 'Kore',
              },
            },
          },
        },
      };

      debugPrint('[TTS] Gemini audio isteği gönderiliyor...');
      _isSpeaking = true;
      onStart?.call();

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        debugPrint('[TTS] Gemini HTTP ${response.statusCode}');
        _isSpeaking = false;
        return false;
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        _isSpeaking = false;
        return false;
      }

      final parts = candidates[0]['content']['parts'] as List;
      // Audio part'ı bul
      Map<String, dynamic>? audioPart;
      for (final part in parts) {
        if (part['inlineData'] != null) {
          audioPart = part['inlineData'];
          break;
        }
      }

      if (audioPart == null) {
        debugPrint('[TTS] Audio data bulunamadı');
        _isSpeaking = false;
        return false;
      }

      final audioBase64 = audioPart['data'] as String;
      final mimeType = audioPart['mimeType'] as String? ?? 'audio/mp3';
      debugPrint('[TTS] Audio alındı, mime: $mimeType, boyut: ${audioBase64.length}');

      // Base64'ü decode et, temp dosyaya yaz, çal
      final audioBytes = base64Decode(audioBase64);
      final tempDir = await getTemporaryDirectory();

      // Dosya uzantısını mime type'a göre belirle
      String ext = 'wav';
      if (mimeType.contains('mp3') || mimeType.contains('mpeg')) ext = 'mp3';
      if (mimeType.contains('opus')) ext = 'opus';
      if (mimeType.contains('pcm') || mimeType.contains('L16')) ext = 'pcm';

      final file = File('${tempDir.path}/gemini_tts.$ext');
      await file.writeAsBytes(audioBytes);

      await _audioPlayer.play(DeviceFileSource(file.path));
      debugPrint('[TTS] Gemini audio çalınıyor');
      return true;
    } catch (e) {
      debugPrint('[TTS] Gemini TTS hatası: $e');
      _isSpeaking = false;
      return false;
    }
  }

  Future<void> speakAck() async {
    await _tts.setSpeechRate(0.5);
    await _tts.speak('hı hı');
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    await _tts.stop();
    _isSpeaking = false;
  }

  bool get isSpeaking => _isSpeaking;

  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _tts.stop();
  }
}
