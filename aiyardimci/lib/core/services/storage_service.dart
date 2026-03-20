import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  static const _keySystemPrompt = 'system_prompt';
  static const _keyFirstLaunch = 'first_launch';
  static const _keyApiKey = 'gemini_api_key';

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

  String getApiKey() {
    final stored = _prefs.getString(_keyApiKey) ?? '';
    if (stored.isNotEmpty) return stored;
    return AppConstants.geminiApiKey; // dart-define fallback
  }

  Future<void> setApiKey(String key) async {
    await _prefs.setString(_keyApiKey, key);
  }
}
