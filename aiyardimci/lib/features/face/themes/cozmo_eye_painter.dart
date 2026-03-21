import 'dart:math';
import 'package:flutter/material.dart';

/// Cozmo-style eye — rounded rectangle, flat color, simple pupil, clean reflections.
class CozmoEyePainter extends CustomPainter {
  final double pupilScale;
  final Offset gazeOffset;
  final Color irisColor;
  final double glowPulse;
  final double squash;

  const CozmoEyePainter({
    required this.pupilScale,
    required this.gazeOffset,
    required this.irisColor,
    required this.glowPulse,
    this.squash = 0.0,
  });

  @override
  bool shouldRepaint(CozmoEyePainter old) {
    return old.pupilScale != pupilScale ||
        old.gazeOffset != gazeOffset ||
        old.irisColor != irisColor ||
        old.glowPulse != glowPulse ||
        old.squash != squash;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Eye dimensions — wide rounded rectangle (Cozmo style)
    final eyeWidth = size.width * 0.85;
    final eyeHeight = size.height * 0.75;
    final cornerRadius = eyeHeight * 0.42;

    // Squash — close from top and bottom toward center
    final effectiveHeight = eyeHeight * (1.0 - squash).clamp(0.0, 1.0);
    if (effectiveHeight < 2) return; // Fully closed

    final eyeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: eyeWidth, height: effectiveHeight),
      Radius.circular(cornerRadius * (effectiveHeight / eyeHeight)),
    );

    // 1. Outer glow
    _drawGlow(canvas, center, eyeWidth, effectiveHeight);

    // 2. Eye background (mood color)
    canvas.drawRRect(
      eyeRect,
      Paint()..color = irisColor,
    );

    // 3. Inner gradient for depth
    canvas.drawRRect(
      eyeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.15),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(eyeRect.outerRect),
    );

    // 4. Pupil (black circle) — moves with gaze
    final pupilRadius = effectiveHeight * 0.32 * pupilScale;
    final maxGazeX = (eyeWidth / 2 - pupilRadius - cornerRadius * 0.3);
    final maxGazeY = (effectiveHeight / 2 - pupilRadius) * 0.5;
    final pupilCenter = Offset(
      center.dx + gazeOffset.dx * maxGazeX,
      center.dy + gazeOffset.dy * maxGazeY,
    );

    // Clip pupil to eye shape
    canvas.save();
    canvas.clipRRect(eyeRect);

    // Pupil shadow
    canvas.drawCircle(
      pupilCenter + const Offset(1.5, 1.5),
      pupilRadius * 1.05,
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    // Pupil
    canvas.drawCircle(
      pupilCenter,
      pupilRadius,
      Paint()..color = const Color(0xFF0A0A0A),
    );

    // Pupil subtle gradient
    canvas.drawCircle(
      pupilCenter,
      pupilRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF0A0A0A),
          ],
        ).createShader(Rect.fromCircle(center: pupilCenter, radius: pupilRadius)),
    );

    // 5. Main reflection (bright square-ish highlight — Cozmo signature)
    final reflSize = pupilRadius * 0.6;
    final reflCenter = Offset(
      pupilCenter.dx - pupilRadius * 0.35,
      pupilCenter.dy - pupilRadius * 0.35,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: reflCenter, width: reflSize, height: reflSize * 1.2),
        Radius.circular(reflSize * 0.25),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // 6. Small secondary reflection
    canvas.drawCircle(
      Offset(pupilCenter.dx + pupilRadius * 0.3, pupilCenter.dy + pupilRadius * 0.3),
      pupilRadius * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    canvas.restore();

    // 7. Eye border (subtle)
    canvas.drawRRect(
      eyeRect,
      Paint()
        ..color = irisColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawGlow(Canvas canvas, Offset center, double w, double h) {
    final glowIntensity = 0.08 + glowPulse * 0.15;
    final glowRadius = max(w, h) * 0.9;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            irisColor.withValues(alpha: glowIntensity),
            irisColor.withValues(alpha: glowIntensity * 0.3),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );
  }
}
