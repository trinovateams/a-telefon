import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/inner_thought.dart';
import 'live_audio_service.dart';
import 'memory_service.dart';
import 'storage_service.dart';
import 'user_model_service.dart';

class CozmoConsciousnessService {
  final LiveAudioService _liveService;
  final MemoryService _memoryService;
  final StorageService _storageService;
  final UserModelService _userModelService;

  Timer? _thinkingTimer;
  bool _active = false;
  InnerThought? _currentThought;
  String _currentMood = 'calm';

  // Conversation turn tracking for user model extraction
  final List<String> _recentTexts = [];
  int _extractionTurnCount = 0;
  static const _extractionInterval = 5;

  // Thinking loop interval: 120–180 seconds (random jitter)
  static const _minThinkSec = 120;
  static const _maxThinkSec = 180;

  CozmoConsciousnessService({
    required LiveAudioService liveService,
    required MemoryService memoryService,
    required StorageService storageService,
    required UserModelService userModelService,
  })  : _liveService = liveService,
        _memoryService = memoryService,
        _storageService = storageService,
        _userModelService = userModelService;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  void start() {
    if (_active) return;
    _active = true;
    _memoryService.ccsActive = true;
    _scheduleNextThink();
    debugPrint('[CCS] başlatıldı');
  }

  void stop() {
    _active = false;
    _memoryService.ccsActive = false;
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    _currentThought = null;
    debugPrint('[CCS] durduruldu');
  }

  void dispose() => stop();

  bool get isActive => _active;

  // ─── Events (called by FaceController) ──────────────────────────────────

  void onInteraction() {
    _userModelService.recordInteraction();
  }

  void onTextReceived(String text) {
    final clean = text.replaceAll(RegExp(r'\[mood:\s*\w+\]'), '').trim();
    if (clean.isNotEmpty) _recentTexts.add('Cozmo: $clean');
  }

  void onUserTextSent(String text) {
    if (text.isNotEmpty) _recentTexts.add('Kullanıcı: $text');
    _extractionTurnCount++;
    if (_extractionTurnCount >= _extractionInterval) {
      _extractionTurnCount = 0;
      _runUserModelExtraction();
    }
  }

  void onMoodChange(String mood) {
    _currentMood = mood;
  }

  void onTurnEnd() {
    if (_memoryService.claimSummarization()) {
      _runMemorySummarization();
    }
  }

  /// Returns current thought content for injection into Live API setup.
  String getThoughtInjection() {
    final t = _currentThought;
    if (t == null) return '';
    // Clear thoughts older than 10 minutes
    if (DateTime.now().difference(t.timestamp).inMinutes > 10) {
      _currentThought = null;
      return '';
    }
    return t.content;
  }

  // ─── Thinking Loop ───────────────────────────────────────────────────────

  void _scheduleNextThink() {
    if (!_active) return;
    final seconds =
        _minThinkSec + Random().nextInt(_maxThinkSec - _minThinkSec);
    _thinkingTimer = Timer(Duration(seconds: seconds), _think);
  }

  Future<void> _think() async {
    if (!_active) return;
    debugPrint('[CCS] düşünüyor...');

    final thought = await _generateThought();
    if (thought != null && _active) {
      _currentThought = thought;
      await _processThought(thought);
    }

    _scheduleNextThink();
  }

  Future<InnerThought?> _generateThought() async {
    final apiKey = _storageService.getApiKey();
    if (apiKey.isEmpty) return null;

    final now = DateTime.now();
    final memories = _memoryService.getMemoriesForPrompt(count: 3);

    final prompt = AppConstants.consciousnessThinkingPrompt
        .replaceAll('{energy}', _formatEnergy())
        .replaceAll('{boredom}', _formatBoredom())
        .replaceAll('{affection}', _formatAffection())
        .replaceAll('{time}',
            '${now.hour}:${now.minute.toString().padLeft(2, '0')}')
        .replaceAll('{day}', _dayName(now.weekday))
        .replaceAll('{user_summary}',
            _userModelService.model.toPromptSummary())
        .replaceAll(
            '{memories}', memories.isEmpty ? 'Henüz anı yok.' : memories);

    final raw = await _callGeminiFlash(prompt, apiKey);
    if (raw == null) return null;

    final thought = InnerThought.fromRawJson(raw);
    debugPrint(
        '[CCS] düşünce: ${thought?.content} (${thought?.desire.name})');
    return thought;
  }

  Future<void> _processThought(InnerThought thought) async {
    switch (thought.desire) {
      case ThoughtDesire.speak:
        // Only speak if Live service is in listening state
        if (_liveService.onListening != null) {
          debugPrint('[CCS] düşünceyi sesli söylüyor');
          await _liveService.sendText(thought.content);
        }
      case ThoughtDesire.silent:
        // _currentThought already set, available for injection
        debugPrint('[CCS] düşünce içerde tutuldu');
      case ThoughtDesire.remember:
        await _memoryService.storeDirectMemory(thought.content, thought.mood);
        debugPrint('[CCS] düşünce hafızaya yazıldı');
    }
  }

  // ─── Memory AI Summarization ─────────────────────────────────────────────

  Future<void> _runMemorySummarization() async {
    final apiKey = _storageService.getApiKey();
    if (apiKey.isEmpty) return;

    final conversation = _memoryService.getConversationForSummary();
    if (conversation.isEmpty) return;

    final prompt = AppConstants.memoryAISummaryPrompt
        .replaceAll('{conversation}', conversation)
        .replaceAll('{user_summary}', _userModelService.model.toPromptSummary());

    final raw = await _callGeminiFlash(prompt, apiKey, maxTokens: 200);
    if (raw == null) {
      // Fallback: simple truncation
      final fallback = conversation.length > 150
          ? '${conversation.substring(0, 150)}...'
          : conversation;
      await _memoryService.storeSummary(fallback, _currentMood);
      return;
    }

    // Merge [user_fact: ...] tags into UserModel
    await _userModelService.mergeFactsFromSummary(raw);

    // Clean tags and store
    final clean =
        raw.replaceAll(RegExp(r'\[user_fact:[^\]]*\]'), '').trim();
    await _memoryService.storeSummary(
        clean.isEmpty ? raw.trim() : clean, _currentMood);
    debugPrint('[CCS] hafıza özeti kaydedildi');
  }

  // ─── UserModel Extraction ────────────────────────────────────────────────

  Future<void> _runUserModelExtraction() async {
    final apiKey = _storageService.getApiKey();
    if (apiKey.isEmpty || _recentTexts.isEmpty) return;

    final conversation = _recentTexts.join('\n');
    _recentTexts.clear();

    final prompt = AppConstants.userModelExtractionPrompt
        .replaceAll('{conversation}', conversation);

    final raw = await _callGeminiFlash(prompt, apiKey, maxTokens: 150);
    if (raw == null) return;

    try {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (match == null) return;
      final data = jsonDecode(match.group(0)!) as Map<String, dynamic>;

      await _userModelService.mergeExtraction(
        name: data['name'] as String?,
        newInterests:
            (data['new_interests'] as List?)?.cast<String>() ?? [],
        newFacts: (data['new_facts'] as List?)?.cast<String>() ?? [],
      );
    } catch (e) {
      debugPrint('[CCS] userModel extraction parse hatası: $e');
    }
  }

  // ─── Gemini REST Helper ──────────────────────────────────────────────────

  Future<String?> _callGeminiFlash(String prompt, String apiKey,
      {int maxTokens = 256}) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-2.0-flash:generateContent?key=$apiKey',
      );
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': maxTokens,
        },
      });

      final resp = await http
          .post(url,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        debugPrint('[CCS] Gemini REST HTTP ${resp.statusCode}');
        return null;
      }

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      return decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
    } catch (e) {
      debugPrint('[CCS] Gemini REST hatası: $e');
      return null;
    }
  }

  // ─── State Helpers ───────────────────────────────────────────────────────

  String _formatEnergy() {
    try {
      final json =
          jsonDecode(_storageService.getBrainState()) as Map<String, dynamic>;
      final v = (json['energy'] as num?)?.toDouble() ?? 0.7;
      if (v > 0.7) return 'yüksek';
      if (v > 0.4) return 'orta';
      return 'düşük';
    } catch (_) {
      return 'orta';
    }
  }

  String _formatBoredom() {
    try {
      final json =
          jsonDecode(_storageService.getBrainState()) as Map<String, dynamic>;
      final v = (json['boredom'] as num?)?.toDouble() ?? 0.0;
      if (v > 0.6) return 'çok sıkılmış';
      if (v > 0.3) return 'biraz sıkılmış';
      return 'meşgul';
    } catch (_) {
      return 'normal';
    }
  }

  String _formatAffection() {
    try {
      final json =
          jsonDecode(_storageService.getBrainState()) as Map<String, dynamic>;
      final v = (json['affection'] as num?)?.toDouble() ?? 0.3;
      if (v > 0.6) return 'çok sevgi dolu';
      if (v > 0.3) return 'sıcak';
      return 'mesafeli';
    } catch (_) {
      return 'normal';
    }
  }

  String _dayName(int weekday) {
    const days = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar'
    ];
    return days[(weekday - 1).clamp(0, 6)];
  }
}
