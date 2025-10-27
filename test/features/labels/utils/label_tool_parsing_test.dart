import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';

void main() {
  group('parseLabelIdsFromToolArgs', () {
    test('parses JSON array of strings', () {
      const json = '{"labelIds":["bug","backend","priority-high"]}';
      final result = parseLabelIdsFromToolArgs(json);
      expect(result, ['bug', 'backend', 'priority-high']);
    });

    test('parses JSON array with non-strings via toString and trims', () {
      const json = '{"labelIds":["a"," b ",123]}';
      final result = parseLabelIdsFromToolArgs(json);
      expect(result, ['a', 'b', '123']);
    });

    test('parses comma-separated string and ignores empties', () {
      const json = '{"labelIds":"a, b, , c ,,d"}';
      final result = parseLabelIdsFromToolArgs(json);
      expect(result, ['a', 'b', 'c', 'd']);
    });

    test('returns empty list when key missing', () {
      const json = '{"other":"value"}';
      final result = parseLabelIdsFromToolArgs(json);
      expect(result, isEmpty);
    });

    test('returns empty list for invalid JSON', () {
      const json = 'not-json';
      final result = parseLabelIdsFromToolArgs(json);
      expect(result, isEmpty);
    });

    test('returns empty list when comma string is whitespace only', () {
      const json = '{"labelIds":"   ,  ,   "}';
      final result = parseLabelIdsFromToolArgs(json);
      expect(result, isEmpty);
    });
  });
}
