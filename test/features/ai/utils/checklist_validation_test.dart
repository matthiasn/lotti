import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/utils/checklist_validation.dart';

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

      test('should handle list with all invalid items', () {
        final raw = [
          '',
          null,
          123,
          {'no_title': 'value'},
          {'title': ''},
          {'title': null},
        ];

        final result = ChecklistValidation.validateItems(raw);
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
        expect(ChecklistValidation.isValidBatchSize(1), true);
        expect(ChecklistValidation.isValidBatchSize(10), true);
        expect(ChecklistValidation.isValidBatchSize(20), true);
      });

      test('should reject invalid batch sizes', () {
        expect(ChecklistValidation.isValidBatchSize(0), false);
        expect(ChecklistValidation.isValidBatchSize(-1), false);
        expect(ChecklistValidation.isValidBatchSize(21), false);
        expect(ChecklistValidation.isValidBatchSize(100), false);
      });

      test('should handle boundary values', () {
        expect(ChecklistValidation.isValidBatchSize(1), true); // Min valid
        expect(ChecklistValidation.isValidBatchSize(20), true); // Max valid
        expect(ChecklistValidation.isValidBatchSize(0), false); // Below min
        expect(ChecklistValidation.isValidBatchSize(21), false); // Above max
      });
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
            'isChecked': 'wrong'
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

        final isValidSize =
            ChecklistValidation.isValidBatchSize(validated.length);
        expect(isValidSize, true);
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

      test('should handle edge case with exactly 400 chars including Unicode',
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
      });
    });
  });
}
