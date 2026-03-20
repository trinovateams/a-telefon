import 'package:flutter/material.dart';
import '../../../core/enums/eye_theme_type.dart';
import '../../../core/enums/face_state.dart';
import 'default_eye.dart';
import 'female_eye.dart';
import 'anime_eye.dart';
import 'robot_eye.dart';
import 'cool_eye.dart';

class EyeThemeManager {
  static Widget getTheme(EyeThemeType type, FaceState state, String mood) {
    switch (type) {
      case EyeThemeType.defaultTheme:
        return DefaultEyeTheme(state: state, mood: mood);
      case EyeThemeType.female:
        return FemaleEyeTheme(state: state, mood: mood);
      case EyeThemeType.anime:
        return AnimeEyeTheme(state: state, mood: mood);
      case EyeThemeType.robot:
        return RobotEyeTheme(state: state, mood: mood);
      case EyeThemeType.cool:
        return CoolEyeTheme(state: state, mood: mood);
    }
  }
}
