import 'package:flutter/material.dart';
import '../../core/enums/face_state.dart';
import '../../core/services/live_audio_service.dart';
import '../../core/services/storage_service.dart';

class FaceController extends ChangeNotifier with WidgetsBindingObserver {
  final LiveAudioService _liveService;
  final StorageService _storageService;

  FaceState _faceState = FaceState.idle;
  String _currentMood = 'calm';
  String _systemPrompt = '';
  String _wakeName = 'Alexia';
  bool _isActive = false;

  FaceController({
    required LiveAudioService liveService,
    required StorageService storageService,
  })  : _liveService = liveService,
        _storageService = storageService {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  void _init() {
    _systemPrompt = _storageService.getSystemPrompt();
    _wakeName = _storageService.getWakeName();

    final apiKey = _storageService.getApiKey();
    final voiceGender = _storageService.getVoiceGender();

    _liveService.updateApiKey(apiKey);
    _liveService.updateSystemPrompt(_systemPrompt);
    _liveService.updateVoice(voiceGender);
    _liveService.updateWakeName(_wakeName);

    _liveService.onListening = () {
      _faceState = FaceState.listening;
      notifyListeners();
    };
    _liveService.onThinking = () {
      _faceState = FaceState.thinking;
      notifyListeners();
    };
    _liveService.onSpeaking = () {
      _faceState = FaceState.speaking;
      notifyListeners();
    };
    _liveService.onIdle = () {
      _faceState = FaceState.idle;
      notifyListeners();
    };
    _liveService.onMoodChange = (mood) {
      _currentMood = mood;
      notifyListeners();
    };
  }

  // === LIFECYCLE ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[APP] lifecycle: $state');
    if (state == AppLifecycleState.resumed && _isActive) {
      _liveService.start();
    } else if (state == AppLifecycleState.paused) {
      _liveService.stop();
    }
  }

  // === GETTERS ==============================================================

  FaceState get faceState => _faceState;
  String get currentMood => _currentMood;
  String get lastMessage => '';
  String get lastResponse => '';
  String get systemPrompt => _systemPrompt;
  String get wakeName => _wakeName;
  bool get isActive => _isActive;
  String get apiKey => _storageService.getApiKey();
  String get voiceGender => _storageService.getVoiceGender();

  // === PUBLIC ===============================================================

  Future<void> activate() async {
    _isActive = true;
    notifyListeners();
    final hasPermission = await _liveService.init();
    if (hasPermission) {
      await _liveService.start();
    }
    debugPrint('[FLOW] activated - live audio');
  }

  Future<void> deactivate() async {
    _isActive = false;
    await _liveService.stop();
    _faceState = FaceState.idle;
    notifyListeners();
  }

  Future<void> sendTextMessage(String message) async {
    if (message.trim().isEmpty) return;
    await _liveService.sendText(message);
  }

  Future<void> stopSpeaking() async {
    await _liveService.stopSpeaking();
    _faceState = FaceState.listening;
    notifyListeners();
  }

  // === AYARLAR ==============================================================

  Future<void> updateSystemPrompt(String prompt) async {
    _systemPrompt = prompt;
    await _storageService.setSystemPrompt(prompt);
    _liveService.updateSystemPrompt(prompt);
    // Yeni prompt için yeniden bağlan
    if (_isActive) {
      await _liveService.stop();
      await _liveService.start();
    }
    notifyListeners();
  }

  Future<void> updateApiKey(String key) async {
    await _storageService.setApiKey(key);
    _liveService.updateApiKey(key);
    if (_isActive) {
      await _liveService.stop();
      await _liveService.start();
    }
    notifyListeners();
  }

  Future<void> updateWakeName(String name) async {
    _wakeName = name.trim();
    await _storageService.setWakeName(_wakeName);
    _liveService.updateWakeName(_wakeName);
    if (_isActive) {
      await _liveService.stop();
      await _liveService.start();
    }
    notifyListeners();
  }

  Future<void> updateVoiceGender(String gender) async {
    await _storageService.setVoiceGender(gender);
    _liveService.updateVoice(gender);
    if (_isActive) {
      await _liveService.stop();
      await _liveService.start();
    }
    notifyListeners();
  }

  void resetChat() {
    // Live API stateless per session — yeniden bağlan
    if (_isActive) {
      _liveService.stop().then((_) => _liveService.start());
    }
    _currentMood = 'calm';
    _faceState = FaceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveService.stop();
    _liveService.dispose();
    super.dispose();
  }
}
