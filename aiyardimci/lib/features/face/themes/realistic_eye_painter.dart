import 'dart:math';
import 'package:flutter/material.dart';

class IrisFiber {
  final double angle;
  final double length;
  final double thickness;

  const IrisFiber({
    required this.angle,
    required this.length,
    required this.thickness,
  });
}

class Crypt {
  final double angle;
  final double distance;
  final double size;

  const Crypt({
    required this.angle,
    required this.distance,
    required this.size,
  });
}

/// Siyah zemin üzerinde yüzen göz — sadece iris + pupil + yansıma.
class RealisticEyePainter extends CustomPainter {
  final double pupilScale;     // 1.0 normal, >1 genişlemiş
  final Offset gazeOffset;     // -1..1 bakış yönü
  final Color irisColor;       // Mood rengi
  final double shimmerAngle;   // Işık açısı
  final double wetness;        // 0..1 parlaklık
  final double glowPulse;      // 0..1 dış ışıma nabzı
  final List<IrisFiber> irisFibers;
  final List<Crypt> irisCrypts;

  const RealisticEyePainter({
    required this.pupilScale,
    required this.gazeOffset,
    required this.irisColor,
    required this.shimmerAngle,
    required this.wetness,
    required this.glowPulse,
    required this.irisFibers,
    required this.irisCrypts,
  });

  @override
  bool shouldRepaint(RealisticEyePainter old) {
    return old.pupilScale != pupilScale ||
        old.gazeOffset != gazeOffset ||
        old.irisColor != irisColor ||
        old.shimmerAngle != shimmerAngle ||
        old.wetness != wetness ||
        old.glowPulse != glowPulse;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final irisRadius = size.width * 0.45;

    final gazeX = gazeOffset.dx * irisRadius * 0.08;
    final gazeY = gazeOffset.dy * irisRadius * 0.08;
    final irisCenter = Offset(center.dx + gazeX, center.dy + gazeY);

    _drawOuterGlow(canvas, irisCenter, irisRadius);
    _drawIris(canvas, irisCenter, irisRadius);
    _drawFibers(canvas, irisCenter, irisRadius);
    _drawCrypts(canvas, irisCenter, irisRadius);
    _drawCollarette(canvas, irisCenter, irisRadius);
    _drawLimbalRing(canvas, irisCenter, irisRadius);
    _drawPupil(canvas, irisCenter, irisRadius);
    _drawReflections(canvas, irisCenter, irisRadius);
  }

  void _drawOuterGlow(Canvas canvas, Offset center, double r) {
    final glowIntensity = 0.12 + glowPulse * 0.18;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          irisColor.withValues(alpha: glowIntensity),
          irisColor.withValues(alpha: glowIntensity * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.6));
    canvas.drawCircle(center, r * 1.6, paint);
  }

  void _drawIris(Canvas canvas, Offset center, double r) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.15, -0.2),
        colors: [
          Color.lerp(irisColor, Colors.white, 0.25)!,
          irisColor,
          Color.lerp(irisColor, Colors.black, 0.45)!,
          const Color(0xFF080808),
        ],
        stops: const [0.0, 0.35, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, paint);
  }

  void _drawFibers(Canvas canvas, Offset center, double r) {
    for (final fiber in irisFibers) {
      final paint = Paint()
        ..color = Color.lerp(irisColor, Colors.white, 0.2)!
            .withValues(alpha: 0.22)
        ..strokeWidth = fiber.thickness
        ..style = PaintingStyle.stroke;

      final innerR = r * 0.28;
      final outerR = r * fiber.length;
      canvas.drawLine(
        Offset(center.dx + innerR * cos(fiber.angle), center.dy + innerR * sin(fiber.angle)),
        Offset(center.dx + outerR * cos(fiber.angle), center.dy + outerR * sin(fiber.angle)),
        paint,
      );
    }
  }

  void _drawCrypts(Canvas canvas, Offset center, double r) {
    for (final crypt in irisCrypts) {
      final paint = Paint()
        ..color = const Color(0xFF0A0A0A).withValues(alpha: 0.35);
      final cr = r * crypt.distance;
      canvas.drawCircle(
        Offset(center.dx + cr * cos(crypt.angle), center.dy + cr * sin(crypt.angle)),
        r * crypt.size,
        paint,
      );
    }
  }

  void _drawCollarette(Canvas canvas, Offset center, double r) {
    final paint = Paint()
      ..color = Color.lerp(irisColor, Colors.orange.shade900, 0.5)!
          .withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03;
    canvas.drawCircle(center, r * 0.42, paint);
  }

  void _drawLimbalRing(Canvas canvas, Offset center, double r) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF050505).withValues(alpha: 0.6),
          const Color(0xFF020202),
        ],
        stops: const [0.7, 0.88, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, paint);
  }

  void _drawPupil(Canvas canvas, Offset center, double r) {
    final pupilR = r * 0.32 * pupilScale;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF000000),
          const Color(0xFF050505),
          const Color(0xFF0D0A08).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: pupilR));
    canvas.drawCircle(center, pupilR, paint);
  }

  void _drawReflections(Canvas canvas, Offset center, double r) {
    // Ana yansıma (köşeli dikdörtgen)
    final mainCenter = Offset(
      center.dx - r * 0.22 + shimmerAngle * 3,
      center.dy - r * 0.28,
    );
    final mainSize = r * 0.18;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: mainCenter, width: mainSize, height: mainSize * 1.4),
        Radius.circular(mainSize * 0.3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.72 * wetness),
    );

    // Küçük ikincil yansıma
    canvas.drawCircle(
      Offset(center.dx + r * 0.22, center.dy + r * 0.24),
      r * 0.08,
      Paint()..color = Colors.white.withValues(alpha: 0.38 * wetness),
    );

    // Islak genel parlaklık
    final wetPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.25 + shimmerAngle * 0.05, -0.25),
        colors: [
          Colors.white.withValues(alpha: 0.10 * wetness),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, wetPaint);
  }

  // ─── Statik üreticiler ────────────────────────────────────────────────────

  static List<IrisFiber> generateIrisFibers(Random rng) {
    return List.generate(240, (i) {
      return IrisFiber(
        angle: (i / 240) * 2 * pi + (rng.nextDouble() - 0.5) * 0.025,
        length: 0.6 + rng.nextDouble() * 0.38,
        thickness: 0.25 + rng.nextDouble() * 0.45,
      );
    });
  }

  static List<Crypt> generateCrypts(Random rng) {
    return List.generate(22, (i) {
      return Crypt(
        angle: rng.nextDouble() * 2 * pi,
        distance: 0.42 + rng.nextDouble() * 0.42,
        size: 0.018 + rng.nextDouble() * 0.028,
      );
    });
  }
}
