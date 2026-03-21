# Living Entity Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Alexia from a passive voice assistant into a Cozmo-like living companion with proactive behavior, memory, idle animations, and environmental awareness.

**Architecture:** Central BrainService manages internal state (energy/boredom/affection) via a periodic timer, triggers proactive speech through LiveAudioService, and drives idle animations via FaceController. MemoryService captures conversation text and stores summaries. Squash-based eye animations (Cozmo style) replace any eyelid approach.

**Tech Stack:** Flutter, Gemini Live API (WebSocket), flutter_sound, record, Provider/ChangeNotifier, SharedPreferences

**Spec:** `docs/superpowers/specs/2026-03-21-living-entity-engine-design.md`

---

## File Structure

```
lib/
├── core/
│   ├── enums/
│   │   ├── face_state.dart              # EXISTING — no change
│   │   ├── idle_behavior.dart           # NEW — IdleBehavior enum
│   │   └── connection_state.dart        # NEW — ConnectionState enum
│   ├── services/
│   │   ├── live_audio_service.dart      # MODIFY — buffer drain fix, onTextOutput, connection state
│   │   ├── brain_service.dart           # NEW — energy/boredom/affection engine
│   │   ├── memory_service.dart          # NEW — conversation memory
│   │   ├── storage_service.dart         # MODIFY — new keys for brain/memory settings
│   │   ├── speech_service.dart          # DELETE
│   │   ├── tts_service.dart             # DELETE
│   │   └── ai_service.dart              # DELETE
│   └── constants/
│       └── app_constants.dart           # MODIFY — brain prompts
├── features/
│   ├── face/
│   │   ├── face_controller.dart         # MODIFY — brain integration, mediator callbacks
│   │   ├── face_screen.dart             # MODIFY — connection status, energy bar, new status messages
│   │   └── themes/
│   │       ├── realistic_eye.dart       # MODIFY — blink controller, squash, IdleBehavior
│   │       └── realistic_eye_painter.dart # MODIFY — squash parameter
│   └── settings/
│       └── settings_screen.dart         # MODIFY — brain settings section
└── main.dart                            # MODIFY — inject BrainService, MemoryService
```

---

## Task 1: Delete Dead Code

**Files:**
- Delete: `lib/core/services/speech_service.dart`
- Delete: `lib/core/services/tts_service.dart`
- Delete: `lib/core/services/ai_service.dart`

These files are confirmed unused — no imports reference them anywhere in the codebase.

- [ ] **Step 1: Delete the three dead service files**

```bash
rm lib/core/services/speech_service.dart
rm lib/core/services/tts_service.dart
rm lib/core/services/ai_service.dart
```

- [ ] **Step 2: Verify no broken imports**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -30
```

Expected: No errors related to these files.

- [ ] **Step 3: Commit**

```bash
git add -u
git commit -m "chore: remove dead code — speech_service, tts_service, ai_service"
```

---

## Task 2: Buffer Drain Fix in LiveAudioService

**Files:**
- Modify: `lib/core/services/live_audio_service.dart`

The current 2-second fixed delay after `turnComplete` is unreliable. Replace with player state monitoring using `flutter_sound`'s `setSubscriptionDuration` + `onProgress` to detect when playback actually finishes.

- [ ] **Step 1: Add tracking variables**

In `LiveAudioService` class, add:

```dart
bool _turnDone = false;
int _pendingAudioBytes = 0;
DateTime? _lastAudioChunkTime;
```

- [ ] **Step 2: Track audio bytes in `_onMessage`**

In the `_onMessage` method, where `inline['data']` is decoded, add byte tracking:

```dart
// After: final bytes = base64Decode(inline['data'] as String);
_pendingAudioBytes += bytes.length;
_lastAudioChunkTime = DateTime.now();
```

- [ ] **Step 3: Replace fixed delay in turnComplete handler**

Replace the existing `turnComplete` block (the `Future.delayed(const Duration(seconds: 2), ...)` section) with:

```dart
if (sc['turnComplete'] == true) {
  debugPrint('[LIVE] turnComplete → buffer draining...');
  _turnDone = true;
  // Estimate remaining buffer: total audio duration minus elapsed time
  // Audio is 24kHz, 16-bit (2 bytes per sample)
  final totalAudioDuration = _pendingAudioBytes / (24000 * 2);
  // Use a shorter drain time since audio has been playing while chunks arrived
  final elapsed = _lastAudioChunkTime != null
      ? DateTime.now().difference(_lastAudioChunkTime!).inMilliseconds / 1000.0
      : 0.0;
  final remainingEstimate = (totalAudioDuration - elapsed).clamp(0.3, 5.0);
  debugPrint('[LIVE] estimated drain: ${remainingEstimate.toStringAsFixed(1)}s');

  Future.delayed(Duration(milliseconds: (remainingEstimate * 1000).toInt()), () {
    if (!_active) return;
    _speaking = false;
    _turnDone = false;
    _pendingAudioBytes = 0;
    _lastAudioChunkTime = null;
    debugPrint('[LIVE] mic açıldı');
    onListening?.call();
  });
}
```

- [ ] **Step 4: Reset tracking on new turn start**

In `_onMessage`, at the beginning where `modelTurn` is detected, reset if this is a new turn:

```dart
final turn = sc['modelTurn'] as Map<String, dynamic>?;
if (turn != null) {
  if (!_speaking) {
    // New turn starting — reset byte tracking
    _pendingAudioBytes = 0;
    _lastAudioChunkTime = DateTime.now();
  }
  // ... existing code
}
```

- [ ] **Step 5: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/live_audio_service.dart
git commit -m "fix: replace fixed 2s buffer drain with estimated audio duration"
```

---

## Task 3: Add onTextOutput Callback and Connection State

**Files:**
- Create: `lib/core/enums/connection_state.dart`
- Modify: `lib/core/services/live_audio_service.dart`

- [ ] **Step 1: Create ConnectionState enum**

Create `lib/core/enums/connection_state.dart`:

```dart
enum LiveConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
}
```

- [ ] **Step 2: Add new callbacks to LiveAudioService**

In `LiveAudioService`, add to the callbacks section:

```dart
Function(String text)? onTextOutput;
Function(LiveConnectionState state)? onConnectionStateChange;
```

- [ ] **Step 3: Fire onTextOutput in _onMessage**

In `_onMessage`, where text is already parsed (the `if (text != null)` block), add:

```dart
final text = p['text'] as String?;
if (text != null) {
  debugPrint('[LIVE] text: $text');
  // Mood tag extraction (existing)
  final m = RegExp(r'\[mood:\s*(\w+)\]').firstMatch(text);
  if (m != null) onMoodChange?.call(m.group(1)!.toLowerCase());
  // NEW: expose raw text to consumers
  onTextOutput?.call(text);
}
```

- [ ] **Step 4: Fire connection state changes**

Add a helper method and call it at appropriate points:

```dart
void _setConnectionState(LiveConnectionState state) {
  onConnectionStateChange?.call(state);
}
```

Fire it in:
- `_tryConnect()` start → `_setConnectionState(LiveConnectionState.connecting)`
- `_tryConnect()` after `_ready = true` → `_setConnectionState(LiveConnectionState.connected)`
- `_tryConnect()` on failure → `_setConnectionState(LiveConnectionState.error)`
- `_reconnect()` → `_setConnectionState(LiveConnectionState.reconnecting)`
- `stop()` → `_setConnectionState(LiveConnectionState.disconnected)`

- [ ] **Step 5: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/enums/connection_state.dart lib/core/services/live_audio_service.dart
git commit -m "feat: add onTextOutput callback and connection state tracking"
```

---

## Task 4: IdleBehavior Enum

**Files:**
- Create: `lib/core/enums/idle_behavior.dart`

- [ ] **Step 1: Create the enum**

```dart
enum IdleBehavior {
  normal,   // standard idle — random saccades
  curious,  // boredom high — wider gaze, faster saccades
  sleepy,   // low energy — slow movement, occasional yawn
  sleeping, // very low energy or night — eyes mostly closed
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/enums/idle_behavior.dart
git commit -m "feat: add IdleBehavior enum"
```

---

## Task 5: Squash Parameter in Eye Painter

**Files:**
- Modify: `lib/features/face/themes/realistic_eye_painter.dart`

- [ ] **Step 1: Add squash parameter to RealisticEyePainter constructor**

Add `required this.squash` to the constructor parameters and field:

```dart
final double squash; // 0.0 = fully open, 1.0 = fully closed
```

- [ ] **Step 2: Apply center-relative squash transform in paint()**

At the very beginning of the `paint()` method, before any drawing:

```dart
@override
void paint(Canvas canvas, Size size) {
  // Apply squash transform (Cozmo-style eye closing)
  if (squash > 0.001) {
    final centerY = size.height / 2;
    canvas.save();
    canvas.translate(0, centerY);
    canvas.scale(1.0, 1.0 - squash);
    canvas.translate(0, -centerY);
  }

  // ... ALL existing drawing code unchanged ...

  // At the very end of paint(), restore if saved:
  if (squash > 0.001) {
    canvas.restore();
  }
}
```

- [ ] **Step 3: Update shouldRepaint**

```dart
@override
bool shouldRepaint(RealisticEyePainter old) =>
    old.pupilScale != pupilScale ||
    old.gazeOffset != gazeOffset ||
    old.irisColor != irisColor ||
    old.shimmerAngle != shimmerAngle ||
    old.wetness != wetness ||
    old.glowPulse != glowPulse ||
    old.squash != squash;
```

- [ ] **Step 4: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

Expected: Error about missing `squash` argument in `realistic_eye.dart` — that's fine, fixed in next task.

- [ ] **Step 5: Commit**

```bash
git add lib/features/face/themes/realistic_eye_painter.dart
git commit -m "feat: add squash parameter to RealisticEyePainter"
```

---

## Task 6: Blink System in RealisticEyeWidget

**Files:**
- Modify: `lib/features/face/themes/realistic_eye.dart`

- [ ] **Step 1: Add blink controller and idle behavior**

Add to `_RealisticEyeWidgetState`:

```dart
late AnimationController _blinkController;
late Animation<double> _blinkAnim;
IdleBehavior _idleBehavior = IdleBehavior.normal;
double _baseSquash = 0.0; // from idle behavior (sleep = 0.6, yawn = 0.5, etc.)
```

Add import at top:

```dart
import '../../../core/enums/idle_behavior.dart';
```

- [ ] **Step 2: Add idleBehavior to widget constructor**

```dart
class RealisticEyeWidget extends StatefulWidget {
  final FaceState state;
  final String mood;
  final IdleBehavior idleBehavior;

  const RealisticEyeWidget({
    super.key,
    required this.state,
    required this.mood,
    this.idleBehavior = IdleBehavior.normal,
  });
```

- [ ] **Step 3: Initialize blink controller in _initControllers**

```dart
_blinkController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 250),
);
_blinkAnim = Tween(begin: 0.0, end: 0.0).animate(_blinkController);
```

- [ ] **Step 4: Add blink loop**

```dart
void _startBlinkLoop() {
  final delay = 3000 + Random().nextInt(4000); // 3-7 seconds
  Future.delayed(Duration(milliseconds: delay), () {
    if (!mounted) return;
    // Don't blink while sleeping (eyes already closed)
    if (_idleBehavior == IdleBehavior.sleeping) {
      _startBlinkLoop();
      return;
    }
    _doBlink();
    _startBlinkLoop();
  });
}

void _doBlink() {
  final doubleBlink = Random().nextDouble() < 0.2;
  _blinkAnim = TweenSequence<double>(
    doubleBlink
        ? [
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
          ]
        : [
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
          ],
  ).animate(CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut));
  _blinkController.duration = Duration(milliseconds: doubleBlink ? 400 : 250);
  _blinkController.forward(from: 0);
}
```

Call `_startBlinkLoop()` from `initState()` after existing init calls.

- [ ] **Step 5: Handle idleBehavior changes in didUpdateWidget**

```dart
if (old.idleBehavior != widget.idleBehavior) {
  _idleBehavior = widget.idleBehavior;
  switch (_idleBehavior) {
    case IdleBehavior.sleeping:
      _baseSquash = 0.65;
      break;
    case IdleBehavior.sleepy:
      _baseSquash = 0.15;
      break;
    default:
      _baseSquash = 0.0;
  }
}
```

- [ ] **Step 6: Compute final squash in build and pass to painters**

In the `builder` callback, compute:

```dart
// Combine blink animation with base squash (sleeping/sleepy)
final blinkSquash = _blinkAnim.value;
final finalSquash = (blinkSquash + _baseSquash).clamp(0.0, 1.0);
```

Pass `squash: finalSquash` to both `RealisticEyePainter` instances (left and right eye).

- [ ] **Step 7: Adjust saccade behavior based on idleBehavior**

In `_updateGaze()`, modify the idle case:

```dart
case FaceState.idle:
  if (_idleBehavior == IdleBehavior.sleeping) {
    newTarget = Offset.zero; // No movement when sleeping
  } else if (_idleBehavior == IdleBehavior.curious) {
    newTarget = Offset((rng.nextDouble() - 0.5) * 0.7, (rng.nextDouble() - 0.5) * 0.5);
  } else {
    newTarget = Offset((rng.nextDouble() - 0.5) * 0.5, (rng.nextDouble() - 0.5) * 0.4);
  }
  break;
```

- [ ] **Step 8: Dispose blink controller**

Add `_blinkController.dispose();` in `dispose()`.

- [ ] **Step 9: Add _blinkController to Listenable.merge in build**

Add `_blinkController` to the merged listenable list.

- [ ] **Step 10: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 11: Commit**

```bash
git add lib/features/face/themes/realistic_eye.dart
git commit -m "feat: add blink system and squash-based idle animations"
```

---

## Task 7: StorageService — New Keys

**Files:**
- Modify: `lib/core/services/storage_service.dart`

- [ ] **Step 1: Add new storage keys and methods**

```dart
// Brain settings
bool getProactiveSpeech() => _prefs.getBool('proactive_speech') ?? true;
Future<void> setProactiveSpeech(bool v) => _prefs.setBool('proactive_speech', v);

double getSpeechFrequency() => _prefs.getDouble('speech_frequency') ?? 0.5; // 0.0-1.0
Future<void> setSpeechFrequency(double v) => _prefs.setDouble('speech_frequency', v);

bool getSleepMode() => _prefs.getBool('sleep_mode') ?? true;
Future<void> setSleepMode(bool v) => _prefs.setBool('sleep_mode', v);

bool getMemoryEnabled() => _prefs.getBool('memory_enabled') ?? true;
Future<void> setMemoryEnabled(bool v) => _prefs.setBool('memory_enabled', v);

// Brain state persistence
String getBrainState() => _prefs.getString('brain_state') ?? '';
Future<void> setBrainState(String json) => _prefs.setString('brain_state', json);

// Memory storage
String getMemories() => _prefs.getString('memories') ?? '[]';
Future<void> setMemories(String json) => _prefs.setString('memories', json);

// Last session timestamp
int getLastSessionTimestamp() => _prefs.getInt('last_session_ts') ?? 0;
Future<void> setLastSessionTimestamp(int ts) => _prefs.setInt('last_session_ts', ts);
```

- [ ] **Step 2: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/storage_service.dart
git commit -m "feat: add storage keys for brain state, memory, and settings"
```

---

## Task 8: MemoryService

**Files:**
- Create: `lib/core/services/memory_service.dart`

- [ ] **Step 1: Create MemoryService**

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class MemoryService {
  final StorageService _storage;
  final List<Map<String, dynamic>> _memories = [];
  final List<String> _currentTurnTexts = [];
  int _turnCount = 0;

  static const int _maxMemories = 50;

  MemoryService({required StorageService storage}) : _storage = storage {
    _loadMemories();
  }

  // --- Load/Save ---

  void _loadMemories() {
    try {
      final json = _storage.getMemories();
      final list = jsonDecode(json) as List;
      _memories.addAll(list.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('[MEMORY] load error, starting fresh: $e');
      _memories.clear();
    }
  }

  Future<void> _saveMemories() async {
    try {
      await _storage.setMemories(jsonEncode(_memories));
    } catch (e) {
      debugPrint('[MEMORY] save error: $e');
    }
  }

  // --- Public API ---

  /// Called when AI sends text output
  void onAIText(String text) {
    // Strip mood tags
    final clean = text.replaceAll(RegExp(r'\[mood:\s*\w+\]'), '').trim();
    if (clean.isNotEmpty) {
      _currentTurnTexts.add('AI: $clean');
      _turnCount++;
    }
  }

  /// Called when user sends text
  void onUserText(String text) {
    _currentTurnTexts.add('User: $text');
    _turnCount++;
  }

  /// Check if it's time to summarize (every 5 turns)
  bool shouldSummarize() => _turnCount >= 5 && _currentTurnTexts.isNotEmpty;

  /// Get conversation text for summarization
  String getConversationForSummary() => _currentTurnTexts.join('\n');

  /// Store a summary (called after Gemini summarizes)
  Future<void> storeSummary(String summary, String mood) async {
    final memory = {
      'summary': summary,
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'mood': mood,
    };
    _memories.add(memory);
    if (_memories.length > _maxMemories) {
      _memories.removeAt(0); // FIFO
    }
    _currentTurnTexts.clear();
    _turnCount = 0;
    await _saveMemories();
    debugPrint('[MEMORY] stored: $summary');
  }

  /// Get recent memories for system prompt injection
  String getMemoriesForPrompt({int count = 10}) {
    if (_memories.isEmpty) return '';
    final recent = _memories.length > count
        ? _memories.sublist(_memories.length - count)
        : _memories;

    final lines = recent.map((m) => '- ${m['date']}: ${m['summary']}').join('\n');
    return 'Hatirladiklarin:\n$lines';
  }

  /// Clear all memories
  Future<void> clearMemories() async {
    _memories.clear();
    _currentTurnTexts.clear();
    _turnCount = 0;
    await _saveMemories();
  }

  bool get isEnabled => _storage.getMemoryEnabled();
}
```

- [ ] **Step 2: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/memory_service.dart
git commit -m "feat: add MemoryService for conversation memory"
```

---

## Task 9: BrainService

**Files:**
- Create: `lib/core/services/brain_service.dart`
- Modify: `lib/core/constants/app_constants.dart`

- [ ] **Step 1: Add brain prompt templates to AppConstants**

Add to `AppConstants` class:

```dart
static const Map<String, String> brainPrompts = {
  'bored': 'Şu an çok sıkıldın. Kendi kendine kısa bir şey söyle veya kullanıcıya bir soru sor.',
  'sleepy': 'Çok uyklusun. Esneyerek veya uykulu bir şekilde kısa bir şey söyle.',
  'miss_user': 'Kullanıcıyı özledin. Kısa ve sevgi dolu bir şey söyle.',
  'morning': 'Günaydın de ve kullanıcının gününün nasıl olacağını sor.',
  'night': 'Geç saat olduğunu belirt, uyku vakti geldiğini ima et.',
  'lunch': 'Öğle yemeği saati olduğunu belirt.',
  'evening': 'Akşam oldu, kullanıcının günü nasıl geçmiş sor.',
  'long_session': 'Kullanıcıyla uzun süredir konuşuyorsun. Bunu takdir eden kısa bir şey söyle.',
  'welcome_back': 'Kullanıcı uzun bir aradan sonra geri döndü. Sevinçle karşıla.',
  'first_meet': 'Kullanıcıyla ilk kez tanışıyorsun. Kendini tanıt ve sıcak bir karşılama yap.',
  'weekend': 'Bugün hafta sonu. Bununla ilgili kısa bir şey söyle.',
  'energy_boost': 'Birisi sana enerji verdi! Sevin ve teşekkür et.',
};
```

- [ ] **Step 2: Create BrainService**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../enums/idle_behavior.dart';
import 'live_audio_service.dart';
import 'memory_service.dart';
import 'storage_service.dart';
import '../constants/app_constants.dart';

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

  // --- Lifecycle ---

  void start() {
    _sessionStart = DateTime.now();
    _applyTimeOfDayEnergy();
    _checkWelcomeBack();
    _startTimer();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _saveState();
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
    // Check if memory should summarize
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

  // --- Timer Loop ---

  void _startTimer() {
    final interval = _idleBehavior == IdleBehavior.sleeping
        ? const Duration(seconds: 60)
        : const Duration(seconds: 30);
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick() {
    if (!_storageService.getProactiveSpeech()) {
      // Still update internal state even if speech is off
      _updateEnergy();
      _updateIdleBehavior();
      _notifyState();
      return;
    }

    _updateEnergy();
    _updateBoredom();
    _updateIdleBehavior();
    _checkTriggers();
    _notifyState();
  }

  void _updateEnergy() {
    _energy = (_energy - 0.02).clamp(0.0, 1.0);

    // Time-of-day adjustment
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 6) {
      _energy = (_energy - 0.01).clamp(0.0, 1.0); // Extra drain at night
    }
  }

  void _updateBoredom() {
    final freq = _storageService.getSpeechFrequency();
    // Higher frequency = boredom increases faster
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
      _idleBehavior = newBehavior;
      onIdleBehaviorChange?.call(_idleBehavior);
      // Adjust timer interval
      _startTimer();
    }
  }

  // --- Triggers ---

  void _checkTriggers() {
    final hour = DateTime.now().hour;
    final silenceMinutes =
        DateTime.now().difference(_lastInteraction).inMinutes;
    final sessionMinutes =
        DateTime.now().difference(_sessionStart).inMinutes;

    // Boredom trigger
    if (_boredom > 0.7 && _canTrigger('bored')) {
      _speak('bored');
      return;
    }

    // Sleepy trigger
    if (_energy < 0.2 && _canTrigger('sleepy')) {
      _speak('sleepy');
      return;
    }

    // Miss user trigger
    if (silenceMinutes >= 5 && _affection > 0.5 && _canTrigger('miss_user')) {
      _speak('miss_user');
      return;
    }

    // Time-based triggers
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

    // Long session trigger
    if (sessionMinutes > 30 && _canTrigger('long_session')) {
      _speak('long_session');
      return;
    }

    // Weekend trigger
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

    // Add memory context if available
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
      // First time ever
      if (_canTrigger('first_meet')) {
        Future.delayed(const Duration(seconds: 3), () => _speak('first_meet'));
      }
      return;
    }

    final lastSession = DateTime.fromMillisecondsSinceEpoch(lastTs);
    final gap = DateTime.now().difference(lastSession);
    if (gap.inHours > 6 && _canTrigger('welcome_back')) {
      Future.delayed(const Duration(seconds: 3), () => _speak('welcome_back'));
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

      // Check time gap for energy
      final lastTs = data['timestamp'] as int? ?? 0;
      if (lastTs > 0) {
        final gap = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(lastTs));
        if (gap.inHours < 6) {
          _energy = (data['energy'] as num?)?.toDouble() ?? 0.8;
          _boredom = (data['boredom'] as num?)?.toDouble() ?? 0.0;
        }
        // else: use time-of-day defaults (set in _applyTimeOfDayEnergy)
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
    // Send as a text message to get a summary back
    // We'll use a special prefix that won't be spoken
    _liveService.sendText(
      'Bu konuşmayı 1 kısa cümleyle özetle, sadece özeti söyle başka bir şey söyleme: $conversation',
    );
    // The summary will come back via onTextReceived and we store it
    // For now, store the raw conversation as summary
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
```

- [ ] **Step 3: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/brain_service.dart lib/core/constants/app_constants.dart
git commit -m "feat: add BrainService with energy/boredom/affection engine"
```

---

## Task 10: FaceController — Brain Integration (Mediator)

**Files:**
- Modify: `lib/features/face/face_controller.dart`

- [ ] **Step 1: Add BrainService dependency**

Update constructor:

```dart
final BrainService _brainService;

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
```

Add imports:

```dart
import '../../core/services/brain_service.dart';
import '../../core/enums/idle_behavior.dart';
import '../../core/enums/connection_state.dart';
```

- [ ] **Step 2: Add new state fields**

```dart
IdleBehavior _idleBehavior = IdleBehavior.normal;
LiveConnectionState _connectionState = LiveConnectionState.disconnected;
double _energy = 0.8;
double _boredom = 0.0;
double _affection = 0.3;
```

- [ ] **Step 3: Add getters**

```dart
IdleBehavior get idleBehavior => _idleBehavior;
LiveConnectionState get connectionState => _connectionState;
double get energy => _energy;
double get boredom => _boredom;
double get affection => _affection;
```

- [ ] **Step 4: Wire Brain callbacks in _init()**

Add after existing callback setup:

```dart
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

// Connection state
_liveService.onConnectionStateChange = (state) {
  _connectionState = state;
  notifyListeners();
};

// Text output → forward to brain for memory
_liveService.onTextOutput = (text) {
  _brainService.onTextReceived(text);
};
```

- [ ] **Step 5: Forward interaction events to Brain**

Modify existing `onListening` callback:

```dart
_liveService.onListening = () {
  _faceState = FaceState.listening;
  _brainService.onTurnEnd();
  notifyListeners();
};
_liveService.onSpeaking = () {
  _faceState = FaceState.speaking;
  _brainService.onInteraction();
  notifyListeners();
};
```

- [ ] **Step 6: Update sendTextMessage to notify Brain**

```dart
Future<void> sendTextMessage(String message) async {
  if (message.trim().isEmpty) return;
  _brainService.onUserTextSent(message);
  await _liveService.sendText(message);
}
```

- [ ] **Step 7: Start/stop Brain with activate/deactivate**

In `activate()`:
```dart
_brainService.start();
```

In `deactivate()`:
```dart
_brainService.stop();
```

- [ ] **Step 8: Add boost method**

```dart
void boostEnergy() {
  _brainService.boost();
}
```

- [ ] **Step 9: Update lifecycle handler**

In `didChangeAppLifecycleState`:
```dart
if (state == AppLifecycleState.paused) {
  _liveService.stop();
  _brainService.stop();
} else if (state == AppLifecycleState.resumed && _isActive) {
  _liveService.start();
  _brainService.start();
}
```

- [ ] **Step 10: Update dispose**

```dart
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _brainService.dispose();
  _liveService.stop();
  _liveService.dispose();
  super.dispose();
}
```

- [ ] **Step 11: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

Expected: Error about `BrainService` not being provided in `main.dart` — fixed in next task.

- [ ] **Step 12: Commit**

```bash
git add lib/features/face/face_controller.dart
git commit -m "feat: integrate BrainService into FaceController as mediator"
```

---

## Task 11: main.dart — Dependency Injection

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Update main() to create and inject new services**

```dart
import 'core/services/memory_service.dart';
import 'core/services/brain_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final liveService = LiveAudioService();
  final memoryService = MemoryService(storage: storageService);
  final brainService = BrainService(
    liveService: liveService,
    memoryService: memoryService,
    storageService: storageService,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => FaceController(
        liveService: liveService,
        brainService: brainService,
        storageService: storageService,
      ),
      child: const AiFaceApp(),
    ),
  );
}
```

- [ ] **Step 2: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire up BrainService and MemoryService in main.dart"
```

---

## Task 12: FaceScreen — Connection Status, Energy Bar, Status Messages

**Files:**
- Modify: `lib/features/face/face_screen.dart`

- [ ] **Step 1: Update _buildStateIndicator for new states**

Replace the existing `_buildStateIndicator` method body. Update the switch to include brain states and connection state:

```dart
Widget _buildStateIndicator(FaceController controller, Color moodColor) {
  String label = '';
  IconData? icon;

  // Connection error takes priority
  if (controller.connectionState == LiveConnectionState.error) {
    label = 'BAĞLANTI HATASI';
    icon = Icons.error_outline_rounded;
    return _buildStatusChip(label, icon, Colors.redAccent, isError: true,
        onTap: () => controller.resetChat());
  }
  if (controller.connectionState == LiveConnectionState.connecting ||
      controller.connectionState == LiveConnectionState.reconnecting) {
    label = 'BAĞLANIYOR...';
    icon = Icons.sync_rounded;
    return _buildStatusChip(label, icon, Colors.orangeAccent);
  }

  switch (controller.faceState) {
    case FaceState.idle:
      // Brain-aware idle messages
      if (controller.idleBehavior == IdleBehavior.sleeping) {
        label = 'zzZ...';
        icon = Icons.nightlight_round;
      } else if (controller.energy < 0.3) {
        label = 'uykulum...';
        icon = Icons.bedtime_rounded;
      } else if (controller.boredom > 0.5) {
        label = 'canım sıkılıyor...';
        icon = Icons.sentiment_dissatisfied_rounded;
      } else {
        final name = controller.wakeName.isEmpty ? 'Alexia' : controller.wakeName;
        label = '"Hey $name" de...';
        icon = Icons.hearing_rounded;
      }
      break;
    case FaceState.listening:
      label = 'DİNLİYORUM...';
      icon = Icons.mic_rounded;
      break;
    case FaceState.thinking:
      label = 'DÜŞÜNÜYORUM...';
      icon = Icons.psychology_rounded;
      break;
    case FaceState.speaking:
      label = 'KONUŞUYORUM...';
      icon = Icons.volume_up_rounded;
      break;
  }

  return _buildStatusRow(controller, label, icon!, moodColor);
}
```

- [ ] **Step 2: Extract status chip builder**

```dart
Widget _buildStatusChip(String label, IconData icon, Color color,
    {bool isError = false, VoidCallback? onTap}) {
  return Center(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: color,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
              ),
            ),
            Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: color, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w500,
            )),
            if (isError) ...[
              const SizedBox(width: 6),
              Text('(dokun)', style: TextStyle(
                color: color.withValues(alpha: 0.5), fontSize: 9,
              )),
            ],
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: Build status row with energy bar**

```dart
Widget _buildStatusRow(FaceController controller, String label, IconData icon, Color moodColor) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Existing status indicator (reuse _buildStatusChip logic)
        _buildStatusChip(label, icon,
          controller.faceState == FaceState.idle ? Colors.white.withValues(alpha: 0.5) : moodColor),
        const SizedBox(height: 6),
        // Energy bar
        GestureDetector(
          onTap: () => controller.boostEnergy(),
          child: Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: controller.energy.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: controller.energy > 0.5
                      ? moodColor.withValues(alpha: 0.6)
                      : controller.energy > 0.2
                          ? Colors.orangeAccent.withValues(alpha: 0.6)
                          : Colors.redAccent.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Add imports**

```dart
import '../../core/enums/idle_behavior.dart';
import '../../core/enums/connection_state.dart';
```

- [ ] **Step 5: Pass idleBehavior to RealisticEyeWidget**

In the eye widget instantiation:

```dart
RealisticEyeWidget(
  state: controller.faceState,
  mood: controller.currentMood,
  idleBehavior: controller.idleBehavior,
),
```

- [ ] **Step 6: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/face/face_screen.dart
git commit -m "feat: add connection status, energy bar, and brain-aware status messages"
```

---

## Task 13: Settings Screen — Brain Settings

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Add brain settings section**

Add a new section after the existing voice section. Read the current file first to understand the pattern, then add:

```dart
// --- BEYIN AYARLARI ---
_buildSectionTitle('BEYİN AYARLARI', moodColor),
const SizedBox(height: 8),

// Proaktif konuşma toggle
SwitchListTile(
  title: const Text('Proaktif Konuşma', style: TextStyle(color: Colors.white)),
  subtitle: Text('Alexia kendi kendine konuşsun',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
  value: controller.storageService.getProactiveSpeech(),
  activeColor: moodColor,
  onChanged: (v) async {
    await controller.storageService.setProactiveSpeech(v);
    setState(() {});
  },
),

// Uyku modu toggle
SwitchListTile(
  title: const Text('Uyku Modu', style: TextStyle(color: Colors.white)),
  subtitle: Text('Gece otomatik uyuklama',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
  value: controller.storageService.getSleepMode(),
  activeColor: moodColor,
  onChanged: (v) async {
    await controller.storageService.setSleepMode(v);
    setState(() {});
  },
),

// Hafıza toggle
SwitchListTile(
  title: const Text('Hafıza', style: TextStyle(color: Colors.white)),
  subtitle: Text('Konuşmaları hatırlasın',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
  value: controller.storageService.getMemoryEnabled(),
  activeColor: moodColor,
  onChanged: (v) async {
    await controller.storageService.setMemoryEnabled(v);
    setState(() {});
  },
),
```

Note: The settings screen needs access to `storageService` via the controller. Add a `StorageService get storageService => _storageService;` getter to `FaceController` if not already public.

- [ ] **Step 2: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/settings_screen.dart lib/features/face/face_controller.dart
git commit -m "feat: add brain settings (proactive speech, sleep mode, memory) to settings screen"
```

---

## Task 14: Memory Injection into System Prompt

**Files:**
- Modify: `lib/core/services/live_audio_service.dart`

- [ ] **Step 1: Add memory prompt setter**

Add to `LiveAudioService`:

```dart
String _memoryPrompt = '';
void updateMemoryPrompt(String p) => _memoryPrompt = p;
```

- [ ] **Step 2: Include in _buildSetup**

In `_buildSetup()`, modify the system instruction text:

```dart
'systemInstruction': {
  'parts': [
    {'text': '$_systemPrompt\n\n$wake\n\n$_memoryPrompt'}
  ],
},
```

- [ ] **Step 3: Wire it up in FaceController**

In `FaceController.activate()`, before `_liveService.start()`:

```dart
// Inject memories into system prompt
final memoryPrompt = _brainService.getMemoryPrompt();
_liveService.updateMemoryPrompt(memoryPrompt);
```

Add to `BrainService`:
```dart
String getMemoryPrompt() => _memoryService.getMemoriesForPrompt();
```

- [ ] **Step 4: Verify builds**

```bash
cd aiyardimci && flutter analyze 2>&1 | head -20
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/live_audio_service.dart lib/features/face/face_controller.dart lib/core/services/brain_service.dart
git commit -m "feat: inject conversation memories into system prompt on connection"
```

---

## Task 15: Final Integration Test

- [ ] **Step 1: Full analysis**

```bash
cd aiyardimci && flutter analyze
```

Expected: No errors. Warnings about unused imports are acceptable if from deleted services.

- [ ] **Step 2: Build APK to verify compilation**

```bash
cd aiyardimci && flutter build apk --debug 2>&1 | tail -20
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit any remaining fixes**

```bash
git add -A
git commit -m "fix: resolve any remaining analysis issues"
```
