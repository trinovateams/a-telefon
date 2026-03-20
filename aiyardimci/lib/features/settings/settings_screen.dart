import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../face/face_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _promptController;
  late TextEditingController _apiKeyController;
  bool _apiKeyObscured = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final controller = context.read<FaceController>();
    _promptController = TextEditingController(text: controller.systemPrompt);
    _apiKeyController = TextEditingController(text: controller.apiKey);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _promptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FaceController>(
      builder: (context, controller, child) {
        final moodColor = MoodColors.getColor(controller.currentMood);

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'AYARLAR',
              style: TextStyle(
                color: moodColor,
                fontSize: 16,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('GEMİNİ API KEY', moodColor),
                const SizedBox(height: 12),
                _buildApiKeyEditor(controller, moodColor),

                const SizedBox(height: 32),

                _buildSectionTitle('KİŞİLİK ŞABLONLARı', moodColor),
                const SizedBox(height: 12),
                _buildPresetList(controller, moodColor),

                const SizedBox(height: 32),

                _buildSectionTitle('ÖZEL KİŞİLİK TANIMI', moodColor),
                const SizedBox(height: 12),
                _buildPromptEditor(controller, moodColor),

                const SizedBox(height: 32),

                _buildSectionTitle('İŞLEMLER', moodColor),
                const SizedBox(height: 12),
                _buildActionButton(
                  'Sohbet Geçmişini Temizle',
                  Icons.delete_outline_rounded,
                  moodColor,
                  () {
                    controller.resetChat();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Sohbet geçmişi temizlendi'),
                        backgroundColor: moodColor.withValues(alpha: 0.8),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color.withValues(alpha: 0.7),
        fontSize: 11,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildApiKeyEditor(FaceController controller, Color moodColor) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: _apiKeyController,
            obscureText: _apiKeyObscured,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'AIzaSy...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: IconButton(
                icon: Icon(
                  _apiKeyObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 18,
                ),
                onPressed: () => setState(() => _apiKeyObscured = !_apiKeyObscured),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Google AI Studio → API Key bölümünden ücretsiz alabilirsin.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final key = _apiKeyController.text.trim();
              await controller.updateApiKey(key);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('API key kaydedildi'),
                  backgroundColor: moodColor.withValues(alpha: 0.8),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: moodColor.withValues(alpha: 0.2),
              foregroundColor: moodColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: moodColor.withValues(alpha: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('KAYDET', style: TextStyle(letterSpacing: 1.5, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetList(FaceController controller, Color moodColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.presetPersonalities.entries.map((entry) {
        final isActive = controller.systemPrompt == entry.value.join(' ');

        return GestureDetector(
          onTap: () {
            final prompt = entry.value.join(' ');
            _promptController.text = prompt;
            controller.updateSystemPrompt(prompt);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isActive
                  ? moodColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isActive ? moodColor : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              entry.key,
              style: TextStyle(
                color: isActive ? moodColor : Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPromptEditor(FaceController controller, Color moodColor) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: _promptController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'AI kişiliğini tanımla...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              controller.updateSystemPrompt(_promptController.text);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Kişilik güncellendi!'),
                  backgroundColor: moodColor.withValues(alpha: 0.8),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: moodColor.withValues(alpha: 0.2),
              foregroundColor: moodColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: moodColor.withValues(alpha: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('KAYDET', style: TextStyle(letterSpacing: 1.5, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label, IconData icon, Color color, VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.redAccent.withValues(alpha: 0.7), size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
