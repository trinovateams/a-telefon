import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/live_audio_service.dart';
import 'core/services/brain_service.dart';
import 'core/services/memory_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/user_model_service.dart';
import 'core/services/cozmo_consciousness_service.dart';
import 'features/face/face_controller.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final liveService = LiveAudioService();
  final memoryService = MemoryService(storage: storageService);
  final userModelService = UserModelService(storage: storageService);
  final brainService = BrainService(
    liveService: liveService,
    memoryService: memoryService,
    storageService: storageService,
  );
  final ccs = CozmoConsciousnessService(
    liveService: liveService,
    memoryService: memoryService,
    storageService: storageService,
    userModelService: userModelService,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => FaceController(
        liveService: liveService,
        brainService: brainService,
        storageService: storageService,
        userModelService: userModelService,
        ccs: ccs,
      ),
      child: const AiFaceApp(),
    ),
  );
}
