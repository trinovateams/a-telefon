import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

/// Kullanıcı modelini yükler, kaydeder ve merge eder.
/// HTTP çağrısı yapmaz — tüm AI çağrıları CozmoConsciousnessService içinde.
class UserModelService {
  final StorageService _storage;
  UserModel _model = UserModel();

  UserModelService({required StorageService storage}) : _storage = storage {
    _load();
  }

  UserModel get model => _model;

  void _load() {
    try {
      final json = _storage.getUserModel();
      if (json == '{}' || json.isEmpty) return;
      _model = UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
      debugPrint('[USER_MODEL] yüklendi: ${_model.name}, '
          '${_model.totalInteractions} etkileşim');
    } catch (e) {
      debugPrint('[USER_MODEL] yükleme hatası, sıfırdan başlıyor: $e');
      _model = UserModel();
    }
  }

  Future<void> save() async {
    try {
      await _storage.setUserModel(jsonEncode(_model.toJson()));
    } catch (e) {
      debugPrint('[USER_MODEL] kayıt hatası: $e');
    }
  }

  Future<void> recordInteraction() async {
    _model.totalInteractions++;
    _model.lastSeen = DateTime.now();
    _model.firstMet ??= DateTime.now();
    _model.updateRelationshipLevel();
    await save();
  }

  Future<void> mergeExtraction({
    String? name,
    List<String> newInterests = const [],
    List<String> newFacts = const [],
  }) async {
    bool changed = false;

    if (name != null && name.isNotEmpty && _model.name == null) {
      _model.name = name;
      changed = true;
    }
    for (final i in newInterests) {
      if (i.isNotEmpty && !_model.interests.contains(i)) {
        _model.interests.add(i);
        changed = true;
      }
    }
    for (final f in newFacts) {
      if (f.isNotEmpty && !_model.facts.contains(f)) {
        _model.facts.add(f);
        changed = true;
      }
    }

    if (_model.interests.length > 20) {
      _model.interests = _model.interests.sublist(_model.interests.length - 20);
    }
    if (_model.facts.length > 30) {
      _model.facts = _model.facts.sublist(_model.facts.length - 30);
    }

    if (changed) {
      await save();
      debugPrint('[USER_MODEL] güncellendi: isim=${_model.name}, '
          'ilgiler=${_model.interests.length}, gerçekler=${_model.facts.length}');
    }
  }

  Future<void> mergeFactsFromSummary(String summary) async {
    final matches = RegExp(r'\[user_fact:\s*([^\]]+)\]').allMatches(summary);
    final facts = matches.map((m) => m.group(1)!.trim()).toList();
    if (facts.isNotEmpty) {
      await mergeExtraction(newFacts: facts);
    }
  }
}
