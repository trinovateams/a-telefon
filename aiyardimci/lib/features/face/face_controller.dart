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
      _faceState = FaceState.listening;
      _brainService.onTurnEnd();
      notifyListeners();
    };
    _liveService.onThinking = () {
      _faceState = FaceState.thinking;
      notifyListeners();
    };
    _liveService.onSpeaking = () {
      _faceState = FaceState.speaking;
      _brainService.onInteraction();
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
    _liveService.onTextOutput = (text) {
      _brainService.onTextReceived(text);
    };
    _liveService.onConnectionStateChange = (state) {
      _connectionState = state;
      notifyListeners();
    };

    // Brain callbacks
    _brainService.onIdleBehaviorChange = (behavior) {
      _idleBehavior = behavior;
      notifyListeners();
    };
    _brainService.onStateChange = (energy, boredom, affection) {
      _energy = energy;
      _boredom = boredom;
      _affection = affection;
      notifyListeners();
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
    notifyListeners();
    final hasPermission = await _liveService.init();
    if (hasPermission) {
      // Inject memories before connecting
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
    notifyListeners();
  }

  Future<void> sendTextMessage(String message) async {
    if (message.trim().isEmpty) return;
    _brainService.onUserTextSent(message);
    await _liveService.sendText(message);
  }

  Future<void> stopSpeaking() async {
    await _liveService.stopSpeaking();
    _faceState = FaceState.listening;
    notifyListeners();
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
    _brainService.dispose();
    _liveService.stop();
    _liveService.dispose();
    super.dispose();
  }
}
