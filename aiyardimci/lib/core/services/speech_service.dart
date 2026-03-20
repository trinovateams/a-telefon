import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum ListenMode { continuous, off }

enum _VadState { waiting, speaking, finalizing }

/// VAD (Voice Activity Detection) tabanlı ses yakalama.
/// SpeechRecognizer kullanmaz → beep yok, restart yok.
/// Mikrofon sürekli açık kalır; sadece konuşma bitince ses Gemini'ye gider.
class SpeechService {
  final AudioRecorder _recorder = AudioRecorder();

  ListenMode _mode = ListenMode.off;
  _VadState _vadState = _VadState.waiting;

  StreamSubscription<Amplitude>? _amplitudeSub;
  DateTime? _speechStart;
  DateTime? _silenceStart;
  int _sessionIndex = 0;
  bool _finalizing = false; // çift tetik önlemi

  String _apiKey = '';

  // VAD eşikleri (dBFS). -160=sessizlik, 0=maksimum ses.
  static const double _speechThreshold = -35.0; // konuşma başlangıcı
  static const double _silenceThreshold = -45.0; // sessizlik
  static const Duration _minSpeechDuration = Duration(milliseconds: 600);
  static const Duration _silenceToFinalize = Duration(milliseconds: 1500);

  Function(String)? onSpeechResult;
  Function()? onSilence;

  void updateApiKey(String key) {
    _apiKey = key;
  }

  // ─── Başlatma ──────────────────────────────────────────────────────────────

  Future<bool> init() async {
    // record paketi izni otomatik ister; sadece mevcut durumu döndür
    final has = await _recorder.hasPermission();
    debugPrint('[VAD] mic permission: $has');
    return has;
  }

  // ─── Sürekli Dinleme ───────────────────────────────────────────────────────

  Future<void> startContinuous() async {
    if (_mode == ListenMode.continuous) return;
    _mode = ListenMode.continuous;
    _vadState = _VadState.waiting;
    _finalizing = false;
    await _startSession();
  }

  Future<void> _startSession() async {
    if (_mode != ListenMode.continuous) return;

    // Önceki oturum hâlâ kayıt yapıyorsa durdur
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    try {
      final dir = await getTemporaryDirectory();
      _sessionIndex++;
      final path = '${dir.path}/vad_$_sessionIndex.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );

      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen(_onAmplitude);

      debugPrint('[VAD] session started (#$_sessionIndex)');
    } catch (e) {
      debugPrint('[VAD] start error: $e');
      if (_mode == ListenMode.continuous) {
        Future.delayed(const Duration(seconds: 2), _startSession);
      }
    }
  }

  // ─── VAD İşleme ────────────────────────────────────────────────────────────

  void _onAmplitude(Amplitude amp) {
    if (_mode != ListenMode.continuous || _finalizing) return;

    final db = amp.current;

    switch (_vadState) {
      case _VadState.waiting:
        if (db > _speechThreshold) {
          _vadState = _VadState.speaking;
          _speechStart = DateTime.now();
          debugPrint('[VAD] konuşma başladı ($db dBFS)');
        }
        break;

      case _VadState.speaking:
        if (db < _silenceThreshold) {
          _vadState = _VadState.finalizing;
          _silenceStart = DateTime.now();
        }
        break;

      case _VadState.finalizing:
        if (db > _speechThreshold) {
          // Kullanıcı tekrar konuşmaya devam etti
          _vadState = _VadState.speaking;
          _silenceStart = null;
        } else {
          final silenceDur = DateTime.now().difference(_silenceStart!);
          if (silenceDur >= _silenceToFinalize) {
            _finalize();
          }
        }
        break;
    }
  }

  Future<void> _finalize() async {
    if (_finalizing || _mode != ListenMode.continuous) return;
    _finalizing = true;
    _vadState = _VadState.waiting;
    _amplitudeSub?.cancel();

    final speechDur = _speechStart != null
        ? DateTime.now().difference(_speechStart!)
        : Duration.zero;
    _speechStart = null;
    _silenceStart = null;

    // Kaydı durdur
    final path = await _recorder.stop().catchError((_) => null);
    debugPrint('[VAD] oturum bitti, konuşma: ${speechDur.inMilliseconds}ms');

    if (speechDur < _minSpeechDuration || path == null) {
      debugPrint('[VAD] çok kısa, yoksay');
      _finalizing = false;
      await _startSession();
      return;
    }

    // AI cevap verene kadar modu kapat (face_controller restart eder)
    _mode = ListenMode.off;
    _finalizing = false;

    // Transkripsyon
    final text = await _transcribeAudio(path);
    _deleteFile(path);

    if (text.isNotEmpty) {
      debugPrint('[VAD] duyuldu: "$text"');
      onSpeechResult?.call(text);
    } else {
      // Boş → dinlemeye devam
      _mode = ListenMode.continuous;
      await _startSession();
    }
  }

  // ─── Gemini Ses → Metin ────────────────────────────────────────────────────

  Future<String> _transcribeAudio(String path) async {
    if (_apiKey.isEmpty) {
      debugPrint('[VAD] API key yok, transkripsyon yapılamıyor');
      return '';
    }
    try {
      final audioBytes = await File(path).readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey',
      );

      final body = {
        'contents': [
          {
            'parts': [
              {
                'inlineData': {
                  'mimeType': 'audio/wav',
                  'data': base64Audio,
                },
              },
              {
                'text':
                    'Bu ses kaydındaki konuşmayı kelimesi kelimesine Türkçe yaz. '
                    'Sadece duyduğunu yaz, hiçbir şey ekleme. '
                    'Eğer hiçbir konuşma yoksa sadece tek bir boşluk karakter döndür.',
              },
            ],
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 300,
          'temperature': 0.0,
        },
      };

      debugPrint('[VAD] transkripsyon isteği gönderiliyor...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint('[VAD] HTTP ${response.statusCode}');
        return '';
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';

      final parts = candidates[0]['content']['parts'] as List;
      return parts.map((p) => p['text'] ?? '').join('').trim();
    } catch (e) {
      debugPrint('[VAD] transkripsyon hatası: $e');
      return '';
    }
  }

  // ─── Durdurma ──────────────────────────────────────────────────────────────

  Future<void> stop() async {
    _mode = ListenMode.off;
    _vadState = _VadState.waiting;
    _finalizing = false;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _speechStart = null;
    _silenceStart = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
  }

  void _deleteFile(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  ListenMode get mode => _mode;
  bool get isListening => _mode == ListenMode.continuous;
}
