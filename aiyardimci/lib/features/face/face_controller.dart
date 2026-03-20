import 'package:flutter/material.dart';
import '../../core/enums/face_state.dart';
import '../../core/enums/eye_theme_type.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/speech_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/storage_service.dart';

class FaceController extends ChangeNotifier with WidgetsBindingObserver {
  final AiService _aiService;
  final SpeechService _speechService;
  final TtsService _ttsService;
  final StorageService _storageService;

  FaceState _faceState = FaceState.idle;
  String _currentMood = 'calm';
  String _lastMessage = '';
  String _lastResponse = '';
  EyeThemeType _currentTheme = EyeThemeType.defaultTheme;
  String _systemPrompt = '';
  bool _isActive = false;

  FaceController({
    required AiService aiService,
    required SpeechService speechService,
    required TtsService ttsService,
    required StorageService storageService,
  })  : _aiService = aiService,
        _speechService = speechService,
        _ttsService = ttsService,
        _storageService = storageService {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  void _init() {
    _systemPrompt = _storageService.getSystemPrompt();
    _currentTheme = _storageService.getEyeTheme();
    _aiService.updateSystemPrompt(_systemPrompt);
    _updateThemePrompt();

    // === CALLBACKS ===

    _speechService.onSpeechResult = (text) async {
      debugPrint('[FLOW] 1. heard: "$text"');
      _lastMessage = text;
      _faceState = FaceState.thinking;
      notifyListeners();

      // Mikrofon zaten speech_service tarafından durduruldu

      debugPrint('[FLOW] 2. asking AI...');
      final result = await _aiService.sendMessage(text);
      _currentMood = result['mood'] ?? 'calm';
      _lastResponse = result['message'] ?? '';

      // Cevabı oku
      _faceState = FaceState.speaking;
      notifyListeners();
      debugPrint('[FLOW] 3. speaking response...');
      _ttsService.onComplete = _afterResponse;
      await _ttsService.speak(_lastResponse);
    };

    _speechService.onSilence = () {
      debugPrint('[FLOW] silence, keep listening');
      if (_isActive) _speechService.startContinuous();
    };
  }

  // Cevap bittikten sonra → tekrar dinlemeye başla
  void _afterResponse() {
    debugPrint('[FLOW] 4. response done, back to listening');
    _faceState = FaceState.idle;
    notifyListeners();
    if (_isActive && _faceState == FaceState.idle) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isActive && _faceState == FaceState.idle) {
          _speechService.startContinuous();
        }
      });
    }
  }

  // === LIFECYCLE ===

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[APP] lifecycle: $state');
    if (state == AppLifecycleState.resumed && _isActive && _faceState == FaceState.idle) {
      _speechService.startContinuous();
    } else if (state == AppLifecycleState.paused) {
      _speechService.stop();
    }
  }

  // === GETTERS ===

  FaceState get faceState => _faceState;
  String get currentMood => _currentMood;
  String get lastMessage => _lastMessage;
  String get lastResponse => _lastResponse;
  EyeThemeType get currentTheme => _currentTheme;
  String get systemPrompt => _systemPrompt;
  bool get isActive => _isActive;

  // === PUBLIC ===

  Future<void> activate() async {
    _isActive = true;
    notifyListeners();
    await _speechService.init();
    await _speechService.startContinuous();
    debugPrint('[FLOW] activated - continuous listening');
  }

  Future<void> deactivate() async {
    _isActive = false;
    await _speechService.stop();
    await _ttsService.stop();
    _faceState = FaceState.idle;
    notifyListeners();
  }

  Future<void> sendTextMessage(String message) async {
    if (message.trim().isEmpty) return;
    _lastMessage = message;
    await _speechService.stop();

    _faceState = FaceState.thinking;
    notifyListeners();

    final result = await _aiService.sendMessage(message);
    _currentMood = result['mood'] ?? 'calm';
    _lastResponse = result['message'] ?? '';

    _faceState = FaceState.speaking;
    notifyListeners();
    _ttsService.onComplete = _afterResponse;
    await _ttsService.speak(_lastResponse);
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stop();
    _faceState = FaceState.idle;
    notifyListeners();
    if (_isActive) _speechService.startContinuous();
  }

  // === AYARLAR ===

  Future<void> setTheme(EyeThemeType theme) async {
    _currentTheme = theme;
    await _storageService.setEyeTheme(theme);
    _updateThemePrompt();
    notifyListeners();
  }

  void _updateThemePrompt() {
    String themePrompt = '';
    switch (_currentTheme) {
      case EyeThemeType.anime:
        themePrompt = 'Sen çok enerjik, dramatik ve ifadecisin.';
        break;
      case EyeThemeType.robot:
        themePrompt = 'Sen mantıksal, kesin ve analitiksin.';
        break;
      case EyeThemeType.female:
        themePrompt = 'Sen zarif, empatik ve akıcısın.';
        break;
      case EyeThemeType.cool:
        themePrompt = 'Sen rahat, kendine güvenen ve doğal havalısın.';
        break;
      default:
        themePrompt = '';
    }
    _aiService.updateThemePrompt(themePrompt);
  }

  Future<void> updateSystemPrompt(String prompt) async {
    _systemPrompt = prompt;
    await _storageService.setSystemPrompt(prompt);
    _aiService.updateSystemPrompt(prompt);
    notifyListeners();
  }

  void resetChat() {
    _aiService.resetChat();
    _lastMessage = '';
    _lastResponse = '';
    _currentMood = 'calm';
    _faceState = FaceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechService.stop();
    _ttsService.dispose();
    super.dispose();
  }
}
