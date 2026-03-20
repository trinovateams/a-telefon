import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/face_state.dart';
import 'face_controller.dart';
import 'themes/eye_theme_manager.dart';
import '../settings/settings_screen.dart';

class FaceScreen extends StatefulWidget {
  const FaceScreen({super.key});

  @override
  State<FaceScreen> createState() => _FaceScreenState();
}

class _FaceScreenState extends State<FaceScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _showControls = false;
  bool _showTextInput = false;

  @override
  void initState() {
    super.initState();
    // Uygulama açıldığında sürekli dinlemeyi başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FaceController>().activate();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FaceController>(
      builder: (context, controller, child) {
        final moodColor = MoodColors.getColor(controller.currentMood);

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () {
              setState(() => _showControls = !_showControls);
              // 5 saniye sonra otomatik gizle
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
                // Siyah arka plan + mood glow
                AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.5,
                      colors: [
                        moodColor.withValues(alpha: _getMoodGlowIntensity(controller.faceState)),
                        Colors.black,
                        Colors.black,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),

                // EYE THEME — tam ekran
                Positioned.fill(
                  child: EyeThemeManager.getTheme(
                    controller.currentTheme,
                    controller.faceState,
                    controller.currentMood,
                  ),
                ),

                // Durum göstergesi (üst)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: _buildStateIndicator(controller, moodColor),
                ),

                // Yanıt metni (alt)
                if (controller.lastResponse.isNotEmpty)
                  Positioned(
                    bottom: _showControls ? 80 : 20,
                    left: 40,
                    right: 40,
                    child: _buildResponseBubble(controller, moodColor),
                  ),

                // Kontroller (ekrana dokunulunca görünür)
                if (_showControls)
                  _buildOverlayControls(controller, moodColor),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getMoodGlowIntensity(FaceState state) {
    switch (state) {
      case FaceState.speaking:
        return 0.12;
      case FaceState.listening:
        return 0.08;
      case FaceState.thinking:
        return 0.06;
      case FaceState.idle:
        return 0.02;
    }
  }

  Widget _buildStateIndicator(FaceController controller, Color moodColor) {
    String label = '';
    IconData? icon;

    switch (controller.faceState) {
      case FaceState.idle:
        label = '"Hey Alexia" de...';
        icon = Icons.hearing_rounded;
        break;
      case FaceState.listening:
        label = 'DİNLİYORUM...';
        icon = Icons.mic_rounded;
        break;
      case FaceState.thinking:
        label = 'DÜŞÜNÜYORUM...';
        icon = Icons.psychology_rounded;
        break;
      case FaceState.speaking:
        label = 'KONUŞUYORUM...';
        icon = Icons.volume_up_rounded;
        break;
    }

    return Center(
      child: AnimatedContainer(
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
            if (controller.faceState != FaceState.idle)
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
            Icon(icon, color: moodColor.withValues(alpha: 0.7), size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: controller.faceState == FaceState.idle
                    ? Colors.white.withValues(alpha: 0.3)
                    : moodColor,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseBubble(FaceController controller, Color moodColor) {
    return AnimatedOpacity(
      opacity: controller.faceState == FaceState.speaking ? 1.0 : 0.6,
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: moodColor.withValues(alpha: 0.2)),
        ),
        child: Text(
          controller.lastResponse,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            height: 1.4,
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
              // Text input
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

              // Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Yazı modu
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

                  // Konuşmayı durdur
                  if (controller.faceState == FaceState.speaking)
                    _buildControlButton(
                      icon: Icons.stop_rounded,
                      color: Colors.redAccent,
                      label: 'Dur',
                      onTap: () => controller.stopSpeaking(),
                    ),

                  if (controller.faceState == FaceState.speaking)
                    const SizedBox(width: 16),

                  // Sıfırla
                  _buildControlButton(
                    icon: Icons.refresh_rounded,
                    color: moodColor,
                    label: 'Sıfırla',
                    onTap: () => controller.resetChat(),
                  ),
                  const SizedBox(width: 16),

                  // Ayarlar
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? color.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: isActive
                    ? color.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
              ),
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
