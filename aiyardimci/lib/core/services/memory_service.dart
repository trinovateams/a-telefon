import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class MemoryService {
  final StorageService _storage;
  final List<Map<String, dynamic>> _memories = [];
  final List<String> _currentTurnTexts = [];
  int _turnCount = 0;

  static const int _maxMemories = 50;

  MemoryService({required StorageService storage}) : _storage = storage {
    _loadMemories();
  }

  // --- Load/Save ---

  void _loadMemories() {
    try {
      final json = _storage.getMemories();
      final list = jsonDecode(json) as List;
      _memories.addAll(list.cast<Map<String, dynamic>>());
      debugPrint('[MEMORY] ${_memories.length} anı yüklendi');
    } catch (e) {
      debugPrint('[MEMORY] load error, starting fresh: $e');
      _memories.clear();
    }
  }

  Future<void> _saveMemories() async {
    try {
      await _storage.setMemories(jsonEncode(_memories));
    } catch (e) {
      debugPrint('[MEMORY] save error: $e');
    }
  }

  // --- Public API ---

  /// Called when AI sends text output
  void onAIText(String text) {
    final clean = text.replaceAll(RegExp(r'\[mood:\s*\w+\]'), '').trim();
    if (clean.isNotEmpty) {
      _currentTurnTexts.add('AI: $clean');
      _turnCount++;
    }
  }

  /// Called when user sends text
  void onUserText(String text) {
    _currentTurnTexts.add('User: $text');
    _turnCount++;
  }

  /// Check if it's time to summarize (every 5 turns)
  bool shouldSummarize() => _turnCount >= 5 && _currentTurnTexts.isNotEmpty;

  /// Get conversation text for summarization
  String getConversationForSummary() => _currentTurnTexts.join('\n');

  /// Store a summary
  Future<void> storeSummary(String summary, String mood) async {
    final memory = {
      'summary': summary,
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'mood': mood,
    };
    _memories.add(memory);
    if (_memories.length > _maxMemories) {
      _memories.removeAt(0);
    }
    _currentTurnTexts.clear();
    _turnCount = 0;
    await _saveMemories();
    debugPrint('[MEMORY] stored: $summary');
  }

  /// Get recent memories for system prompt injection
  String getMemoriesForPrompt({int count = 10}) {
    if (_memories.isEmpty) return '';
    final recent = _memories.length > count
        ? _memories.sublist(_memories.length - count)
        : _memories;

    final lines = recent.map((m) => '- ${m['date']}: ${m['summary']}').join('\n');
    return 'Hatırladıkların:\n$lines';
  }

  /// Clear all memories
  Future<void> clearMemories() async {
    _memories.clear();
    _currentTurnTexts.clear();
    _turnCount = 0;
    await _saveMemories();
  }

  /// CCS aktifse BrainService summarize işlemini atlar.
  bool ccsActive = false;

  /// CCS tarafından doğrudan hafıza kaydetmek için kullanılır.
  Future<void> storeDirectMemory(String content, String mood) async {
    await storeSummary(content, mood);
  }

  /// Özetleme hakkını talep eder. true dönerse caller summarize etmeli.
  /// Counter sıfırlanır — double-fire olmaz.
  bool claimSummarization() {
    if (!shouldSummarize()) return false;
    _turnCount = 0;
    return true;
  }

  bool get isEnabled => _storage.getMemoryEnabled();
}
