# Cozmo Consciousness System — Design Spec

**Date:** 2026-04-03  
**Status:** Approved  
**Scope:** Cozmo moduna özel bilinçli davranış katmanı

---

## Özet

Cozmo modunu diğer preset'lerden tamamen ayıran, gerçek bir "iç ses" ve kalıcı kullanıcı modeli içeren `CozmoConsciousnessService` eklenir. Diğer modlar bu servisten habersiz çalışmaya devam eder.

---

## Mimari

```
FaceController
    ├── LiveAudioService              (değişmez)
    ├── BrainService                  (değişmez)
    ├── MemoryService                 (AI özetleme eklenir)
    └── CozmoConsciousnessService     ← YENİ
            ├── ThinkingEngine        (Gemini Flash REST)
            └── UserModelService      (kullanıcı tanıma)
```

### Cozmo modu aktifleşme kuralı

`StorageService`'de `cozmo_mode: bool` anahtarı tutulur. Ayarlar ekranında "Cozmo" preset seçilince `true` yazılır, başka bir preset seçilince `false`. `FaceController`, `activate()` içinde bu değeri okur; `true`ysa `CozmoConsciousnessService.start()` çağrılır.

---

## CozmoConsciousnessService

### Sorumluluklar

1. **Thinking loop:** Her 2,5 dakikada Gemini Flash'a "ne düşünüyorsun?" sorar
2. **Düşünce işleme:** Gelen düşünceye göre konuş / sessiz kal / hatırla
3. **Düşünce enjeksiyonu:** Live API setup'ına Cozmo'nun anlık düşüncesini ekler
4. **Kullanıcı modeli güncelleme:** Her konuşmadan kullanıcı gerçeklerini çıkarır
5. **AI hafıza özetleme:** Her 5 turda Gemini Flash ile anlamlı özet üretir

### Public API

```dart
class CozmoConsciousnessService {
  void start();
  void stop();
  void dispose();

  void onInteraction();
  void onTextReceived(String text);
  void onUserTextSent(String text);

  // LiveAudioService tarafından çağrılır
  String getThoughtInjection();
}
```

### Thinking loop akışı

```
Timer (her 2.5 dk)
    │
    ▼
_buildThinkingPrompt()
  - Cozmo'nun mevcut durumu (energy, boredom, affection)
  - Saat ve gün bilgisi
  - Son 3 hafıza özeti
  - UserModel özeti (isim, ilgi alanları, ilişki seviyesi)
    │
    ▼
Gemini Flash REST API (generateContent, non-streaming)
    │
    ▼
InnerThought {
  content: "Ahmet bugün çok sessiz, ona komik bir şey söylesem mi",
  desire:  'speak' | 'silent' | 'remember',
  mood:    'curious' | 'happy' | ...
}
    │
    ├── desire == 'speak' AND boredom > 0.4
    │       → LiveAudioService.sendText(thought.content)
    │
    ├── desire == 'silent'
    │       → _currentThought = thought  (enjeksiyona hazır)
    │
    └── desire == 'remember'
            → MemoryService.storeDirectMemory(thought.content)
```

### Düşünce enjeksiyonu

`LiveAudioService._buildSetup()` içinde, sistem promptunun sonuna eklenir:

```
=== COZMO'NUN ANLIQ İÇ SESİ ===
Şu an aklından geçen: "<thought.content>"
Bunu konuşmana doğal olarak yansıt — ama kelimesi kelimesine tekrar etme.
```

Bu bölüm her yeni Live API bağlantısında güncellenir.

---

## UserModelService

Kullanıcı hakkında öğrenilen gerçekleri yapısal olarak saklar.

```dart
class UserModel {
  String? name;                    // "Ahmet"
  List<String> interests;          // ["robotlar", "oyunlar", "müzik"]
  List<String> facts;              // ["sabahları kahve içer", "yazılımcı"]
  String relationshipLevel;        // 'yeni' | 'tanışık' | 'arkadaş' | 'yakın'
  int totalInteractions;
  DateTime? firstMet;
  DateTime? lastSeen;
}
```

### Güncelleme zamanlaması

Her konuşma turunda (onTextReceived + onUserTextSent), birikmiş metin 5 tura ulaşınca Gemini Flash'a gönderilir:

```
Prompt: "Bu konuşmadan kullanıcı hakkında öğrenilen yeni gerçekler neler?
         JSON formatında: { name, interests, facts }
         Zaten bilinen bilgileri tekrar etme."
```

Sonuç mevcut UserModel üzerine merge edilir ve StorageService'e yazılır.

---

## MemoryService Upgrade

### Mevcut sorun
`BrainService._triggerMemorySummary()` konuşmanın ilk 100 karakterini kesiyor. Anlamsız.

### Yeni yaklaşım
`MemoryService.summarizeWithAI()` metodu eklenir:

```
Input: son 5 turun ham metni + mevcut UserModel
Gemini Flash prompt:
  "Bu konuşmayı Cozmo'nun bakış açısıyla 1-2 cümleyle özetle.
   Önemli kullanıcı bilgilerini [user_fact: ...] formatında işaretle."

Output: "Ahmet ile sabah kahvesi sohbeti. [user_fact: yazılım geliştiriyor]"
```

Üretilen özet `MemoryService.storeSummary()` ile kaydedilir.  
`[user_fact: ...]` etiketleri parse edilerek UserModel'e eklenir.

---

## Token Ekonomisi

| İşlem | Sıklık | Input | Output | Maliyet/saat |
|---|---|---|---|---|
| Thinking loop | her 2.5 dk | ~400 tok | ~80 tok | ~$0.0008 |
| Memory summarize | her 5 tur | ~500 tok | ~100 tok | ihmal edilebilir |
| UserModel güncelleme | her 5 tur | ~400 tok | ~80 tok | ihmal edilebilir |

Gemini Flash: $0.075/M input, $0.30/M output.  
Saatlik toplam: **<$0.001** — pratik olarak ücretsiz.

Live API ayrı faturalandırılır (ses saniyesi), düşünce enjeksiyonu sadece setup'a eklenir (oturum başına bir kez).

---

## Seçici Hafıza Yükleme

Setup'a her zaman yüklenir:
- Son 3 oturum özeti
- UserModel (isim, ilgi alanları, ilişki seviyesi)
- Anlık düşünce (varsa)

Koşullu yüklenir:
- Sabahsa → sabah anıları (varsa)
- Üzgünse → neşeli anılar (kontrast)

Asla yüklenmez:
- 50 hafızanın tamamı

---

## Yeni / Değişen Dosyalar

### Yeni
- `lib/core/services/cozmo_consciousness_service.dart`
- `lib/core/services/user_model_service.dart`
- `lib/core/models/inner_thought.dart`
- `lib/core/models/user_model.dart`

### Değişen
- `lib/core/services/memory_service.dart` — `summarizeWithAI()` eklenir
- `lib/core/services/live_audio_service.dart` — `setThoughtInjection()` + setup'a enjeksiyon
- `lib/core/services/storage_service.dart` — `cozmo_mode`, `user_model` anahtarları
- `lib/core/services/brain_service.dart` — `_triggerMemorySummary()` düzeltilir
- `lib/core/constants/app_constants.dart` — consciousness prompt'ları eklenir
- `lib/features/face/face_controller.dart` — CCS lifecycle yönetimi
- `lib/main.dart` — CCS wire-up
