import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import '../constants/app_constants.dart';
import '../enums/connection_state.dart';

/// Gemini Live API — ses giriş/çıkışı.
///
///  MİK (record, PCM 16kHz) → base64 → WS → Gemini
///  Gemini → WS → PCM 24kHz → flutter_sound player → hoparlör
class LiveAudioService {
  // ─── Sabitler ──────────────────────────────────────────────────────────────

  static const _wsBase = 'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
  static const _modelsUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ─── Ses araçları ──────────────────────────────────────────────────────────

  final AudioRecorder _mic = AudioRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  // ─── Ayarlar ───────────────────────────────────────────────────────────────

  String _apiKey = AppConstants.geminiApiKey;
  String _systemPrompt = AppConstants.defaultSystemPrompt;
  String _voiceName = 'Aoede';
  String _wakeName = 'Cozmo';
  String _memoryPrompt = '';
  String _thoughtInjection = '';
  bool _cozmoMode = true;

  // ─── Durum ─────────────────────────────────────────────────────────────────

  WebSocket? _ws;
  StreamSubscription? _wsSub;
  StreamSubscription<Uint8List>? _micSub;

  bool _active = false;
  bool _ready = false;
  bool _speaking = false; // model konuşuyor mu — mikrofonu susturmak için
  bool _reconnecting = false; // reconnect yarış durumu koruması
  String? _liveModel;
  bool _playerOpen = false;

  // Buffer drain tracking
  int _pendingAudioBytes = 0;
  DateTime? _firstAudioChunkTime;

  // ─── Callback'ler ──────────────────────────────────────────────────────────

  Function()? onListening;
  Function()? onThinking;
  Function()? onSpeaking;
  Function()? onIdle;
  Function(String mood)? onMoodChange;
  Function(String text)? onTextOutput;
  Function(LiveConnectionState state)? onConnectionStateChange;

  // ─── Ayar güncellemeleri ───────────────────────────────────────────────────

  void updateApiKey(String k) {
    _apiKey = k;
    _liveModel = null;
  }

  void updateSystemPrompt(String p) => _systemPrompt = p;
  void updateVoice(String g) {
    if (g == 'male') {
      _voiceName = 'Charon';
    } else if (g == 'cozmo') {
      _voiceName = 'Puck';
    } else {
      _voiceName = 'Aoede';
    }
  }
  void updateWakeName(String n) => _wakeName = n;
  void updateMemoryPrompt(String p) => _memoryPrompt = p;
  void setThoughtInjection(String thought) => _thoughtInjection = thought;
  void updateCozmoMode(bool isCozmo) => _cozmoMode = isCozmo;

  // ─── Yaşam döngüsü ────────────────────────────────────────────────────────

  Future<bool> init() async => _mic.hasPermission();

  Future<void> start() async {
    if (_active) return;
    _active = true;
    _reconnecting = false;
    _speaking = false;
    _pendingAudioBytes = 0;
    _firstAudioChunkTime = null;

    // Player'ı aç (bir kez)
    if (!_playerOpen) {
      await _player.openPlayer();
      _playerOpen = true;
    }

    await _connectLoop();
  }

  Future<void> stop() async {
    _active = false;
    _ready = false;
    _reconnecting = false;
    onConnectionStateChange?.call(LiveConnectionState.disconnected);
    await _stopMic();
    await _closeWs();
    await _player.stopPlayer();
  }

  Future<void> stopSpeaking() async {
    await _player.stopPlayer();
  }

  Future<void> dispose() async {
    await stop();
    if (_playerOpen) {
      _player.closePlayer();
      _playerOpen = false;
    }
  }

  // ─── Metin gönder ──────────────────────────────────────────────────────────

  Future<void> sendText(String text) async {
    if (!_ready) return;
    _send({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text}
            ],
          }
        ],
        'turnComplete': true,
      }
    });
    onThinking?.call();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BAĞLANTI
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _connectLoop() async {
    while (_active) {
      if (await _tryConnect()) return;
      debugPrint('[LIVE] 8s sonra tekrar...');
      await Future.delayed(const Duration(seconds: 8));
    }
  }

  Future<bool> _tryConnect() async {
    if (_apiKey.isEmpty) {
      debugPrint('[LIVE] API key boş');
      onConnectionStateChange?.call(LiveConnectionState.error);
      return false;
    }

    onConnectionStateChange?.call(LiveConnectionState.connecting);

    // Model bul
    _liveModel ??= await _findLiveModel();
    if (_liveModel == null) {
      onConnectionStateChange?.call(LiveConnectionState.error);
      return false;
    }

    // WS bağlan
    try {
      debugPrint('[LIVE] bağlanıyor: $_liveModel');
      _ws = await WebSocket.connect('$_wsBase?key=$_apiKey')
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[LIVE] WS hata: $e');
      _liveModel = null;
      onConnectionStateChange?.call(LiveConnectionState.error);
      return false;
    }

    // Tek listener — hem setup hem oturum mesajları
    final setupDone = Completer<bool>();

    _wsSub = _ws!.listen(
      (raw) {
        final data = _parse(raw);
        if (data == null) return;

        if (!_ready) {
          // Setup aşaması
          if (data.containsKey('setupComplete')) {
            if (!setupDone.isCompleted) setupDone.complete(true);
          } else if (data.containsKey('error')) {
            debugPrint('[LIVE] setup hatası: ${data['error']}');
            if (!setupDone.isCompleted) setupDone.complete(false);
          }
        } else {
          _onMessage(data);
        }
      },
      onError: (e) {
        debugPrint('[LIVE] WS stream hata: $e');
        if (!setupDone.isCompleted) setupDone.complete(false);
        if (_ready) _reconnect();
      },
      onDone: () {
        debugPrint('[LIVE] WS kapandı code=${_ws?.closeCode}');
        if (!setupDone.isCompleted) setupDone.complete(false);
        if (_ready) _reconnect();
      },
    );

    // Setup gönder
    _send(_buildSetup());

    final ok = await setupDone.future
        .timeout(const Duration(seconds: 12), onTimeout: () => false);

    if (!ok) {
      debugPrint('[LIVE] setup başarısız');
      await _closeWs();
      return false;
    }

    _ready = true;
    onConnectionStateChange?.call(LiveConnectionState.connected);
    debugPrint('[LIVE] ✓ HAZIR');

    // Streaming player başlat (Gemini 24kHz PCM16 çıkış verir)
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: 24000,
      numChannels: 1,
      interleaved: true,
      bufferSize: 8192,
    );

    await _startMic();
    onListening?.call();
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SUNUCU MESAJLARI
  // ═══════════════════════════════════════════════════════════════════════════

  void _onMessage(Map<String, dynamic> data) {
    final sc = data['serverContent'] as Map<String, dynamic>?;
    if (sc == null) return;

    // Kullanıcı konuştu → model kesildi
    if (sc['interrupted'] == true) {
      debugPrint('[LIVE] interrupted');
      _speaking = false;
      _player.stopPlayer().then((_) {
        if (!_active || !_ready) return;
        _player.startPlayerFromStream(
          codec: Codec.pcm16,
          sampleRate: 24000,
          numChannels: 1,
          interleaved: true,
          bufferSize: 8192,
        );
      });
      onListening?.call();
      return;
    }

    // Model yanıt
    final turn = sc['modelTurn'] as Map<String, dynamic>?;
    if (turn != null) {
      for (final p in (turn['parts'] as List? ?? [])) {
        // Text (mood vs.)
        final text = p['text'] as String?;
        if (text != null) {
          debugPrint('[LIVE] text: $text');
          final m = RegExp(r'\[mood:\s*(\w+)\]').firstMatch(text);
          if (m != null) onMoodChange?.call(m.group(1)!.toLowerCase());
          onTextOutput?.call(text);
        }

        // Audio → doğrudan player'a feed et
        final inline = p['inlineData'] as Map<String, dynamic>?;
        if (inline != null) {
          if (!_speaking) {
            _speaking = true;
            _pendingAudioBytes = 0;
            _firstAudioChunkTime = DateTime.now();
            onSpeaking?.call();
            debugPrint('[LIVE] konuşma başladı → mic susturuldu');
          }
          final bytes = base64Decode(inline['data'] as String);
          _pendingAudioBytes += bytes.length;

          _player.uint8ListSink?.add(bytes);
        }
      }
    }

    // Turn bitti → buffer'daki sesin çalınmasını bekle, sonra mic aç
    if (sc['turnComplete'] == true) {
      debugPrint('[LIVE] turnComplete → buffer draining...');
      // Estimate remaining audio in player buffer
      // Audio: 24kHz, 16-bit (2 bytes/sample) = 48000 bytes/sec
      final totalAudioSec = _pendingAudioBytes / 48000.0;
      final elapsedSec = _firstAudioChunkTime != null
          ? DateTime.now().difference(_firstAudioChunkTime!).inMilliseconds / 1000.0
          : 0.0;
      final remainingEst = (totalAudioSec - elapsedSec).clamp(1.2, 12.0);
      debugPrint('[LIVE] drain estimate: ${remainingEst.toStringAsFixed(1)}s '
          '(total=${totalAudioSec.toStringAsFixed(1)}s, elapsed=${elapsedSec.toStringAsFixed(1)}s)');

      Future.delayed(Duration(milliseconds: (remainingEst * 1000).toInt()), () {
        if (!_active || !_ready) return;
        _pendingAudioBytes = 0;
        _firstAudioChunkTime = null;
        // Brief grace period before enabling mic — prevents echo/ambient noise
        // from triggering an immediate interrupt right as audio finishes
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!_active || !_ready) return;
          _speaking = false;
          debugPrint('[LIVE] mic açıldı');
          onListening?.call();
        });
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MİKROFON
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startMic() async {
    try {
      final stream = await _mic.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      var n = 0;
      _micSub = stream.listen((chunk) {
        if (!_active || !_ready || _ws == null) return;
        // Model konuşurken mic verisi gönderme (echo önleme)
        if (_speaking) return;
        n++;
        if (n == 1 || n % 200 == 0) {
          debugPrint('[LIVE] mic #$n (${chunk.length}b)');
        }
        _send({
          'realtimeInput': {
            'audio': {
              'data': base64Encode(chunk),
              'mimeType': 'audio/pcm;rate=16000',
            }
          }
        });
      });

      debugPrint('[LIVE] mikrofon açık');
    } catch (e) {
      debugPrint('[LIVE] mikrofon hatası: $e');
    }
  }

  Future<void> _stopMic() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      if (await _mic.isRecording()) await _mic.stop();
    } catch (e) {
      debugPrint('[LIVE] mikrofon kapatma hatası: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MODEL KEŞFİ
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String?> _findLiveModel() async {
    try {
      final resp = await http
          .get(Uri.parse('$_modelsUrl?key=$_apiKey'))
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        debugPrint('[LIVE] model API HTTP ${resp.statusCode}');
        return null;
      }

      final models = (jsonDecode(resp.body)['models'] as List?) ?? [];
      final liveModels = <String>[];
      for (final m in models) {
        final methods =
            (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? [];
        if (methods.contains('bidiGenerateContent')) {
          liveModels.add(m['name'] as String);
        }
      }

      if (liveModels.isEmpty) return null;

      debugPrint('[LIVE] live modeller: $liveModels');

      // En hızlı modeli seç: live > flash > diğer, preview sonra
      String best = liveModels.first;
      int bestScore = _modelScore(best);
      for (final m in liveModels) {
        final s = _modelScore(m);
        if (s > bestScore) { best = m; bestScore = s; }
      }

      debugPrint('[LIVE] seçilen model: $best (skor: $bestScore)');
      return best;
    } catch (e) {
      debugPrint('[LIVE] model keşfi hatası: $e');
      return null;
    }
  }

  /// Hızlı/stabil modellere yüksek skor ver
  int _modelScore(String name) {
    var score = 0;
    if (name.contains('flash')) score += 10;
    if (name.contains('live')) score += 20;
    if (name.contains('preview')) score -= 5;
    if (name.contains('exp')) score -= 3;
    if (name.contains('native-audio')) score += 5;
    return score;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  YARDIMCILAR
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _buildSetup() {
    final wake = _wakeName.trim().isEmpty
        ? ''
        : 'ÖNEMLİ: Senin adın "$_wakeName" (Kullanıcı sana Kozmo, Kosmos, Cosmos veya Cozma derse de seni kastediyordur). '
            'Sadece kullanıcı sana adınla seslendiğinde cevap ver. '
            'Kullanıcıya "$_wakeName" diye hitap ETME, "$_wakeName" senin kendi adın. '
            'Kullanıcı "$_wakeName" demeden konuşursa sessiz kal.';

    return {
      'setup': {
        'model': _liveModel,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': _voiceName},
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {
              'text': '${AppConstants.hiddenSystemRules.join('\n')}\n'
                  '${_cozmoMode ? '${AppConstants.cozmoHiddenRules.join('\n')}\n' : ''}\n'
                  '$_systemPrompt\n\n'
                  '$wake'
                  '${_thoughtInjection.isNotEmpty ? AppConstants.thoughtInjectionTemplate.replaceAll('{thought}', _thoughtInjection) : ''}'
                  '${_memoryPrompt.isNotEmpty ? '\n\n$_memoryPrompt' : ''}'
            }
          ],
        },
      }
    };
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _ws?.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('[LIVE] gönderim hatası: $e');
    }
  }

  Map<String, dynamic>? _parse(dynamic raw) {
    try {
      if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
      if (raw is List<int>) {
        return jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[LIVE] parse: $e');
      return null;
    }
  }

  Future<void> _closeWs() async {
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  Future<void> _reconnect() async {
    if (!_active || _reconnecting) return;
    _reconnecting = true;
    _ready = false;
    _speaking = false;
    _pendingAudioBytes = 0;
    _firstAudioChunkTime = null;
    onConnectionStateChange?.call(LiveConnectionState.reconnecting);
    await _stopMic();
    await _player.stopPlayer();
    await _closeWs();
    debugPrint('[LIVE] 3s sonra yeniden bağlanıyor...');
    await Future.delayed(const Duration(seconds: 3));
    _reconnecting = false;
    if (_active) await _connectLoop();
  }
}
