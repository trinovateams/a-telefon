import 'dart:math';
import 'package:flutter/material.dart';

// ─── Veri sınıfları ───────────────────────────────────────────────────────────

class BloodVessel {
  final Offset start;
  final Offset control1, control2, end;
  final double thickness;
  final double opacity;

  const BloodVessel({
    required this.start,
    required this.control1,
    required this.control2,
    required this.end,
    required this.thickness,
    required this.opacity,
  });
}

class IrisFiber {
  final double angle;
  final double length; // 0..1 (iris yarıçapına oran)
  final double thickness;

  const IrisFiber({
    required this.angle,
    required this.length,
    required this.thickness,
  });
}

class Lash {
  final double position; // 0..1 kapak üzerindeki konum
  final double length;
  final double angle;
  final double curve;

  const Lash({
    required this.position,
    required this.length,
    required this.angle,
    required this.curve,
  });
}

class Crypt {
  final double angle;
  final double distance; // pupil'den uzaklık oranı
  final double size;

  const Crypt({
    required this.angle,
    required this.distance,
    required this.size,
  });
}

// ─── CustomPainter ────────────────────────────────────────────────────────────

class RealisticEyePainter extends CustomPainter {
  final double blinkValue; // 0.0 (açık) → 1.0 (kapalı)
  final double pupilScale; // 1.0 = normal, >1 genişlemiş, <1 daralmış
  final Offset gazeOffset; // -1..1 x,y bakış yönü
  final Color irisColor; // Mood'a göre iris rengi
  final double shimmerAngle; // Islak parlama açısı (radyan)
  final double wetness; // 0..1 ıslaklık yoğunluğu
  final double lidDroop; // 0..1 üst kapak düşüklüğü (sad mood)
  final bool isLeftEye; // Sol/sağ göz (asimetri için)
  final List<BloodVessel> bloodVessels;
  final List<IrisFiber> irisFibers;
  final List<Lash> upperLashes;
  final List<Lash> lowerLashes;
  final List<Crypt> irisCrypts;

  const RealisticEyePainter({
    required this.blinkValue,
    required this.pupilScale,
    required this.gazeOffset,
    required this.irisColor,
    required this.shimmerAngle,
    required this.wetness,
    required this.lidDroop,
    required this.isLeftEye,
    required this.bloodVessels,
    required this.irisFibers,
    required this.upperLashes,
    required this.lowerLashes,
    required this.irisCrypts,
  });

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

  // ─── Şekil ──────────────────────────────────────────────────────────────────

  void _clipToEyeShape(Canvas canvas, Offset center, double w, double h) {
    canvas.clipPath(_getEyePath(center, w, h));
  }

  Path _getEyePath(Offset center, double w, double h) {
    final adjustedH = h * (1.0 - blinkValue); // kırpışmada daralır
    final path = Path();
    // Sol köşe
    path.moveTo(center.dx - w / 2, center.dy);
    // Üst kapak eğrisi
    path.quadraticBezierTo(
      center.dx,
      center.dy - adjustedH / 2,
      center.dx + w / 2,
      center.dy,
    );
    // Alt kapak eğrisi
    path.quadraticBezierTo(
      center.dx,
      center.dy + adjustedH * 0.35,
      center.dx - w / 2,
      center.dy,
    );
    path.close();
    return path;
  }

  // ─── Katmanlar ──────────────────────────────────────────────────────────────

  void _drawSocketShadow(Canvas canvas, Offset center, double w, double h) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1A1410).withValues(alpha: 0.6),
          const Color(0xFF1A1410).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCenter(center: center, width: w * 1.4, height: h * 2.0),
      );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 1.3, height: h * 1.8),
      paint,
    );
  }

  void _drawSkinBase(Canvas canvas, Offset center, double w, double h) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF2A2018), // ten rengi (karanlık ortam)
          Color(0xFF1A1410),
        ],
      ).createShader(
        Rect.fromCenter(center: center, width: w * 1.2, height: h * 1.5),
      );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 1.15, height: h * 1.4),
      paint,
    );
  }

  void _drawSclera(Canvas canvas, Offset center, double w, double h) {
    final scleraRect = Rect.fromCenter(center: center, width: w, height: h);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        radius: 0.8,
        colors: const [
          Color(0xFFF8F4EF),
          Color(0xFFF0E8DF),
          Color(0xFFE0D0C0),
          Color(0xFFCBB8A5),
        ],
        stops: const [0.0, 0.4, 0.75, 1.0],
      ).createShader(scleraRect);
    canvas.drawOval(scleraRect, paint);
  }

  void _drawBloodVessels(Canvas canvas, Offset center, double w, double h) {
    for (final vessel in bloodVessels) {
      final paint = Paint()
        ..color = const Color(0xFFCC4444).withValues(alpha: vessel.opacity)
        ..strokeWidth = vessel.thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final s = Offset(
        center.dx + vessel.start.dx * w / 2,
        center.dy + vessel.start.dy * h / 2,
      );
      final c1 = Offset(
        center.dx + vessel.control1.dx * w / 2,
        center.dy + vessel.control1.dy * h / 2,
      );
      final c2 = Offset(
        center.dx + vessel.control2.dx * w / 2,
        center.dy + vessel.control2.dy * h / 2,
      );
      final e = Offset(
        center.dx + vessel.end.dx * w / 2,
        center.dy + vessel.end.dy * h / 2,
      );

      final path = Path()
        ..moveTo(s.dx, s.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
      canvas.drawPath(path, paint);
    }
  }

  void _drawIris(Canvas canvas, Offset center, double w, double h) {
    final irisRadius = w * 0.18;
    final gazeX = gazeOffset.dx * w * 0.06;
    final gazeY = gazeOffset.dy * h * 0.06;
    final irisCenter = Offset(center.dx + gazeX, center.dy + gazeY);

    // 1. Ana iris gradyenti
    final irisPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          irisColor.withValues(alpha: 0.9),
          irisColor,
          Color.lerp(irisColor, Colors.brown.shade900, 0.5)!,
          const Color(0xFF2A1A0A),
        ],
        stops: const [0.0, 0.4, 0.8, 1.0],
      ).createShader(
        Rect.fromCircle(center: irisCenter, radius: irisRadius),
      );
    canvas.drawCircle(irisCenter, irisRadius, irisPaint);

    // 2. Limbal halka
    final limbalPaint = Paint()
      ..color = const Color(0xFF1A0E05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = irisRadius * 0.08;
    canvas.drawCircle(irisCenter, irisRadius, limbalPaint);

    // 3. Fiber dokusu (220 radyal çizgi)
    for (final fiber in irisFibers) {
      final fiberPaint = Paint()
        ..color = Color.lerp(irisColor, Colors.white, 0.15)!
            .withValues(alpha: 0.3)
        ..strokeWidth = fiber.thickness
        ..style = PaintingStyle.stroke;

      final innerR = irisRadius * 0.3;
      final outerR = irisRadius * fiber.length;
      final dx1 = irisCenter.dx + innerR * cos(fiber.angle);
      final dy1 = irisCenter.dy + innerR * sin(fiber.angle);
      final dx2 = irisCenter.dx + outerR * cos(fiber.angle);
      final dy2 = irisCenter.dy + outerR * sin(fiber.angle);

      canvas.drawLine(Offset(dx1, dy1), Offset(dx2, dy2), fiberPaint);
    }

    // 4. Collarette halkası
    final collarettePaint = Paint()
      ..color = Color.lerp(irisColor, Colors.orange.shade800, 0.4)!
          .withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = irisRadius * 0.04;
    canvas.drawCircle(irisCenter, irisRadius * 0.42, collarettePaint);

    // 5. Kriptalar
    for (final crypt in irisCrypts) {
      final cryptPaint = Paint()
        ..color = const Color(0xFF1A0E05).withValues(alpha: 0.4);
      final cr = irisRadius * crypt.distance;
      final cx = irisCenter.dx + cr * cos(crypt.angle);
      final cy = irisCenter.dy + cr * sin(crypt.angle);
      canvas.drawCircle(Offset(cx, cy), irisRadius * crypt.size, cryptPaint);
    }
  }

  void _drawPupil(Canvas canvas, Offset center, double w, double h) {
    final irisRadius = w * 0.18;
    final gazeX = gazeOffset.dx * w * 0.06;
    final gazeY = gazeOffset.dy * h * 0.06;
    final pupilCenter = Offset(center.dx + gazeX, center.dy + gazeY);
    final pupilRadius = irisRadius * 0.35 * pupilScale;

    final pupilPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF050505),
          const Color(0xFF0A0805),
          const Color(0xFF150E08).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.75, 1.0],
      ).createShader(
        Rect.fromCircle(center: pupilCenter, radius: pupilRadius),
      );
    canvas.drawCircle(pupilCenter, pupilRadius, pupilPaint);
  }

  void _drawCorneaReflection(Canvas canvas, Offset center, double w, double h) {
    final irisRadius = w * 0.18;
    final gazeX = gazeOffset.dx * w * 0.06;
    final gazeY = gazeOffset.dy * h * 0.06;
    final irisCenter = Offset(center.dx + gazeX, center.dy + gazeY);

    // 1. Ana yansıma
    final mainRefSize = irisRadius * 0.25;
    final mainRefCenter = Offset(
      irisCenter.dx - irisRadius * 0.25 + shimmerAngle * 2,
      irisCenter.dy - irisRadius * 0.3,
    );
    final mainRefPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7 * wetness);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: mainRefCenter,
          width: mainRefSize,
          height: mainRefSize * 1.3,
        ),
        Radius.circular(mainRefSize * 0.25),
      ),
      mainRefPaint,
    );

    // 2. İkincil yansıma
    final secRefCenter = Offset(
      irisCenter.dx + irisRadius * 0.2,
      irisCenter.dy + irisRadius * 0.25,
    );
    final secRefPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4 * wetness);
    canvas.drawCircle(secRefCenter, irisRadius * 0.1, secRefPaint);

    // 3. Genel ıslak parlama
    final wetPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.3 + shimmerAngle * 0.1, -0.3),
        colors: [
          Colors.white.withValues(alpha: 0.15 * wetness),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: irisCenter, radius: irisRadius * 1.2),
      );
    canvas.drawCircle(irisCenter, irisRadius * 1.2, wetPaint);
  }

  void _drawLidShadow(Canvas canvas, Offset center, double w, double h) {
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          const Color(0xFF1A1410).withValues(alpha: 0.5),
          const Color(0xFF1A1410).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCenter(center: center, width: w, height: h),
      );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - h * 0.15),
        width: w,
        height: h * 0.4,
      ),
      shadowPaint,
    );
  }

  void _drawUpperLid(Canvas canvas, Offset center, double w, double h) {
    final adjustedH = h * (1.0 - blinkValue);
    final droopOffset = lidDroop * h * 0.1;

    final lidPath = Path();
    lidPath.moveTo(center.dx - w * 0.65, center.dy - h * 0.3);
    lidPath.quadraticBezierTo(
      center.dx,
      center.dy - h * 0.9 + droopOffset,
      center.dx + w * 0.65,
      center.dy - h * 0.3,
    );
    lidPath.quadraticBezierTo(
      center.dx,
      center.dy - adjustedH / 2,
      center.dx - w * 0.65,
      center.dy - h * 0.3,
    );
    lidPath.close();

    final lidPaint = Paint()..color = const Color(0xFF2A2018);
    canvas.drawPath(lidPath, lidPaint);

    // Crease çizgisi
    final creasePaint = Paint()
      ..color = const Color(0xFF1A1410).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final creasePath = Path();
    creasePath.moveTo(center.dx - w * 0.5, center.dy - h * 0.35);
    creasePath.quadraticBezierTo(
      center.dx,
      center.dy - h * 0.75 + droopOffset,
      center.dx + w * 0.5,
      center.dy - h * 0.35,
    );
    canvas.drawPath(creasePath, creasePaint);
  }

  void _drawLowerLid(Canvas canvas, Offset center, double w, double h) {
    final adjustedH = h * (1.0 - blinkValue);

    final lidPath = Path();
    lidPath.moveTo(center.dx - w * 0.55, center.dy + h * 0.15);
    lidPath.quadraticBezierTo(
      center.dx,
      center.dy + adjustedH * 0.35,
      center.dx + w * 0.55,
      center.dy + h * 0.15,
    );
    lidPath.quadraticBezierTo(
      center.dx,
      center.dy + h * 0.55,
      center.dx - w * 0.55,
      center.dy + h * 0.15,
    );
    lidPath.close();

    final lidPaint = Paint()..color = const Color(0xFF2A2018);
    canvas.drawPath(lidPath, lidPaint);

    // Waterline
    final waterlinePaint = Paint()
      ..color = const Color(0xFFD4A89A).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final waterlinePath = Path();
    waterlinePath.moveTo(center.dx - w * 0.4, center.dy + adjustedH * 0.3);
    waterlinePath.quadraticBezierTo(
      center.dx,
      center.dy + adjustedH * 0.38,
      center.dx + w * 0.4,
      center.dy + adjustedH * 0.3,
    );
    canvas.drawPath(waterlinePath, waterlinePaint);
  }

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
      final t = lash.position;
      final y = center.dy - adjustedH / 2 * sin(t * pi);

      final tipX = x + cos(lash.angle) * lash.length * w * 0.05;
      final tipY = y - sin(lash.angle) * lash.length * w * 0.05;
      final ctrlX = x + cos(lash.angle) * lash.length * w * 0.025;
      final ctrlY =
          y - sin(lash.angle) * lash.length * w * 0.04 * (1 + lash.curve);

      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(ctrlX, ctrlY, tipX, tipY);
      canvas.drawPath(path, lashPaint);
    }

    // Alt kirpikler
    final lowerLashPaint = Paint()
      ..color = const Color(0xFF0A0805).withValues(alpha: 0.7)
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

  // ─── Prosedürel veri üreticiler ───────────────────────────────────────────

  static List<BloodVessel> generateBloodVessels(Random rng) {
    return List.generate(10, (i) {
      final angle = rng.nextDouble() * 2 * pi;
      final startR = 0.7 + rng.nextDouble() * 0.3;
      final endR = 0.2 + rng.nextDouble() * 0.3;
      return BloodVessel(
        start: Offset(cos(angle) * startR, sin(angle) * startR),
        control1: Offset(
          cos(angle + 0.1) * (startR - 0.15),
          sin(angle + 0.1) * (startR - 0.15),
        ),
        control2: Offset(
          cos(angle - 0.05) * (endR + 0.15),
          sin(angle - 0.05) * (endR + 0.15),
        ),
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
      final t = (i + 1) / 19;
      return Lash(
        position: t,
        length: 0.6 +
            rng.nextDouble() * 0.4 +
            (t > 0.4 && t < 0.7 ? 0.2 : 0),
        angle: 1.2 + (t - 0.5) * 0.8,
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
}
