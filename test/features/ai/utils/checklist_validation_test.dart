import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/utils/checklist_validation.dart';

enum _GeneratedChecklistEntryShape {
  validUnchecked,
  validChecked,
  validPadded,
  validCheckedString,
  emptyTitle,
  whitespaceTitle,
  tooLongTitle,
  missingTitle,
  nonStringTitle,
  stringEntry,
  numberEntry,
  nullEntry,
  listEntry,
}

class _GeneratedChecklistEntry {
  const _GeneratedChecklistEntry({
    required this.shape,
    required this.seed,
  });

  final _GeneratedChecklistEntryShape shape;
  final int seed;

  dynamic get raw => switch (shape) {
    _GeneratedChecklistEntryShape.validUnchecked => {
      'title': 'Generated item $seed',
      'isChecked': false,
    },
    _GeneratedChecklistEntryShape.validChecked => {
      'title': 'Generated checked item $seed',
      'isChecked': true,
    },
    _GeneratedChecklistEntryShape.validPadded => {
      'title': '  Generated padded item $seed  ',
      'isChecked': seed.isEven,
    },
    _GeneratedChecklistEntryShape.validCheckedString => {
      'title': 'Generated string checked item $seed',
      'isChecked': 'true',
    },
    _GeneratedChecklistEntryShape.emptyTitle => {'title': ''},
    _GeneratedChecklistEntryShape.whitespaceTitle => {'title': '   '},
    _GeneratedChecklistEntryShape.tooLongTitle => {'title': 'x' * 401},
    _GeneratedChecklistEntryShape.missingTitle => {'notTitle': 'item $seed'},
    _GeneratedChecklistEntryShape.nonStringTitle => {'title': seed},
    _GeneratedChecklistEntryShape.stringEntry => 'Generated string entry $seed',
    _GeneratedChecklistEntryShape.numberEntry => seed,
    _GeneratedChecklistEntryShape.nullEntry => null,
    _GeneratedChecklistEntryShape.listEntry => ['Generated', seed],
  };

  ({String title, bool isChecked})? get expected => switch (shape) {
    _GeneratedChecklistEntryShape.validUnchecked => (
      title: 'Generated item $seed',
      isChecked: false,
    ),
    _GeneratedChecklistEntryShape.validChecked => (
      title: 'Generated checked item $seed',
      isChecked: true,
    ),
    _GeneratedChecklistEntryShape.validPadded => (
      title: 'Generated padded item $seed',
      isChecked: seed.isEven,
    ),
    _GeneratedChecklistEntryShape.validCheckedString => (
      title: 'Generated string checked item $seed',
      isChecked: false,
    ),
    _ => null,
  };

  @override
  String toString() {
    return '_GeneratedChecklistEntry(shape: $shape, seed: $seed)';
  }
}

class _GeneratedChecklistValidationScenario {
  const _GeneratedChecklistValidationScenario({required this.entries});

  final List<_GeneratedChecklistEntry> entries;

  List<dynamic> get rawEntries => entries.map((entry) => entry.raw).toList();

  List<({String title, bool isChecked})> get expectedItems =>
      entries.map((entry) => entry.expected).nonNulls.toList();

  @override
  String toString() {
    return '_GeneratedChecklistValidationScenario(entries: $entries)';
  }
}

extension _AnyGeneratedChecklistValidationScenario on glados.Any {
  glados.Generator<_GeneratedChecklistEntryShape> get checklistEntryShape =>
      glados.AnyUtils(this).choose(_GeneratedChecklistEntryShape.values);

  glados.Generator<_GeneratedChecklistEntry> get checklistEntry =>
      glados.CombinableAny(this).combine2(
        checklistEntryShape,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedChecklistEntryShape shape,
          int seed,
        ) => _GeneratedChecklistEntry(shape: shape, seed: seed),
      );

  glados.Generator<_GeneratedChecklistValidationScenario>
  get checklistValidationScenario => glados.ListAnys(this)
      .listWithLengthInRange(0, 30, checklistEntry)
      .map(
        (entries) => _GeneratedChecklistValidationScenario(
          entries: entries,
        ),
      );

  /// Sizes within the valid batch range: `[1, maxBatchSize]`.
  glados.Generator<int> get validBatchSize => glados.IntAnys(
    this,
  ).intInRange(1, ChecklistValidation.maxBatchSize + 1);

  /// Sizes strictly above `maxBatchSize`.
  glados.Generator<int> get tooLargeBatchSize =>
      glados.IntAnys(this).intInRange(
        ChecklistValidation.maxBatchSize + 1,
        ChecklistValidation.maxBatchSize + 1001,
      );

  /// Non-positive sizes: `<= 0`.
  glados.Generator<int> get nonPositiveBatchSize =>
      glados.IntAnys(this).intInRange(-1000, 1);

  /// Strictly negative sizes: `< 0`, which hit the generic fallback message.
  glados.Generator<int> get negativeBatchSize =>
      glados.IntAnys(this).intInRange(-1000, 0);
}

void main() {
  group('ChecklistValidation', () {
    group('constants', () {
      test('should have correct max title length', () {
        expect(ChecklistValidation.maxTitleLength, 400);
      });

      test('should have correct max batch size', () {
        expect(ChecklistValidation.maxBatchSize, 20);
      });
    });

    group('validateItems', () {
      test('should validate and sanitize valid items', () {
        final raw = [
          {'title': 'Buy milk', 'isChecked': false},
          {'title': 'Walk dog', 'isChecked': true},
          {'title': '  Trim whitespace  ', 'isChecked': false},
        ];

        final result = ChecklistValidation.validateItems(raw);

        expect(result.length, 3);
        expect(result[0].title, 'Buy milk');
        expect(result[0].isChecked, false);
        expect(result[1].title, 'Walk dog');
        expect(result[1].isChecked, true);
        expect(result[2].title, 'Trim whitespace');
        expect(result[2].isChecked, false);
      });

      test('should handle missing isChecked field', () {
        final raw = [
          {'title': 'Task without isChecked'},
          {'title': 'Another task'},
        ];

        final result = ChecklistValidation.validateItems(raw);

        expect(result.length, 2);
        expect(result[0].title, 'Task without isChecked');
        expect(result[0].isChecked, false);
        expect(result[1].title, 'Another task');
        expect(result[1].isChecked, false);
      });

      test('should handle various isChecked values', () {
        final raw = [
          {'title': 'True boolean', 'isChecked': true},
          {'title': 'False boolean', 'isChecked': false},
          {'title': 'Null value', 'isChecked': null},
          {'title': 'String value', 'isChecked': 'true'},
          {'title': 'Number value', 'isChecked': 1},
          {'title': 'Zero value', 'isChecked': 0},
        ];

        final result = ChecklistValidation.validateItems(raw);

        expect(result.length, 6);
        expect(result[0].isChecked, true);
        expect(result[1].isChecked, false);
        expect(result[2].isChecked, false); // null -> false
        expect(result[3].isChecked, false); // 'true' string -> false
        expect(result[4].isChecked, false); // 1 -> false
        expect(result[5].isChecked, false); // 0 -> false
      });

      test('should filter out invalid items', () {
        final raw = [
          {'title': 'Valid item'},
          {'title': ''}, // Empty title
          {'title': '   '}, // Whitespace only
          {'no_title': 'Missing title field'},
          'String instead of map',
          123, // Number
          null, // Null
          {'title': null}, // Null title
          {'title': 123}, // Non-string title
        ];

        final result = ChecklistValidation.validateItems(raw);

        expect(result.length, 1);
        expect(result[0].title, 'Valid item');
      });

      test('should filter out items exceeding max title length', () {
        final longTitle = 'a' * 401; // 401 characters
        final maxTitle = 'b' * 400; // Exactly 400 characters

        final raw = [
          {'title': longTitle},
          {'title': maxTitle},
          {'title': 'Normal length'},
        ];

        final result = ChecklistValidation.validateItems(raw);

        expect(result.length, 2);
        expect(result[0].title, maxTitle);
        expect(result[1].title, 'Normal length');
      });

      test('should handle empty list', () {
        final result = ChecklistValidation.validateItems([]);
        expect(result, isEmpty);
      });

      test('should preserve item order', () {
        final raw = [
          {'title': 'First', 'isChecked': true},
          {'title': 'Second', 'isChecked': false},
          {'title': 'Third', 'isChecked': true},
        ];

        final result = ChecklistValidation.validateItems(raw);

        expect(result.length, 3);
        expect(result[0].title, 'First');
        expect(result[1].title, 'Second');
        expect(result[2].title, 'Third');
      });

      glados.Glados(
        glados.any.checklistValidationScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated sanitization and per-entry validation semantics',
        (scenario) {
          final result = ChecklistValidation.validateItems(
            scenario.rawEntries,
          );

          expect(
            result,
            scenario.expectedItems,
            reason: '$scenario',
          );

          for (final entry in scenario.entries) {
            expect(
              ChecklistValidation.validateItemEntry(entry.raw) == null,
              entry.expected != null,
              reason: '$scenario entry=$entry',
            );
          }

          expect(
            ChecklistValidation.isValidBatchSize(result.length),
            result.isNotEmpty &&
                result.length <= ChecklistValidation.maxBatchSize,
            reason: '$scenario',
          );
        },
        tags: 'glados',
      );
    });

    group('validateItemEntry', () {
      test('should return null for valid item', () {
        final item = {'title': 'Valid item', 'isChecked': false};
        expect(ChecklistValidation.validateItemEntry(item), isNull);
      });

      test('should return null for valid item with only title', () {
        final item = {'title': 'Valid item'};
        expect(ChecklistValidation.validateItemEntry(item), isNull);
      });

      test('should return error for string entry', () {
        final error = ChecklistValidation.validateItemEntry('String item');
        expect(error, contains('Each item must be an object'));
        expect(error, contains('Example'));
      });

      test('should return error for non-map entry', () {
        final error = ChecklistValidation.validateItemEntry(123);
        expect(error, contains('Invalid item format'));
        expect(error, contains('expected an object'));
      });

      test('should return error for null entry', () {
        final error = ChecklistValidation.validateItemEntry(null);
        expect(error, contains('Invalid item format'));
        expect(error, contains('expected an object'));
      });

      test('should return error for missing title', () {
        final item = {'no_title': 'value'};
        final error = ChecklistValidation.validateItemEntry(item);
        expect(error, 'Item title must be a string');
      });

      test('should return error for non-string title', () {
        final item = {'title': 123};
        final error = ChecklistValidation.validateItemEntry(item);
        expect(error, 'Item title must be a string');
      });

      test('should return error for null title', () {
        final item = {'title': null};
        final error = ChecklistValidation.validateItemEntry(item);
        expect(error, 'Item title must be a string');
      });

      test('should return error for empty title', () {
        final item = {'title': ''};
        final error = ChecklistValidation.validateItemEntry(item);
        expect(error, 'Item title cannot be empty');
      });

      test('should return error for whitespace-only title', () {
        final item = {'title': '   '};
        final error = ChecklistValidation.validateItemEntry(item);
        expect(error, 'Item title cannot be empty');
      });

      test('should return error for title exceeding max length', () {
        final longTitle = 'a' * 401;
        final item = {'title': longTitle};
        final error = ChecklistValidation.validateItemEntry(item);
        expect(error, contains('exceeds maximum length'));
        expect(error, contains('400'));
      });

      test('should accept title at max length', () {
        final maxTitle = 'b' * 400;
        final item = {'title': maxTitle};
        expect(ChecklistValidation.validateItemEntry(item), isNull);
      });

      test('should handle items with extra fields', () {
        final item = {
          'title': 'Valid item',
          'isChecked': true,
          'extra': 'field',
          'another': 123,
        };
        expect(ChecklistValidation.validateItemEntry(item), isNull);
      });
    });

    group('isValidBatchSize', () {
      test('should accept valid batch sizes', () {
        expect(ChecklistValidation.isValidBatchSize(1), isTrue);
        expect(ChecklistValidation.isValidBatchSize(10), isTrue);
        expect(ChecklistValidation.isValidBatchSize(20), isTrue);
      });

      test('should reject invalid batch sizes', () {
        expect(ChecklistValidation.isValidBatchSize(0), isFalse);
        expect(ChecklistValidation.isValidBatchSize(-1), isFalse);
        expect(ChecklistValidation.isValidBatchSize(21), isFalse);
        expect(ChecklistValidation.isValidBatchSize(100), isFalse);
      });

      test('should handle boundary values', () {
        expect(ChecklistValidation.isValidBatchSize(1), isTrue); // Min valid
        expect(ChecklistValidation.isValidBatchSize(20), isTrue); // Max valid
        expect(ChecklistValidation.isValidBatchSize(0), isFalse); // Below min
        expect(ChecklistValidation.isValidBatchSize(21), isFalse); // Above max
      });

      glados.Glados(glados.any.validBatchSize).test(
        'is true for every size within [1, maxBatchSize]',
        (size) {
          expect(ChecklistValidation.isValidBatchSize(size), isTrue);
        },
        tags: 'glados',
      );

      glados.Glados(glados.any.tooLargeBatchSize).test(
        'is false for every size above maxBatchSize',
        (size) {
          expect(ChecklistValidation.isValidBatchSize(size), isFalse);
        },
        tags: 'glados',
      );

      glados.Glados(glados.any.nonPositiveBatchSize).test(
        'is false for every non-positive size',
        (size) {
          expect(ChecklistValidation.isValidBatchSize(size), isFalse);
        },
        tags: 'glados',
      );
    });

    group('getBatchSizeErrorMessage', () {
      test('should return specific message for zero items', () {
        final message = ChecklistValidation.getBatchSizeErrorMessage(0);
        expect(message, contains('No valid items found'));
        expect(message, contains('400 chars'));
      });

      test('should return specific message for too many items', () {
        final message = ChecklistValidation.getBatchSizeErrorMessage(21);
        expect(message, contains('Too many items'));
        expect(message, contains('max 20'));
      });

      test('should return generic message for other invalid sizes', () {
        final message = ChecklistValidation.getBatchSizeErrorMessage(-5);
        expect(message, 'Invalid batch size: -5');
      });

      test('should handle extremely large sizes', () {
        final message = ChecklistValidation.getBatchSizeErrorMessage(1000);
        expect(message, contains('Too many items'));
        expect(message, contains('max 20'));
      });

      glados.Glados(glados.any.tooLargeBatchSize).test(
        'reports "Too many items" for every size above maxBatchSize',
        (size) {
          expect(
            ChecklistValidation.getBatchSizeErrorMessage(size),
            contains('Too many items'),
          );
        },
        tags: 'glados',
      );

      glados.Glados(glados.any.negativeBatchSize).test(
        'reports the generic "Invalid batch size" message for negative sizes',
        (size) {
          expect(
            ChecklistValidation.getBatchSizeErrorMessage(size),
            'Invalid batch size: $size',
          );
        },
        tags: 'glados',
      );
    });

    group('integration scenarios', () {
      test('should handle mixed valid and invalid items', () {
        final raw = [
          {'title': 'Valid 1'},
          {'title': ''}, // Invalid: empty
          {'title': 'Valid 2', 'isChecked': true},
          null, // Invalid: null
          {'title': 'a' * 401}, // Invalid: too long
          {'title': '  Valid 3  '}, // Valid: will be trimmed
          'String item', // Invalid: not a map
          {'no_title': 'Missing'}, // Invalid: no title
          {
            'title': 'Valid 4',
            'isChecked': 'wrong',
          }, // Valid but isChecked will be false
        ];

        final result = ChecklistValidation.validateItems(raw);

        expect(result.length, 4);
        expect(result[0].title, 'Valid 1');
        expect(result[1].title, 'Valid 2');
        expect(result[2].title, 'Valid 3');
        expect(result[3].title, 'Valid 4');

        expect(result[0].isChecked, false);
        expect(result[1].isChecked, true);
        expect(result[2].isChecked, false);
        expect(result[3].isChecked, false);
      });

      test('should validate items then check batch size', () {
        // Create 25 items (5 invalid, 20 valid)
        final raw = List.generate(25, (i) {
          if (i < 5) {
            return {'title': ''}; // Invalid: empty title
          }
          return {'title': 'Item ${i - 4}', 'isChecked': i.isEven};
        });

        final validated = ChecklistValidation.validateItems(raw);
        expect(validated.length, 20);

        final isValidSize = ChecklistValidation.isValidBatchSize(
          validated.length,
        );
        expect(isValidSize, isTrue);
      });

      test('should handle Unicode and special characters', () {
        final raw = [
          {'title': '🎉 Celebration item'},
          {'title': 'Item with "quotes"'},
          {'title': 'Item with\nnewline'},
          {'title': 'Ítém wíth áccénts'},
          {'title': '项目 (Chinese)'},
          {'title': 'مهمة (Arabic)'},
          {'title': '🚀🎯📝 Multiple emojis'},
        ];

        final result = ChecklistValidation.validateItems(raw);

        expect(result.length, 7);
        expect(result[0].title, '🎉 Celebration item');
        expect(result[1].title, 'Item with "quotes"');
        expect(result[2].title, 'Item with\nnewline');
        expect(result[3].title, 'Ítém wíth áccénts');
        expect(result[4].title, '项目 (Chinese)');
        expect(result[5].title, 'مهمة (Arabic)');
        expect(result[6].title, '🚀🎯📝 Multiple emojis');
      });

      test(
        'should handle edge case with exactly 400 chars including Unicode',
        () {
          // Unicode characters can be multiple bytes but should count as single chars
          const unicodeChar = '🎉';
          const baseText = 'Task ';
          const paddingLength = 400 - baseText.length - unicodeChar.length;
          final title = baseText + ('x' * paddingLength) + unicodeChar;

          expect(title.length, 400); // Verify our test setup

          final raw = [
            {'title': title},
          ];

          final result = ChecklistValidation.validateItems(raw);
          expect(result.length, 1);
          expect(result[0].title, title);
        },
      );
    });
  });
}
