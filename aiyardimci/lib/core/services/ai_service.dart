import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/app_constants.dart';

class AiService {
  late GenerativeModel _model;
  late ChatSession _chat;
  String _systemPrompt = AppConstants.defaultSystemPrompt;
  String _themePromptAddition = '';

  AiService() {
    _initModel();
  }

  void _initModel() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: AppConstants.geminiApiKey,
      systemInstruction: Content.text(_buildFullPrompt()),
      generationConfig: GenerationConfig(
        maxOutputTokens: 256,
        temperature: 0.8,
      ),
    );
    _chat = _model.startChat();
  }

  String _buildFullPrompt() {
    final buffer = StringBuffer();

    buffer.writeln('=== SYSTEM RULES (ALWAYS FOLLOW) ===');
    for (final rule in AppConstants.hiddenSystemRules) {
      buffer.writeln('- $rule');
    }
    buffer.writeln();

    if (_themePromptAddition.isNotEmpty) {
      buffer.writeln('=== PERSONALITY MODIFIER ===');
      buffer.writeln(_themePromptAddition);
      buffer.writeln();
    }

    buffer.writeln('=== YOUR PERSONALITY ===');
    buffer.writeln(_systemPrompt);

    return buffer.toString();
  }

  void updateSystemPrompt(String prompt) {
    _systemPrompt = prompt;
    _initModel();
  }

  void updateThemePrompt(String themePrompt) {
    _themePromptAddition = themePrompt;
    _initModel();
  }

  String get currentPrompt => _systemPrompt;

  Future<Map<String, String>> sendMessage(String message) async {
    try {
      final response = await _chat.sendMessage(Content.text(message));
      final text = response.text ?? 'I have no response for that.';
      return _parseMoodAndMessage(text);
    } catch (e) {
      return {
        'mood': 'calm',
        'message': 'Sorry, I encountered an error. Please try again.',
      };
    }
  }

  Map<String, String> _parseMoodAndMessage(String text) {
    final moodRegex = RegExp(r'\[mood:\s*(\w+)\]');
    final match = moodRegex.firstMatch(text);

    String mood = 'calm';
    String message = text;

    if (match != null) {
      mood = match.group(1)?.toLowerCase() ?? 'calm';
      message = text.replaceAll(moodRegex, '').trim();
    }

    return {'mood': mood, 'message': message};
  }

  void resetChat() {
    _chat = _model.startChat();
  }
}
