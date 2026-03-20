import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/face/face_screen.dart';

class AiFaceApp extends StatelessWidget {
  const AiFaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
      ),
    );

    // Yatay mod (landscape)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Tam ekran — status bar ve navigation bar gizle
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return MaterialApp(
      title: 'AI Yardımcı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const FaceScreen(),
    );
  }
}
