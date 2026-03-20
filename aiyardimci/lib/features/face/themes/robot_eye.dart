import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/enums/face_state.dart';
import '../../../core/constants/app_constants.dart';

class RobotEyeTheme extends StatefulWidget {
  final FaceState state;
  final String mood;

  const RobotEyeTheme({super.key, required this.state, required this.mood});

  @override
  State<RobotEyeTheme> createState() => _RobotEyeThemeState();
}

class _RobotEyeThemeState extends State<RobotEyeTheme>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _glitchController;
  late AnimationController _blinkController;
  late Animation<double> _scanAnimation;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );

    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.05).animate(
      _blinkController,
    );

    _startGlitchLoop();
    _startBlinkLoop();
  }

  void _startGlitchLoop() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 5 + Random().nextInt(8)));
      if (!mounted) return;
      for (int i = 0; i < 3; i++) {
        await _glitchController.forward();
        await _glitchController.reverse();
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 4 + Random().nextInt(6)));
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _glitchController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = MoodColors.getColor(widget.mood);

    return AnimatedBuilder(
      animation: Listenable.merge([_scanAnimation, _blinkAnimation]),
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEye(moodColor),
            const SizedBox(width: 40),
            _buildEye(moodColor),
          ],
        );
      },
    );
  }

  Widget _buildEye(Color moodColor) {
    return Container(
      width: 100,
      height: 70 * _blinkAnimation.value,
      decoration: BoxDecoration(
        border: Border.all(color: moodColor.withValues(alpha: 0.8), width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: moodColor.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: _blinkAnimation.value > 0.3
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CustomPaint(
                painter: _RobotEyePainter(
                  color: moodColor,
                  scanValue: _scanAnimation.value,
                  state: widget.state,
                ),
              ),
            )
          : null,
    );
  }
}

class _RobotEyePainter extends CustomPainter {
  final Color color;
  final double scanValue;
  final FaceState state;

  _RobotEyePainter({
    required this.color,
    required this.scanValue,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Grid lines
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.width; i += 10) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        gridPaint,
      );
    }
    for (double i = 0; i < size.height; i += 10) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        gridPaint,
      );
    }

    // Scan line
    final scanX = (scanValue + 1) / 2 * size.width;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.6),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(scanX - 20, 0, 40, size.height));
    canvas.drawRect(
      Rect.fromLTWH(scanX - 10, 0, 20, size.height),
      scanPaint,
    );

    // Central display (digital pupil)
    final center = Offset(size.width / 2, size.height / 2);
    final displayRadius = min(size.width, size.height) * 0.3;

    // Hexagonal shape
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 6;
      final point = Offset(
        center.dx + cos(angle) * displayRadius,
        center.dy + sin(angle) * displayRadius,
      );
      if (i == 0) {
        hexPath.moveTo(point.dx, point.dy);
      } else {
        hexPath.lineTo(point.dx, point.dy);
      }
    }
    hexPath.close();

    final hexPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hexPath, hexPaint);

    final hexBorderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(hexPath, hexBorderPaint);

    // Center dot
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(center, displayRadius * 0.2, dotPaint);

    // Corner brackets
    final bracketPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final bSize = 8.0;
    // Top-left
    canvas.drawLine(Offset(2, 2), Offset(2, bSize + 2), bracketPaint);
    canvas.drawLine(Offset(2, 2), Offset(bSize + 2, 2), bracketPaint);
    // Top-right
    canvas.drawLine(
        Offset(size.width - 2, 2), Offset(size.width - bSize - 2, 2), bracketPaint);
    canvas.drawLine(
        Offset(size.width - 2, 2), Offset(size.width - 2, bSize + 2), bracketPaint);
    // Bottom-left
    canvas.drawLine(
        Offset(2, size.height - 2), Offset(2, size.height - bSize - 2), bracketPaint);
    canvas.drawLine(
        Offset(2, size.height - 2), Offset(bSize + 2, size.height - 2), bracketPaint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - 2, size.height - 2),
        Offset(size.width - bSize - 2, size.height - 2), bracketPaint);
    canvas.drawLine(Offset(size.width - 2, size.height - 2),
        Offset(size.width - 2, size.height - bSize - 2), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _RobotEyePainter old) => true;
}
