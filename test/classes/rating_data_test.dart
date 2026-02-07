import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/rating_data.dart';

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
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
      );

      expect(data.timeEntryId, equals('entry-1'));
      expect(data.dimensions, equals(testDimensions));
      expect(data.schemaVersion, equals(1));
      expect(data.note, isNull);
    });

    test('creates with all fields', () {
      const data = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
        schemaVersion: 2,
        note: 'Great session',
      );

      expect(data.timeEntryId, equals('entry-1'));
      expect(data.dimensions.length, equals(4));
      expect(data.schemaVersion, equals(2));
      expect(data.note, equals('Great session'));
    });

    test('equality works correctly', () {
      const data1 = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
        note: 'test',
      );
      const data2 = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
        note: 'test',
      );

      expect(data1, equals(data2));
    });

    test('inequality with different timeEntryId', () {
      const data1 = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
      );
      const data2 = RatingData(
        timeEntryId: 'entry-2',
        dimensions: testDimensions,
      );

      expect(data1, isNot(equals(data2)));
    });

    test('copyWith preserves fields', () {
      const data = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
        note: 'original note',
      );

      final updated = data.copyWith(note: 'updated note');

      expect(updated.timeEntryId, equals('entry-1'));
      expect(updated.dimensions, equals(testDimensions));
      expect(updated.note, equals('updated note'));
    });

    test('copyWith can clear optional note', () {
      const data = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
        note: 'some note',
      );

      final updated = data.copyWith(note: null);

      expect(updated.note, isNull);
    });

    test('copyWith can update dimensions', () {
      const data = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
      );

      const newDimensions = [
        RatingDimension(key: 'productivity', value: 1),
      ];

      final updated = data.copyWith(dimensions: newDimensions);

      expect(updated.dimensions, equals(newDimensions));
      expect(updated.timeEntryId, equals('entry-1'));
    });

    test('serializes to and from JSON', () {
      const data = RatingData(
        timeEntryId: 'entry-1',
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
        timeEntryId: 'entry-abc',
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

      expect(decoded.timeEntryId, equals('entry-abc'));
      expect(decoded.dimensions.length, equals(4));
      expect(decoded.dimensions[0].key, equals('productivity'));
      expect(decoded.dimensions[0].value, equals(0.85));
      expect(decoded.schemaVersion, equals(1));
      expect(decoded.note, equals('Feeling great'));
    });

    test('dimensionValue returns value for existing key', () {
      const data = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
      );

      expect(data.dimensionValue('productivity'), equals(0.8));
      expect(data.dimensionValue('energy'), equals(0.6));
      expect(data.dimensionValue('focus'), equals(0.9));
      expect(data.dimensionValue('challenge_skill'), equals(0.5));
    });

    test('dimensionValue returns null for missing key', () {
      const data = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
      );

      expect(data.dimensionValue('nonexistent'), isNull);
    });

    test('dimensionValue returns null for empty dimensions', () {
      const data = RatingData(
        timeEntryId: 'entry-1',
        dimensions: [],
      );

      expect(data.dimensionValue('productivity'), isNull);
    });

    test('serializes without optional note', () {
      const data = RatingData(
        timeEntryId: 'entry-1',
        dimensions: testDimensions,
      );

      final jsonString = jsonEncode(data.toJson());
      final restored = RatingData.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(restored.note, isNull);
      expect(restored, equals(data));
    });
  });
}
