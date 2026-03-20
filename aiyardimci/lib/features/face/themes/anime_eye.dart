import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/enums/face_state.dart';
import '../../../core/constants/app_constants.dart';

class AnimeEyeTheme extends StatefulWidget {
  final FaceState state;
  final String mood;

  const AnimeEyeTheme({super.key, required this.state, required this.mood});

  @override
  State<AnimeEyeTheme> createState() => _AnimeEyeThemeState();
}

class _AnimeEyeThemeState extends State<AnimeEyeTheme>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late AnimationController _blinkController;
  late Animation<double> _rotateAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      _rotateController,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.08).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _startBlinkLoop();
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 3 + Random().nextInt(5)));
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  @override
  void didUpdateWidget(AnimeEyeTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    final speed = MoodAnimationSpeed.getSpeed(widget.mood);
    _rotateController.duration = Duration(
      milliseconds: (8000 / speed).round(),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = MoodColors.getColor(widget.mood);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _rotateAnimation,
        _pulseAnimation,
        _blinkAnimation,
      ]),
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEye(moodColor),
            const SizedBox(width: 50),
            _buildEye(moodColor),
          ],
        );
      },
    );
  }

  Widget _buildEye(Color moodColor) {
    return Transform.scale(
      scale: _pulseAnimation.value,
      child: SizedBox(
        width: 100,
        height: 100 * _blinkAnimation.value,
        child: _blinkAnimation.value > 0.3
            ? CustomPaint(
                painter: _AnimeEyePainter(
                  color: moodColor,
                  rotation: _rotateAnimation.value,
                  state: widget.state,
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFCF0000),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
      ),
    );
  }
}

class _AnimeEyePainter extends CustomPainter {
  final Color color;
  final double rotation;
  final FaceState state;

  _AnimeEyePainter({
    required this.color,
    required this.rotation,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Outer red circle
    final outerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF0000),
          const Color(0xFFCF0000),
          const Color(0xFF8B0000),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, outerPaint);

    // Outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFF0000).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 15);
    canvas.drawCircle(center, radius, glowPaint);

    // Rotating pattern (tomoe-inspired, original design)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final patternPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Inner ring
    canvas.drawCircle(Offset.zero, radius * 0.55, patternPaint);

    // Rotating comma shapes (3 of them)
    for (int i = 0; i < 3; i++) {
      final angle = (2 * pi / 3) * i;
      final dotCenter = Offset(
        cos(angle) * radius * 0.55,
        sin(angle) * radius * 0.55,
      );

      final commaPaint = Paint()..color = Colors.black;
      canvas.drawCircle(dotCenter, radius * 0.12, commaPaint);

      // Tail of comma
      final tailPath = Path();
      tailPath.moveTo(dotCenter.dx, dotCenter.dy);
      final tailAngle = angle + pi / 2;
      tailPath.quadraticBezierTo(
        dotCenter.dx + cos(tailAngle) * radius * 0.2,
        dotCenter.dy + sin(tailAngle) * radius * 0.2,
        dotCenter.dx + cos(tailAngle) * radius * 0.3,
        dotCenter.dy + sin(tailAngle) * radius * 0.3,
      );
      final tailPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(tailPath, tailPaint);
    }

    canvas.restore();

    // Central pupil
    final pupilPaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, radius * 0.18, pupilPaint);

    if (state == FaceState.speaking || state == FaceState.listening) {
      final activePaint = Paint()
        ..color = const Color(0xFFFF0000).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 25);
      canvas.drawCircle(center, radius, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimeEyePainter old) => true;
}
