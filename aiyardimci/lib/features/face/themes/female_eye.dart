import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/enums/face_state.dart';
import '../../../core/constants/app_constants.dart';

class FemaleEyeTheme extends StatefulWidget {
  final FaceState state;
  final String mood;

  const FemaleEyeTheme({super.key, required this.state, required this.mood});

  @override
  State<FemaleEyeTheme> createState() => _FemaleEyeThemeState();
}

class _FemaleEyeThemeState extends State<FemaleEyeTheme>
    with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _moveController;
  late AnimationController _shimmerController;
  late Animation<double> _blinkAnimation;
  late Animation<double> _moveAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.05).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _moveAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _startBlinkLoop();
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 3 + Random().nextInt(3)));
      if (!mounted) return;
      await _blinkController.forward();
      await Future.delayed(const Duration(milliseconds: 100));
      await _blinkController.reverse();
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _moveController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = MoodColors.getColor(widget.mood);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _blinkAnimation,
        _moveAnimation,
        _shimmerAnimation,
      ]),
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEye(moodColor, isLeft: true),
            const SizedBox(width: 50),
            _buildEye(moodColor, isLeft: false),
          ],
        );
      },
    );
  }

  Widget _buildEye(Color moodColor, {required bool isLeft}) {
    return SizedBox(
      width: 110,
      height: 110,
      child: CustomPaint(
        painter: _FemaleEyePainter(
          color: moodColor,
          blinkValue: _blinkAnimation.value,
          moveValue: _moveAnimation.value,
          shimmerValue: _shimmerAnimation.value,
          state: widget.state,
          isLeft: isLeft,
        ),
      ),
    );
  }
}

class _FemaleEyePainter extends CustomPainter {
  final Color color;
  final double blinkValue;
  final double moveValue;
  final double shimmerValue;
  final FaceState state;
  final bool isLeft;

  _FemaleEyePainter({
    required this.color,
    required this.blinkValue,
    required this.moveValue,
    required this.shimmerValue,
    required this.state,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eyeWidth = size.width * 0.85;
    final eyeHeight = size.height * 0.45 * blinkValue;

    // Eye shape (almond)
    final eyePath = Path();
    eyePath.moveTo(center.dx - eyeWidth / 2, center.dy);
    eyePath.quadraticBezierTo(
      center.dx, center.dy - eyeHeight, center.dx + eyeWidth / 2, center.dy);
    eyePath.quadraticBezierTo(
      center.dx, center.dy + eyeHeight, center.dx - eyeWidth / 2, center.dy);
    eyePath.close();

    // White fill
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawPath(eyePath, whitePaint);

    // Eye outline
    final outlinePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(eyePath, outlinePaint);

    if (blinkValue > 0.3) {
      // Iris
      final irisCenter = Offset(
        center.dx + moveValue * eyeWidth * 0.2,
        center.dy,
      );
      final irisRadius = eyeHeight * 0.65;

      canvas.save();
      canvas.clipPath(eyePath);

      final irisPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.8),
            color,
            color.withValues(alpha: 0.5),
          ],
        ).createShader(
            Rect.fromCircle(center: irisCenter, radius: irisRadius));
      canvas.drawCircle(irisCenter, irisRadius, irisPaint);

      // Pupil
      final pupilPaint = Paint()..color = Colors.black;
      canvas.drawCircle(irisCenter, irisRadius * 0.4, pupilPaint);

      // Shimmer highlight
      final shimmerPaint = Paint()
        ..color = Colors.white.withValues(alpha: shimmerValue);
      canvas.drawCircle(
        Offset(irisCenter.dx - irisRadius * 0.3,
            irisCenter.dy - irisRadius * 0.3),
        irisRadius * 0.2,
        shimmerPaint,
      );
      // Second smaller highlight
      canvas.drawCircle(
        Offset(irisCenter.dx + irisRadius * 0.15,
            irisCenter.dy + irisRadius * 0.15),
        irisRadius * 0.1,
        shimmerPaint,
      );

      canvas.restore();
    }

    // Eyelashes (top)
    if (blinkValue > 0.5) {
      final lashPaint = Paint()
        ..color = Colors.black87
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < 5; i++) {
        final t = (i + 1) / 6;
        final point = _getPointOnQuadBezier(
          Offset(center.dx - eyeWidth / 2, center.dy),
          Offset(center.dx, center.dy - eyeHeight),
          Offset(center.dx + eyeWidth / 2, center.dy),
          t,
        );
        final angle = isLeft ? -0.3 - t * 0.5 : -0.8 + t * 0.5;
        final lashLength = 12.0 + sin(t * pi) * 8;
        canvas.drawLine(
          point,
          Offset(
            point.dx + cos(angle) * lashLength,
            point.dy + sin(angle) * lashLength,
          ),
          lashPaint,
        );
      }
    }
  }

  Offset _getPointOnQuadBezier(Offset p0, Offset p1, Offset p2, double t) {
    final x = (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx;
    final y = (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _FemaleEyePainter old) => true;
}
