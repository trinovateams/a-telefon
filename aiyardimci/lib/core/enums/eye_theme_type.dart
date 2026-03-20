enum EyeThemeType {
  defaultTheme,
  female,
  anime,
  robot,
  cool,
}

extension EyeThemeTypeExtension on EyeThemeType {
  String get displayName {
    switch (this) {
      case EyeThemeType.defaultTheme:
        return 'Default';
      case EyeThemeType.female:
        return 'Female';
      case EyeThemeType.anime:
        return 'Anime';
      case EyeThemeType.robot:
        return 'Robot';
      case EyeThemeType.cool:
        return 'Cool';
    }
  }

  String get description {
    switch (this) {
      case EyeThemeType.defaultTheme:
        return 'Classic AI eyes with smooth animations';
      case EyeThemeType.female:
        return 'Elegant eyes with long lashes';
      case EyeThemeType.anime:
        return 'Dramatic red eyes with rotating patterns';
      case EyeThemeType.robot:
        return 'Mechanical eyes with digital effects';
      case EyeThemeType.cool:
        return 'Stylish eyes with neon glow';
    }
  }
}
