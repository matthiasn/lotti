import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/utils/item_list_parsing.dart';

void main() {
  group('parseItemListString', () {
    test('splits simple comma-separated values', () {
      expect(parseItemListString('a, b, c'), ['a', 'b', 'c']);
    });

    test('handles quoted items containing commas', () {
      expect(parseItemListString('"a, b", c'), ['a, b', 'c']);
      expect(parseItemListString("'a, b', c"), ['a, b', 'c']);
    });

    test('handles escaped commas', () {
      expect(parseItemListString(r'a\, b, c'), ['a, b', 'c']);
    });

    test('does not split commas in parentheses/brackets/braces', () {
      expect(parseItemListString('x(y, z), w'), ['x(y, z)', 'w']);
      expect(parseItemListString('[a, b], c'), ['[a, b]', 'c']);
      expect(parseItemListString('{k: a, b}, c'), ['{k: a, b}', 'c']);
    });

    test('trims and discards empties', () {
      expect(parseItemListString('a, , b , ,'), ['a', 'b']);
    });
  });
}
