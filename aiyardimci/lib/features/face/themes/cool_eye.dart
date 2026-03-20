import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/enums/face_state.dart';
import '../../../core/constants/app_constants.dart';

class CoolEyeTheme extends StatefulWidget {
  final FaceState state;
  final String mood;

  const CoolEyeTheme({super.key, required this.state, required this.mood});

  @override
  State<CoolEyeTheme> createState() => _CoolEyeThemeState();
}

class _CoolEyeThemeState extends State<CoolEyeTheme>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _moveController;
  late AnimationController _blinkController;
  late Animation<double> _glowAnimation;
  late Animation<double> _moveAnimation;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _moveAnimation = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _startBlinkLoop();
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 3 + Random().nextInt(4)));
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _moveController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = MoodColors.getColor(widget.mood);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _glowAnimation,
        _moveAnimation,
        _blinkAnimation,
      ]),
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEye(moodColor, isLeft: true),
            const SizedBox(width: 55),
            _buildEye(moodColor, isLeft: false),
          ],
        );
      },
    );
  }

  Widget _buildEye(Color moodColor, {required bool isLeft}) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: _CoolEyePainter(
          color: moodColor,
          glowIntensity: _glowAnimation.value,
          moveValue: _moveAnimation.value,
          blinkValue: _blinkAnimation.value,
          state: widget.state,
          isLeft: isLeft,
        ),
      ),
    );
  }
}

class _CoolEyePainter extends CustomPainter {
  final Color color;
  final double glowIntensity;
  final double moveValue;
  final double blinkValue;
  final FaceState state;
  final bool isLeft;

  _CoolEyePainter({
    required this.color,
    required this.glowIntensity,
    required this.moveValue,
    required this.blinkValue,
    required this.state,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eyeWidth = size.width * 0.85;
    final eyeHeight = size.height * 0.35 * blinkValue;

    // Narrow, sleek eye shape (half-lidded cool look)
    final eyePath = Path();
    final topLid = isLeft ? 0.7 : 0.7; // Slightly droopy top for cool effect
    eyePath.moveTo(center.dx - eyeWidth / 2, center.dy + eyeHeight * 0.1);
    eyePath.quadraticBezierTo(
      center.dx,
      center.dy - eyeHeight * topLid,
      center.dx + eyeWidth / 2,
      center.dy + eyeHeight * 0.1,
    );
    eyePath.quadraticBezierTo(
      center.dx,
      center.dy + eyeHeight,
      center.dx - eyeWidth / 2,
      center.dy + eyeHeight * 0.1,
    );
    eyePath.close();

    // Neon glow behind eye
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 20);
    canvas.drawPath(eyePath, glowPaint);

    // Black fill
    final fillPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawPath(eyePath, fillPaint);

    // Neon border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(eyePath, borderPaint);

    if (blinkValue > 0.3) {
      canvas.save();
      canvas.clipPath(eyePath);

      // Iris with neon gradient
      final irisCenter = Offset(
        center.dx + moveValue * eyeWidth * 0.2,
        center.dy + eyeHeight * 0.1,
      );
      final irisRadius = eyeHeight * 0.6;

      final neonGradient = Paint()
        ..shader = RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.7),
            Colors.transparent,
          ],
          stops: const [0.3, 0.7, 1.0],
        ).createShader(
            Rect.fromCircle(center: irisCenter, radius: irisRadius * 1.5));
      canvas.drawCircle(irisCenter, irisRadius * 1.5, neonGradient);

      // Bright core
      final corePaint = Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glowIntensity);
      canvas.drawCircle(irisCenter, irisRadius * 0.4, corePaint);

      // Pupil slit (vertical, cat-like for cool effect)
      final slitPaint = Paint()..color = Colors.black;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: irisCenter,
            width: irisRadius * 0.2,
            height: irisRadius * 1.2,
          ),
          const Radius.circular(3),
        ),
        slitPaint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CoolEyePainter old) => true;
}
