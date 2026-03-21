import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/live_audio_service.dart';
import 'core/services/storage_service.dart';
import 'features/face/face_controller.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final liveService = LiveAudioService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => FaceController(
        liveService: liveService,
        storageService: storageService,
      ),
      child: const AiFaceApp(),
    ),
  );
}
