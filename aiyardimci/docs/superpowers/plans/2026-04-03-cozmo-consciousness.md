# Cozmo Consciousness System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cozmo moduna özel, arka planda düşünen, kullanıcıyı tanıyan ve hafızası gerçek AI özetlemeyle çalışan bir bilinç katmanı eklemek.

**Architecture:** `CozmoConsciousnessService` bağımsız bir servis olarak çalışır; her 2,5 dakikada Gemini Flash REST API'ye "ne düşünüyorsun?" sorar ve üretilen düşünceyi Live API setup'ına enjekte eder. Tüm Gemini REST çağrıları CCS içinde toplanır; `UserModelService` ve `MemoryService` saf veri sınıfları olarak kalır. `FaceController` mediator rolünü üstlenir.

**Tech Stack:** Flutter/Dart, Gemini Flash REST API (`http` paketi), SharedPreferences, Provider

---

## Dosya Haritası

### Yeni dosyalar
| Dosya | Sorumluluk |
|---|---|
| `lib/core/models/inner_thought.dart` | InnerThought veri sınıfı + ThoughtDesire enum |
| `lib/core/models/user_model.dart` | UserModel veri sınıfı + JSON serialize + prompt özeti |
| `lib/core/services/user_model_service.dart` | UserModel yükleme, kaydetme, merge (HTTP yok) |
| `lib/core/services/cozmo_consciousness_service.dart` | Tüm bilinç mantığı + Gemini REST çağrıları |
| `test/core/models/inner_thought_test.dart` | InnerThought unit testleri |
| `test/core/models/user_model_test.dart` | UserModel unit testleri |

### Değişen dosyalar
| Dosya | Değişiklik |
|---|---|
| `lib/core/services/storage_service.dart` | `cozmo_mode`, `user_model` anahtarları |
| `lib/core/constants/app_constants.dart` | Consciousness prompt sabitleri |
| `lib/core/services/memory_service.dart` | `storeDirectMemory()`, `ccsActive` flag |
| `lib/core/services/live_audio_service.dart` | `setThoughtInjection()` + setup enjeksiyonu |
| `lib/core/services/brain_service.dart` | `ccsActive` flag, summarization delegation |
| `lib/features/face/face_controller.dart` | CCS lifecycle, `selectPreset()`, injection bridge |
| `lib/main.dart` | CCS ve UserModelService wire-up |
| `lib/features/settings/settings_screen.dart` | `selectPreset()` kullanımı + Cozmo modu rozeti |

---

## Task 1: InnerThought ve ThoughtDesire modelleri

**Files:**
- Create: `lib/core/models/inner_thought.dart`
- Create: `test/core/models/inner_thought_test.dart`

- [ ] **Adım 1: Test dosyasını yaz (fail olacak)**

```dart
// test/core/models/inner_thought_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiyardimci/core/models/inner_thought.dart';

void main() {
  group('ThoughtDesire', () {
    test('fromString geçerli değerleri parse eder', () {
      expect(ThoughtDesire.fromString('speak'), ThoughtDesire.speak);
      expect(ThoughtDesire.fromString('silent'), ThoughtDesire.silent);
      expect(ThoughtDesire.fromString('remember'), ThoughtDesire.remember);
    });

    test('fromString bilinmeyen değerde silent döner', () {
      expect(ThoughtDesire.fromString('unknown'), ThoughtDesire.silent);
      expect(ThoughtDesire.fromString(''), ThoughtDesire.silent);
    });
  });

  group('InnerThought', () {
    test('fromJson geçerli JSON parse eder', () {
      final json = {
        'content': 'Ahmet bugün sessiz',
        'desire': 'speak',
        'mood': 'curious',
      };
      final thought = InnerThought.fromJson(json);
      expect(thought.content, 'Ahmet bugün sessiz');
      expect(thought.desire, ThoughtDesire.speak);
      expect(thought.mood, 'curious');
    });

    test('fromJson eksik alanları default değerle doldurur', () {
      final thought = InnerThought.fromJson({'content': 'test'});
      expect(thought.desire, ThoughtDesire.silent);
      expect(thought.mood, 'calm');
    });

    test('fromRawJson JSON bloğunu string içinden çıkarır', () {
      const raw = 'İşte cevabım: {"content": "düşünce", "desire": "speak", "mood": "happy"} tamam';
      final thought = InnerThought.fromRawJson(raw);
      expect(thought, isNotNull);
      expect(thought!.content, 'düşünce');
    });

    test('fromRawJson JSON yoksa null döner', () {
      expect(InnerThought.fromRawJson('JSON yok burada'), isNull);
    });
  });
}
```

- [ ] **Adım 2: Testi çalıştır, fail olduğunu doğrula**

```bash
cd /home/emrah/Masaüstü/aıyardımcı/aiyardimci
flutter test test/core/models/inner_thought_test.dart
```

Beklenen: `Error: uri ... not found`

- [ ] **Adım 3: Modeli implement et**

```dart
// lib/core/models/inner_thought.dart
import 'dart:convert';

enum ThoughtDesire {
  speak,
  silent,
  remember;

  static ThoughtDesire fromString(String s) {
    return ThoughtDesire.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ThoughtDesire.silent,
    );
  }
}

class InnerThought {
  final String content;
  final ThoughtDesire desire;
  final String mood;
  final DateTime timestamp;

  InnerThought({
    required this.content,
    this.desire = ThoughtDesire.silent,
    this.mood = 'calm',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory InnerThought.fromJson(Map<String, dynamic> json) => InnerThought(
        content: json['content'] as String? ?? '',
        desire: ThoughtDesire.fromString(json['desire'] as String? ?? ''),
        mood: json['mood'] as String? ?? 'calm',
      );

  /// Ham Gemini yanıtından (JSON bloğu içerebilir) InnerThought parse eder.
  /// JSON bulunamazsa null döner.
  static InnerThought? fromRawJson(String raw) {
    try {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (match == null) return null;
      final decoded = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      return InnerThought.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Adım 4: Testi çalıştır, pass olduğunu doğrula**

```bash
flutter test test/core/models/inner_thought_test.dart
```

Beklenen: `All tests passed!`

- [ ] **Adım 5: Commit**

```bash
git add lib/core/models/inner_thought.dart test/core/models/inner_thought_test.dart
git commit -m "feat: add InnerThought model and ThoughtDesire enum"
```

---

## Task 2: UserModel veri sınıfı

**Files:**
- Create: `lib/core/models/user_model.dart`
- Create: `test/core/models/user_model_test.dart`

- [ ] **Adım 1: Test dosyasını yaz**

```dart
// test/core/models/user_model_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiyardimci/core/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('varsayılan değerlerle oluşturulur', () {
      final m = UserModel();
      expect(m.name, isNull);
      expect(m.interests, isEmpty);
      expect(m.facts, isEmpty);
      expect(m.relationshipLevel, 'yeni');
      expect(m.totalInteractions, 0);
    });

    test('toJson ve fromJson round-trip', () {
      final m = UserModel(
        name: 'Ahmet',
        interests: ['robotlar', 'müzik'],
        facts: ['sabah kahvesi içer'],
        relationshipLevel: 'arkadaş',
        totalInteractions: 25,
      );
      final json = m.toJson();
      final restored = UserModel.fromJson(json);
      expect(restored.name, 'Ahmet');
      expect(restored.interests, ['robotlar', 'müzik']);
      expect(restored.facts, ['sabah kahvesi içer']);
      expect(restored.relationshipLevel, 'arkadaş');
      expect(restored.totalInteractions, 25);
    });

    test('toPromptSummary isim yoksa uygun metin üretir', () {
      final m = UserModel(interests: ['oyunlar'], totalInteractions: 3);
      final summary = m.toPromptSummary();
      expect(summary, contains('oyunlar'));
      expect(summary, contains('yeni'));
    });

    test('toPromptSummary boş modelde kısa metin döner', () {
      final m = UserModel();
      expect(m.toPromptSummary(), isNotEmpty);
    });

    test('updateRelationshipLevel eşiğe göre güncellenir', () {
      final m = UserModel();
      m.totalInteractions = 4;
      m.updateRelationshipLevel();
      expect(m.relationshipLevel, 'yeni');

      m.totalInteractions = 10;
      m.updateRelationshipLevel();
      expect(m.relationshipLevel, 'tanışık');

      m.totalInteractions = 40;
      m.updateRelationshipLevel();
      expect(m.relationshipLevel, 'arkadaş');

      m.totalInteractions = 70;
      m.updateRelationshipLevel();
      expect(m.relationshipLevel, 'yakın');
    });
  });
}
```

- [ ] **Adım 2: Testi çalıştır, fail olduğunu doğrula**

```bash
flutter test test/core/models/user_model_test.dart
```

- [ ] **Adım 3: Modeli implement et**

```dart
// lib/core/models/user_model.dart

class UserModel {
  String? name;
  List<String> interests;
  List<String> facts;
  String relationshipLevel; // 'yeni' | 'tanışık' | 'arkadaş' | 'yakın'
  int totalInteractions;
  DateTime? firstMet;
  DateTime? lastSeen;

  UserModel({
    this.name,
    List<String>? interests,
    List<String>? facts,
    this.relationshipLevel = 'yeni',
    this.totalInteractions = 0,
    this.firstMet,
    this.lastSeen,
  })  : interests = interests ?? [],
        facts = facts ?? [];

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        name: json['name'] as String?,
        interests: (json['interests'] as List?)?.cast<String>() ?? [],
        facts: (json['facts'] as List?)?.cast<String>() ?? [],
        relationshipLevel: json['relationshipLevel'] as String? ?? 'yeni',
        totalInteractions: json['totalInteractions'] as int? ?? 0,
        firstMet: json['firstMet'] != null
            ? DateTime.tryParse(json['firstMet'] as String)
            : null,
        lastSeen: json['lastSeen'] != null
            ? DateTime.tryParse(json['lastSeen'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'interests': interests,
        'facts': facts,
        'relationshipLevel': relationshipLevel,
        'totalInteractions': totalInteractions,
        'firstMet': firstMet?.toIso8601String(),
        'lastSeen': lastSeen?.toIso8601String(),
      };

  void updateRelationshipLevel() {
    if (totalInteractions < 5) {
      relationshipLevel = 'yeni';
    } else if (totalInteractions < 20) {
      relationshipLevel = 'tanışık';
    } else if (totalInteractions < 60) {
      relationshipLevel = 'arkadaş';
    } else {
      relationshipLevel = 'yakın';
    }
  }

  String toPromptSummary() {
    final parts = <String>[];
    if (name != null) parts.add('İsim: $name');
    if (interests.isNotEmpty) {
      parts.add('İlgi alanları: ${interests.take(10).join(', ')}');
    }
    if (facts.isNotEmpty) {
      parts.add('Bilinen gerçekler: ${facts.take(10).join('; ')}');
    }
    parts.add('İlişki: $relationshipLevel ($totalInteractions etkileşim)');
    return parts.join('\n');
  }
}
```

- [ ] **Adım 4: Testi çalıştır, pass olduğunu doğrula**

```bash
flutter test test/core/models/user_model_test.dart
```

- [ ] **Adım 5: Commit**

```bash
git add lib/core/models/user_model.dart test/core/models/user_model_test.dart
git commit -m "feat: add UserModel data class"
```

---

## Task 3: StorageService — yeni anahtarlar

**Files:**
- Modify: `lib/core/services/storage_service.dart`

- [ ] **Adım 1: Storage anahtarlarını ekle**

`lib/core/services/storage_service.dart` dosyasının sonundaki `getLastSessionTimestamp` bloğunun altına ekle:

```dart
  // ─── Cozmo Consciousness ─────────────────────────────────────────────────

  bool getCozmoMode() => _prefs.getBool('cozmo_mode') ?? false;
  Future<void> setCozmoMode(bool v) => _prefs.setBool('cozmo_mode', v);

  String getUserModel() => _prefs.getString('user_model') ?? '{}';
  Future<void> setUserModel(String json) =>
      _prefs.setString('user_model', json);
```

- [ ] **Adım 2: Analyze et**

```bash
flutter analyze lib/core/services/storage_service.dart
```

Beklenen: `No issues found`

- [ ] **Adım 3: Commit**

```bash
git add lib/core/services/storage_service.dart
git commit -m "feat: add cozmo_mode and user_model storage keys"
```

---

## Task 4: AppConstants — consciousness prompt sabitleri

**Files:**
- Modify: `lib/core/constants/app_constants.dart`

- [ ] **Adım 1: Prompt sabitlerini ekle**

`lib/core/constants/app_constants.dart` içindeki `AppConstants` class'ının kapanış `}` satırından önce ekle:

```dart
  // ─── Consciousness Prompts ────────────────────────────────────────────────

  static const String consciousnessThinkingPrompt = '''
Sen Cozmo robotsun. Şu anki iç dünyan:
Enerji: {energy}
Sıkılma: {boredom}
Sevgi: {affection}
Saat: {time}
Gün: {day}

Hakkında bildiklerin:
{user_summary}

Son anılar:
{memories}

Bu durumda aklından ne geçiyor? Tamamen Cozmo karakterinde 1-2 cümle düşün.
Yanıtı SADECE JSON olarak ver, başka hiçbir şey ekleme:
{"content": "aklından geçen düşünce", "desire": "speak veya silent veya remember", "mood": "happy veya sad veya angry veya calm veya excited veya curious"}
desire: speak=sesli söylemek istiyorsun, silent=içinde tutuyorsun ama konuşmana renk katar, remember=bunu kaydetmek istiyorsun''';

  static const String memoryAISummaryPrompt = '''
Aşağıdaki konuşmayı Cozmo robotun bakış açısıyla 1-2 cümleyle özetle.
Önemli kullanıcı bilgilerini [user_fact: bilgi] formatında işaretle.
Özet kısa ve Cozmo'nun kişiliğine uygun olsun.

Konuşma:
{conversation}

Kullanıcı hakkında zaten bilinenler:
{user_summary}

SADECE özet metnini yaz, JSON değil.''';

  static const String userModelExtractionPrompt = '''
Aşağıdaki konuşmadan kullanıcı hakkında NET olarak öğrenilen YENİ bilgiler neler?
Tahmin etme, sadece açıkça söylenenleri çıkar.
Yanıtı SADECE JSON olarak ver:
{"name": "varsa isim string, yoksa null", "new_interests": ["yeni ilgi alanları"], "new_facts": ["yeni gerçekler"]}

Konuşma:
{conversation}''';

  static const String thoughtInjectionTemplate =
      '\n\n=== COZMO\'NUN ANLIQ İÇ SESİ ===\n'
      'Şu an aklından geçen: "{thought}"\n'
      'Bunu konuşmana doğal olarak yansıt — ama kelimesi kelimesine tekrar etme.\n';
```

- [ ] **Adım 2: Analyze et**

```bash
flutter analyze lib/core/constants/app_constants.dart
```

- [ ] **Adım 3: Commit**

```bash
git add lib/core/constants/app_constants.dart
git commit -m "feat: add consciousness prompt constants"
```

---

## Task 5: UserModelService

**Files:**
- Create: `lib/core/services/user_model_service.dart`

- [ ] **Adım 1: Servisi implement et**

```dart
// lib/core/services/user_model_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

/// Kullanıcı modelini yükler, kaydeder ve merge eder.
/// HTTP çağrısı yapmaz — tüm AI çağrıları CozmoConsciousnessService içinde.
class UserModelService {
  final StorageService _storage;
  UserModel _model = UserModel();

  UserModelService({required StorageService storage}) : _storage = storage {
    _load();
  }

  UserModel get model => _model;

  // ─── Yükleme / Kaydetme ──────────────────────────────────────────────────

  void _load() {
    try {
      final json = _storage.getUserModel();
      if (json == '{}' || json.isEmpty) return;
      _model = UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
      debugPrint('[USER_MODEL] yüklendi: ${_model.name}, '
          '${_model.totalInteractions} etkileşim');
    } catch (e) {
      debugPrint('[USER_MODEL] yükleme hatası, sıfırdan başlıyor: $e');
      _model = UserModel();
    }
  }

  Future<void> save() async {
    try {
      await _storage.setUserModel(jsonEncode(_model.toJson()));
    } catch (e) {
      debugPrint('[USER_MODEL] kayıt hatası: $e');
    }
  }

  // ─── Etkileşim kaydı ────────────────────────────────────────────────────

  Future<void> recordInteraction() async {
    _model.totalInteractions++;
    _model.lastSeen = DateTime.now();
    _model.firstMet ??= DateTime.now();
    _model.updateRelationshipLevel();
    await save();
  }

  // ─── Merge (CCS tarafından çağrılır) ────────────────────────────────────

  /// CCS'in Gemini'den parse ettiği sonucu modele merge eder.
  Future<void> mergeExtraction({
    String? name,
    List<String> newInterests = const [],
    List<String> newFacts = const [],
  }) async {
    bool changed = false;

    if (name != null && name.isNotEmpty && _model.name == null) {
      _model.name = name;
      changed = true;
    }
    for (final i in newInterests) {
      if (i.isNotEmpty && !_model.interests.contains(i)) {
        _model.interests.add(i);
        changed = true;
      }
    }
    for (final f in newFacts) {
      if (f.isNotEmpty && !_model.facts.contains(f)) {
        _model.facts.add(f);
        changed = true;
      }
    }

    // Listeleri sınırlı tut
    if (_model.interests.length > 20) {
      _model.interests = _model.interests.sublist(_model.interests.length - 20);
    }
    if (_model.facts.length > 30) {
      _model.facts = _model.facts.sublist(_model.facts.length - 30);
    }

    if (changed) {
      await save();
      debugPrint('[USER_MODEL] güncellendi: isim=${_model.name}, '
          'ilgiler=${_model.interests.length}, gerçekler=${_model.facts.length}');
    }
  }

  /// Hafıza özetinden [user_fact: ...] etiketlerini parse ederek merge eder.
  Future<void> mergeFactsFromSummary(String summary) async {
    final matches = RegExp(r'\[user_fact:\s*([^\]]+)\]').allMatches(summary);
    final facts = matches.map((m) => m.group(1)!.trim()).toList();
    if (facts.isNotEmpty) {
      await mergeExtraction(newFacts: facts);
    }
  }
}
```

- [ ] **Adım 2: Analyze et**

```bash
flutter analyze lib/core/services/user_model_service.dart
```

- [ ] **Adım 3: Commit**

```bash
git add lib/core/services/user_model_service.dart
git commit -m "feat: add UserModelService"
```

---

## Task 6: MemoryService — storeDirectMemory + ccsActive flag

**Files:**
- Modify: `lib/core/services/memory_service.dart`

- [ ] **Adım 1: `ccsActive` flag ve `storeDirectMemory` ekle**

`lib/core/services/memory_service.dart` içinde `bool get isEnabled` satırının üstüne ekle:

```dart
  /// CCS aktifse BrainService summarize işlemini atlar.
  bool ccsActive = false;
```

`clearMemories()` metodunun altına ekle:

```dart
  /// CCS tarafından doğrudan hafıza kaydetmek için kullanılır.
  Future<void> storeDirectMemory(String content, String mood) async {
    await storeSummary(content, mood);
  }

  /// Özetleme yapılıp yapılmayacağını kontrol eder ve counter'ı sıfırlar.
  /// true dönerse caller summarize etmeli. İkinci caller false alır (double-fire yok).
  bool claimSummarization() {
    if (!shouldSummarize()) return false;
    _turnCount = 0; // Counter'ı sıfırla — sadece bir caller summarize eder
    return true;
  }
```

- [ ] **Adım 2: Analyze et**

```bash
flutter analyze lib/core/services/memory_service.dart
```

- [ ] **Adım 3: Commit**

```bash
git add lib/core/services/memory_service.dart
git commit -m "feat: add ccsActive flag and storeDirectMemory to MemoryService"
```

---

## Task 7: LiveAudioService — düşünce enjeksiyonu

**Files:**
- Modify: `lib/core/services/live_audio_service.dart`

- [ ] **Adım 1: `_thoughtInjection` field ve setter ekle**

`live_audio_service.dart` içinde `// ─── Ayarlar` bölümündeki son field'dan (`String _memoryPrompt = '';`) sonra ekle:

```dart
  String _thoughtInjection = '';
```

`updateMemoryPrompt` metodunun altına ekle:

```dart
  void setThoughtInjection(String thought) => _thoughtInjection = thought;
```

- [ ] **Adım 2: `_buildSetup` içinde enjeksiyonu ekle**

`_buildSetup()` metodundaki mevcut system instruction text'ini değiştir.

Eski:
```dart
            {'text': '${AppConstants.hiddenSystemRules.join('\n')}\n\n$_systemPrompt\n\n$wake${_memoryPrompt.isNotEmpty ? '\n\n$_memoryPrompt' : ''}'}
```

Yeni:
```dart
            {
              'text': '${AppConstants.hiddenSystemRules.join('\n')}\n\n'
                  '$_systemPrompt\n\n'
                  '$wake'
                  '${_thoughtInjection.isNotEmpty ? AppConstants.thoughtInjectionTemplate.replaceAll('{thought}', _thoughtInjection) : ''}'
                  '${_memoryPrompt.isNotEmpty ? '\n\n$_memoryPrompt' : ''}'
            }
```

- [ ] **Adım 3: Analyze et**

```bash
flutter analyze lib/core/services/live_audio_service.dart
```

- [ ] **Adım 4: Commit**

```bash
git add lib/core/services/live_audio_service.dart
git commit -m "feat: add thought injection to LiveAudioService setup"
```

---

## Task 8: CozmoConsciousnessService

**Files:**
- Create: `lib/core/services/cozmo_consciousness_service.dart`

- [ ] **Adım 1: Servisi oluştur**

```dart
// lib/core/services/cozmo_consciousness_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/inner_thought.dart';
import 'live_audio_service.dart';
import 'memory_service.dart';
import 'storage_service.dart';
import 'user_model_service.dart';

class CozmoConsciousnessService {
  final LiveAudioService _liveService;
  final MemoryService _memoryService;
  final StorageService _storageService;
  final UserModelService _userModelService;

  Timer? _thinkingTimer;
  bool _active = false;
  InnerThought? _currentThought;

  // Tur takibi (UserModel extraction için)
  final List<String> _recentTexts = [];
  int _extractionTurnCount = 0;
  static const _extractionInterval = 5;

  // Thinking loop aralığı: 120–180 saniye (rastgele jitter)
  static const _minThinkSec = 120;
  static const _maxThinkSec = 180;

  CozmoConsciousnessService({
    required LiveAudioService liveService,
    required MemoryService memoryService,
    required StorageService storageService,
    required UserModelService userModelService,
  })  : _liveService = liveService,
        _memoryService = memoryService,
        _storageService = storageService,
        _userModelService = userModelService;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  void start() {
    if (_active) return;
    _active = true;
    _memoryService.ccsActive = true;
    _scheduleNextThink();
    debugPrint('[CCS] başlatıldı');
  }

  void stop() {
    _active = false;
    _memoryService.ccsActive = false;
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    _currentThought = null;
    debugPrint('[CCS] durduruldu');
  }

  void dispose() => stop();

  // ─── Olaylar (FaceController tarafından çağrılır) ────────────────────────

  void onInteraction() {
    _userModelService.recordInteraction();
  }

  void onTextReceived(String text) {
    final clean = text.replaceAll(RegExp(r'\[mood:\s*\w+\]'), '').trim();
    if (clean.isNotEmpty) _recentTexts.add('Cozmo: $clean');
  }

  void onUserTextSent(String text) {
    if (text.isNotEmpty) _recentTexts.add('Kullanıcı: $text');
    _extractionTurnCount++;
    if (_extractionTurnCount >= _extractionInterval) {
      _extractionTurnCount = 0;
      _runUserModelExtraction();
    }
  }

  void onTurnEnd() {
    if (_memoryService.claimSummarization()) {
      _runMemorySummarization();
    }
  }

  /// LiveAudioService.setThoughtInjection() için mevcut düşünceyi döner.
  String getThoughtInjection() {
    final t = _currentThought;
    if (t == null) return '';
    // 10 dakikadan eski düşünceleri temizle
    if (DateTime.now().difference(t.timestamp).inMinutes > 10) {
      _currentThought = null;
      return '';
    }
    return t.content;
  }

  // ─── Thinking Loop ───────────────────────────────────────────────────────

  void _scheduleNextThink() {
    if (!_active) return;
    final seconds =
        _minThinkSec + Random().nextInt(_maxThinkSec - _minThinkSec);
    _thinkingTimer = Timer(Duration(seconds: seconds), _think);
  }

  Future<void> _think() async {
    if (!_active) return;
    debugPrint('[CCS] düşünüyor...');

    final thought = await _generateThought();
    if (thought != null && _active) {
      _currentThought = thought;
      await _processThought(thought);
    }

    _scheduleNextThink();
  }

  Future<InnerThought?> _generateThought() async {
    final apiKey = _storageService.getApiKey();
    if (apiKey.isEmpty) return null;

    final now = DateTime.now();
    final memories = _memoryService.getMemoriesForPrompt(count: 3);

    final prompt = AppConstants.consciousnessThinkingPrompt
        .replaceAll('{energy}', _formatLevel(_storageService))
        .replaceAll('{boredom}', _formatBoredom(_storageService))
        .replaceAll('{affection}', _formatAffection(_storageService))
        .replaceAll('{time}', '${now.hour}:${now.minute.toString().padLeft(2, '0')}')
        .replaceAll('{day}', _dayName(now.weekday))
        .replaceAll('{user_summary}', _userModelService.model.toPromptSummary())
        .replaceAll('{memories}', memories.isEmpty ? 'Henüz anı yok.' : memories);

    final raw = await _callGeminiFlash(prompt, apiKey);
    if (raw == null) return null;

    final thought = InnerThought.fromRawJson(raw);
    debugPrint('[CCS] düşünce: ${thought?.content} (${thought?.desire.name})');
    return thought;
  }

  Future<void> _processThought(InnerThought thought) async {
    switch (thought.desire) {
      case ThoughtDesire.speak:
        if (_liveService.onListening != null) {
          // Sadece aktif dinleme modundaysa konuş
          debugPrint('[CCS] düşünceyi sesli söylüyor');
          await _liveService.sendText(thought.content);
        }
      case ThoughtDesire.silent:
        // _currentThought zaten set edildi, injection'a hazır
        debugPrint('[CCS] düşünce içerde tutuldu');
      case ThoughtDesire.remember:
        await _memoryService.storeDirectMemory(thought.content, thought.mood);
        debugPrint('[CCS] düşünce hafızaya yazıldı');
    }
  }

  // ─── Hafıza AI Özetleme ──────────────────────────────────────────────────

  Future<void> _runMemorySummarization() async {
    final apiKey = _storageService.getApiKey();
    if (apiKey.isEmpty) return;

    final conversation = _memoryService.getConversationForSummary();
    if (conversation.isEmpty) return;

    final prompt = AppConstants.memoryAISummaryPrompt
        .replaceAll('{conversation}', conversation)
        .replaceAll('{user_summary}', _userModelService.model.toPromptSummary());

    final raw = await _callGeminiFlash(prompt, apiKey, maxTokens: 200);
    if (raw == null) {
      // Fallback: basit kırpma
      final fallback = conversation.length > 150
          ? '${conversation.substring(0, 150)}...'
          : conversation;
      await _memoryService.storeSummary(fallback, 'calm');
      return;
    }

    // [user_fact: ...] etiketlerini UserModel'e merge et
    await _userModelService.mergeFactsFromSummary(raw);

    // Etiketleri temizle, özeti kaydet
    final clean = raw.replaceAll(RegExp(r'\[user_fact:[^\]]*\]'), '').trim();
    await _memoryService.storeSummary(clean, 'calm');
    debugPrint('[CCS] hafıza özeti: $clean');
  }

  // ─── UserModel Extraction ────────────────────────────────────────────────

  Future<void> _runUserModelExtraction() async {
    final apiKey = _storageService.getApiKey();
    if (apiKey.isEmpty || _recentTexts.isEmpty) return;

    final conversation = _recentTexts.join('\n');
    _recentTexts.clear();

    final prompt = AppConstants.userModelExtractionPrompt
        .replaceAll('{conversation}', conversation);

    final raw = await _callGeminiFlash(prompt, apiKey, maxTokens: 150);
    if (raw == null) return;

    try {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (match == null) return;
      final data = jsonDecode(match.group(0)!) as Map<String, dynamic>;

      await _userModelService.mergeExtraction(
        name: data['name'] as String?,
        newInterests: (data['new_interests'] as List?)?.cast<String>() ?? [],
        newFacts: (data['new_facts'] as List?)?.cast<String>() ?? [],
      );
    } catch (e) {
      debugPrint('[CCS] userModel extraction parse hatası: $e');
    }
  }

  // ─── Gemini REST Helper ──────────────────────────────────────────────────

  Future<String?> _callGeminiFlash(String prompt, String apiKey,
      {int maxTokens = 256}) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-2.0-flash:generateContent?key=$apiKey',
      );
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': maxTokens,
        },
      });

      final resp = await http
          .post(url,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        debugPrint('[CCS] Gemini REST HTTP ${resp.statusCode}');
        return null;
      }

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      return decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
    } catch (e) {
      debugPrint('[CCS] Gemini REST hatası: $e');
      return null;
    }
  }

  // ─── Yardımcılar ─────────────────────────────────────────────────────────

  String _formatLevel(StorageService s) {
    // BrainState'e erişim yok; storageService üzerinden brain state oku
    try {
      final json = jsonDecode(s.getBrainState()) as Map<String, dynamic>;
      final v = (json['energy'] as num?)?.toDouble() ?? 0.7;
      if (v > 0.7) return 'yüksek';
      if (v > 0.4) return 'orta';
      return 'düşük';
    } catch (_) {
      return 'orta';
    }
  }

  String _formatBoredom(StorageService s) {
    try {
      final json = jsonDecode(s.getBrainState()) as Map<String, dynamic>;
      final v = (json['boredom'] as num?)?.toDouble() ?? 0.0;
      if (v > 0.6) return 'çok sıkılmış';
      if (v > 0.3) return 'biraz sıkılmış';
      return 'meşgul';
    } catch (_) {
      return 'normal';
    }
  }

  String _formatAffection(StorageService s) {
    try {
      final json = jsonDecode(s.getBrainState()) as Map<String, dynamic>;
      final v = (json['affection'] as num?)?.toDouble() ?? 0.3;
      if (v > 0.6) return 'çok sevgi dolu';
      if (v > 0.3) return 'sıcak';
      return 'mesafeli';
    } catch (_) {
      return 'normal';
    }
  }

  String _dayName(int weekday) {
    const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return days[(weekday - 1).clamp(0, 6)];
  }
}
```

- [ ] **Adım 2: Analyze et**

```bash
flutter analyze lib/core/services/cozmo_consciousness_service.dart
```

- [ ] **Adım 3: Commit**

```bash
git add lib/core/services/cozmo_consciousness_service.dart
git commit -m "feat: add CozmoConsciousnessService"
```

---

## Task 9: BrainService — summarization delegation düzeltmesi

**Files:**
- Modify: `lib/core/services/brain_service.dart`

- [ ] **Adım 1: `onTurnEnd` içinde CCS check ekle**

`brain_service.dart` dosyasında `onTurnEnd` metodunu değiştir:

Eski:
```dart
  void onTurnEnd() {
    if (_memoryService.isEnabled && _memoryService.shouldSummarize()) {
      _triggerMemorySummary();
    }
  }
```

Yeni:
```dart
  void onTurnEnd() {
    // CCS aktifse summarization'ı CCS üstlenir (CCS.onTurnEnd içinde claimSummarization çağrılır)
    if (_memoryService.isEnabled && !_memoryService.ccsActive) {
      if (_memoryService.claimSummarization()) {
        _triggerMemorySummary();
      }
    }
  }
```

- [ ] **Adım 2: Analyze et**

```bash
flutter analyze lib/core/services/brain_service.dart
```

- [ ] **Adım 3: Commit**

```bash
git add lib/core/services/brain_service.dart
git commit -m "fix: delegate memory summarization to CCS when active"
```

---

## Task 10: FaceController — CCS lifecycle + injection bridge + selectPreset

**Files:**
- Modify: `lib/features/face/face_controller.dart`

- [ ] **Adım 1: CCS import ve field ekle**

`face_controller.dart` import bloğuna ekle:

```dart
import '../../core/services/cozmo_consciousness_service.dart';
import '../../core/services/user_model_service.dart';
```

Constructor parametreleri ve field'ları güncelle.

Eski constructor:
```dart
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

Yeni — field'ları ve constructor'ı değiştir:

```dart
  // Mevcut field'ların altına ekle:
  CozmoConsciousnessService? _ccs;
  final UserModelService _userModelService;
```

```dart
  FaceController({
    required LiveAudioService liveService,
    required BrainService brainService,
    required StorageService storageService,
    required UserModelService userModelService,
    required CozmoConsciousnessService ccs,
  })  : _liveService = liveService,
        _brainService = brainService,
        _storageService = storageService,
        _userModelService = userModelService,
        _ccs = ccs {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }
```

- [ ] **Adım 2: `_init` içinde CCS callback'lerini bağla**

`_init()` metodunun sonuna (son `}` satırından önce) ekle:

```dart
    // CCS callbacks
    _liveService.onTextOutput = (text) {
      if (_disposed) return;
      _brainService.onTextReceived(text);
      _ccs?.onTextReceived(text);
    };
```

Not: mevcut `onTextOutput` callback'i sadece `_brainService.onTextReceived(text)` çağırıyor. Bunu yukarıdaki ile değiştir (override et, duplike etme).

`onListening` callback'ini de güncelle — CCS.onTurnEnd() ekle:

Eski:
```dart
    _liveService.onListening = () {
      if (_disposed) return;
      _faceState = FaceState.listening;
      _brainService.onTurnEnd();
      _safeNotify();
    };
```

Yeni:
```dart
    _liveService.onListening = () {
      if (_disposed) return;
      _faceState = FaceState.listening;
      _brainService.onTurnEnd();
      _ccs?.onTurnEnd();
      _safeNotify();
    };
```

`onSpeaking` callback'ini de güncelle — CCS.onInteraction() ekle:

Eski:
```dart
    _liveService.onSpeaking = () {
      if (_disposed) return;
      _faceState = FaceState.speaking;
      _brainService.onInteraction();
      _safeNotify();
    };
```

Yeni:
```dart
    _liveService.onSpeaking = () {
      if (_disposed) return;
      _faceState = FaceState.speaking;
      _brainService.onInteraction();
      _ccs?.onInteraction();
      _safeNotify();
    };
```

- [ ] **Adım 3: `_startLive` helper metodu ekle**

`activate()` metodunun üstüne yeni private metod ekle:

```dart
  /// Live servisini başlatmadan önce düşünce enjeksiyonunu günceller.
  Future<void> _startLive() async {
    _liveService.setThoughtInjection(_ccs?.getThoughtInjection() ?? '');
    await _liveService.start();
  }
```

`activate()` metodunda `await _liveService.start()` → `await _startLive()` olarak değiştir.

Ayrıca `updateSystemPrompt`, `updateApiKey`, `updateWakeName`, `updateVoiceGender`, `resetChat` içindeki tüm `_liveService.start()` çağrılarını `_startLive()` ile değiştir.

- [ ] **Adım 4: `activate()` / `deactivate()` içinde CCS lifecycle**

`activate()` metodunu güncelle:

Eski:
```dart
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
```

Yeni:
```dart
  Future<void> activate() async {
    _isActive = true;
    _safeNotify();
    final hasPermission = await _liveService.init();
    if (hasPermission) {
      final memoryPrompt = _brainService.getMemoryPrompt();
      _liveService.updateMemoryPrompt(memoryPrompt);
      if (_storageService.getCozmoMode()) _ccs?.start();
      await _startLive();
      _brainService.start();
    }
    debugPrint('[FLOW] activated - live audio + brain + ${_storageService.getCozmoMode() ? "CCS" : "no CCS"}');
  }
```

`deactivate()` metodunu güncelle:

Eski:
```dart
  Future<void> deactivate() async {
    _isActive = false;
    _brainService.stop();
    await _liveService.stop();
    _faceState = FaceState.idle;
    _safeNotify();
  }
```

Yeni:
```dart
  Future<void> deactivate() async {
    _isActive = false;
    _ccs?.stop();
    _brainService.stop();
    await _liveService.stop();
    _faceState = FaceState.idle;
    _safeNotify();
  }
```

- [ ] **Adım 5: `sendTextMessage` içinde CCS'e haber ver**

Eski:
```dart
  Future<void> sendTextMessage(String message) async {
    if (message.trim().isEmpty) return;
    _brainService.onUserTextSent(message);
    await _liveService.sendText(message);
  }
```

Yeni:
```dart
  Future<void> sendTextMessage(String message) async {
    if (message.trim().isEmpty) return;
    _brainService.onUserTextSent(message);
    _ccs?.onUserTextSent(message);
    await _liveService.sendText(message);
  }
```

- [ ] **Adım 6: `selectPreset` metodu ekle**

`resetChat()` metodunun altına ekle:

```dart
  Future<void> selectPreset(String presetName, String prompt) async {
    final isCozmo = presetName == 'Cozmo';
    await _storageService.setCozmoMode(isCozmo);

    if (isCozmo && _isActive && _ccs != null && !(_ccs!.isActive)) {
      _ccs!.start();
    } else if (!isCozmo) {
      _ccs?.stop();
    }

    await updateSystemPrompt(prompt);
  }
```

Not: `CozmoConsciousnessService` içine `bool get isActive => _active;` getter eklemek gerekiyor (bir sonraki adımda).

- [ ] **Adım 7: `dispose` içinde CCS temizliği**

`dispose()` metodunda `_brainService.onStateChange = null;` satırının altına ekle:

```dart
    _ccs?.stop();
    _ccs = null;
```

Ve `unawaited(_liveService.dispose())` satırından önce.

- [ ] **Adım 8: CozmoConsciousnessService'e isActive getter ekle**

`lib/core/services/cozmo_consciousness_service.dart` içindeki `dispose()` metodunun üstüne ekle:

```dart
  bool get isActive => _active;
```

- [ ] **Adım 9: Analyze et**

```bash
flutter analyze lib/features/face/face_controller.dart lib/core/services/cozmo_consciousness_service.dart
```

- [ ] **Adım 10: Commit**

```bash
git add lib/features/face/face_controller.dart lib/core/services/cozmo_consciousness_service.dart
git commit -m "feat: integrate CCS lifecycle into FaceController"
```

---

## Task 11: main.dart — wire-up

**Files:**
- Modify: `lib/main.dart`

- [ ] **Adım 1: main.dart'ı güncelle**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/live_audio_service.dart';
import 'core/services/brain_service.dart';
import 'core/services/memory_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/user_model_service.dart';
import 'core/services/cozmo_consciousness_service.dart';
import 'features/face/face_controller.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final liveService = LiveAudioService();
  final memoryService = MemoryService(storage: storageService);
  final userModelService = UserModelService(storage: storageService);
  final brainService = BrainService(
    liveService: liveService,
    memoryService: memoryService,
    storageService: storageService,
  );
  final ccs = CozmoConsciousnessService(
    liveService: liveService,
    memoryService: memoryService,
    storageService: storageService,
    userModelService: userModelService,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => FaceController(
        liveService: liveService,
        brainService: brainService,
        storageService: storageService,
        userModelService: userModelService,
        ccs: ccs,
      ),
      child: const AiFaceApp(),
    ),
  );
}
```

- [ ] **Adım 2: Analyze et**

```bash
flutter analyze lib/main.dart
```

- [ ] **Adım 3: Tam proje analyze**

```bash
flutter analyze
```

Beklenen: `No issues found`

- [ ] **Adım 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire up CCS and UserModelService in main.dart"
```

---

## Task 12: Settings — selectPreset entegrasyonu + Cozmo modu rozeti

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`

- [ ] **Adım 1: `_buildPresetList` içinde `selectPreset` kullan**

`settings_screen.dart` dosyasında `_buildPresetList` metodundaki `onTap` callback'ini değiştir:

Eski:
```dart
          onTap: () {
            final prompt = entry.value.join(' ');
            _promptController.text = prompt;
            controller.updateSystemPrompt(prompt);
          },
```

Yeni:
```dart
          onTap: () {
            final prompt = entry.value.join(' ');
            _promptController.text = prompt;
            controller.selectPreset(entry.key, prompt);
          },
```

- [ ] **Adım 2: Cozmo preset kartına rozet ekle**

`_buildPresetList` içindeki `Text(entry.key, ...)` satırını Cozmo için rozet ile değiştir:

```dart
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.key,
                  style: TextStyle(
                    color: isActive ? moodColor : Colors.white70,
                    fontSize: 13,
                  ),
                ),
                if (entry.key == 'Cozmo') ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: moodColor.withValues(alpha: 0.2),
                    ),
                    child: Text(
                      'BİLİNÇLİ',
                      style: TextStyle(
                        color: moodColor,
                        fontSize: 7,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
```

- [ ] **Adım 3: Analyze et**

```bash
flutter analyze lib/features/settings/settings_screen.dart
```

- [ ] **Adım 4: Tam proje final analyze**

```bash
flutter analyze
```

Beklenen: `No issues found`

- [ ] **Adım 5: Tüm testleri çalıştır**

```bash
flutter test
```

Beklenen: `All tests passed!`

- [ ] **Adım 6: Final commit**

```bash
git add lib/features/settings/settings_screen.dart
git commit -m "feat: integrate selectPreset in settings + Cozmo mode badge"
```

---

## Self-Review Notları

**Spec coverage kontrolü:**
- ✅ CozmoConsciousnessService — Task 8
- ✅ ThinkingEngine (Gemini Flash REST, her 2.5 dk) — Task 8
- ✅ UserModelService (isim, ilgiler, gerçekler, ilişki) — Task 5
- ✅ AI hafıza özetleme — Task 8 + Task 6
- ✅ Düşünce enjeksiyonu — Task 7 + Task 10
- ✅ Cozmo modu ayrımı — Task 3 + Task 10 + Task 12
- ✅ Seçici hafıza yükleme (son 3 özet) — Task 8 (`getMemoriesForPrompt(count: 3)`)
- ✅ Token ekonomisi (Gemini Flash, küçük promptlar) — Task 8
- ✅ FaceController mediator rolü — Task 10
- ✅ main.dart wire-up — Task 11

**Önemli notlar implementasyon sırasında:**
- `FaceController._init()` içinde mevcut `onTextOutput` callback'i Task 10 Adım 2'de override edilecek — duplike oluşmaması için eski satırı sil
- `didChangeAppLifecycleState` içinde `_liveService.start()` çağrısı da `_startLive()` olarak güncellenmeli (Task 10 kapsıyor)
- `resetChat()` içindeki `_liveService.stop().then((_) => _liveService.start())` → `_liveService.stop().then((_) => _startLive())` olmalı
