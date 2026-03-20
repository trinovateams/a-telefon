import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../enums/eye_theme_type.dart';

class StorageService {
  static const _keySystemPrompt = 'system_prompt';
  static const _keyEyeTheme = 'eye_theme';
  static const _keyFirstLaunch = 'first_launch';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isFirstLaunch => _prefs.getBool(_keyFirstLaunch) ?? true;

  Future<void> setFirstLaunchDone() async {
    await _prefs.setBool(_keyFirstLaunch, false);
  }

  String getSystemPrompt() {
    return _prefs.getString(_keySystemPrompt) ??
        AppConstants.defaultSystemPrompt;
  }

  Future<void> setSystemPrompt(String prompt) async {
    await _prefs.setString(_keySystemPrompt, prompt);
  }

  EyeThemeType getEyeTheme() {
    final index = _prefs.getInt(_keyEyeTheme) ?? 0;
    return EyeThemeType.values[index];
  }

  Future<void> setEyeTheme(EyeThemeType theme) async {
    await _prefs.setInt(_keyEyeTheme, theme.index);
  }
}
