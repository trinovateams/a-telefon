import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../enums/idle_behavior.dart';
import '../constants/app_constants.dart';
import 'live_audio_service.dart';
import 'memory_service.dart';
import 'storage_service.dart';

class BrainService {
  final LiveAudioService _liveService;
  final MemoryService _memoryService;
  final StorageService _storageService;

  // Internal state
  double _energy = 0.8;
  double _boredom = 0.0;
  double _affection = 0.3;
  DateTime _lastInteraction = DateTime.now();
  DateTime _sessionStart = DateTime.now();

  // Cooldowns
  final Map<String, DateTime> _cooldowns = {};
  static const _cooldownDuration = Duration(minutes: 30);

  // Timer
  Timer? _timer;
  IdleBehavior _idleBehavior = IdleBehavior.normal;

  // Callbacks
  Function(IdleBehavior behavior)? onIdleBehaviorChange;
  Function(double energy, double boredom, double affection)? onStateChange;

  BrainService({
    required LiveAudioService liveService,
    required MemoryService memoryService,
    required StorageService storageService,
  })  : _liveService = liveService,
        _memoryService = memoryService,
        _storageService = storageService {
    _loadState();
  }

  // --- Getters ---

  double get energy => _energy;
  double get boredom => _boredom;
  double get affection => _affection;
  IdleBehavior get idleBehavior => _idleBehavior;

  String getMemoryPrompt() => _memoryService.getMemoriesForPrompt();

  // --- Lifecycle ---

  void start() {
    _sessionStart = DateTime.now();
    _applyTimeOfDayEnergy();
    _checkWelcomeBack();
    _startTimer();
    debugPrint('[BRAIN] started — energy=$_energy boredom=$_boredom affection=$_affection');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _saveState();
    debugPrint('[BRAIN] stopped, state saved');
  }

  void dispose() {
    stop();
  }

  // --- Events from FaceController (mediator) ---

  void onInteraction() {
    _boredom = 0;
    _energy = (_energy + 0.1).clamp(0.0, 1.0);
    _affection = (_affection + 0.03).clamp(0.0, 1.0);
    _lastInteraction = DateTime.now();
    _updateIdleBehavior();
    _notifyState();
  }

  void onTurnEnd() {
    if (_memoryService.isEnabled && _memoryService.shouldSummarize()) {
      _triggerMemorySummary();
    }
  }

  void onTextReceived(String text) {
    if (_memoryService.isEnabled) {
      _memoryService.onAIText(text);
    }
  }

  void onUserTextSent(String text) {
    if (_memoryService.isEnabled) {
      _memoryService.onUserText(text);
    }
    onInteraction();
  }

  /// Energy boost (coffee button)
  void boost() {
    _energy = (_energy + 0.3).clamp(0.0, 1.0);
    _boredom = 0;
    _updateIdleBehavior();
    _notifyState();
    if (_canTrigger('energy_boost')) {
      _speak('energy_boost');
    }
  }

  /// Clear memories
  Future<void> clearMemories() async {
    await _memoryService.clearMemories();
  }

  // --- Timer Loop ---

  void _startTimer() {
    final interval = _idleBehavior == IdleBehavior.sleeping
        ? const Duration(seconds: 60)
        : const Duration(seconds: 30);
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick() {
    _updateEnergy();

    if (_storageService.getProactiveSpeech()) {
      _updateBoredom();
      _checkTriggers();
    }

    _updateIdleBehavior();
    _notifyState();
  }

  void _updateEnergy() {
    _energy = (_energy - 0.02).clamp(0.0, 1.0);

    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 6) {
      _energy = (_energy - 0.01).clamp(0.0, 1.0);
    }
  }

  void _updateBoredom() {
    final freq = _storageService.getSpeechFrequency();
    final boredomRate = 0.03 + (freq * 0.04); // 0.03–0.07
    _boredom = (_boredom + boredomRate).clamp(0.0, 1.0);
  }

  void _updateIdleBehavior() {
    final hour = DateTime.now().hour;
    final sleepMode = _storageService.getSleepMode();

    IdleBehavior newBehavior;
    if (sleepMode && (_energy < 0.15 || (hour >= 0 && hour < 6))) {
      newBehavior = IdleBehavior.sleeping;
    } else if (_energy < 0.3) {
      newBehavior = IdleBehavior.sleepy;
    } else if (_boredom > 0.5) {
      newBehavior = IdleBehavior.curious;
    } else {
      newBehavior = IdleBehavior.normal;
    }

    if (newBehavior != _idleBehavior) {
      debugPrint('[BRAIN] idle: $_idleBehavior → $newBehavior');
      _idleBehavior = newBehavior;
      onIdleBehaviorChange?.call(_idleBehavior);
      _startTimer(); // Adjust timer interval
    }
  }

  // --- Triggers ---

  void _checkTriggers() {
    final hour = DateTime.now().hour;
    final silenceMinutes =
        DateTime.now().difference(_lastInteraction).inMinutes;
    final sessionMinutes =
        DateTime.now().difference(_sessionStart).inMinutes;

    if (_boredom > 0.7 && _canTrigger('bored')) {
      _speak('bored');
      return;
    }

    if (_energy < 0.2 && _canTrigger('sleepy')) {
      _speak('sleepy');
      return;
    }

    if (silenceMinutes >= 5 && _affection > 0.5 && _canTrigger('miss_user')) {
      _speak('miss_user');
      return;
    }

    if (hour >= 6 && hour < 10 && _canTrigger('morning')) {
      _speak('morning');
      return;
    }
    if (hour >= 23 && _canTrigger('night')) {
      _speak('night');
      return;
    }
    if (hour >= 12 && hour < 14 && _canTrigger('lunch')) {
      _speak('lunch');
      return;
    }
    if (hour >= 18 && hour < 21 && _canTrigger('evening')) {
      _speak('evening');
      return;
    }

    if (sessionMinutes > 30 && _canTrigger('long_session')) {
      _speak('long_session');
      return;
    }

    final weekday = DateTime.now().weekday;
    if ((weekday == 6 || weekday == 7) && _canTrigger('weekend')) {
      _speak('weekend');
      return;
    }
  }

  bool _canTrigger(String id) {
    final last = _cooldowns[id];
    if (last == null) return true;
    return DateTime.now().difference(last) > _cooldownDuration;
  }

  void _speak(String promptKey) {
    final prompt = AppConstants.brainPrompts[promptKey];
    if (prompt == null) return;

    _cooldowns[promptKey] = DateTime.now();

    String fullPrompt = prompt;
    if (_memoryService.isEnabled) {
      final memories = _memoryService.getMemoriesForPrompt(count: 5);
      if (memories.isNotEmpty) {
        fullPrompt = '$prompt\n\nBağlam:\n$memories';
      }
    }

    debugPrint('[BRAIN] trigger: $promptKey');
    _liveService.sendText(fullPrompt);
  }

  // --- Welcome Back ---

  void _checkWelcomeBack() {
    final lastTs = _storageService.getLastSessionTimestamp();
    _storageService.setLastSessionTimestamp(
        DateTime.now().millisecondsSinceEpoch);

    if (lastTs == 0) {
      if (_canTrigger('first_meet')) {
        Future.delayed(const Duration(seconds: 5), () => _speak('first_meet'));
      }
      return;
    }

    final lastSession = DateTime.fromMillisecondsSinceEpoch(lastTs);
    final gap = DateTime.now().difference(lastSession);
    if (gap.inHours > 6 && _canTrigger('welcome_back')) {
      Future.delayed(const Duration(seconds: 5), () => _speak('welcome_back'));
    }
  }

  void _applyTimeOfDayEnergy() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 10) {
      _energy = 0.9;
    } else if (hour >= 10 && hour < 18) {
      _energy = 0.7;
    } else if (hour >= 18 && hour < 22) {
      _energy = 0.5;
    } else {
      _energy = 0.3;
    }
  }

  // --- Persistence ---

  void _loadState() {
    try {
      final json = _storageService.getBrainState();
      if (json.isEmpty) return;
      final data = jsonDecode(json) as Map<String, dynamic>;
      _affection = (data['affection'] as num?)?.toDouble() ?? 0.3;

      final lastTs = data['timestamp'] as int? ?? 0;
      if (lastTs > 0) {
        final gap = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(lastTs));
        if (gap.inHours < 6) {
          _energy = (data['energy'] as num?)?.toDouble() ?? 0.8;
          _boredom = (data['boredom'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (e) {
      debugPrint('[BRAIN] load state error: $e');
    }
  }

  void _saveState() {
    final data = {
      'energy': _energy,
      'boredom': _boredom,
      'affection': _affection,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _storageService.setBrainState(jsonEncode(data));
  }

  // --- Memory Summary ---

  void _triggerMemorySummary() {
    final conversation = _memoryService.getConversationForSummary();
    _memoryService.storeSummary(
      conversation.length > 100
          ? '${conversation.substring(0, 100)}...'
          : conversation,
      'calm',
    );
  }

  void _notifyState() {
    onStateChange?.call(_energy, _boredom, _affection);
  }
}
