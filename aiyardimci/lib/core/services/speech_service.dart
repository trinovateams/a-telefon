import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum ListenMode { continuous, off }

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  ListenMode _mode = ListenMode.off;
  Timer? _restartTimer;
  bool _isTransitioning = false; // Geçiş kilidi

  Function(String)? onSpeechResult;
  Function()? onSilence;

  Future<bool> init() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (e) {
        debugPrint('[MIC] error: ${e.errorMsg}');
      },
      onStatus: (s) {
        debugPrint('[MIC] status: $s | mode: $_mode');
        if (s == 'done' && _mode == ListenMode.continuous) {
          _scheduleRestart();
        }
      },
    );
    debugPrint('[MIC] init: $_initialized');
    return _initialized;
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () {
      if (_mode != ListenMode.continuous) return;
      debugPrint('[MIC] restarting continuous listen...');
      _doStartContinuous();
    });
  }

  // ===== SÜREKLİ DİNLEME =====

  Future<void> startContinuous() async {
    if (!_initialized) return;
    _restartTimer?.cancel();
    _mode = ListenMode.continuous;

    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await _doStartContinuous();
  }

  Future<void> _doStartContinuous() async {
    if (_mode != ListenMode.continuous) return;
    if (_isTransitioning) {
      debugPrint('[MIC] transitioning, skip restart');
      return;
    }

    if (_speech.isListening) {
      debugPrint('[MIC] already listening, skip');
      return;
    }

    try {
      debugPrint('[MIC] continuous listening...');
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult && !_isTransitioning) {
            final text = result.recognizedWords.trim();
            debugPrint('[MIC] heard: "$text"');
            if (text.isNotEmpty) {
              _isTransitioning = true;
              _mode = ListenMode.off;
              _restartTimer?.cancel();
              _speech.stop().then((_) {
                _isTransitioning = false;
                onSpeechResult?.call(text);
              });
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'tr_TR',
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('[MIC] continuous error: $e');
      if (_mode == ListenMode.continuous) {
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(seconds: 2), () {
          if (_mode == ListenMode.continuous) _doStartContinuous();
        });
      }
    }
  }

  // ===== KONTROL =====

  Future<void> stop() async {
    _mode = ListenMode.off;
    _restartTimer?.cancel();
    if (_speech.isListening) {
      try { await _speech.stop(); } catch (_) {}
    }
  }

  ListenMode get mode => _mode;
  bool get isListening => _speech.isListening;
}
