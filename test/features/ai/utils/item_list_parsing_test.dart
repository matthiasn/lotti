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

    test('handles nested quotes in items', () {
      expect(
        parseItemListString('"item with \'nested\' quotes", other'),
        ["item with 'nested' quotes", 'other'],
      );
    });

    test('handles mixed grouping with parentheses inside brackets', () {
      expect(parseItemListString('[item (with, nested), groups], next'),
          ['[item (with, nested), groups]', 'next']);
    });

    test('returns empty list for empty input', () {
      expect(parseItemListString(''), const <String>[]);
      expect(parseItemListString('   '), const <String>[]);
    });

    test('trailing backslash is ignored (best-effort)', () {
      expect(parseItemListString(r'item\'), ['item']);
    });

    test('multiple consecutive escapes', () {
      // Four backslashes become a single literal backslash before the comma
      expect(parseItemListString(r'a\\, b'), [r'a\', 'b']);
    });

    test('unbalanced grouping keeps commas unsplit', () {
      expect(parseItemListString('(unclosed, bracket, next'),
          ['(unclosed, bracket, next']);
    });

    test('quotes in the middle of items', () {
      expect(parseItemListString('item "middle, part" end, next'),
          ['item middle, part end', 'next']);
    });

    test('handles newlines and tabs around commas', () {
      expect(parseItemListString('item1\n, item2\t'), ['item1', 'item2']);
    });

    test('handles unicode characters', () {
      expect(parseItemListString('Café, naïve, 日本語'), ['Café', 'naïve', '日本語']);
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
