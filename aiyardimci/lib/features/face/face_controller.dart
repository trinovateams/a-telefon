import 'package:flutter/material.dart';
import '../../core/enums/face_state.dart';
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
  String _systemPrompt = '';
  String _wakeName = 'Alexia';
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
    _aiService.updateSystemPrompt(_systemPrompt);

    final apiKey = _storageService.getApiKey();
    _aiService.updateApiKey(apiKey);
    _ttsService.updateApiKey(apiKey);
    _speechService.updateApiKey(apiKey);

    final voiceGender = _storageService.getVoiceGender();
    _ttsService.updateVoice(voiceGender);

    _wakeName = _storageService.getWakeName();

    // === CALLBACKS ===

    _speechService.onSpeechResult = (text) async {
      debugPrint('[FLOW] 1. heard: "$text"');

      // Wake word kontrolü — isim geçmiyorsa dinlemeye devam et
      if (!_containsWakeName(text)) {
        debugPrint('[FLOW] wake word yok, geçiliyor');
        if (_isActive) _speechService.startContinuous();
        return;
      }

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

  // Wake word kontrolü — Türkçe büyük/küçük harf toleranslı
  bool _containsWakeName(String text) {
    if (_wakeName.trim().isEmpty) return true; // isim boşsa her şeye cevap ver
    final normalizedText = text.toLowerCase().replaceAll('i̇', 'i').replaceAll('ı', 'i');
    final normalizedName = _wakeName.toLowerCase().replaceAll('i̇', 'i').replaceAll('ı', 'i');
    return normalizedText.contains(normalizedName);
  }

  // === GETTERS ===

  FaceState get faceState => _faceState;
  String get currentMood => _currentMood;
  String get lastMessage => _lastMessage;
  String get lastResponse => _lastResponse;
  String get systemPrompt => _systemPrompt;
  String get wakeName => _wakeName;
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

  Future<void> updateSystemPrompt(String prompt) async {
    _systemPrompt = prompt;
    await _storageService.setSystemPrompt(prompt);
    _aiService.updateSystemPrompt(prompt);
    notifyListeners();
  }

  Future<void> updateApiKey(String key) async {
    await _storageService.setApiKey(key);
    _aiService.updateApiKey(key);
    _ttsService.updateApiKey(key);
    _speechService.updateApiKey(key);
    notifyListeners();
  }

  String get apiKey => _storageService.getApiKey();

  Future<void> updateWakeName(String name) async {
    _wakeName = name.trim();
    await _storageService.setWakeName(_wakeName);
    notifyListeners();
  }

  Future<void> updateVoiceGender(String gender) async {
    await _storageService.setVoiceGender(gender);
    _ttsService.updateVoice(gender);
    notifyListeners();
  }

  String get voiceGender => _storageService.getVoiceGender();

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
