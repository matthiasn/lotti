import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/uuid.dart';

void main() {
  group('UUID test', () {
    test('Generated UUID is valid', () {
      expect(isUuid(uuid.v1()), true);
    });

    test('Returns true for valid UUID', () {
      expect(isUuid('123e4567-e89b-12d3-a456-426614174000'), true);
    });

    test('Returns false for null', () {
      expect(isUuid(null), false);
    });

    test('Returns false for empty string', () {
      expect(isUuid(''), false);
    });

    test('Returns false for string without hyphens', () {
      expect(isUuid('123e4567e89b12d3a456426614174000'), false);
    });

    test('Returns false for string with invalid length', () {
      expect(isUuid('123e4567-e89b-12d3-a456-42661417400'), false);
    });

    test('Returns false for string with invalid characters', () {
      expect(isUuid('123e4567-e89b-12d3-a456-42661417400g'), false);
    });
  });
}
