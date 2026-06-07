import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
        description:
            'Measures subjective productivity. '
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
        description:
            'Challenge-skill balance. '
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

    glados.Glados(
      glados.any.generatedRatingDimension,
      glados.ExploreConfig(numRuns: 80),
    ).test('round-trips generated dimensions through JSON', (scenario) {
      final dimension = scenario.dimension;

      final restored = RatingDimension.fromJson(
        jsonDecode(jsonEncode(dimension.toJson())) as Map<String, dynamic>,
      );

      expect(restored, equals(dimension), reason: '$scenario');
    }, tags: 'glados');
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

    glados.Glados(
      glados.any.generatedRatingData,
      glados.ExploreConfig(numRuns: 160),
    ).test('round-trips generated rating data through JSON', (scenario) {
      final data = scenario.data;

      final restored = RatingData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );

      expect(restored, equals(data), reason: '$scenario');
      expect(restored.targetId, data.targetId, reason: '$scenario');
      expect(restored.catalogId, data.catalogId, reason: '$scenario');
      expect(restored.dimensions, data.dimensions, reason: '$scenario');
    }, tags: 'glados');
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

class _GeneratedRatingDimension {
  const _GeneratedRatingDimension({
    required this.key,
    required this.valueSlot,
    required this.questionSlot,
    required this.descriptionSlot,
    required this.inputTypeSlot,
    required this.optionLabels,
    required this.optionValueSlots,
  });

  final String key;
  final int valueSlot;
  final int questionSlot;
  final int descriptionSlot;
  final int inputTypeSlot;
  final List<String> optionLabels;
  final List<int> optionValueSlots;

  RatingDimension get dimension => RatingDimension(
    key: key,
    value: valueSlot / 100,
    question: _optionalText(questionSlot, 'Question'),
    description: _optionalText(descriptionSlot, 'Description'),
    inputType: _optionalInputType(inputTypeSlot),
    optionLabels: optionLabels.isEmpty ? null : optionLabels,
    optionValues: optionValueSlots.isEmpty
        ? null
        : optionValueSlots.map((slot) => slot / 100).toList(),
  );

  @override
  String toString() {
    return '_GeneratedRatingDimension('
        'key: "$key", '
        'valueSlot: $valueSlot, '
        'questionSlot: $questionSlot, '
        'descriptionSlot: $descriptionSlot, '
        'inputTypeSlot: $inputTypeSlot, '
        'optionLabels: $optionLabels, '
        'optionValueSlots: $optionValueSlots)';
  }
}

class _GeneratedRatingData {
  const _GeneratedRatingData({
    required this.targetId,
    required this.dimensions,
    required this.catalogId,
    required this.schemaVersion,
    required this.noteSlot,
  });

  final String targetId;
  final List<_GeneratedRatingDimension> dimensions;
  final String catalogId;
  final int schemaVersion;
  final int noteSlot;

  RatingData get data => RatingData(
    targetId: targetId,
    dimensions: dimensions.map((generated) => generated.dimension).toList(),
    catalogId: catalogId,
    schemaVersion: schemaVersion,
    note: _optionalText(noteSlot, 'Note'),
  );

  @override
  String toString() {
    return '_GeneratedRatingData('
        'targetId: "$targetId", '
        'dimensions: $dimensions, '
        'catalogId: "$catalogId", '
        'schemaVersion: $schemaVersion, '
        'noteSlot: $noteSlot)';
  }
}

extension _AnyRatingData on glados.Any {
  glados.Generator<String> get _ratingText =>
      glados.AnyUtils(this).choose(const [
        '',
        'productivity',
        'energy',
        'challenge_skill',
        'Text with spaces',
        'Text with "quotes"',
        r'Text with \ slash',
      ]);

  glados.Generator<_GeneratedRatingDimension> get generatedRatingDimension =>
      glados.CombinableAny(this).combine7(
        _ratingText,
        glados.IntAnys(this).intInRange(0, 100),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        glados.ListAnys(this).listWithLengthInRange(0, 4, _ratingText),
        glados.ListAnys(this).listWithLengthInRange(
          0,
          4,
          glados.IntAnys(this).intInRange(0, 100),
        ),
        (
          String key,
          int valueSlot,
          int questionSlot,
          int descriptionSlot,
          int inputTypeSlot,
          List<String> optionLabels,
          List<int> optionValueSlots,
        ) => _GeneratedRatingDimension(
          key: key,
          valueSlot: valueSlot,
          questionSlot: questionSlot,
          descriptionSlot: descriptionSlot,
          inputTypeSlot: inputTypeSlot,
          optionLabels: optionLabels,
          optionValueSlots: optionValueSlots,
        ),
      );

  glados.Generator<_GeneratedRatingData> get generatedRatingData =>
      glados.CombinableAny(this).combine5(
        _ratingText,
        glados.ListAnys(this).listWithLengthInRange(
          0,
          5,
          generatedRatingDimension,
        ),
        _ratingText,
        glados.IntAnys(this).intInRange(1, 8),
        glados.IntAnys(this).intInRange(0, 20),
        (
          String targetId,
          List<_GeneratedRatingDimension> dimensions,
          String catalogId,
          int schemaVersion,
          int noteSlot,
        ) => _GeneratedRatingData(
          targetId: targetId,
          dimensions: dimensions,
          catalogId: catalogId,
          schemaVersion: schemaVersion,
          noteSlot: noteSlot,
        ),
      );
}

String? _optionalText(int slot, String prefix) {
  if (slot % 4 == 0) {
    return null;
  }

  return switch (slot % 4) {
    1 => '$prefix $slot',
    2 => '$prefix with "quotes" $slot',
    _ => '$prefix with \\ slash',
  };
}

String? _optionalInputType(int slot) {
  return switch (slot % 5) {
    0 => null,
    1 => 'tapBar',
    2 => 'segmented',
    3 => 'boolean',
    _ => 'future-input',
  };
}
