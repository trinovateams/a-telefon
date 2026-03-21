import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/face_state.dart';
import '../../../core/enums/idle_behavior.dart';
import 'realistic_eye_painter.dart';

class RealisticEyeWidget extends StatefulWidget {
  final FaceState state;
  final String mood;
  final IdleBehavior idleBehavior;

  const RealisticEyeWidget({
    super.key,
    required this.state,
    required this.mood,
    this.idleBehavior = IdleBehavior.normal,
  });

  @override
  State<RealisticEyeWidget> createState() => _RealisticEyeWidgetState();
}

class _RealisticEyeWidgetState extends State<RealisticEyeWidget>
    with TickerProviderStateMixin {

  late AnimationController _pupilController;
  late AnimationController _saccadeController;
  late AnimationController _irisColorController;
  late AnimationController _shimmerController;
  late AnimationController _glowController;
  late AnimationController _blinkController;
  late AnimationController _squashController;

  late Animation<double> _pupilAnim;
  late Animation<Offset> _saccadeAnim;
  late Animation<Color?> _irisColorAnim;
  late Animation<double> _blinkAnim;
  late Animation<double> _squashAnim;

  // Prosedürel veriler (sabit seed — sol/sağ göz farklı)
  late final List<IrisFiber> _leftFibers;
  late final List<Crypt> _leftCrypts;
  late final List<IrisFiber> _rightFibers;
  late final List<Crypt> _rightCrypts;

  double _targetPupilScale = 1.0;
  Offset _targetGaze = Offset.zero;
  Offset _microJitter = Offset.zero;
  double _baseSquash = 0.0;

  @override
  void initState() {
    super.initState();
    _initData();
    _initControllers();
    _startSaccadeLoop();
    _startMicroSaccadeLoop();
    _startBlinkLoop();
  }

  void _initData() {
    _leftFibers = RealisticEyePainter.generateIrisFibers(Random(42));
    _leftCrypts = RealisticEyePainter.generateCrypts(Random(42));
    _rightFibers = RealisticEyePainter.generateIrisFibers(Random(137));
    _rightCrypts = RealisticEyePainter.generateCrypts(Random(137));
  }

  void _initControllers() {
    _pupilController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
      duration: const Duration(milliseconds: 700),
    );
    _irisColorAnim = ColorTween(
      begin: MoodColors.getColor(widget.mood),
      end: MoodColors.getColor(widget.mood),
    ).animate(_irisColorController);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Blink controller
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _blinkAnim = Tween(begin: 0.0, end: 0.0).animate(_blinkController);

    // Squash controller (for smooth idle behavior transitions)
    _squashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _squashAnim = Tween(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _squashController, curve: Curves.easeInOut),
    );
  }

  // ─── Blink ───────────────────────────────────────────────────────────────

  void _startBlinkLoop() {
    final delay = 3000 + Random().nextInt(4000); // 3-7 seconds
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      // Don't blink while sleeping (eyes already closed) or during speaking
      if (widget.idleBehavior != IdleBehavior.sleeping &&
          widget.state != FaceState.speaking) {
        _doBlink();
      }
      _startBlinkLoop();
    });
  }

  void _doBlink() {
    final doubleBlink = Random().nextDouble() < 0.2;
    _blinkAnim = TweenSequence<double>(
      doubleBlink
          ? [
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
            ]
          : [
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
            ],
    ).animate(CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut));
    _blinkController.duration = Duration(milliseconds: doubleBlink ? 400 : 250);
    _blinkController.forward(from: 0);
  }

  // ─── Saccade ──────────────────────────────────────────────────────────────

  void _startSaccadeLoop() {
    Future.delayed(Duration(seconds: 3 + Random().nextInt(4)), () {
      if (!mounted) return;
      _updateGaze();
      _startSaccadeLoop();
    });
  }

  void _updateGaze() {
    final rng = Random();
    Offset newTarget;
    switch (widget.state) {
      case FaceState.idle:
        if (widget.idleBehavior == IdleBehavior.sleeping) {
          newTarget = Offset.zero; // No movement when sleeping
        } else if (widget.idleBehavior == IdleBehavior.curious) {
          newTarget = Offset(
              (rng.nextDouble() - 0.5) * 0.7, (rng.nextDouble() - 0.5) * 0.5);
        } else {
          newTarget = Offset(
              (rng.nextDouble() - 0.5) * 0.5, (rng.nextDouble() - 0.5) * 0.4);
        }
        break;
      case FaceState.listening:
        newTarget = Offset((rng.nextDouble() - 0.5) * 0.15, -0.1);
        break;
      case FaceState.thinking:
        newTarget = Offset(-0.25 + rng.nextDouble() * 0.1, 0.1);
        break;
      case FaceState.speaking:
        newTarget = Offset((rng.nextDouble() - 0.5) * 0.06, 0.0);
        break;
    }
    _saccadeAnim = Tween(begin: _targetGaze, end: newTarget).animate(
      CurvedAnimation(parent: _saccadeController, curve: Curves.easeInOut),
    );
    _targetGaze = newTarget;
    _saccadeController.forward(from: 0);
  }

  void _startMicroSaccadeLoop() {
    Future.delayed(Duration(milliseconds: 400 + Random().nextInt(1200)), () {
      if (!mounted) return;
      // Reduce jitter when sleeping
      final jitterAmount = widget.idleBehavior == IdleBehavior.sleeping
          ? 0.005
          : 0.018;
      setState(() {
        _microJitter = Offset(
          (Random().nextDouble() - 0.5) * jitterAmount,
          (Random().nextDouble() - 0.5) * jitterAmount,
        );
      });
      _startMicroSaccadeLoop();
    });
  }

  // ─── State / Mood / IdleBehavior değişimleri ────────────────────────────

  @override
  void didUpdateWidget(RealisticEyeWidget old) {
    super.didUpdateWidget(old);

    if (old.mood != widget.mood) {
      _irisColorAnim = ColorTween(
        begin: _irisColorAnim.value ?? MoodColors.getColor(old.mood),
        end: MoodColors.getColor(widget.mood),
      ).animate(_irisColorController);
      _irisColorController.forward(from: 0);
    }

    if (old.state != widget.state) {
      _applyStateEffects();
      _updateGaze();
      _glowController.duration = widget.state == FaceState.speaking
          ? const Duration(milliseconds: 600)
          : const Duration(seconds: 3);
      _glowController
        ..stop()
        ..repeat(reverse: true);
    }

    if (old.idleBehavior != widget.idleBehavior) {
      _applyIdleBehavior();
    }
  }

  void _applyStateEffects() {
    final scales = {
      FaceState.idle: 1.0,
      FaceState.listening: 1.25,
      FaceState.thinking: 0.80,
      FaceState.speaking: 1.08,
    };
    final newScale = scales[widget.state] ?? 1.0;
    _pupilAnim = Tween(begin: _targetPupilScale, end: newScale).animate(
      CurvedAnimation(parent: _pupilController, curve: Curves.easeOut),
    );
    _targetPupilScale = newScale;
    _pupilController.forward(from: 0);
  }

  void _applyIdleBehavior() {
    double newSquash;
    switch (widget.idleBehavior) {
      case IdleBehavior.sleeping:
        newSquash = 0.65;
        break;
      case IdleBehavior.sleepy:
        newSquash = 0.15;
        break;
      case IdleBehavior.curious:
        // Slightly wider eyes (negative won't work, keep 0)
        newSquash = 0.0;
        break;
      case IdleBehavior.normal:
        newSquash = 0.0;
        break;
    }
    _squashAnim = Tween(begin: _baseSquash, end: newSquash).animate(
      CurvedAnimation(parent: _squashController, curve: Curves.easeInOut),
    );
    _baseSquash = newSquash;
    _squashController.forward(from: 0);

    // Curious = bigger pupils
    if (widget.idleBehavior == IdleBehavior.curious) {
      _pupilAnim = Tween(begin: _targetPupilScale, end: 1.15).animate(
        CurvedAnimation(parent: _pupilController, curve: Curves.easeOut),
      );
      _targetPupilScale = 1.15;
      _pupilController.forward(from: 0);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pupilController,
        _saccadeController,
        _irisColorController,
        _shimmerController,
        _glowController,
        _blinkController,
        _squashController,
      ]),
      builder: (context, _) {
        final shimmerAngle = _shimmerController.value * 2 * pi;
        final wetness = 0.65 + sin(_shimmerController.value * 2 * pi) * 0.35;
        final gaze = _saccadeAnim.value + _microJitter;
        final irisColor = _irisColorAnim.value ?? MoodColors.getColor(widget.mood);
        final glowPulse = _glowController.value;

        double extraOsc = 0.0;
        if (widget.state == FaceState.speaking) {
          extraOsc = sin(_shimmerController.value * 6 * pi) * 0.06;
        } else if (widget.state == FaceState.thinking) {
          extraOsc = sin(_shimmerController.value * 2 * pi) * 0.025;
        }
        final pupilScale = _pupilAnim.value + extraOsc;

        // Combine blink and idle squash
        final blinkSquash = _blinkAnim.value;
        final idleSquash = _squashAnim.value;
        final finalSquash = (blinkSquash + idleSquash).clamp(0.0, 1.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sol göz (anisocoria: %2 büyük)
            Expanded(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: RealisticEyePainter(
                    pupilScale: pupilScale * 1.02,
                    gazeOffset: gaze,
                    irisColor: irisColor,
                    shimmerAngle: shimmerAngle,
                    wetness: wetness,
                    glowPulse: glowPulse,
                    irisFibers: _leftFibers,
                    irisCrypts: _leftCrypts,
                    squash: finalSquash,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48),
            // Sağ göz
            Expanded(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: RealisticEyePainter(
                    pupilScale: pupilScale,
                    gazeOffset: gaze,
                    irisColor: irisColor,
                    shimmerAngle: shimmerAngle,
                    wetness: wetness,
                    glowPulse: glowPulse,
                    irisFibers: _rightFibers,
                    irisCrypts: _rightCrypts,
                    squash: finalSquash,
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
    _pupilController.dispose();
    _saccadeController.dispose();
    _irisColorController.dispose();
    _shimmerController.dispose();
    _glowController.dispose();
    _blinkController.dispose();
    _squashController.dispose();
    super.dispose();
  }
}
