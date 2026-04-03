// test/core/models/user_model_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiyardimci/core/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('varsayılan değerlerle oluşturulur', () {
      final m = UserModel();
      expect(m.name, isNull);
      expect(m.interests, isEmpty);
      expect(m.facts, isEmpty);
      expect(m.relationshipLevel, 'yeni');
      expect(m.totalInteractions, 0);
    });

    test('toJson ve fromJson round-trip', () {
      final m = UserModel(
        name: 'Ahmet',
        interests: ['robotlar', 'müzik'],
        facts: ['sabah kahvesi içer'],
        relationshipLevel: 'arkadaş',
        totalInteractions: 25,
      );
      final json = m.toJson();
      final restored = UserModel.fromJson(json);
      expect(restored.name, 'Ahmet');
      expect(restored.interests, ['robotlar', 'müzik']);
      expect(restored.facts, ['sabah kahvesi içer']);
      expect(restored.relationshipLevel, 'arkadaş');
      expect(restored.totalInteractions, 25);
    });

    test('toPromptSummary isim yoksa uygun metin üretir', () {
      final m = UserModel(interests: ['oyunlar'], totalInteractions: 3);
      final summary = m.toPromptSummary();
      expect(summary, contains('oyunlar'));
      expect(summary, contains('yeni'));
    });

    test('toPromptSummary boş modelde kısa metin döner', () {
      final m = UserModel();
      expect(m.toPromptSummary(), isNotEmpty);
    });

    test('updateRelationshipLevel eşiğe göre güncellenir', () {
      final m = UserModel();
      m.totalInteractions = 4;
      m.updateRelationshipLevel();
      expect(m.relationshipLevel, 'yeni');

      m.totalInteractions = 10;
      m.updateRelationshipLevel();
      expect(m.relationshipLevel, 'tanışık');

      m.totalInteractions = 40;
      m.updateRelationshipLevel();
      expect(m.relationshipLevel, 'arkadaş');

      m.totalInteractions = 70;
      m.updateRelationshipLevel();
      expect(m.relationshipLevel, 'yakın');
    });
  });
}
