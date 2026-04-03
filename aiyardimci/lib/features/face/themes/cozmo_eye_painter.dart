import 'dart:math';
import 'package:flutter/material.dart';

/// Flawless Cozmo-style eye — exact geometry using path combinations
/// Supports brow tilts (angry/sad) and cheek squashes (happy).
class CozmoEyePainter extends CustomPainter {
  final double pupilScale;
  final Offset gazeOffset;
  final Color irisColor;
  final double glowPulse;
  final double squash;
  final double tilt;       // >0 angry (inner down), <0 sad (outer down)
  final double cheekSquash; // >0 happy (cheeks push bottom up)
  final bool isLeftEye;

  const CozmoEyePainter({
    required this.pupilScale,
    required this.gazeOffset,
    required this.irisColor,
    required this.glowPulse,
    this.squash = 0.0,
    this.tilt = 0.0,
    this.cheekSquash = 0.0,
    required this.isLeftEye,
  });

  @override
  bool shouldRepaint(CozmoEyePainter old) {
    return old.pupilScale != pupilScale ||
        old.gazeOffset != gazeOffset ||
        old.irisColor != irisColor ||
        old.glowPulse != glowPulse ||
        old.squash != squash ||
        old.tilt != tilt ||
        old.cheekSquash != cheekSquash ||
        old.isLeftEye != isLeftEye;
  }

  Path _buildEyePath(double w, double h, double r) {
    // 1. Base RRect (Square-ish for Vector/Cozmo)
    final baseRect = Rect.fromLTWH(-w / 2, -h / 2, w, h);
    final baseEyePath = Path()..addRRect(RRect.fromRectAndRadius(baseRect, Radius.circular(r)));

    // 2. Brow Mask (Tilt / Eyebrow raising/lowering)
    double tlY = 0;
    double trY = 0;
    // Dramatic tilt for better expression visibility
    if (tilt > 0) { // Angry / Focused (inner corners down)
      if (isLeftEye) {
        trY = h * tilt * 0.5; 
      } else {
        tlY = h * tilt * 0.5;
      }
    } else if (tilt < 0) { // Sad / Raised brow (outer corners down or just raised)
      if (isLeftEye) {
        tlY = h * (-tilt) * 0.5; 
      } else {
        trY = h * (-tilt) * 0.5; 
      }
    }

    final browMaskPath = Path()
      ..moveTo(-w, -h * 1.5 + tlY) // Top left
      ..lineTo(w, -h * 1.5 + trY)  // Top right
      ..lineTo(w, h * 1.5)         // Bottom right
      ..lineTo(-w, h * 1.5)        // Bottom left
      ..close();

    var finalPath = Path.combine(PathOperation.intersect, baseEyePath, browMaskPath);

    // 3. Cheek Mask (Happy crescent / squinting from bottom)
    if (cheekSquash > 0) {
      final cheekHeight = h * 0.45 * cheekSquash; // Higher squash
      final cheekMaskPath = Path()
        ..moveTo(-w, -h)
        ..lineTo(w, -h)
        ..lineTo(w, h / 2 - cheekHeight)
        ..quadraticBezierTo(0, h / 2 + cheekHeight * 2, -w, h / 2 - cheekHeight)
        ..close();
        
      finalPath = Path.combine(PathOperation.intersect, finalPath, cheekMaskPath);
    }

    return finalPath;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Vector/Cozmo eyes are almost perfect squares. We'll use 0.85 ratio.
    final shortestSide = min(size.width, size.height);
    // Add pulsing scale to the overall eye block
    final dynamicScale = 0.80 + (pupilScale * 0.20);
    // Squarish proportions
    final eyeWidth = shortestSide * dynamicScale * 0.85;
    final eyeHeight = shortestSide * dynamicScale * 0.85; 
    // Soft, wide rounded corners just like Vector
    final cornerRadius = eyeWidth * 0.35;

    // Apply strict vertical squash (for blinking, sleeping, speaking)
    final effectiveHeight = eyeHeight * (1.0 - squash).clamp(0.01, 1.0);

    // gazeOffset moves the *entire eye block*
    final maxShiftX = size.width * 0.18;
    final maxShiftY = size.height * 0.18;
    final gazeShift = Offset(
      gazeOffset.dx * maxShiftX,
      gazeOffset.dy * maxShiftY,
    );

    final finalCenter = center + gazeShift;

    // 1. Extreme outer LED glow (soft blur)
    _drawGlow(canvas, finalCenter, eyeWidth, effectiveHeight);

    canvas.save();
    canvas.translate(finalCenter.dx, finalCenter.dy);

    // Build the dynamic eye shape
    final eyePath = _buildEyePath(eyeWidth, effectiveHeight, cornerRadius * (effectiveHeight/eyeHeight));

    // 2. Main eye color (Flat, solid pure color just like an LED screen!)
    // We add a tiny radial gradient so the center is purely bright, and edges are slightly darker.
    canvas.drawPath(
      eyePath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.1),
            irisColor,
            irisColor.withValues(alpha: 0.78),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromLTWH(-eyeWidth/2, -effectiveHeight/2, eyeWidth, effectiveHeight)),
    );

    // 3. Optional: very faint scanlines to make it look like a robot screen
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.restore();
  }

  void _drawGlow(Canvas canvas, Offset center, double w, double h) {
    // A soft ambient glow that visually mimics the phosphor glow on Cozmo's screen
    final maxD = max(w, h);
    final glowRadius = maxD * 0.9;
    
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            irisColor.withValues(alpha: 0.4 + (glowPulse * 0.2)),
            irisColor.withValues(alpha: 0.1),
            Colors.transparent,
          ],
          stops: const [0.3, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );
  }
}
