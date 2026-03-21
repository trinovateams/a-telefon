import 'package:flutter/material.dart';
import '../../core/enums/face_state.dart';
import '../../core/enums/idle_behavior.dart';
import '../../core/enums/connection_state.dart';
import '../../core/services/live_audio_service.dart';
import '../../core/services/brain_service.dart';
import '../../core/services/storage_service.dart';

class FaceController extends ChangeNotifier with WidgetsBindingObserver {
  final LiveAudioService _liveService;
  final BrainService _brainService;
  final StorageService _storageService;

  FaceState _faceState = FaceState.idle;
  String _currentMood = 'calm';
  String _systemPrompt = '';
  String _wakeName = 'Alexia';
  bool _isActive = false;
  bool _disposed = false;

  // Brain state
  IdleBehavior _idleBehavior = IdleBehavior.normal;
  LiveConnectionState _connectionState = LiveConnectionState.disconnected;
  double _energy = 0.8;
  double _boredom = 0.0;
  double _affection = 0.3;

  FaceController({
    required LiveAudioService liveService,
    required BrainService brainService,
    required StorageService storageService,
  })  : _liveService = liveService,
        _brainService = brainService,
        _storageService = storageService {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
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

    // Live service callbacks
    _liveService.onListening = () {
      if (_disposed) return;
      _faceState = FaceState.listening;
      _brainService.onTurnEnd();
      _safeNotify();
    };
    _liveService.onThinking = () {
      if (_disposed) return;
      _faceState = FaceState.thinking;
      _safeNotify();
    };
    _liveService.onSpeaking = () {
      if (_disposed) return;
      _faceState = FaceState.speaking;
      _brainService.onInteraction();
      _safeNotify();
    };
    _liveService.onIdle = () {
      if (_disposed) return;
      _faceState = FaceState.idle;
      _safeNotify();
    };
    _liveService.onMoodChange = (mood) {
      if (_disposed) return;
      _currentMood = mood;
      _safeNotify();
    };
    _liveService.onTextOutput = (text) {
      if (_disposed) return;
      _brainService.onTextReceived(text);
    };
    _liveService.onConnectionStateChange = (state) {
      if (_disposed) return;
      _connectionState = state;
      _safeNotify();
    };

    // Brain callbacks
    _brainService.onIdleBehaviorChange = (behavior) {
      if (_disposed) return;
      _idleBehavior = behavior;
      _safeNotify();
    };
    _brainService.onStateChange = (energy, boredom, affection) {
      if (_disposed) return;
      _energy = energy;
      _boredom = boredom;
      _affection = affection;
      _safeNotify();
    };
  }

  // === LIFECYCLE ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[APP] lifecycle: $state');
    if (state == AppLifecycleState.resumed && _isActive) {
      _liveService.start();
      _brainService.start();
    } else if (state == AppLifecycleState.paused) {
      _liveService.stop();
      _brainService.stop();
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
  StorageService get storageService => _storageService;

  // Brain getters
  IdleBehavior get idleBehavior => _idleBehavior;
  LiveConnectionState get connectionState => _connectionState;
  double get energy => _energy;
  double get boredom => _boredom;
  double get affection => _affection;

  // === PUBLIC ===============================================================

  Future<void> activate() async {
    _isActive = true;
    _safeNotify();
    final hasPermission = await _liveService.init();
    if (hasPermission) {
      final memoryPrompt = _brainService.getMemoryPrompt();
      _liveService.updateMemoryPrompt(memoryPrompt);
      await _liveService.start();
      _brainService.start();
    }
    debugPrint('[FLOW] activated - live audio + brain');
  }

  Future<void> deactivate() async {
    _isActive = false;
    _brainService.stop();
    await _liveService.stop();
    _faceState = FaceState.idle;
    _safeNotify();
  }

  Future<void> sendTextMessage(String message) async {
    if (message.trim().isEmpty) return;
    _brainService.onUserTextSent(message);
    await _liveService.sendText(message);
  }

  Future<void> stopSpeaking() async {
    await _liveService.stopSpeaking();
    _faceState = FaceState.listening;
    _safeNotify();
  }

  void boostEnergy() {
    _brainService.boost();
  }

  // === AYARLAR ==============================================================

  Future<void> updateSystemPrompt(String prompt) async {
    _systemPrompt = prompt;
    await _storageService.setSystemPrompt(prompt);
    _liveService.updateSystemPrompt(prompt);
    if (_isActive) {
      await _liveService.stop();
      await _liveService.start();
    }
    _safeNotify();
  }

  Future<void> updateApiKey(String key) async {
    await _storageService.setApiKey(key);
    _liveService.updateApiKey(key);
    if (_isActive) {
      await _liveService.stop();
      await _liveService.start();
    }
    _safeNotify();
  }

  Future<void> updateWakeName(String name) async {
    _wakeName = name.trim();
    await _storageService.setWakeName(_wakeName);
    _liveService.updateWakeName(_wakeName);
    if (_isActive) {
      await _liveService.stop();
      await _liveService.start();
    }
    _safeNotify();
  }

  Future<void> updateVoiceGender(String gender) async {
    await _storageService.setVoiceGender(gender);
    _liveService.updateVoice(gender);
    if (_isActive) {
      await _liveService.stop();
      await _liveService.start();
    }
    _safeNotify();
  }

  void resetChat() {
    if (_isActive) {
      _liveService.stop().then((_) => _liveService.start());
    }
    _currentMood = 'calm';
    _faceState = FaceState.idle;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);

    // Clear all callbacks to prevent post-dispose calls
    _liveService.onListening = null;
    _liveService.onThinking = null;
    _liveService.onSpeaking = null;
    _liveService.onIdle = null;
    _liveService.onMoodChange = null;
    _liveService.onTextOutput = null;
    _liveService.onConnectionStateChange = null;
    _brainService.onIdleBehaviorChange = null;
    _brainService.onStateChange = null;

    _brainService.dispose();
    _liveService.dispose();
    super.dispose();
  }
}
