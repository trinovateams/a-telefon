# Ultra-Realistik Göz Implementasyon Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 5 çocuksu göz temasını kaldırıp, tek bir ultra-realistik iki göz tasarımıyla değiştirmek.

**Architecture:** CustomPaint ile anatomik doğrulukta göz çizimi. RealisticEyeWidget animasyon orchestration yapar, RealisticEyePainter tüm katmanları çizer. Eski tema sistemi tamamen kaldırılır.

**Tech Stack:** Flutter CustomPaint, AnimationController, TickerProviderStateMixin

**Spec:** `docs/superpowers/specs/2026-03-20-ultra-realistic-eye-redesign.md`

---

### Task 1: Eski tema sistemini kaldır

**Files:**
- Delete: `lib/core/enums/eye_theme_type.dart`
- Delete: `lib/features/face/themes/eye_theme_manager.dart`
- Delete: `lib/features/face/themes/default_eye.dart`
- Delete: `lib/features/face/themes/female_eye.dart`
- Delete: `lib/features/face/themes/anime_eye.dart`
- Delete: `lib/features/face/themes/robot_eye.dart`
- Delete: `lib/features/face/themes/cool_eye.dart`
- Modify: `lib/core/services/storage_service.dart`
- Modify: `lib/core/services/ai_service.dart`
- Modify: `lib/features/face/face_controller.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/features/face/face_screen.dart`

- [ ] **Step 1: storage_service.dart — tema metotlarını kaldır**

`lib/core/services/storage_service.dart` dosyasından:
- Satır 3: `import '../enums/eye_theme_type.dart';` → sil
- Satır 7: `static const _keyEyeTheme = 'eye_theme';` → sil
- Satır 31-38: `getEyeTheme()` ve `setEyeTheme()` metotlarını sil

Sonuç:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  static const _keySystemPrompt = 'system_prompt';
  static const _keyFirstLaunch = 'first_launch';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isFirstLaunch => _prefs.getBool(_keyFirstLaunch) ?? true;

  Future<void> setFirstLaunchDone() async {
    await _prefs.setBool(_keyFirstLaunch, false);
  }

  String getSystemPrompt() {
    return _prefs.getString(_keySystemPrompt) ??
        AppConstants.defaultSystemPrompt;
  }

  Future<void> setSystemPrompt(String prompt) async {
    await _prefs.setString(_keySystemPrompt, prompt);
  }
}
```

- [ ] **Step 2: ai_service.dart — tema prompt'unu kaldır**

`lib/core/services/ai_service.dart` dosyasından:
- Satır 8: `String _themePromptAddition = '';` → sil
- Satır 20-24: `_themePromptAddition` kontrol bloğunu sil (`if (_themePromptAddition.isNotEmpty) { ... }`)
- Satır 36-38: `updateThemePrompt()` metodunu sil

- [ ] **Step 3: face_controller.dart — tema yönetimini kaldır**

`lib/features/face/face_controller.dart` dosyasından:
- Satır 3: `import '../../core/enums/eye_theme_type.dart';` → sil
- Satır 19: `EyeThemeType _currentTheme = EyeThemeType.defaultTheme;` → sil
- Satır 38: `_currentTheme = _storageService.getEyeTheme();` → sil
- Satır 40: `_updateThemePrompt();` → sil
- Satır 103: `EyeThemeType get currentTheme => _currentTheme;` → sil
- Satır 152-178: `setTheme()` ve `_updateThemePrompt()` metotlarını sil

- [ ] **Step 4: face_screen.dart — EyeThemeManager referansını kaldır**

`lib/features/face/face_screen.dart` dosyasından:
- Satır 6: `import 'themes/eye_theme_manager.dart';` → sil (Task 4'te yeni import eklenecek)
- Satır 78-84: `EyeThemeManager.getTheme(...)` çağrısını geçici olarak `const SizedBox()` ile değiştir (Task 4'te gerçek widget ile değiştirilecek)

- [ ] **Step 5: settings_screen.dart — tema seçicisini kaldır**

`lib/features/settings/settings_screen.dart` dosyasından:
- Satır 4: `import '../../core/enums/eye_theme_type.dart';` → sil
- Satır 61-63: `_buildSectionTitle('GÖZ TEMASI'...)`, `SizedBox`, `_buildThemeSelector(...)` → sil
- Satır 65: İlk `SizedBox(height: 32)` → sil
- Satır 116-181: `_buildThemeSelector()` ve `_getThemeIcon()` metotlarını sil

- [ ] **Step 6: Eski tema dosyalarını sil**

```bash
rm lib/core/enums/eye_theme_type.dart
rm lib/features/face/themes/eye_theme_manager.dart
rm lib/features/face/themes/default_eye.dart
rm lib/features/face/themes/female_eye.dart
rm lib/features/face/themes/anime_eye.dart
rm lib/features/face/themes/robot_eye.dart
rm lib/features/face/themes/cool_eye.dart
```

- [ ] **Step 7: Derleme kontrolü**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: remove old theme system (5 themes, theme manager, theme enum)"
```

---

### Task 2: RealisticEyePainter — anatomik göz çizimi

**Files:**
- Create: `lib/features/face/themes/realistic_eye_painter.dart`

Bu dosya tüm CustomPaint çizim mantığını içerir. Yaklaşık 600-800 satır.

- [ ] **Step 1: Painter dosyasını oluştur — temel yapı ve parametreler**

`lib/features/face/themes/realistic_eye_painter.dart` dosyasını oluştur.

Dosya başına `import 'dart:math';` ve `import 'package:flutter/material.dart';` eklenmeli.

**NOT:** Tüm yeni kodda `withOpacity()` yerine `withValues(alpha:)` kullanılmalı (mevcut codebase convention'ı).

Painter şu parametreleri alır:
```dart
class RealisticEyePainter extends CustomPainter {
  final double blinkValue;        // 0.0 (açık) → 1.0 (kapalı)
  final double pupilScale;        // 1.0 = normal, >1 genişlemiş, <1 daralmış
  final Offset gazeOffset;        // -1..1 x,y bakış yönü
  final Color irisColor;          // Mood'a göre iris rengi
  final double shimmerAngle;      // Islak parlama açısı (radyan)
  final double wetness;           // 0..1 ıslaklık yoğunluğu
  final double lidDroop;          // 0..1 üst kapak düşüklüğü (sad mood)
  final bool isLeftEye;           // Sol/sağ göz (asimetri için)
  final List<BloodVessel> bloodVessels;  // Önceden üretilmiş kan damarları
  final List<IrisFiber> irisFibers;      // Önceden üretilmiş iris fiberleri
  final List<Lash> upperLashes;          // Üst kirpikler
  final List<Lash> lowerLashes;          // Alt kirpikler
  final List<Crypt> irisCrypts;          // İris kriptaları
}
```

Yardımcı veri sınıfları (aynı dosyada, private):
```dart
class BloodVessel {
  final Offset start;
  final Offset control1, control2, end;
  final double thickness;
  final double opacity;
}

class IrisFiber {
  final double angle;
  final double length;    // 0..1 (iris yarıçapına oran)
  final double thickness;
}

class Lash {
  final double position;  // 0..1 kapak üzerindeki konum
  final double length;
  final double angle;
  final double curve;
}

class Crypt {
  final double angle;
  final double distance;  // pupil'den uzaklık oranı
  final double size;
}
```

`shouldRepaint`:
```dart
@override
bool shouldRepaint(RealisticEyePainter old) {
  return old.blinkValue != blinkValue ||
         old.pupilScale != pupilScale ||
         old.gazeOffset != gazeOffset ||
         old.irisColor != irisColor ||
         old.shimmerAngle != shimmerAngle ||
         old.wetness != wetness ||
         old.lidDroop != lidDroop;
}
```

- [ ] **Step 2: paint() metodu — katman sıralaması**

`paint()` metodu çizim sırasını tanımlar:
```dart
@override
void paint(Canvas canvas, Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  final eyeWidth = size.width * 0.9;
  final eyeHeight = eyeWidth * 0.45; // badem oranı

  _drawSocketShadow(canvas, center, eyeWidth, eyeHeight);
  _drawSkinBase(canvas, center, eyeWidth, eyeHeight);

  // Göz beyazı ve üstü klip bölgesiyle sınırla
  canvas.save();
  _clipToEyeShape(canvas, center, eyeWidth, eyeHeight);

  _drawSclera(canvas, center, eyeWidth, eyeHeight);
  _drawBloodVessels(canvas, center, eyeWidth, eyeHeight);
  _drawIris(canvas, center, eyeWidth, eyeHeight);
  _drawPupil(canvas, center, eyeWidth, eyeHeight);
  _drawCorneaReflection(canvas, center, eyeWidth, eyeHeight);
  _drawLidShadow(canvas, center, eyeWidth, eyeHeight);

  canvas.restore();

  _drawUpperLid(canvas, center, eyeWidth, eyeHeight);
  _drawLowerLid(canvas, center, eyeWidth, eyeHeight);
  _drawLashes(canvas, center, eyeWidth, eyeHeight);
}
```

- [ ] **Step 3: _clipToEyeShape — badem göz şekli**

```dart
void _clipToEyeShape(Canvas canvas, Offset center, double w, double h) {
  canvas.clipPath(_getEyePath(center, w, h));
}
```

Göz beyazını sınırlayan badem şekli (Path):
```dart
Path _getEyePath(Offset center, double w, double h) {
  final adjustedH = h * (1.0 - blinkValue); // kırpışmada daralır
  final path = Path();
  // Sol köşe
  path.moveTo(center.dx - w / 2, center.dy);
  // Üst kapak eğrisi
  path.quadraticBezierTo(
    center.dx, center.dy - adjustedH / 2,
    center.dx + w / 2, center.dy,
  );
  // Alt kapak eğrisi
  path.quadraticBezierTo(
    center.dx, center.dy + adjustedH * 0.35,
    center.dx - w / 2, center.dy,
  );
  path.close();
  return path;
}
```

- [ ] **Step 4: _drawSocketShadow ve _drawSkinBase**

```dart
void _drawSocketShadow(Canvas canvas, Offset center, double w, double h) {
  final paint = Paint()
    ..shader = RadialGradient(
      colors: [
        const Color(0xFF1A1410).withOpacity(0.6),
        const Color(0xFF1A1410).withOpacity(0.0),
      ],
    ).createShader(Rect.fromCenter(center: center, width: w * 1.4, height: h * 2.0));
  canvas.drawOval(
    Rect.fromCenter(center: center, width: w * 1.3, height: h * 1.8),
    paint,
  );
}

void _drawSkinBase(Canvas canvas, Offset center, double w, double h) {
  final paint = Paint()
    ..shader = RadialGradient(
      colors: [
        const Color(0xFF2A2018), // ten rengi (karanlık ortam)
        const Color(0xFF1A1410),
      ],
    ).createShader(Rect.fromCenter(center: center, width: w * 1.2, height: h * 1.5));
  canvas.drawOval(
    Rect.fromCenter(center: center, width: w * 1.15, height: h * 1.4),
    paint,
  );
}
```

- [ ] **Step 5: _drawSclera — göz beyazı**

```dart
void _drawSclera(Canvas canvas, Offset center, double w, double h) {
  final scleraRect = Rect.fromCenter(center: center, width: w, height: h);
  final paint = Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.2, -0.3), // üst kapak gölgesi etkisi
      radius: 0.8,
      colors: const [
        Color(0xFFF8F4EF), // sıcak beyaz
        Color(0xFFF0E8DF),
        Color(0xFFE0D0C0), // krem kenar
        Color(0xFFCBB8A5),
      ],
      stops: const [0.0, 0.4, 0.75, 1.0],
    ).createShader(scleraRect);
  canvas.drawOval(scleraRect, paint);
}
```

- [ ] **Step 6: _drawBloodVessels — kan damarları**

```dart
void _drawBloodVessels(Canvas canvas, Offset center, double w, double h) {
  for (final vessel in bloodVessels) {
    final paint = Paint()
      ..color = const Color(0xFFCC4444).withOpacity(vessel.opacity)
      ..strokeWidth = vessel.thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Pozisyonları göz boyutuna ölçekle
    final s = Offset(center.dx + vessel.start.dx * w / 2, center.dy + vessel.start.dy * h / 2);
    final c1 = Offset(center.dx + vessel.control1.dx * w / 2, center.dy + vessel.control1.dy * h / 2);
    final c2 = Offset(center.dx + vessel.control2.dx * w / 2, center.dy + vessel.control2.dy * h / 2);
    final e = Offset(center.dx + vessel.end.dx * w / 2, center.dy + vessel.end.dy * h / 2);

    final path = Path()
      ..moveTo(s.dx, s.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
    canvas.drawPath(path, paint);
  }
}
```

- [ ] **Step 7: _drawIris — çok katmanlı iris**

```dart
void _drawIris(Canvas canvas, Offset center, double w, double h) {
  final irisRadius = w * 0.18;
  final gazeX = gazeOffset.dx * w * 0.06;
  final gazeY = gazeOffset.dy * h * 0.06;
  final irisCenter = Offset(center.dx + gazeX, center.dy + gazeY);

  // 1. Ana iris gradyenti
  final irisPaint = Paint()
    ..shader = RadialGradient(
      colors: [
        irisColor.withOpacity(0.9),
        irisColor,
        Color.lerp(irisColor, Colors.brown.shade900, 0.5)!,
        const Color(0xFF2A1A0A), // limbal halka
      ],
      stops: const [0.0, 0.4, 0.8, 1.0],
    ).createShader(Rect.fromCircle(center: irisCenter, radius: irisRadius));
  canvas.drawCircle(irisCenter, irisRadius, irisPaint);

  // 2. Limbal halka (koyu dış çerçeve)
  final limbalPaint = Paint()
    ..color = const Color(0xFF1A0E05)
    ..style = PaintingStyle.stroke
    ..strokeWidth = irisRadius * 0.08;
  canvas.drawCircle(irisCenter, irisRadius, limbalPaint);

  // 3. Fiber dokusu (200+ radyal çizgi)
  for (final fiber in irisFibers) {
    final fiberPaint = Paint()
      ..color = Color.lerp(irisColor, Colors.white, 0.15)!.withOpacity(0.3)
      ..strokeWidth = fiber.thickness
      ..style = PaintingStyle.stroke;

    final innerR = irisRadius * 0.3; // collarette'den başla
    final outerR = irisRadius * fiber.length;
    final dx1 = irisCenter.dx + innerR * cos(fiber.angle);
    final dy1 = irisCenter.dy + innerR * sin(fiber.angle);
    final dx2 = irisCenter.dx + outerR * cos(fiber.angle);
    final dy2 = irisCenter.dy + outerR * sin(fiber.angle);

    canvas.drawLine(Offset(dx1, dy1), Offset(dx2, dy2), fiberPaint);
  }

  // 4. Collarette halkası
  final collarettePaint = Paint()
    ..color = Color.lerp(irisColor, Colors.orange.shade800, 0.4)!.withOpacity(0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = irisRadius * 0.04;
  canvas.drawCircle(irisCenter, irisRadius * 0.42, collarettePaint);

  // 5. Kriptalar (koyu noktalar)
  for (final crypt in irisCrypts) {
    final cryptPaint = Paint()
      ..color = const Color(0xFF1A0E05).withOpacity(0.4);
    final cr = irisRadius * crypt.distance;
    final cx = irisCenter.dx + cr * cos(crypt.angle);
    final cy = irisCenter.dy + cr * sin(crypt.angle);
    canvas.drawCircle(Offset(cx, cy), irisRadius * crypt.size, cryptPaint);
  }
}
```

Bu step'te `dart:math` import'u gerekli (`cos`, `sin`).

- [ ] **Step 8: _drawPupil — pupil**

```dart
void _drawPupil(Canvas canvas, Offset center, double w, double h) {
  final irisRadius = w * 0.18;
  final gazeX = gazeOffset.dx * w * 0.06;
  final gazeY = gazeOffset.dy * h * 0.06;
  final pupilCenter = Offset(center.dx + gazeX, center.dy + gazeY);
  final pupilRadius = irisRadius * 0.35 * pupilScale;

  // Pupil derinlik gradyenti
  final pupilPaint = Paint()
    ..shader = RadialGradient(
      colors: [
        const Color(0xFF050505),
        const Color(0xFF0A0805),
        const Color(0xFF150E08).withOpacity(0.0), // iris'e yumuşak geçiş
      ],
      stops: const [0.0, 0.75, 1.0],
    ).createShader(Rect.fromCircle(center: pupilCenter, radius: pupilRadius));
  canvas.drawCircle(pupilCenter, pupilRadius, pupilPaint);
}
```

- [ ] **Step 9: _drawCorneaReflection — ışık yansımaları**

```dart
void _drawCorneaReflection(Canvas canvas, Offset center, double w, double h) {
  final irisRadius = w * 0.18;
  final gazeX = gazeOffset.dx * w * 0.06;
  final gazeY = gazeOffset.dy * h * 0.06;
  final irisCenter = Offset(center.dx + gazeX, center.dy + gazeY);

  // 1. Ana yansıma (üst-sol, dikdörtgenimsi)
  final mainRefSize = irisRadius * 0.25;
  final mainRefCenter = Offset(
    irisCenter.dx - irisRadius * 0.25 + shimmerAngle * 2,
    irisCenter.dy - irisRadius * 0.3,
  );
  final mainRefPaint = Paint()
    ..color = Colors.white.withOpacity(0.7 * wetness);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: mainRefCenter, width: mainRefSize, height: mainRefSize * 1.3),
      Radius.circular(mainRefSize * 0.25),
    ),
    mainRefPaint,
  );

  // 2. İkincil yansıma (sağ-alt, küçük daire)
  final secRefCenter = Offset(
    irisCenter.dx + irisRadius * 0.2,
    irisCenter.dy + irisRadius * 0.25,
  );
  final secRefPaint = Paint()
    ..color = Colors.white.withOpacity(0.4 * wetness);
  canvas.drawCircle(secRefCenter, irisRadius * 0.1, secRefPaint);

  // 3. Genel ıslak parlama (cornea üzeri radyal)
  final wetPaint = Paint()
    ..shader = RadialGradient(
      center: Alignment(-0.3 + shimmerAngle * 0.1, -0.3),
      colors: [
        Colors.white.withOpacity(0.15 * wetness),
        Colors.white.withOpacity(0.0),
      ],
    ).createShader(Rect.fromCircle(center: irisCenter, radius: irisRadius * 1.2));
  canvas.drawCircle(irisCenter, irisRadius * 1.2, wetPaint);
}
```

- [ ] **Step 10: _drawLidShadow — kapak gölgesi iris üstünde**

```dart
void _drawLidShadow(Canvas canvas, Offset center, double w, double h) {
  final shadowPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.center,
      colors: [
        const Color(0xFF1A1410).withOpacity(0.5),
        const Color(0xFF1A1410).withOpacity(0.0),
      ],
    ).createShader(Rect.fromCenter(center: center, width: w, height: h));
  canvas.drawRect(
    Rect.fromCenter(center: Offset(center.dx, center.dy - h * 0.15), width: w, height: h * 0.4),
    shadowPaint,
  );
}
```

- [ ] **Step 11: _drawUpperLid ve _drawLowerLid — göz kapakları**

```dart
void _drawUpperLid(Canvas canvas, Offset center, double w, double h) {
  final eyePath = _getEyePath(center, w, h);
  final adjustedH = h * (1.0 - blinkValue);
  final droopOffset = lidDroop * h * 0.1;

  // Kapak cildi
  final lidPath = Path();
  lidPath.moveTo(center.dx - w * 0.65, center.dy - h * 0.3);
  lidPath.quadraticBezierTo(
    center.dx, center.dy - h * 0.9 + droopOffset,
    center.dx + w * 0.65, center.dy - h * 0.3,
  );
  // Göz üst kenarına bağla
  lidPath.quadraticBezierTo(
    center.dx, center.dy - adjustedH / 2,
    center.dx - w * 0.65, center.dy - h * 0.3,
  );
  // Lid'in altını kapak kenarına kadar doldur
  lidPath.close();

  final lidPaint = Paint()..color = const Color(0xFF2A2018);
  canvas.drawPath(lidPath, lidPaint);

  // Crease çizgisi
  final creasePaint = Paint()
    ..color = const Color(0xFF1A1410).withOpacity(0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final creasePath = Path();
  creasePath.moveTo(center.dx - w * 0.5, center.dy - h * 0.35);
  creasePath.quadraticBezierTo(
    center.dx, center.dy - h * 0.75 + droopOffset,
    center.dx + w * 0.5, center.dy - h * 0.35,
  );
  canvas.drawPath(creasePath, creasePaint);
}

void _drawLowerLid(Canvas canvas, Offset center, double w, double h) {
  final adjustedH = h * (1.0 - blinkValue);

  final lidPath = Path();
  lidPath.moveTo(center.dx - w * 0.55, center.dy + h * 0.15);
  lidPath.quadraticBezierTo(
    center.dx, center.dy + adjustedH * 0.35,
    center.dx + w * 0.55, center.dy + h * 0.15,
  );
  lidPath.quadraticBezierTo(
    center.dx, center.dy + h * 0.55,
    center.dx - w * 0.55, center.dy + h * 0.15,
  );
  lidPath.close();

  final lidPaint = Paint()..color = const Color(0xFF2A2018);
  canvas.drawPath(lidPath, lidPaint);

  // Waterline
  final waterlinePaint = Paint()
    ..color = const Color(0xFFD4A89A).withOpacity(0.3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final waterlinePath = Path();
  waterlinePath.moveTo(center.dx - w * 0.4, center.dy + adjustedH * 0.3);
  waterlinePath.quadraticBezierTo(
    center.dx, center.dy + adjustedH * 0.38,
    center.dx + w * 0.4, center.dy + adjustedH * 0.3,
  );
  canvas.drawPath(waterlinePath, waterlinePaint);
}
```

- [ ] **Step 12: _drawLashes — kirpikler**

```dart
void _drawLashes(Canvas canvas, Offset center, double w, double h) {
  final adjustedH = h * (1.0 - blinkValue);
  final lashPaint = Paint()
    ..color = const Color(0xFF0A0805)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;

  // Üst kirpikler
  for (final lash in upperLashes) {
    final x = center.dx - w / 2 + lash.position * w;
    // Kapak kenarındaki y pozisyonu (badem eğrisinden)
    final t = lash.position;
    final y = center.dy - adjustedH / 2 * sin(t * pi); // parabolik eğri

    final tipX = x + cos(lash.angle) * lash.length * w * 0.05;
    final tipY = y - sin(lash.angle) * lash.length * w * 0.05;
    final ctrlX = x + cos(lash.angle) * lash.length * w * 0.025;
    final ctrlY = y - sin(lash.angle) * lash.length * w * 0.04 * (1 + lash.curve);

    final path = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(ctrlX, ctrlY, tipX, tipY);
    canvas.drawPath(path, lashPaint);
  }

  // Alt kirpikler (daha kısa, aşağı yönlü)
  final lowerLashPaint = Paint()
    ..color = const Color(0xFF0A0805).withOpacity(0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9
    ..strokeCap = StrokeCap.round;

  for (final lash in lowerLashes) {
    final x = center.dx - w * 0.35 + lash.position * w * 0.7;
    final t = lash.position;
    final y = center.dy + adjustedH * 0.35 * sin(t * pi);

    final tipX = x + cos(lash.angle) * lash.length * w * 0.03;
    final tipY = y + sin(lash.angle.abs()) * lash.length * w * 0.03;

    final path = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(x, tipY * 0.5 + y * 0.5, tipX, tipY);
    canvas.drawPath(path, lowerLashPaint);
  }
}
```

- [ ] **Step 13: Prosedürel veri üreticiler — static fonksiyonlar**

Aynı dosyada, seed'den veri üreten static metotlar:

```dart
static List<BloodVessel> generateBloodVessels(Random rng) {
  return List.generate(10, (i) {
    // Kenardan merkeze doğru
    final angle = rng.nextDouble() * 2 * pi;
    final startR = 0.7 + rng.nextDouble() * 0.3;
    final endR = 0.2 + rng.nextDouble() * 0.3;
    return BloodVessel(
      start: Offset(cos(angle) * startR, sin(angle) * startR),
      control1: Offset(cos(angle + 0.1) * (startR - 0.15), sin(angle + 0.1) * (startR - 0.15)),
      control2: Offset(cos(angle - 0.05) * (endR + 0.15), sin(angle - 0.05) * (endR + 0.15)),
      end: Offset(cos(angle) * endR, sin(angle) * endR),
      thickness: 0.3 + rng.nextDouble() * 0.5,
      opacity: 0.15 + rng.nextDouble() * 0.2,
    );
  });
}

static List<IrisFiber> generateIrisFibers(Random rng) {
  return List.generate(220, (i) {
    return IrisFiber(
      angle: (i / 220) * 2 * pi + (rng.nextDouble() - 0.5) * 0.03,
      length: 0.6 + rng.nextDouble() * 0.4,
      thickness: 0.3 + rng.nextDouble() * 0.5,
    );
  });
}

static List<Lash> generateUpperLashes(Random rng) {
  return List.generate(18, (i) {
    final t = (i + 1) / 19; // 0..1 pozisyon
    return Lash(
      position: t,
      length: 0.6 + rng.nextDouble() * 0.4 + (t > 0.4 && t < 0.7 ? 0.2 : 0),
      angle: 1.2 + (t - 0.5) * 0.8, // ortada dik, kenarlarda yatık
      curve: 0.3 + rng.nextDouble() * 0.4,
    );
  });
}

static List<Lash> generateLowerLashes(Random rng) {
  return List.generate(10, (i) {
    final t = (i + 1) / 11;
    return Lash(
      position: t,
      length: 0.3 + rng.nextDouble() * 0.3,
      angle: -0.8 + (t - 0.5) * 0.4,
      curve: 0.2 + rng.nextDouble() * 0.3,
    );
  });
}

static List<Crypt> generateCrypts(Random rng) {
  return List.generate(20, (i) {
    return Crypt(
      angle: rng.nextDouble() * 2 * pi,
      distance: 0.45 + rng.nextDouble() * 0.4,
      size: 0.02 + rng.nextDouble() * 0.03,
    );
  });
}
```

- [ ] **Step 14: Derleme kontrolü**

Run: `flutter analyze`
Expected: No issues found (painter henüz kullanılmıyor, ama derlenmeli)

- [ ] **Step 15: Commit**

```bash
git add lib/features/face/themes/realistic_eye_painter.dart
git commit -m "feat: add RealisticEyePainter with anatomical eye rendering"
```

---

### Task 3: RealisticEyeWidget — animasyon ve iki göz layout

**Files:**
- Create: `lib/features/face/themes/realistic_eye.dart`

Bu widget animasyon controller'ları yönetir ve iki göz layout'unu oluşturur.

- [ ] **Step 1: Widget yapısı ve animation controller'lar**

`lib/features/face/themes/realistic_eye.dart` dosyasını oluştur:

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/face_state.dart';
import 'realistic_eye_painter.dart';

class RealisticEyeWidget extends StatefulWidget {
  final FaceState state;
  final String mood;

  const RealisticEyeWidget({
    super.key,
    required this.state,
    required this.mood,
  });

  @override
  State<RealisticEyeWidget> createState() => _RealisticEyeWidgetState();
}

class _RealisticEyeWidgetState extends State<RealisticEyeWidget>
    with TickerProviderStateMixin {

  // Animation controllers
  late AnimationController _blinkController;
  late AnimationController _pupilController;
  late AnimationController _saccadeController;
  late AnimationController _irisColorController;
  late AnimationController _shimmerController;
  late AnimationController _breathController;

  // Animasyon değerleri
  late Animation<double> _blinkAnim;
  late Animation<double> _pupilAnim;
  late Animation<Offset> _saccadeAnim;
  late Animation<Color?> _irisColorAnim;

  // Prosedürel veriler (sabit seed)
  late final List _leftBloodVessels;
  late final List _leftIrisFibers;
  late final List _leftUpperLashes;
  late final List _leftLowerLashes;
  late final List _leftCrypts;
  late final List _rightBloodVessels;
  late final List _rightIrisFibers;
  late final List _rightUpperLashes;
  late final List _rightLowerLashes;
  late final List _rightCrypts;

  // State
  double _targetPupilScale = 1.0;
  Offset _targetGaze = Offset.zero;
  Color _currentIrisColor = const Color(0xFF81D4FA);
  double _lidDroop = 0.0;

  @override
  void initState() {
    super.initState();
    _initProceduralData();
    _initControllers();
    _startBlinkLoop();
    _startSaccadeLoop();
  }
  // ... (devamı aşağıda)
}
```

- [ ] **Step 2: _initProceduralData — seed'li veri üretimi**

```dart
void _initProceduralData() {
  final leftRng = Random(42);
  final rightRng = Random(137);

  _leftBloodVessels = RealisticEyePainter.generateBloodVessels(leftRng);
  _leftIrisFibers = RealisticEyePainter.generateIrisFibers(leftRng);
  _leftUpperLashes = RealisticEyePainter.generateUpperLashes(leftRng);
  _leftLowerLashes = RealisticEyePainter.generateLowerLashes(leftRng);
  _leftCrypts = RealisticEyePainter.generateCrypts(leftRng);

  _rightBloodVessels = RealisticEyePainter.generateBloodVessels(rightRng);
  _rightIrisFibers = RealisticEyePainter.generateIrisFibers(rightRng);
  _rightUpperLashes = RealisticEyePainter.generateUpperLashes(rightRng);
  _rightLowerLashes = RealisticEyePainter.generateLowerLashes(rightRng);
  _rightCrypts = RealisticEyePainter.generateCrypts(rightRng);
}
```

- [ ] **Step 3: _initControllers — animasyon controller'ları**

```dart
void _initControllers() {
  _blinkController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 120),
  );
  _blinkAnim = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _blinkController, curve: Curves.easeIn, reverseCurve: Curves.easeOut),
  );

  _pupilController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  _pupilAnim = Tween(begin: 1.0, end: 1.0).animate(
    CurvedAnimation(parent: _pupilController, curve: Curves.easeOut),
  );

  _saccadeController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  _saccadeAnim = Tween(begin: Offset.zero, end: Offset.zero).animate(
    CurvedAnimation(parent: _saccadeController, curve: Curves.easeInOut),
  );

  _irisColorController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  _irisColorAnim = ColorTween(
    begin: MoodColors.getColor(widget.mood),
    end: MoodColors.getColor(widget.mood),
  ).animate(_irisColorController);

  _shimmerController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  _breathController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);
}
```

- [ ] **Step 4: Kırpışma loop'u**

```dart
void _startBlinkLoop() {
  Future.delayed(Duration(milliseconds: 3000 + Random().nextInt(3000)), () {
    if (!mounted) return;
    _doBlink();
  });
}

void _doBlink() async {
  if (!mounted) return;
  await _blinkController.forward();
  await Future.delayed(const Duration(milliseconds: 50));
  await _blinkController.reverse();

  // %10 çift kırpışma
  if (Random().nextDouble() < 0.1) {
    await Future.delayed(const Duration(milliseconds: 200));
    await _blinkController.forward();
    await Future.delayed(const Duration(milliseconds: 50));
    await _blinkController.reverse();
  }

  _startBlinkLoop();
}
```

- [ ] **Step 5: Saccade (bakış) loop'u**

```dart
void _startSaccadeLoop() {
  Future.delayed(Duration(seconds: 4 + Random().nextInt(3)), () {
    if (!mounted) return;
    _updateGaze();
    _startSaccadeLoop();
  });
}

void _updateGaze() {
  final rng = Random();
  Offset newTarget;

  switch (widget.state) {
    case FaceState.idle:
      newTarget = Offset(
        (rng.nextDouble() - 0.5) * 0.4,
        (rng.nextDouble() - 0.5) * 0.3,
      );
      break;
    case FaceState.listening:
      newTarget = Offset((rng.nextDouble() - 0.5) * 0.1, -0.15);
      break;
    case FaceState.thinking:
      newTarget = Offset(-0.2 + rng.nextDouble() * 0.1, 0.15);
      break;
    case FaceState.speaking:
      newTarget = Offset((rng.nextDouble() - 0.5) * 0.05, 0.0);
      break;
  }

  _saccadeAnim = Tween(begin: _targetGaze, end: newTarget).animate(
    CurvedAnimation(parent: _saccadeController, curve: Curves.easeInOut),
  );
  _targetGaze = newTarget;
  _saccadeController.forward(from: 0);
}
```

- [ ] **Step 6: didUpdateWidget — state/mood değişim tepkileri**

```dart
@override
void didUpdateWidget(RealisticEyeWidget oldWidget) {
  super.didUpdateWidget(oldWidget);

  // Mood renk geçişi
  if (oldWidget.mood != widget.mood) {
    _irisColorAnim = ColorTween(
      begin: _irisColorAnim.value ?? MoodColors.getColor(oldWidget.mood),
      end: MoodColors.getColor(widget.mood),
    ).animate(_irisColorController);
    _irisColorController.forward(from: 0);
    _updateMoodEffects();
  }

  // State değişimi → pupil ve droop güncelle
  if (oldWidget.state != widget.state) {
    _updateStateEffects();
    _updateGaze(); // bakışı hemen güncelle
  }
}

void _updateStateEffects() {
  double newPupilScale;
  switch (widget.state) {
    case FaceState.idle:
      newPupilScale = 1.0;
      _lidDroop = 0.0;
      break;
    case FaceState.listening:
      newPupilScale = 1.2;
      _lidDroop = 0.0;
      break;
    case FaceState.thinking:
      newPupilScale = 0.85;
      _lidDroop = 0.0;
      break;
    case FaceState.speaking:
      newPupilScale = 1.05;
      _lidDroop = 0.0;
      break;
  }

  _pupilAnim = Tween(begin: _targetPupilScale, end: newPupilScale).animate(
    CurvedAnimation(parent: _pupilController, curve: Curves.easeOut),
  );
  _targetPupilScale = newPupilScale;
  _pupilController.forward(from: 0);
}

void _updateMoodEffects() {
  switch (widget.mood.toLowerCase()) {
    case 'sad':
      _lidDroop = 0.5;
      break;
    case 'angry':
      _targetPupilScale *= 0.85;
      _lidDroop = 0.0;
      break;
    case 'excited':
    case 'curious':
      _targetPupilScale *= 1.1;
      _lidDroop = 0.0;
      break;
    default:
      _lidDroop = 0.0;
  }
}
```

- [ ] **Step 7: build() — iki göz layout**

```dart
@override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: Listenable.merge([
      _blinkController, _pupilController, _saccadeController,
      _irisColorController, _shimmerController, _breathController,
    ]),
    builder: (context, child) {
      final breathScale = 1.0 + (_breathController.value - 0.5) * 0.03;
      final shimmerAngle = _shimmerController.value * 2 * pi;
      final wetness = 0.7 + sin(_shimmerController.value * 2 * pi) * 0.3;
      final pupilScale = _pupilAnim.value * breathScale;
      final gaze = _saccadeAnim.value;
      final irisColor = _irisColorAnim.value ?? MoodColors.getColor(widget.mood);

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sol göz
          Expanded(
            flex: 3,
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: RealisticEyePainter(
                  blinkValue: _blinkAnim.value,
                  pupilScale: pupilScale * 1.02, // sol göz %2 büyük (anisocoria)
                  gazeOffset: gaze,
                  irisColor: irisColor,
                  shimmerAngle: shimmerAngle,
                  wetness: wetness,
                  lidDroop: _lidDroop,
                  isLeftEye: true,
                  bloodVessels: _leftBloodVessels,
                  irisFibers: _leftIrisFibers,
                  upperLashes: _leftUpperLashes,
                  lowerLashes: _leftLowerLashes,
                  irisCrypts: _leftCrypts,
                ),
              ),
            ),
          ),
          // Burun köprüsü boşluğu
          const Spacer(flex: 1),
          // Sağ göz
          Expanded(
            flex: 3,
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: RealisticEyePainter(
                  blinkValue: _blinkAnim.value,
                  pupilScale: pupilScale,
                  gazeOffset: gaze,
                  irisColor: irisColor,
                  shimmerAngle: shimmerAngle,
                  wetness: wetness,
                  lidDroop: _lidDroop,
                  isLeftEye: false,
                  bloodVessels: _rightBloodVessels,
                  irisFibers: _rightIrisFibers,
                  upperLashes: _rightUpperLashes,
                  lowerLashes: _rightLowerLashes,
                  irisCrypts: _rightCrypts,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
```

- [ ] **Step 8: dispose()**

```dart
@override
void dispose() {
  _blinkController.dispose();
  _pupilController.dispose();
  _saccadeController.dispose();
  _irisColorController.dispose();
  _shimmerController.dispose();
  _breathController.dispose();
  super.dispose();
}
```

- [ ] **Step 9: Derleme kontrolü**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 10: Commit**

```bash
git add lib/features/face/themes/realistic_eye.dart
git commit -m "feat: add RealisticEyeWidget with dual-eye layout and animations"
```

---

### Task 4: face_screen.dart'ı yeni göz widget'ıyla entegre et

**Files:**
- Modify: `lib/features/face/face_screen.dart`

- [ ] **Step 1: Import'u güncelle ve RealisticEyeWidget'ı bağla**

`face_screen.dart` dosyasında:
- Import: `import 'themes/realistic_eye.dart';` (zaten Step 4'te eklendi)
- Satır 78-84 civarındaki `Positioned.fill` içindeki `Placeholder()` veya eski `EyeThemeManager.getTheme(...)` çağrısını değiştir:

```dart
// EYE — iki gerçekçi göz
Positioned(
  top: MediaQuery.of(context).size.height * 0.15,
  bottom: MediaQuery.of(context).size.height * 0.25,
  left: MediaQuery.of(context).size.width * 0.1,
  right: MediaQuery.of(context).size.width * 0.1,
  child: RealisticEyeWidget(
    state: controller.faceState,
    mood: controller.currentMood,
  ),
),
```

- [ ] **Step 2: Arkaplan glow güncelle**

`_getMoodGlowIntensity` değerlerini spec'e göre güncelle:
```dart
double _getMoodGlowIntensity(FaceState state) {
  switch (state) {
    case FaceState.speaking:
      return 0.08;
    case FaceState.listening:
      return 0.05;
    case FaceState.thinking:
      return 0.04;
    case FaceState.idle:
      return 0.02;
  }
}
```

- [ ] **Step 3: Response bubble'a glassmorphism**

`_buildResponseBubble` içindeki Container decoration'ı güncelle:
```dart
decoration: BoxDecoration(
  color: Colors.white.withOpacity(0.06),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: Colors.white.withOpacity(0.15)),
  boxShadow: [
    BoxShadow(
      color: moodColor.withOpacity(0.05),
      blurRadius: 20,
    ),
  ],
),
```

- [ ] **Step 4: Derleme kontrolü**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/features/face/face_screen.dart
git commit -m "feat: integrate RealisticEyeWidget into face screen with glassmorphism UI"
```

---

### Task 5: Spec'teki eksik animasyon detayları

**Files:**
- Modify: `lib/features/face/themes/realistic_eye.dart`

- [ ] **Step 1: Mikro-saccade ekle (0.5-2s arası ±%1 titreşim)**

`_RealisticEyeWidgetState`'e bir mikro-saccade timer ekle. `_startSaccadeLoop` yanına:

```dart
void _startMicroSaccadeLoop() {
  Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1500)), () {
    if (!mounted) return;
    setState(() {
      _microJitter = Offset(
        (Random().nextDouble() - 0.5) * 0.02,
        (Random().nextDouble() - 0.5) * 0.02,
      );
    });
    _startMicroSaccadeLoop();
  });
}
```

`build()` içinde gaze offset'e `_microJitter` ekle:
```dart
final gaze = _saccadeAnim.value + _microJitter;
```

- [ ] **Step 2: Kırpışma asimetrisi (10-20ms fark)**

`_blinkAnim.value` yerine sol/sağ göze farklı değer ver. Sağ göze 15ms delay:

Widget'a `_rightBlinkDelay` field'ı ekle ve build'de sağ göz için `blinkValue` hesapla:
```dart
// build() içinde:
final rightBlinkValue = (_blinkAnim.value - 0.05).clamp(0.0, 1.0);
// Sol göz: _blinkAnim.value, Sağ göz: rightBlinkValue
```

- [ ] **Step 3: Kırpışma sonrası ıslaklık artışı**

`_doBlink()` sonunda wetness'ı geçici artır:
```dart
void _doBlink() async {
  // ... mevcut blink kodu ...
  // Blink sonrası ıslaklık
  _postBlinkWetBoost = 1.0;
  Future.delayed(const Duration(milliseconds: 500), () {
    if (mounted) setState(() => _postBlinkWetBoost = 0.0);
  });
  _startBlinkLoop();
}
```

build'de: `final wetness = 0.7 + sin(...) * 0.3 + _postBlinkWetBoost * 0.3;`

- [ ] **Step 4: Speaking ritmik pupil ve thinking mikro-titreşim**

Speaking state için breathController'a ek ritmik oscillation ekle:
```dart
// build() içinde:
double extraPupilOscillation = 0.0;
if (widget.state == FaceState.speaking) {
  extraPupilOscillation = sin(_breathController.value * 4 * pi) * 0.05;
} else if (widget.state == FaceState.thinking) {
  extraPupilOscillation = (Random().nextDouble() - 0.5) * 0.03;
}
final pupilScale = _pupilAnim.value * breathScale + extraPupilOscillation;
```

- [ ] **Step 5: Burun köprüsü gölgesi**

`build()` içinde Spacer yerine gölgeli Container:
```dart
// Burun köprüsü gölgesi
Expanded(
  flex: 1,
  child: Container(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [
          const Color(0xFF0A0805).withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ),
    ),
  ),
),
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/face/themes/realistic_eye.dart
git commit -m "feat: add micro-saccade, blink asymmetry, post-blink wetness, speaking rhythm"
```

---

### Task 6: Son doğrulama ve polish

- [ ] **Step 1: flutter analyze**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: Uygulamayı cihazda çalıştır ve görsel kontrol**

Run: `flutter run --dart-define=GEMINI_API_KEY=...`

Kontrol listesi:
- İki göz ekranda göründü mü?
- Kırpışma animasyonu çalışıyor mu?
- Bakış hareketi var mı?
- Mood değişiminde iris rengi değişiyor mu?
- State geçişlerinde pupil boyutu değişiyor mu?
- Kirpikler görünüyor mu?
- Kan damarları ince şekilde görünüyor mu?
- Iris fiber dokusu var mı?
- Cornea yansımaları parlıyor mu?
- 60fps'te akıcı mı?

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete ultra-realistic eye redesign"
```

---

## Notlar

- Tüm yeni kodda `withOpacity()` yerine `withValues(alpha:)` kullanılmalı (mevcut codebase convention'ı)
- Prosedürel veri tipleri (BloodVessel, IrisFiber, Lash, Crypt) public olmalı — realistic_eye.dart'tan erişilebilir olması için
- `dart:math` import'u painter dosyasına eklenmeli
- `CustomPaint` widget'ına `size: Size.infinite` verilmeli
