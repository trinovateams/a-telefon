import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  static const _keySystemPrompt = 'system_prompt';
  static const _keyFirstLaunch = 'first_launch';
  static const _keyApiKey = 'gemini_api_key';
  static const _keyWakeName = 'wake_name';
  static const _keyVoiceGender = 'voice_gender';

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

  String getWakeName() {
    return _prefs.getString(_keyWakeName) ?? 'Cozmo';
  }

  Future<void> setWakeName(String name) async {
    await _prefs.setString(_keyWakeName, name);
  }

  /// 'female', 'male' veya 'cozmo'
  String getVoiceGender() {
    return _prefs.getString(_keyVoiceGender) ?? 'cozmo';
  }

  Future<void> setVoiceGender(String gender) async {
    await _prefs.setString(_keyVoiceGender, gender);
  }

  // ─── Brain settings ──────────────────────────────────────────────────────

  bool getProactiveSpeech() => _prefs.getBool('proactive_speech') ?? true;
  Future<void> setProactiveSpeech(bool v) => _prefs.setBool('proactive_speech', v);

  double getSpeechFrequency() => _prefs.getDouble('speech_frequency') ?? 0.5;
  Future<void> setSpeechFrequency(double v) => _prefs.setDouble('speech_frequency', v);

  bool getSleepMode() => _prefs.getBool('sleep_mode') ?? true;
  Future<void> setSleepMode(bool v) => _prefs.setBool('sleep_mode', v);

  bool getMemoryEnabled() => _prefs.getBool('memory_enabled') ?? true;
  Future<void> setMemoryEnabled(bool v) => _prefs.setBool('memory_enabled', v);

  // ─── Brain state persistence ─────────────────────────────────────────────

  String getBrainState() => _prefs.getString('brain_state') ?? '';
  Future<void> setBrainState(String json) => _prefs.setString('brain_state', json);

  String getMemories() => _prefs.getString('memories') ?? '[]';
  Future<void> setMemories(String json) => _prefs.setString('memories', json);

  int getLastSessionTimestamp() => _prefs.getInt('last_session_ts') ?? 0;
  Future<void> setLastSessionTimestamp(int ts) => _prefs.setInt('last_session_ts', ts);

  // ─── Cozmo Consciousness ─────────────────────────────────────────────────

  bool getCozmoMode() => _prefs.getBool('cozmo_mode') ?? true;
  Future<void> setCozmoMode(bool v) => _prefs.setBool('cozmo_mode', v);

  String getUserModel() => _prefs.getString('user_model') ?? '{}';
  Future<void> setUserModel(String json) =>
      _prefs.setString('user_model', json);
}
