import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/enums/face_state.dart';
import '../../../core/constants/app_constants.dart';

class DefaultEyeTheme extends StatefulWidget {
  final FaceState state;
  final String mood;

  const DefaultEyeTheme({super.key, required this.state, required this.mood});

  @override
  State<DefaultEyeTheme> createState() => _DefaultEyeThemeState();
}

class _DefaultEyeThemeState extends State<DefaultEyeTheme>
    with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _pupilController;
  late AnimationController _breathController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _pupilController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _startBlinkLoop();
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 3000 + Random().nextInt(4000)));
      if (!mounted) return;
      await _blinkController.forward();
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      await _blinkController.reverse();
    }
  }

  @override
  void didUpdateWidget(DefaultEyeTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    final speed = MoodAnimationSpeed.getSpeed(widget.mood);
    _pupilController.duration = Duration(milliseconds: (5000 / speed).round());
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _pupilController.dispose();
    _breathController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: Listenable.merge([
            _blinkController,
            _pupilController,
            _breathController,
            _shimmerController,
          ]),
          builder: (context, child) {
            final blink = Tween<double>(begin: 1.0, end: 0.0)
                .animate(CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut))
                .value;
            final pupilMove = Tween<double>(begin: -1.0, end: 1.0)
                .animate(CurvedAnimation(parent: _pupilController, curve: Curves.easeInOut))
                .value;
            final breath = Tween<double>(begin: 0.96, end: 1.04)
                .animate(CurvedAnimation(parent: _breathController, curve: Curves.easeInOut))
                .value;
            final shimmer = Tween<double>(begin: 0.5, end: 1.0)
                .animate(CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut))
                .value;

            final moodColor = MoodColors.getColor(widget.mood);
            final eyeH = constraints.maxHeight * 0.65;
            final eyeW = constraints.maxWidth * 0.38;
            final gap = constraints.maxWidth * 0.06;
            final centerY = constraints.maxHeight / 2;
            final centerX = constraints.maxWidth / 2;

            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _PhotoRealisticEyePainter(
                blinkValue: blink,
                pupilMove: pupilMove,
                breathScale: breath,
                shimmerValue: shimmer,
                moodColor: moodColor,
                faceState: widget.state,
                leftEyeCenter: Offset(centerX - eyeW / 2 - gap / 2, centerY),
                rightEyeCenter: Offset(centerX + eyeW / 2 + gap / 2, centerY),
                eyeWidth: eyeW,
                eyeHeight: eyeH,
              ),
            );
          },
        );
      },
    );
  }
}

class _PhotoRealisticEyePainter extends CustomPainter {
  final double blinkValue;
  final double pupilMove;
  final double breathScale;
  final double shimmerValue;
  final Color moodColor;
  final FaceState faceState;
  final Offset leftEyeCenter;
  final Offset rightEyeCenter;
  final double eyeWidth;
  final double eyeHeight;

  _PhotoRealisticEyePainter({
    required this.blinkValue,
    required this.pupilMove,
    required this.breathScale,
    required this.shimmerValue,
    required this.moodColor,
    required this.faceState,
    required this.leftEyeCenter,
    required this.rightEyeCenter,
    required this.eyeWidth,
    required this.eyeHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSingleEye(canvas, leftEyeCenter, true);
    _drawSingleEye(canvas, rightEyeCenter, false);
  }

  void _drawSingleEye(Canvas canvas, Offset center, bool isLeft) {
    final w = eyeWidth;
    final h = eyeHeight * blinkValue.clamp(0.02, 1.0);
    final fullH = eyeHeight;

    // === 1. GÖZ ÇUKURU GÖLGESİ ===
    final socketPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

    // Dış gölge
    socketPaint.color = const Color(0xFF0D0D0D);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 1.25, height: fullH * 1.1),
      socketPaint,
    );

    // === 2. GÖZ BEYAZI (SKLERA) ===
    final eyePath = _almondPath(center, w, h);

    canvas.save();
    canvas.clipPath(eyePath);

    // Sklera — gerçekçi renk gradyanı
    final scleraRect = Rect.fromCenter(center: center, width: w, height: fullH);
    final scleraPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: const [
          Color(0xFFF8F4EF), // Merkez — sıcak beyaz
          Color(0xFFF0E8DF), // Orta
          Color(0xFFE0D0C0), // Kenar — hafif ten rengi
          Color(0xFFCBB8A5), // En dış — koyu ten
        ],
        stops: const [0.0, 0.4, 0.75, 1.0],
      ).createShader(scleraRect);
    canvas.drawRect(scleraRect, scleraPaint);

    // Kırmızı damarlar
    _drawBloodVessels(canvas, center, w, h);

    // Göz kenarı iç gölge
    final innerShadow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF4A3020).withValues(alpha: 0.15),
          const Color(0xFF2A1A10).withValues(alpha: 0.35),
        ],
        stops: const [0.0, 0.5, 0.8, 1.0],
      ).createShader(scleraRect);
    canvas.drawRect(scleraRect, innerShadow);

    // === 3. İRİS ===
    final irisRadius = fullH * 0.38 * breathScale;
    final pupilShift = pupilMove * w * 0.04;
    final irisCenter = Offset(center.dx + pupilShift, center.dy);

    // Dinleme modunda iris büyüsün
    final stateScale = faceState == FaceState.listening ? 1.1 :
                       faceState == FaceState.thinking ? 0.92 :
                       faceState == FaceState.speaking ? 1.05 : 1.0;
    final finalR = irisRadius * stateScale;

    _drawDetailedIris(canvas, irisCenter, finalR);

    // === 4. GÖZ BEBEĞİ ===
    final pupilR = finalR * 0.4 * breathScale;
    final pupilPaint = Paint()..color = const Color(0xFF020202);
    canvas.drawCircle(irisCenter, pupilR, pupilPaint);

    // Pupil derinlik gradyanı
    final pupilDepth = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF080808),
          const Color(0xFF000000),
        ],
      ).createShader(Rect.fromCircle(center: irisCenter, radius: pupilR));
    canvas.drawCircle(irisCenter, pupilR, pupilDepth);

    // === 5. IŞIK YANSIMALARI ===
    _drawLightReflections(canvas, irisCenter, finalR, pupilR);

    canvas.restore();

    // === 6. GÖZE KAPAĞLARI & ÇİZGİLER ===
    if (blinkValue > 0.05) {
      _drawEyelids(canvas, center, w, h, fullH);
    }

    // Kapalıyken kapak çizgisi
    if (blinkValue < 0.15) {
      final closedPaint = Paint()
        ..color = const Color(0xFF1A1410)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final closedPath = Path();
      closedPath.moveTo(center.dx - w * 0.48, center.dy);
      closedPath.cubicTo(
        center.dx - w * 0.15, center.dy - fullH * 0.05,
        center.dx + w * 0.15, center.dy - fullH * 0.05,
        center.dx + w * 0.48, center.dy,
      );
      canvas.drawPath(closedPath, closedPaint);
    }

    // === 7. MOOD GLOW ===
    if (faceState == FaceState.speaking || faceState == FaceState.listening) {
      final glowPaint = Paint()
        ..color = moodColor.withValues(alpha: 0.06 * shimmerValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 50);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: w * 1.3, height: fullH * 1.3),
        glowPaint,
      );
    }
  }

  Path _almondPath(Offset center, double w, double h) {
    final path = Path();
    final hw = w / 2;

    // Sol köşe (gözyaşı kanalı — daha yuvarlak)
    path.moveTo(center.dx - hw, center.dy);

    // Üst kapak eğrisi
    path.cubicTo(
      center.dx - hw * 0.55, center.dy - h * 0.52,
      center.dx + hw * 0.45, center.dy - h * 0.55,
      center.dx + hw, center.dy + h * 0.02,
    );

    // Alt kapak eğrisi (daha düz)
    path.cubicTo(
      center.dx + hw * 0.45, center.dy + h * 0.42,
      center.dx - hw * 0.45, center.dy + h * 0.45,
      center.dx - hw, center.dy,
    );

    path.close();
    return path;
  }

  void _drawBloodVessels(Canvas canvas, Offset center, double w, double h) {
    final rng = Random(42);

    for (int i = 0; i < 12; i++) {
      final veinPaint = Paint()
        ..color = Color.fromRGBO(
          180 + rng.nextInt(40),
          80 + rng.nextInt(50),
          80 + rng.nextInt(50),
          0.08 + rng.nextDouble() * 0.12,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3 + rng.nextDouble() * 0.5
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final angle = rng.nextDouble() * 2 * pi;
      final startR = w * (0.25 + rng.nextDouble() * 0.15);
      final startX = center.dx + cos(angle) * startR;
      final startY = center.dy + sin(angle) * startR * 0.6;
      path.moveTo(startX, startY);

      double curX = startX;
      double curY = startY;
      final segments = 3 + rng.nextInt(4);

      for (int j = 0; j < segments; j++) {
        final dx = cos(angle) * (5 + rng.nextDouble() * 10);
        final dy = sin(angle) * (3 + rng.nextDouble() * 6) +
            (rng.nextDouble() - 0.5) * 4;
        curX += dx;
        curY += dy;
        path.lineTo(curX, curY);

        // Dallanma
        if (rng.nextInt(3) == 0) {
          final branchPath = Path();
          branchPath.moveTo(curX, curY);
          branchPath.lineTo(
            curX + (rng.nextDouble() - 0.5) * 8,
            curY + (rng.nextDouble() - 0.5) * 5,
          );
          final branchPaint = Paint()
            ..color = veinPaint.color.withValues(alpha: 0.05)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.2;
          canvas.drawPath(branchPath, branchPaint);
        }
      }
      canvas.drawPath(path, veinPaint);
    }
  }

  void _drawDetailedIris(Canvas canvas, Offset center, double radius) {
    // === Dış iris halkası (limbal ring) ===
    final limbalPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF1A0F05).withValues(alpha: 0.3),
          const Color(0xFF0D0805),
        ],
        stops: const [0.85, 0.93, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, limbalPaint);

    // === İris base renk ===
    final irisBase = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF8B7B3A), // Merkez — altın
          Color(0xFF6B5C2E), // Orta — koyu altın
          Color(0xFF4A3D1E), // Dış — kahverengi
          Color(0xFF2D2412), // En dış — koyu kahve
        ],
        stops: const [0.15, 0.4, 0.7, 0.95],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.97, irisBase);

    // === İris fiber dokusu ===
    final rng = Random(13);
    final fiberCount = 80;

    for (int i = 0; i < fiberCount; i++) {
      final angle = (2 * pi / fiberCount) * i + rng.nextDouble() * 0.04;
      final innerR = radius * (0.2 + rng.nextDouble() * 0.1);
      final outerR = radius * (0.8 + rng.nextDouble() * 0.15);

      final brightness = rng.nextDouble();
      final Color fiberColor;
      if (brightness < 0.3) {
        fiberColor = Color.fromRGBO(160, 140, 60, 0.35 + rng.nextDouble() * 0.2);
      } else if (brightness < 0.6) {
        fiberColor = Color.fromRGBO(100, 80, 30, 0.3 + rng.nextDouble() * 0.25);
      } else {
        fiberColor = Color.fromRGBO(70, 55, 20, 0.25 + rng.nextDouble() * 0.2);
      }

      final fiberPaint = Paint()
        ..color = fiberColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3 + rng.nextDouble() * 0.5;

      canvas.drawLine(
        Offset(center.dx + cos(angle) * innerR, center.dy + sin(angle) * innerR),
        Offset(center.dx + cos(angle) * outerR, center.dy + sin(angle) * outerR),
        fiberPaint,
      );
    }

    // === Collarette (pupil çevresi halka) ===
    final collarettePaint = Paint()
      ..color = const Color(0xFFAA9040).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.03;
    canvas.drawCircle(center, radius * 0.42, collarettePaint);

    // === Kripta desenleri (iris çukurları) ===
    for (int i = 0; i < 20; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = radius * (0.45 + rng.nextDouble() * 0.35);
      final cryptCenter = Offset(
        center.dx + cos(angle) * dist,
        center.dy + sin(angle) * dist,
      );
      final cryptPaint = Paint()
        ..color = const Color(0xFF2A1E0A).withValues(alpha: 0.15 + rng.nextDouble() * 0.15);
      canvas.drawCircle(cryptCenter, 1.0 + rng.nextDouble() * 2.0, cryptPaint);
    }

    // === Mood rengi overlay ===
    final moodOverlay = Paint()
      ..color = moodColor.withValues(alpha: 0.08)
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(center, radius * 0.9, moodOverlay);
  }

  void _drawLightReflections(Canvas canvas, Offset center, double irisR, double pupilR) {
    // Ana pencere yansıması (üst sol, dikdörtgenimsi)
    canvas.save();
    canvas.clipRect(Rect.fromCircle(center: center, radius: irisR));

    final mainRefPos = Offset(center.dx - irisR * 0.25, center.dy - irisR * 0.3);
    final mainRefPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75 * shimmerValue);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: mainRefPos, width: pupilR * 0.7, height: pupilR * 0.5),
        const Radius.circular(2),
      ),
      mainRefPaint,
    );

    // İkincil yansıma (alt sağ, küçük daire)
    final secRefPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * shimmerValue);
    canvas.drawCircle(
      Offset(center.dx + irisR * 0.2, center.dy + irisR * 0.18),
      pupilR * 0.12,
      secRefPaint,
    );

    // Cornea (kornea) yansıma ark
    final corneaPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04 * shimmerValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = irisR * 0.08;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: irisR * 0.7),
      -pi * 0.8,
      pi * 0.5,
      false,
      corneaPaint,
    );

    canvas.restore();
  }

  void _drawEyelids(Canvas canvas, Offset center, double w, double h, double fullH) {
    // === ÜST KAPAK GÖLGESİ ===
    final topShadowPath = Path();
    topShadowPath.moveTo(center.dx - w * 0.55, center.dy - h * 0.05);
    topShadowPath.cubicTo(
      center.dx - w * 0.2, center.dy - h * 0.6,
      center.dx + w * 0.25, center.dy - h * 0.63,
      center.dx + w * 0.55, center.dy - h * 0.05,
    );
    topShadowPath.lineTo(center.dx + w * 0.55, center.dy - fullH * 0.5);
    topShadowPath.lineTo(center.dx - w * 0.55, center.dy - fullH * 0.5);
    topShadowPath.close();

    final topShadow = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - h * 0.55),
        Offset(center.dx, center.dy - h * 0.15),
        [
          const Color(0xFF080606).withValues(alpha: 0.0),
          const Color(0xFF080606).withValues(alpha: 0.5),
        ],
      );
    canvas.drawPath(topShadowPath, topShadow);

    // === ÜST KAPAK KIVRIMI (CREASE) ===
    final creasePaint = Paint()
      ..color = const Color(0xFF2A2015).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final creasePath = Path();
    creasePath.moveTo(center.dx - w * 0.45, center.dy - h * 0.08);
    creasePath.cubicTo(
      center.dx - w * 0.15, center.dy - h * 0.55,
      center.dx + w * 0.2, center.dy - h * 0.58,
      center.dx + w * 0.45, center.dy - h * 0.08,
    );
    canvas.drawPath(creasePath, creasePaint);

    // === KİRPİK HATTI (üst) ===
    final lashPaint = Paint()
      ..color = const Color(0xFF0A0805)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final lashPath = _almondPath(center, w, h);
    canvas.drawPath(lashPath, lashPaint);

    // === ALT SU ÇİZGİSİ (waterline) ===
    final waterPaint = Paint()
      ..color = const Color(0xFFD4A8A0).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final waterPath = Path();
    waterPath.moveTo(center.dx - w * 0.42, center.dy + h * 0.02);
    waterPath.cubicTo(
      center.dx - w * 0.15, center.dy + h * 0.38,
      center.dx + w * 0.15, center.dy + h * 0.4,
      center.dx + w * 0.45, center.dy + h * 0.02,
    );
    canvas.drawPath(waterPath, waterPaint);
  }

  @override
  bool shouldRepaint(covariant _PhotoRealisticEyePainter old) => true;
}
