# 🏗️ AI Face Assistant — Architecture Document

> **Version:** 1.0.0  
> **Platform:** Android (Flutter)  
> **State Management:** Provider  
> **AI Backend:** Google Gemini 2.0 Flash  
> **Last Updated:** 2026-03-18

---

## 📋 Table of Contents

1. [Overview](#-overview)
2. [System Architecture](#-system-architecture)
3. [Project Structure](#-project-structure)
4. [Layer Architecture](#-layer-architecture)
5. [Core Services](#-core-services)
6. [Eye Theme System](#-eye-theme-system)
7. [Mood System](#-mood-system)
8. [Voice Interaction Flow](#-voice-interaction-flow)
9. [State Machine](#-state-machine)
10. [AI Personality System](#-ai-personality-system)
11. [Setup & Installation](#-setup--installation)
12. [Build & Deploy](#-build--deploy)
13. [Dependencies](#-dependencies)
14. [Configuration](#-configuration)
15. [Security Notes](#-security-notes)

---

## 🎯 Overview

AI Face Assistant, kullanıcıyla **sesli ve yazılı iletişim** kuran, **animasyonlu AI gözleri** ile görsel geri bildirim veren bir Flutter Android uygulamasıdır.

### Core Capabilities

| Capability | Technology |
|---|---|
| AI Chat | Google Gemini 2.0 Flash API |
| Voice Input | `speech_to_text` (STT) |
| Voice Output | `flutter_tts` (TTS) |
| Eye Animations | `CustomPainter` + `AnimationController` |
| State Management | `Provider` (ChangeNotifier) |
| Local Storage | `SharedPreferences` |

### Key Design Decisions

- **Gemini over OpenAI**: Tier-1 API key ile ücretsiz/düşük maliyetli kullanım.
- **CustomPainter over Rive**: Harici `.riv` dosya bağımlılığı yok, tamamen kod tabanlı animasyonlar.
- **Provider over BLoC**: MVP için yeterli karmaşıklık, tek controller modeli.
- **SharedPreferences over Firebase**: Offline çalışabilirlik, hızlı kurulum.

---

## 🧩 System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Face Screen  │  │Settings Screen│  │  Theme Widgets│ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                 │                  │          │
│         └────────┬────────┘──────────────────┘          │
│                  │                                      │
│         ┌────────▼────────┐                             │
│         │ FaceController   │  ◄── Provider               │
│         │ (ChangeNotifier) │                             │
│         └──┬──┬──┬──┬─────┘                             │
│            │  │  │  │                                   │
├────────────┼──┼──┼──┼───────────────────────────────────┤
│            │  │  │  │        Service Layer               │
│  ┌─────────▼┐ │  │  ▼─────────┐                         │
│  │AiService │ │  │  │Storage   │                         │
│  │(Gemini)  │ │  │  │Service   │                         │
│  └──────────┘ │  │  └──────────┘                         │
│     ┌─────────▼┐ ▼─────────┐                             │
│     │Speech    │ │TTS       │                             │
│     │Service   │ │Service   │                             │
│     └──────────┘ └──────────┘                             │
├──────────────────────────────────────────────────────────┤
│                    Platform Layer                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────┐ │
│  │ Gemini   │ │Android   │ │Android   │ │SharedPrefs  │ │
│  │ API      │ │Mic/STT   │ │TTS Engine│ │(Local)      │ │
│  └──────────┘ └──────────┘ └──────────┘ └─────────────┘ │
└──────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
lib/
├── main.dart                          # Entry point, service initialization
├── app.dart                           # MaterialApp configuration
│
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # API keys, colors, mood mappings, presets
│   ├── enums/
│   │   ├── face_state.dart            # idle, listening, thinking, speaking
│   │   └── eye_theme_type.dart        # defaultTheme, female, anime, robot, cool
│   └── services/
│       ├── ai_service.dart            # Gemini API integration + prompt builder
│       ├── speech_service.dart        # Speech-to-Text wrapper
│       ├── tts_service.dart           # Text-to-Speech wrapper
│       └── storage_service.dart       # SharedPreferences wrapper
│
├── features/
│   ├── face/
│   │   ├── face_screen.dart           # Main UI screen
│   │   ├── face_controller.dart       # Central state controller (ChangeNotifier)
│   │   └── themes/
│   │       ├── eye_theme_manager.dart # Theme factory/router
│   │       ├── default_eye.dart       # Classic AI eyes
│   │       ├── female_eye.dart        # Almond-shaped with lashes
│   │       ├── anime_eye.dart         # Red circular with rotating pattern
│   │       ├── robot_eye.dart         # Digital HUD-style rectangular
│   │       └── cool_eye.dart          # Half-lidded neon cat-eye
│   │
│   └── settings/
│       └── settings_screen.dart       # Theme selector + prompt editor
│
└── test/
    └── widget_test.dart               # Smoke test
```

---

## 🧱 Layer Architecture

### 1. UI Layer (Widgets)

Kullanıcı ile etkileşim sağlayan görsel katman.

| Widget | Responsibility |
|---|---|
| `FaceScreen` | Ana ekran: gözler, mikrofon, yanıt balonu |
| `SettingsScreen` | Tema seçimi, kişilik ayarları, prompt editörü |
| `*EyeTheme` widgets | Her tema için CustomPainter tabanlı göz animasyonları |

### 2. Controller Layer (Business Logic)

Tüm iş mantığını yöneten tek controller:

```dart
FaceController extends ChangeNotifier
├── faceState      → idle | listening | thinking | speaking
├── currentMood    → happy | sad | angry | calm | excited | curious
├── currentTheme   → defaultTheme | female | anime | robot | cool
├── lastResponse   → Son AI yanıtı
├── lastMessage    → Son kullanıcı mesajı
└── systemPrompt   → Aktif kişilik tanımı
```

### 3. Service Layer

Servislerin hiçbiri Flutter widget'larına bağımlı değil — saf Dart sınıfları:

| Service | External Dependency |
|---|---|
| `AiService` | `google_generative_ai` package |
| `SpeechService` | `speech_to_text` package |
| `TtsService` | `flutter_tts` package |
| `StorageService` | `shared_preferences` package |

---

## ⚙️ Core Services

### AiService

Gemini API ile iletişim kurar. Prompt yapısı:

```
┌─────────────────────────────────────┐
│ === SYSTEM RULES (ALWAYS FOLLOW) ===│  ← Gizli, kullanıcı göremez
│ - Keep responses concise            │
│ - Always include mood tag           │
│ - Avoid harmful content             │
├─────────────────────────────────────┤
│ === PERSONALITY MODIFIER ===        │  ← Seçili tema'ya göre eklenir
│ "You are expressive and dramatic."  │
├─────────────────────────────────────┤
│ === YOUR PERSONALITY ===            │  ← Kullanıcının tanımladığı prompt
│ "You are calm, intelligent..."      │
└─────────────────────────────────────┘
```

**Mood Parsing:**

AI yanıtı daima `[mood: happy] actual response text` formatında gelir.
`_parseMoodAndMessage()` metodu bunu ayrıştırır:

```dart
Input:  "[mood: happy] That's a great question!"
Output: { mood: "happy", message: "That's a great question!" }
```

### SpeechService

- `speech_to_text` paketini wrapler
- Varsayılan locale: `tr_TR` (Türkçe)
- 30 saniye dinleme limiti, 3 saniye sessizlik sonrası otomatik durdurma

### TtsService

- `flutter_tts` paketini wrapler
- Varsayılan dil: `tr-TR`
- Konuşma hızı: 0.5 (normal-yavaş arası)
- `onStart` ve `onComplete` callback'leri ile state yönetimi

### StorageService

`SharedPreferences` üzerinde 3 anahtar yönetir:

| Key | Type | Purpose |
|---|---|---|
| `system_prompt` | String | Kullanıcının kişilik tanımı |
| `eye_theme` | int | Seçili tema indeksi |
| `first_launch` | bool | İlk açılış kontrolü |

---

## 👁️ Eye Theme System

### Architecture

Her tema, bağımsız bir `StatefulWidget` + `CustomPainter` kombinasyonudur:

```
EyeThemeManager.getTheme(type, state, mood)
       │
       ├── DefaultEyeTheme   → Klasik yuvarlak göz, iris gradyanı
       ├── FemaleEyeTheme    → Badem şekli, kirpikler (Bezier eğrileri)
       ├── AnimeEyeTheme     → Kırmızı daire, dönen tomoe deseni
       ├── RobotEyeTheme     → Dikdörtgen, tarama çizgisi, HUD köşeleri
       └── CoolEyeTheme      → Yarı kapalı göz, neon parıltı, kedi gözü
```

### Animation Controllers (Her Temada)

| Controller | Purpose | Duration |
|---|---|---|
| `_blinkController` | Göz kırpma | 80-200ms |
| `_moveController` | Göz bebeği hareketi | 3-5s (repeat) |
| `_pulseController` | Nabız efekti | 1.5-2s (repeat) |
| `_rotateController` | Desen döndürme (Anime) | 8s (repeat) |
| `_scanController` | Tarama çizgisi (Robot) | 2s (repeat) |
| `_glowController` | Neon parıltı (Cool) | 2s (repeat) |
| `_shimmerController` | Parlama efekti (Female) | 2s (repeat) |

### Blink Loop

Her tema, rastgele aralıklarla (2-6 saniye) göz kırpma döngüsü çalıştırır:

```dart
void _startBlinkLoop() async {
  while (mounted) {
    await Future.delayed(Duration(seconds: 2 + Random().nextInt(4)));
    if (!mounted) return;
    await _blinkController.forward();
    await _blinkController.reverse();
  }
}
```

---

## 🎨 Mood System

### AI → Mood → UI Pipeline

```
AI Response
    │
    ▼
[mood: happy] That's great!
    │
    ▼ _parseMoodAndMessage()
    │
    ├─ mood: "happy"
    │      │
    │      ├─► MoodColors    → #4FC3F7 (Mavi)
    │      ├─► MoodGlow      → opacity: 0.4
    │      └─► AnimSpeed     → 1.5x
    │
    └─ message: "That's great!"
           │
           └─► TTS speak + Response bubble
```

### Color Mapping

| Mood | Hex | Visual |
|---|---|---|
| happy | `#4FC3F7` | Açık Mavi |
| sad | `#9C27B0` | Mor |
| angry | `#FF5252` | Kırmızı |
| calm | `#81D4FA` | Yumuşak Mavi |
| excited | `#FFD740` | Altın Sarı |
| curious | `#69F0AE` | Yeşil |

### Animation Speed Multiplier

| Mood | Speed |
|---|---|
| angry | 2.5x |
| excited | 2.0x |
| happy | 1.5x |
| curious | 1.3x |
| calm | 0.6x |
| sad | 0.4x |

---

## 🗣️ Voice Interaction Flow

```
                    ┌─────────┐
                    │  IDLE   │
                    └────┬────┘
                         │ Kullanıcı mikrofona basar
                    ┌────▼────┐
                    │LISTENING│ ← Eyes: focused
                    └────┬────┘
                         │ Ses → Metin dönüşümü tamamlanır
                    ┌────▼────┐
                    │THINKING │ ← Eyes: subtle motion
                    └────┬────┘
                         │ Gemini API yanıtı alınır
                         │ Mood parse edilir
                    ┌────▼────┐
                    │SPEAKING │ ← Eyes: active animation
                    │         │   Background: mood color
                    │         │   TTS: yanıtı okur
                    └────┬────┘
                         │ TTS tamamlanır
                    ┌────▼────┐
                    │  IDLE   │
                    └─────────┘
```

---

## 📊 State Machine

```dart
enum FaceState {
  idle,       // Yavaş animasyon, bekleme
  listening,  // Odaklanmış gözler, mikrofon aktif
  thinking,   // Hafif hareket, API çağrısı beklemede
  speaking,   // Aktif animasyon, TTS çalışıyor
}
```

### State Transitions

| From | Event | To |
|---|---|---|
| `idle` | Mic tap | `listening` |
| `listening` | Speech recognized | `thinking` |
| `listening` | Mic tap (cancel) | `idle` |
| `idle` | Text sent | `thinking` |
| `thinking` | AI response received | `speaking` |
| `speaking` | TTS complete | `idle` |
| `speaking` | Stop tap | `idle` |

---

## 🎭 AI Personality System

### Prompt Layers

1. **Hidden Rules** (her zaman aktif, kullanıcı değiştiremez)
2. **Theme Modifier** (seçili temaya göre otomatik eklenir)
3. **User Prompt** (kullanıcının özelleştirdiği kişilik)

### Theme ↔ Personality Connection

| Theme | Auto-added Modifier |
|---|---|
| Default | *(boş)* |
| Female | "You are graceful, empathetic, and eloquent." |
| Anime | "You are expressive, dramatic, and full of energy." |
| Robot | "You are logical, precise, and analytical." |
| Cool | "You are laid-back, confident, and effortlessly cool." |

### Preset Personalities

| Preset | Prompt |
|---|---|
| Cool | "You are cool, concise, and slightly sarcastic. You speak like a confident tech expert." |
| Funny | "You are playful, humorous, and love puns. You try to make the user smile." |
| Scientist | "You explain things logically and precisely. You reference scientific concepts." |
| Poet | "You speak in a poetic and artistic manner. You use metaphors." |
| Friendly | "You are warm, empathetic, and supportive." |

---

## 🚀 Setup & Installation

### Prerequisites

| Tool | Minimum Version |
|---|---|
| Flutter SDK | 3.10.8+ |
| Dart SDK | 3.10.8+ |
| Android SDK | API 21+ (minSdk) |
| Java / JDK | 17+ |

### Installation Steps

```bash
# 1. Repo'yu klonla
git clone <repo-url>
cd aiyardimci

# 2. Bağımlılıkları kur
flutter pub get

# 3. Analyze et (0 hata olmalı)
flutter analyze

# 4. Cihazda çalıştır
flutter run
```

### Android Permissions (Otomatik)

`android/app/src/main/AndroidManifest.xml` içinde:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```

---

## 📦 Build & Deploy

### Debug Build

```bash
flutter run                    # Bağlı cihaza debug build
flutter run --release          # Release modda test
```

### APK Build

```bash
flutter build apk --release   # Fat APK (tüm mimari)
flutter build apk --split-per-abi  # Mimari başına ayrı APK
```

APK çıktısı: `build/app/outputs/flutter-apk/`

### App Bundle (Play Store)

```bash
flutter build appbundle --release
```

Bundle çıktısı: `build/app/outputs/bundle/release/`

---

## 📚 Dependencies

| Package | Version | Purpose |
|---|---|---|
| `provider` | ^6.1.2 | State management (ChangeNotifier) |
| `google_generative_ai` | ^0.4.6 | Gemini API client |
| `speech_to_text` | ^7.0.0 | Mikrofon → metin dönüşümü |
| `flutter_tts` | ^4.2.0 | Metin → ses dönüşümü |
| `shared_preferences` | ^2.3.4 | Key-value yerel depolama |
| `http` | ^1.2.2 | HTTP client (yedek) |

---

## ⚙️ Configuration

### API Key

API anahtarı `lib/core/constants/app_constants.dart` içinde saklanır:

```dart
static const String geminiApiKey = 'AIzaSy...';
```

> ⚠️ **Prodüksiyonda** bu anahtarı environment variable'a veya secure storage'a taşıyın.

### Language Settings

| Service | Default Locale |
|---|---|
| Speech-to-Text | `tr_TR` |
| Text-to-Speech | `tr-TR` |

Değiştirmek için ilgili service dosyasındaki locale parametresini güncelleyin.

### AI Model

```dart
model: 'gemini-2.0-flash'  // Hızlı, düşük maliyetli
```

Alternatifler: `gemini-1.5-pro` (daha akıllı, yavaş), `gemini-2.0-flash-lite` (en hafif)

---

## 🔒 Security Notes

| Concern | Status | Recommendation |
|---|---|---|
| API Key exposure | ⚠️ Hardcoded | Prodüksiyonda env variable veya `--dart-define` kullanın |
| Network requests | ✅ HTTPS only | Gemini API TLS zorunlu |
| Microphone access | ✅ Runtime permission | Android 6+ otomatik izin istenir |
| Local storage | ✅ App-private | SharedPreferences app sandbox'ta |

### Prodüksiyon İçin API Key Güvenliği

```bash
# Build sırasında inject etme
flutter run --dart-define=GEMINI_API_KEY=your_key_here

# Kod tarafında okuma
const apiKey = String.fromEnvironment('GEMINI_API_KEY');
```

---

## 🔄 Future Improvements

- [ ] Firebase Auth + Firestore entegrasyonu
- [ ] Rive animasyonları (göz temaları için)
- [ ] Çoklu dil desteği (STT/TTS locale switcher)
- [ ] Sohbet geçmişi kaydetme
- [ ] Göz teması önizleme (Settings'te canlı animasyon)
- [ ] Widget test coverage artırma
- [ ] CI/CD pipeline (GitHub Actions)
