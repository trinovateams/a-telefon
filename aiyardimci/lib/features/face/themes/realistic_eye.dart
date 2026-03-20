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
  late final List<BloodVessel> _leftBloodVessels;
  late final List<IrisFiber> _leftIrisFibers;
  late final List<Lash> _leftUpperLashes;
  late final List<Lash> _leftLowerLashes;
  late final List<Crypt> _leftCrypts;
  late final List<BloodVessel> _rightBloodVessels;
  late final List<IrisFiber> _rightIrisFibers;
  late final List<Lash> _rightUpperLashes;
  late final List<Lash> _rightLowerLashes;
  late final List<Crypt> _rightCrypts;

  // State
  double _targetPupilScale = 1.0;
  Offset _targetGaze = Offset.zero;
  double _lidDroop = 0.0;
  Offset _microJitter = Offset.zero;
  double _postBlinkWetBoost = 0.0;

  @override
  void initState() {
    super.initState();
    _initProceduralData();
    _initControllers();
    _startBlinkLoop();
    _startSaccadeLoop();
    _startMicroSaccadeLoop();
  }

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

  void _initControllers() {
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _blinkAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _blinkController,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
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

  // ─── Kırpışma loop ──────────────────────────────────────────────────────────

  void _startBlinkLoop() {
    Future.delayed(
      Duration(milliseconds: 3000 + Random().nextInt(3000)),
      () {
        if (!mounted) return;
        _doBlink();
      },
    );
  }

  void _doBlink() async {
    if (!mounted) return;
    await _blinkController.forward();
    await Future.delayed(const Duration(milliseconds: 50));
    await _blinkController.reverse();

    // Blink sonrası ıslaklık artışı
    if (mounted) {
      setState(() => _postBlinkWetBoost = 1.0);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _postBlinkWetBoost = 0.0);
      });
    }

    // %10 çift kırpışma
    if (Random().nextDouble() < 0.1) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await _blinkController.forward();
      await Future.delayed(const Duration(milliseconds: 50));
      await _blinkController.reverse();
    }

    _startBlinkLoop();
  }

  // ─── Saccade loop ───────────────────────────────────────────────────────────

  void _startSaccadeLoop() {
    Future.delayed(
      Duration(seconds: 4 + Random().nextInt(3)),
      () {
        if (!mounted) return;
        _updateGaze();
        _startSaccadeLoop();
      },
    );
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

  // ─── Mikro-saccade loop ─────────────────────────────────────────────────────

  void _startMicroSaccadeLoop() {
    Future.delayed(
      Duration(milliseconds: 500 + Random().nextInt(1500)),
      () {
        if (!mounted) return;
        setState(() {
          _microJitter = Offset(
            (Random().nextDouble() - 0.5) * 0.02,
            (Random().nextDouble() - 0.5) * 0.02,
          );
        });
        _startMicroSaccadeLoop();
      },
    );
  }

  // ─── Widget değişim tepkileri ────────────────────────────────────────────────

  @override
  void didUpdateWidget(RealisticEyeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.mood != widget.mood) {
      _irisColorAnim = ColorTween(
        begin: _irisColorAnim.value ?? MoodColors.getColor(oldWidget.mood),
        end: MoodColors.getColor(widget.mood),
      ).animate(_irisColorController);
      _irisColorController.forward(from: 0);
      _updateMoodEffects();
    }

    if (oldWidget.state != widget.state) {
      _updateStateEffects();
      _updateGaze();
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

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _blinkController,
        _pupilController,
        _saccadeController,
        _irisColorController,
        _shimmerController,
        _breathController,
      ]),
      builder: (context, child) {
        final breathScale = 1.0 + (_breathController.value - 0.5) * 0.03;
        final shimmerAngle = _shimmerController.value * 2 * pi;
        final wetness = (0.7 + sin(_shimmerController.value * 2 * pi) * 0.3) +
            _postBlinkWetBoost * 0.3;
        final gaze = _saccadeAnim.value + _microJitter;
        final irisColor =
            _irisColorAnim.value ?? MoodColors.getColor(widget.mood);

        // Speaking ritmik pupil / thinking mikro-titreşim
        double extraPupilOscillation = 0.0;
        if (widget.state == FaceState.speaking) {
          extraPupilOscillation =
              sin(_breathController.value * 4 * pi) * 0.05;
        } else if (widget.state == FaceState.thinking) {
          extraPupilOscillation = (Random().nextDouble() - 0.5) * 0.03;
        }
        final pupilScale =
            _pupilAnim.value * breathScale + extraPupilOscillation;

        // Kırpışma asimetrisi: sağ göz 5 frame gecikmeli
        final rightBlinkValue =
            (_blinkAnim.value - 0.05).clamp(0.0, 1.0);

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
                    pupilScale: pupilScale * 1.02, // anisocoria: sol %2 büyük
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
            // Sağ göz
            Expanded(
              flex: 3,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: RealisticEyePainter(
                    blinkValue: rightBlinkValue,
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
}
