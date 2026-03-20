# 🤖 AI Face Assistant (Flutter) - MASTER IMPLEMENTATION PLAN

## 🎯 Project Goal

Build a **Flutter Android application** that displays an **animated AI face (eyes only)** and communicates with the user using **voice + AI (OpenAI)**.

The AI must:

* Have a **custom personality (system prompt)**
* Have a **visual identity (eye themes)**
* React with **emotions (mood → animation + color)**

---

# 🧠 CORE CONCEPT

This app is built on 3 layers:

1. **AI Personality Layer** (System Prompt)
2. **Visual Layer** (Eye Theme System)
3. **Interaction Layer** (Voice + Chat)

---

# 👁️ 1. EYE THEME SYSTEM (CRITICAL)

## Overview

The app must support multiple **visual eye themes** representing different AI personalities.

Each theme controls:

* Eye design
* Animation style
* Color behavior
* Interaction feedback

---

## Required Themes

* Default
* Female
* Anime (inspired, NOT copyrighted)
* Robot
* Cool

---

## Architecture

Each theme must be implemented as a separate widget:

```dart id="t1"
abstract class EyeTheme {
  Widget build(BuildContext context, FaceState state, String mood);
}
```

---

## Theme Enum

```dart id="t2"
enum EyeThemeType {
  defaultTheme,
  female,
  anime,
  robot,
  cool
}
```

---

## Theme Manager

```dart id="t3"
Widget getEyeTheme(EyeThemeType type, FaceState state, String mood) {
  switch (type) {
    case EyeThemeType.anime:
      return AnimeEyeTheme(state: state, mood: mood);
    case EyeThemeType.female:
      return FemaleEyeTheme(state: state, mood: mood);
    default:
      return DefaultEyeTheme(state: state, mood: mood);
  }
}
```

---

## Animation Rules

Each theme MUST implement:

* Idle → slow movement
* Listening → focused eyes
* Thinking → subtle motion
* Speaking → active animation

---

## Animation Implementation Options

### Option A (Simple)

* AnimatedContainer
* Transform
* Opacity

### Option B (Advanced - Recommended)

Use:

* Rive animations

---

## Anime Theme (Important)

Anime theme should include:

* Red circular eye
* Rotating internal pattern
* High energy animation

DO NOT copy copyrighted designs.
Create an inspired version using CustomPainter.

---

# 🎭 2. AI PERSONALITY SYSTEM

## User-Defined System Prompt

On first launch:

* User must enter a system prompt

Example:
"You are a calm, intelligent, slightly sarcastic AI."

---

## Storage

* Save locally OR Firebase Firestore

---

## Editable

User must be able to:

* Edit prompt anytime
* Reset prompt
* Choose presets

---

## Hidden System Rules (Always Applied)

```id="t4"
- Keep responses concise
- Avoid long paragraphs
- Be natural and conversational
- Avoid harmful content
```

---

## Final Prompt Construction

```id="t5"
[HIDDEN RULES]

[USER PROMPT]

Always include mood tag:
[mood: happy/sad/angry/calm]
```

---

# 🎨 3. MOOD SYSTEM (UI REACTION)

## AI Response Format

Example:

```id="t6"
[mood: happy] That’s actually a great question.
```

---

## Mood Parsing

Extract mood and message separately.

---

## Mood → Color Mapping

| Mood  | Color      |
| ----- | ---------- |
| happy | Blue/Green |
| sad   | Purple     |
| angry | Red        |
| calm  | Soft Blue  |

---

## Mood → Animation Impact

* angry → faster animation
* calm → slower animation
* happy → bounce effect

---

# 🗣️ 4. VOICE SYSTEM

## Features

* Speech-to-Text (input)
* Text-to-Speech (output)

---

## Flutter Packages

* speech_to_text
* flutter_tts

---

## Flow

1. Tap microphone
2. Convert speech → text
3. Send to AI
4. Receive response
5. Speak response

---

# ⚙️ 5. APP STATE MANAGEMENT

## States

```dart id="t7"
enum FaceState {
  idle,
  listening,
  thinking,
  speaking
}
```

---

## Behavior

| State     | UI Reaction      |
| --------- | ---------------- |
| idle      | slow animation   |
| listening | focused eyes     |
| thinking  | subtle movement  |
| speaking  | active animation |

---

# 🧱 6. ARCHITECTURE

## Frontend

* Flutter

## Backend (optional but recommended)

Use:

* Firebase (Auth + Firestore)

---

## AI Integration

Use:

* OpenAI API

---

# 📁 7. PROJECT STRUCTURE

```id="t8"
lib/
│
├── main.dart
├── app.dart
│
├── core/
│   ├── services/
│   │   ├── ai_service.dart
│   │   ├── speech_service.dart
│   │   ├── tts_service.dart
│   │   └── storage_service.dart
│
├── features/
│   ├── face/
│   │   ├── face_screen.dart
│   │   ├── face_controller.dart
│   │   ├── themes/
│   │   │   ├── default_eye.dart
│   │   │   ├── female_eye.dart
│   │   │   ├── anime_eye.dart
│   │   │   ├── robot_eye.dart
│   │   │   └── cool_eye.dart
│
│   ├── chat/
│   │   ├── chat_controller.dart
│
│   ├── settings/
│   │   ├── settings_screen.dart
│   │   ├── prompt_editor.dart
│   │   └── theme_selector.dart
│
└── shared/
```

---

# 🔁 8. MAIN FLOW

1. App starts
2. Load:

   * system prompt
   * selected theme
3. Display eye theme
4. User taps mic
5. Speech → text
6. Send to OpenAI
7. Receive response
8. Parse mood
9. Update UI (color + animation)
10. Speak response
11. Return to idle

---

# 🎛️ 9. SETTINGS SCREEN

User can:

* Change system prompt
* Select eye theme
* Choose preset personalities

---

# 🎭 10. PRESET PERSONALITIES

Examples:

Cool:
"You are cool, concise, slightly sarcastic."

Funny:
"You are playful and humorous."

Scientist:
"You explain things logically."

---

# 🔗 11. AI + THEME CONNECTION

Theme must influence AI behavior.

Example:

Anime theme adds:
"You are expressive and dramatic."

Robot theme adds:
"You are logical and precise."

---

# 🚀 12. MVP ROADMAP

## Phase 1

* Basic eye UI
* Text input
* OpenAI integration

## Phase 2

* Voice system
* Mood detection
* Color reactions

## Phase 3

* Theme system
* Settings screen

## Phase 4

* Firebase integration

---

# ⚠️ CONSTRAINTS

* Must be lightweight
* Must run smoothly on mobile
* Avoid heavy animations unless optimized

---

# ✅ SUCCESS CRITERIA

* Smooth animations
* Fast AI responses
* Accurate mood detection
* Easy customization
* Clean UI

---

# 🧩 FINAL NOTE

Start simple.
Get MVP working first.
Then expand with themes and personality depth.

---
