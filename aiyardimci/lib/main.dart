import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/ai_service.dart';
import 'core/services/speech_service.dart';
import 'core/services/tts_service.dart';
import 'core/services/storage_service.dart';
import 'features/face/face_controller.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final aiService = AiService();
  final speechService = SpeechService();
  final ttsService = TtsService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => FaceController(
        aiService: aiService,
        speechService: speechService,
        ttsService: ttsService,
        storageService: storageService,
      ),
      child: const AiFaceApp(),
    ),
  );
}
