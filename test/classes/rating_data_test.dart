import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/services/db_notification.dart';

void main() {
  group('RatingDimension', () {
    test('creates with required fields', () {
      const dim = RatingDimension(key: 'productivity', value: 0.8);

      expect(dim.key, equals('productivity'));
      expect(dim.value, equals(0.8));
    });

    test('equality works correctly', () {
      const dim1 = RatingDimension(key: 'energy', value: 0.6);
      const dim2 = RatingDimension(key: 'energy', value: 0.6);

      expect(dim1, equals(dim2));
    });

    test('inequality with different values', () {
      const dim1 = RatingDimension(key: 'energy', value: 0.6);
      const dim2 = RatingDimension(key: 'energy', value: 0.7);

      expect(dim1, isNot(equals(dim2)));
    });

    test('inequality with different keys', () {
      const dim1 = RatingDimension(key: 'energy', value: 0.6);
      const dim2 = RatingDimension(key: 'focus', value: 0.6);

      expect(dim1, isNot(equals(dim2)));
    });

    test('serializes to and from JSON', () {
      const dim = RatingDimension(key: 'focus', value: 0.75);
      final json = dim.toJson();
      final restored = RatingDimension.fromJson(json);

      expect(restored, equals(dim));
      expect(json['key'], equals('focus'));
      expect(json['value'], equals(0.75));
    });

    test('copyWith creates new instance with updated fields', () {
      const original = RatingDimension(key: 'productivity', value: 0.5);
      final updated = original.copyWith(value: 0.9);

      expect(updated.key, equals('productivity'));
      expect(updated.value, equals(0.9));
      expect(original.value, equals(0.5));
    });

    test('creates with self-describing metadata', () {
      const dim = RatingDimension(
        key: 'productivity',
        value: 0.8,
        question: 'How productive was this session?',
        description: 'Measures subjective productivity. '
            '0.0 = completely unproductive, 1.0 = peak productivity.',
        inputType: 'tapBar',
      );

      expect(dim.question, equals('How productive was this session?'));
      expect(dim.description, contains('subjective productivity'));
      expect(dim.inputType, equals('tapBar'));
      expect(dim.optionLabels, isNull);
    });

    test('creates segmented dimension with option labels', () {
      const dim = RatingDimension(
        key: 'challenge_skill',
        value: 0.5,
        question: 'This work felt...',
        description: 'Challenge-skill balance. '
            '0.0 = too easy, 0.5 = just right, 1.0 = too challenging.',
        inputType: 'segmented',
        optionLabels: ['Too easy', 'Just right', 'Too challenging'],
        optionValues: [0.0, 0.5, 1.0],
      );

      expect(dim.optionLabels, hasLength(3));
      expect(dim.optionLabels, contains('Just right'));
      expect(dim.optionValues, hasLength(3));
      expect(dim.optionValues, equals([0.0, 0.5, 1.0]));
    });

    test('new optional fields default to null for backward compat', () {
      const dim = RatingDimension(key: 'energy', value: 0.6);

      expect(dim.question, isNull);
      expect(dim.description, isNull);
      expect(dim.inputType, isNull);
      expect(dim.optionLabels, isNull);
      expect(dim.optionValues, isNull);
    });

    test('deserializes legacy JSON without new fields', () {
      final legacyJson = <String, dynamic>{
        'key': 'focus',
        'value': 0.75,
      };
      final dim = RatingDimension.fromJson(legacyJson);

      expect(dim.key, equals('focus'));
      expect(dim.value, equals(0.75));
      expect(dim.question, isNull);
      expect(dim.description, isNull);
      expect(dim.inputType, isNull);
      expect(dim.optionLabels, isNull);
      expect(dim.optionValues, isNull);
    });

    test('JSON round-trip preserves self-describing fields', () {
      const dim = RatingDimension(
        key: 'productivity',
        value: 0.8,
        question: 'How productive was this session?',
        description: 'Measures subjective productivity.',
        inputType: 'tapBar',
      );

      final jsonString = jsonEncode(dim.toJson());
      final restored = RatingDimension.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(restored, equals(dim));
    });

    test('JSON round-trip preserves option labels', () {
      const dim = RatingDimension(
        key: 'challenge_skill',
        value: 0.5,
        question: 'This work felt...',
        description: 'Challenge-skill balance.',
        inputType: 'segmented',
        optionLabels: ['Too easy', 'Just right', 'Too challenging'],
      );

      final jsonString = jsonEncode(dim.toJson());
      final restored = RatingDimension.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(restored, equals(dim));
      expect(restored.optionLabels, hasLength(3));
    });

    test('JSON round-trip preserves optionValues', () {
      const dim = RatingDimension(
        key: 'severity',
        value: 0.2,
        question: 'How severe?',
        inputType: 'segmented',
        optionLabels: ['Mild', 'Moderate', 'Severe'],
        optionValues: [0.0, 0.2, 1.0],
      );

      final jsonString = jsonEncode(dim.toJson());
      final restored = RatingDimension.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(restored, equals(dim));
      expect(restored.optionValues, equals([0.0, 0.2, 1.0]));
    });

    test('equality distinguishes optionValues', () {
      const withValues = RatingDimension(
        key: 'x',
        value: 0.5,
        optionLabels: ['A', 'B'],
        optionValues: [0.0, 1.0],
      );
      const withoutValues = RatingDimension(
        key: 'x',
        value: 0.5,
        optionLabels: ['A', 'B'],
      );
      const withDifferentValues = RatingDimension(
        key: 'x',
        value: 0.5,
        optionLabels: ['A', 'B'],
        optionValues: [0.0, 0.5],
      );

      expect(withValues, isNot(equals(withoutValues)));
      expect(withValues, isNot(equals(withDifferentValues)));
    });

    test('deserializes JSON with optionLabels but without optionValues', () {
      final json = <String, dynamic>{
        'key': 'challenge_skill',
        'value': 0.5,
        'inputType': 'segmented',
        'optionLabels': ['Too easy', 'Just right', 'Too challenging'],
      };
      final dim = RatingDimension.fromJson(json);

      expect(dim.optionLabels, hasLength(3));
      expect(dim.optionValues, isNull);
    });
  });

  group('RatingData', () {
    const testDimensions = [
      RatingDimension(key: 'productivity', value: 0.8),
      RatingDimension(key: 'energy', value: 0.6),
      RatingDimension(key: 'focus', value: 0.9),
      RatingDimension(key: 'challenge_skill', value: 0.5),
    ];

    test('creates with required fields and defaults', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
      );

      expect(data.targetId, equals('entry-1'));
      expect(data.dimensions, equals(testDimensions));
      expect(data.catalogId, equals('session'));
      expect(data.schemaVersion, equals(1));
      expect(data.note, isNull);
    });

    test('creates with all fields', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
        schemaVersion: 2,
        note: 'Great session',
      );

      expect(data.targetId, equals('entry-1'));
      expect(data.dimensions.length, equals(4));
      expect(data.schemaVersion, equals(2));
      expect(data.note, equals('Great session'));
    });

    test('equality works correctly', () {
      const data1 = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
        note: 'test',
      );
      const data2 = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
        note: 'test',
      );

      expect(data1, equals(data2));
    });

    test('inequality with different targetId', () {
      const data1 = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
      );
      const data2 = RatingData(
        targetId: 'entry-2',
        dimensions: testDimensions,
      );

      expect(data1, isNot(equals(data2)));
    });

    test('copyWith preserves fields', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
        note: 'original note',
      );

      final updated = data.copyWith(note: 'updated note');

      expect(updated.targetId, equals('entry-1'));
      expect(updated.dimensions, equals(testDimensions));
      expect(updated.note, equals('updated note'));
    });

    test('copyWith can clear optional note', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
        note: 'some note',
      );

      final updated = data.copyWith(note: null);

      expect(updated.note, isNull);
    });

    test('copyWith can update dimensions', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
      );

      const newDimensions = [
        RatingDimension(key: 'productivity', value: 1),
      ];

      final updated = data.copyWith(dimensions: newDimensions);

      expect(updated.dimensions, equals(newDimensions));
      expect(updated.targetId, equals('entry-1'));
    });

    test('serializes to and from JSON', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
        note: 'Great focus session',
      );

      // Full encode/decode round-trip to ensure nested objects
      // are serialized as maps (not Dart objects)
      final jsonString = jsonEncode(data.toJson());
      final restored = RatingData.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(restored, equals(data));
    });

    test('JSON round-trip preserves all fields', () {
      const data = RatingData(
        targetId: 'entry-abc',
        dimensions: [
          RatingDimension(key: 'productivity', value: 0.85),
          RatingDimension(key: 'energy', value: 0.4),
          RatingDimension(key: 'focus', value: 0.95),
          RatingDimension(key: 'challenge_skill', value: 0.5),
        ],
        note: 'Feeling great',
      );

      final jsonString = jsonEncode(data.toJson());
      final decoded =
          RatingData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

      expect(decoded.targetId, equals('entry-abc'));
      expect(decoded.dimensions.length, equals(4));
      expect(decoded.dimensions[0].key, equals('productivity'));
      expect(decoded.dimensions[0].value, equals(0.85));
      expect(decoded.schemaVersion, equals(1));
      expect(decoded.note, equals('Feeling great'));
    });

    test('dimensionValue returns value for existing key', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
      );

      expect(data.dimensionValue('productivity'), equals(0.8));
      expect(data.dimensionValue('energy'), equals(0.6));
      expect(data.dimensionValue('focus'), equals(0.9));
      expect(data.dimensionValue('challenge_skill'), equals(0.5));
    });

    test('dimensionValue returns null for missing key', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
      );

      expect(data.dimensionValue('nonexistent'), isNull);
    });

    test('dimensionValue returns null for empty dimensions', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: [],
      );

      expect(data.dimensionValue('productivity'), isNull);
    });

    test('serializes without optional note', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
      );

      final jsonString = jsonEncode(data.toJson());
      final restored = RatingData.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(restored.note, isNull);
      expect(restored, equals(data));
    });

    test('catalogId defaults to session', () {
      const data = RatingData(
        targetId: 'entry-1',
        dimensions: testDimensions,
      );

      expect(data.catalogId, equals('session'));
    });

    test('catalogId can be set explicitly', () {
      const data = RatingData(
        targetId: 'dayplan-2026-02-09',
        dimensions: testDimensions,
        catalogId: 'day_morning',
      );

      expect(data.catalogId, equals('day_morning'));
    });

    test('deserializes legacy JSON without catalogId as session', () {
      final legacyJson = <String, dynamic>{
        'timeEntryId': 'entry-1',
        'dimensions': [
          {'key': 'productivity', 'value': 0.8},
        ],
        'schemaVersion': 1,
      };

      final data = RatingData.fromJson(legacyJson);

      expect(data.catalogId, equals('session'));
      expect(data.targetId, equals('entry-1'));
    });

    test('JSON round-trip preserves catalogId', () {
      const data = RatingData(
        targetId: 'task-123',
        dimensions: testDimensions,
        catalogId: 'task_completed',
      );

      final jsonString = jsonEncode(data.toJson());
      final restored = RatingData.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(restored.catalogId, equals('task_completed'));
      expect(restored, equals(data));
    });
  });

  group('RatingEntry', () {
    test('affectedIds includes ratingNotification', () {
      final entry = JournalEntity.rating(
        meta: Metadata(
          id: 'rating-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: const RatingData(
          targetId: 'te-1',
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.8),
          ],
        ),
      );

      expect(entry.affectedIds, contains(ratingNotification));
      expect(entry.affectedIds, contains('rating-1'));
    });
  });
}
