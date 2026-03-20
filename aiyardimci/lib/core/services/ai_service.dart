import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class AiService {
  String _systemPrompt = AppConstants.defaultSystemPrompt;
  final List<Map<String, dynamic>> _chatHistory = [];

  String _buildFullPrompt() {
    final buffer = StringBuffer();

    buffer.writeln('=== SYSTEM RULES (ALWAYS FOLLOW) ===');
    for (final rule in AppConstants.hiddenSystemRules) {
      buffer.writeln('- $rule');
    }
    buffer.writeln();

    buffer.writeln('=== YOUR PERSONALITY ===');
    buffer.writeln(_systemPrompt);

    return buffer.toString();
  }

  void updateSystemPrompt(String prompt) {
    _systemPrompt = prompt;
  }

  String get currentPrompt => _systemPrompt;

  Future<Map<String, String>> sendMessage(String message) async {
    final apiKey = AppConstants.geminiApiKey;

    // Kullanıcı mesajını history'ye ekle
    _chatHistory.add({
      'role': 'user',
      'parts': [{'text': message}],
    });

    final body = {
      'system_instruction': {
        'parts': [{'text': _buildFullPrompt()}],
      },
      'contents': _chatHistory,
      'tools': [
        {'google_search': {}},
      ],
      'generationConfig': {
        'maxOutputTokens': 256,
        'temperature': 0.8,
      },
    };

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
      );

      debugPrint('[AI] sending request with grounding...');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        debugPrint('[AI] HTTP ${response.statusCode}: ${response.body}');
        _chatHistory.removeLast(); // başarısız mesajı kaldır
        return {
          'mood': 'sad',
          'message': 'API hatası: ${response.statusCode}',
        };
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        _chatHistory.removeLast();
        return {'mood': 'sad', 'message': 'Yanıt alamadım.'};
      }

      final parts = candidates[0]['content']['parts'] as List;
      final text = parts.map((p) => p['text'] ?? '').join('').trim();

      // Model yanıtını history'ye ekle
      _chatHistory.add({
        'role': 'model',
        'parts': [{'text': text}],
      });

      debugPrint('[AI] response: $text');
      return _parseMoodAndMessage(text);
    } catch (e) {
      debugPrint('[AI] HATA: $e');
      _chatHistory.removeLast();
      return {
        'mood': 'sad',
        'message': 'Bir hata oluştu, tekrar dene.',
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
    _chatHistory.clear();
  }
}
