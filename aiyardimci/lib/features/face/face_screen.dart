import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/face_state.dart';
import '../../core/enums/idle_behavior.dart';
import '../../core/enums/connection_state.dart';
import 'face_controller.dart';
import 'themes/cozmo_eye.dart';
import '../settings/settings_screen.dart';

class FaceScreen extends StatefulWidget {
  const FaceScreen({super.key});

  @override
  State<FaceScreen> createState() => _FaceScreenState();
}

class _FaceScreenState extends State<FaceScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  bool _showControls = false;
  bool _showTextInput = false;
  late AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FaceController>().activate();
    });
  }

  @override
  void dispose() {
    _breathController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FaceController>(
      builder: (context, controller, child) {
        final moodColor = MoodColors.getColor(controller.currentMood);

        return Scaffold(
          backgroundColor: const Color(0xFF040A18),
          body: GestureDetector(
            onTap: () {
              setState(() => _showControls = !_showControls);
              if (_showControls) {
                Future.delayed(const Duration(seconds: 5), () {
                  if (mounted && _showControls && !_showTextInput) {
                    setState(() => _showControls = false);
                  }
                });
              }
            },
            child: Stack(
              children: [
                // Ambient background
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: controller.faceState == FaceState.speaking ? 1.5 : 1.2,
                      colors: [
                        moodColor.withValues(alpha: _getMoodGlowIntensity(controller)),
                        Color.lerp(
                          const Color(0xFF040A18),
                          moodColor.withValues(alpha: 0.04),
                          controller.faceState == FaceState.speaking ? 1.0 : 0.0,
                        )!,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),

                // EYE
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.35,
                  bottom: MediaQuery.of(context).size.height * 0.35,
                  left: MediaQuery.of(context).size.width * 0.05,
                  right: MediaQuery.of(context).size.width * 0.05,
                  child: AnimatedBuilder(
                    animation: _breathController,
                    builder: (context, child) {
                      final isSpeaking = controller.faceState == FaceState.speaking;
                      final scale = isSpeaking
                          ? 0.95 + _breathController.value * 0.10
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: CozmoEyeWidget(
                      state: controller.faceState,
                      mood: controller.currentMood,
                      idleBehavior: controller.idleBehavior,
                    ),
                  ),
                ),

                // Status indicator (top)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: _buildStateIndicator(controller, moodColor),
                ),

                // Controls overlay
                if (_showControls)
                  _buildOverlayControls(controller, moodColor),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getMoodGlowIntensity(FaceController controller) {
    // Sleeping = very dim
    if (controller.idleBehavior == IdleBehavior.sleeping) return 0.02;

    switch (controller.faceState) {
      case FaceState.speaking:
        return 0.35;
      case FaceState.listening:
        return 0.12;
      case FaceState.thinking:
        return 0.18;
      case FaceState.idle:
        return 0.05;
    }
  }

  Widget _buildStateIndicator(FaceController controller, Color moodColor) {
    // Connection error takes priority
    if (controller.connectionState == LiveConnectionState.error) {
      return _buildStatusChip(
        'BAĞLANTI HATASI',
        Icons.error_outline_rounded,
        Colors.redAccent,
        onTap: () => controller.resetChat(),
        suffix: '(dokun)',
      );
    }
    if (controller.connectionState == LiveConnectionState.connecting ||
        controller.connectionState == LiveConnectionState.reconnecting) {
      return _buildStatusChip(
        'BAĞLANIYOR...',
        Icons.sync_rounded,
        Colors.orangeAccent,
      );
    }

    String label;
    IconData icon;
    Color color;
    bool showDot = true;

    switch (controller.faceState) {
      case FaceState.idle:
        showDot = false;
        if (controller.idleBehavior == IdleBehavior.sleeping) {
          label = 'zzZ...';
          icon = Icons.nightlight_round;
          color = Colors.indigo.withValues(alpha: 0.7);
        } else if (controller.energy < 0.3) {
          label = 'uykulum...';
          icon = Icons.bedtime_rounded;
          color = Colors.white.withValues(alpha: 0.4);
        } else if (controller.boredom > 0.5) {
          label = 'canım sıkılıyor...';
          icon = Icons.sentiment_dissatisfied_rounded;
          color = Colors.white.withValues(alpha: 0.4);
        } else {
          final name = controller.wakeName.isEmpty ? 'Cozmo' : controller.wakeName;
          label = '"Hey $name" de...';
          icon = Icons.hearing_rounded;
          color = Colors.white.withValues(alpha: 0.3);
        }
        break;
      case FaceState.listening:
        label = 'DİNLİYORUM...';
        icon = Icons.mic_rounded;
        color = moodColor;
        break;
      case FaceState.thinking:
        label = 'DÜŞÜNÜYORUM...';
        icon = Icons.psychology_rounded;
        color = moodColor;
        break;
      case FaceState.speaking:
        label = 'KONUŞUYORUM...';
        icon = Icons.volume_up_rounded;
        color = moodColor;
        break;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status chip
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: controller.faceState == FaceState.idle
                  ? Colors.white.withValues(alpha: 0.05)
                  : moodColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: controller.faceState == FaceState.idle
                    ? Colors.white.withValues(alpha: 0.1)
                    : moodColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDot)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: moodColor,
                      boxShadow: [
                        BoxShadow(
                          color: moodColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Energy bar
          GestureDetector(
            onTap: () => controller.boostEnergy(),
            child: Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: controller.energy.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: controller.energy > 0.5
                        ? moodColor.withValues(alpha: 0.5)
                        : controller.energy > 0.2
                            ? Colors.orangeAccent.withValues(alpha: 0.5)
                            : Colors.redAccent.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, IconData icon, Color color,
      {VoidCallback? onTap, String? suffix}) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
                  ],
                ),
              ),
              Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                color: color, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w500,
              )),
              if (suffix != null) ...[
                const SizedBox(width: 6),
                Text(suffix, style: TextStyle(
                  color: color.withValues(alpha: 0.5), fontSize: 9,
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayControls(FaceController controller, Color moodColor) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showTextInput)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: moodColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Mesaj yaz...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onSubmitted: (text) => _sendTextMessage(controller),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _sendTextMessage(controller),
                        icon: Icon(Icons.send_rounded, color: moodColor, size: 20),
                      ),
                    ],
                  ),
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildControlButton(
                    icon: Icons.keyboard_rounded,
                    color: moodColor,
                    label: 'Yaz',
                    onTap: () {
                      setState(() => _showTextInput = !_showTextInput);
                    },
                    isActive: _showTextInput,
                  ),
                  const SizedBox(width: 16),

                  if (controller.faceState == FaceState.speaking)
                    _buildControlButton(
                      icon: Icons.stop_rounded,
                      color: Colors.redAccent,
                      label: 'Dur',
                      onTap: () => controller.stopSpeaking(),
                    ),

                  if (controller.faceState == FaceState.speaking)
                    const SizedBox(width: 16),

                  _buildControlButton(
                    icon: Icons.refresh_rounded,
                    color: moodColor,
                    label: 'Sıfırla',
                    onTap: () => controller.resetChat(),
                  ),
                  const SizedBox(width: 16),

                  _buildControlButton(
                    icon: Icons.tune_rounded,
                    color: moodColor,
                    label: 'Ayarlar',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isActive
                  ? color.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: isActive
                    ? color.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: isActive ? [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)
              ] : [],
            ),
            child: Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  void _sendTextMessage(FaceController controller) {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      controller.sendTextMessage(text);
      _textController.clear();
      setState(() {
        _showTextInput = false;
        _showControls = false;
      });
    }
  }
}
