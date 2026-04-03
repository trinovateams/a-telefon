import 'dart:convert';

enum ThoughtDesire {
  speak,
  silent,
  remember;

  static ThoughtDesire fromString(String s) {
    return ThoughtDesire.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ThoughtDesire.silent,
    );
  }
}

class InnerThought {
  final String content;
  final ThoughtDesire desire;
  final String mood;
  final DateTime timestamp;

  InnerThought({
    required this.content,
    this.desire = ThoughtDesire.silent,
    this.mood = 'calm',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory InnerThought.fromJson(Map<String, dynamic> json) => InnerThought(
        content: json['content'] as String? ?? '',
        desire: ThoughtDesire.fromString(json['desire'] as String? ?? ''),
        mood: json['mood'] as String? ?? 'calm',
      );

  /// Ham Gemini yanıtından (JSON bloğu içerebilir) InnerThought parse eder.
  /// JSON bulunamazsa null döner.
  static InnerThought? fromRawJson(String raw) {
    try {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (match == null) return null;
      final decoded = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      return InnerThought.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
