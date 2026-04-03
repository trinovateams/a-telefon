import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiyardimci/core/models/inner_thought.dart';

void main() {
  group('ThoughtDesire', () {
    test('fromString geçerli değerleri parse eder', () {
      expect(ThoughtDesire.fromString('speak'), ThoughtDesire.speak);
      expect(ThoughtDesire.fromString('silent'), ThoughtDesire.silent);
      expect(ThoughtDesire.fromString('remember'), ThoughtDesire.remember);
    });

    test('fromString bilinmeyen değerde silent döner', () {
      expect(ThoughtDesire.fromString('unknown'), ThoughtDesire.silent);
      expect(ThoughtDesire.fromString(''), ThoughtDesire.silent);
    });
  });

  group('InnerThought', () {
    test('fromJson geçerli JSON parse eder', () {
      final json = {
        'content': 'Ahmet bugün sessiz',
        'desire': 'speak',
        'mood': 'curious',
      };
      final thought = InnerThought.fromJson(json);
      expect(thought.content, 'Ahmet bugün sessiz');
      expect(thought.desire, ThoughtDesire.speak);
      expect(thought.mood, 'curious');
    });

    test('fromJson eksik alanları default değerle doldurur', () {
      final thought = InnerThought.fromJson({'content': 'test'});
      expect(thought.desire, ThoughtDesire.silent);
      expect(thought.mood, 'calm');
    });

    test('fromRawJson JSON bloğunu string içinden çıkarır', () {
      const raw = 'İşte cevabım: {"content": "düşünce", "desire": "speak", "mood": "happy"} tamam';
      final thought = InnerThought.fromRawJson(raw);
      expect(thought, isNotNull);
      expect(thought!.content, 'düşünce');
    });

    test('fromRawJson JSON yoksa null döner', () {
      expect(InnerThought.fromRawJson('JSON yok burada'), isNull);
    });
  });
}
