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
  late TextEditingController _wakeNameController;
  bool _apiKeyObscured = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final controller = context.read<FaceController>();
    _promptController = TextEditingController(text: controller.systemPrompt);
    _apiKeyController = TextEditingController(text: controller.apiKey);
    _wakeNameController = TextEditingController(text: controller.wakeName);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    _promptController.dispose();
    _apiKeyController.dispose();
    _wakeNameController.dispose();
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
                _buildSectionTitle('SES', moodColor),
                const SizedBox(height: 12),
                _buildVoiceSelector(controller, moodColor),

                const SizedBox(height: 32),

                _buildSectionTitle('BEYİN AYARLARI', moodColor),
                const SizedBox(height: 12),
                _buildBrainSettings(controller, moodColor),

                const SizedBox(height: 32),

                _buildSectionTitle('UYANDIRMA İSMİ', moodColor),
                const SizedBox(height: 12),
                _buildWakeNameEditor(controller, moodColor),

                const SizedBox(height: 32),

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

  Widget _buildVoiceSelector(FaceController controller, Color moodColor) {
    final current = controller.voiceGender;
    return Row(
      children: [
        Expanded(
          child: _buildVoiceOption(
            gender: 'female',
            label: 'Kadın',
            subtitle: 'Aoede · Sıcak & Doğal',
            icon: Icons.face_retouching_natural_rounded,
            selected: current == 'female',
            moodColor: moodColor,
            onTap: () => controller.updateVoiceGender('female'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildVoiceOption(
            gender: 'male',
            label: 'Erkek',
            subtitle: 'Charon · Derin & Net',
            icon: Icons.face_rounded,
            selected: current == 'male',
            moodColor: moodColor,
            onTap: () => controller.updateVoiceGender('male'),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceOption({
    required String gender,
    required String label,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color moodColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? moodColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected ? moodColor : Colors.white.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? moodColor : Colors.white.withValues(alpha: 0.4),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? moodColor : Colors.white70,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWakeNameEditor(FaceController controller, Color moodColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: _wakeNameController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Alexia',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(
                Icons.record_voice_over_outlined,
                color: moodColor.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
            onSubmitted: (name) => controller.updateWakeName(name),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sadece bu ismi duyunca cevap verir. Boş bırakırsan her şeye cevap verir.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final name = _wakeNameController.text.trim();
              controller.updateWakeName(name);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    name.isEmpty
                        ? 'İsim kaldırıldı — her şeye cevap verir'
                        : '"$name" ismi kaydedildi',
                  ),
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

  Widget _buildBrainSettings(FaceController controller, Color moodColor) {
    final storage = controller.storageService;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Proaktif Konuşma', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(
              'Alexia kendi kendine konuşsun',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            ),
            value: storage.getProactiveSpeech(),
            activeTrackColor: moodColor.withValues(alpha: 0.5),
            onChanged: (v) async {
              await storage.setProactiveSpeech(v);
              setState(() {});
            },
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          SwitchListTile(
            title: const Text('Uyku Modu', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(
              'Gece otomatik uyuklama',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            ),
            value: storage.getSleepMode(),
            activeTrackColor: moodColor.withValues(alpha: 0.5),
            onChanged: (v) async {
              await storage.setSleepMode(v);
              setState(() {});
            },
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          SwitchListTile(
            title: const Text('Hafıza', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(
              'Konuşmaları hatırlasın',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            ),
            value: storage.getMemoryEnabled(),
            activeTrackColor: moodColor.withValues(alpha: 0.5),
            onChanged: (v) async {
              await storage.setMemoryEnabled(v);
              setState(() {});
            },
          ),
        ],
      ),
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
