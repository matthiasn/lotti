import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/utils/item_list_parsing.dart';

enum _GeneratedItemListShape {
  plain,
  padded,
  doubleQuotedComma,
  singleQuotedComma,
  escapedComma,
  parentheses,
  brackets,
  braces,
}

class _GeneratedItemListElement {
  const _GeneratedItemListElement({
    required this.shape,
    required this.seed,
  });

  final _GeneratedItemListShape shape;
  final int seed;

  String get base => 'item-$seed';

  String get rawSegment => switch (shape) {
    _GeneratedItemListShape.plain => base,
    _GeneratedItemListShape.padded => '  $base  ',
    _GeneratedItemListShape.doubleQuotedComma => '"$base, detail"',
    _GeneratedItemListShape.singleQuotedComma => "'$base, detail'",
    _GeneratedItemListShape.escapedComma => '$base\\, detail',
    _GeneratedItemListShape.parentheses => '$base (left, right)',
    _GeneratedItemListShape.brackets => '[$base, detail]',
    _GeneratedItemListShape.braces => '{$base: left, right}',
  };

  String get expected => switch (shape) {
    _GeneratedItemListShape.plain => base,
    _GeneratedItemListShape.padded => base,
    _GeneratedItemListShape.doubleQuotedComma => '$base, detail',
    _GeneratedItemListShape.singleQuotedComma => '$base, detail',
    _GeneratedItemListShape.escapedComma => '$base, detail',
    _GeneratedItemListShape.parentheses => '$base (left, right)',
    _GeneratedItemListShape.brackets => '[$base, detail]',
    _GeneratedItemListShape.braces => '{$base: left, right}',
  };

  @override
  String toString() {
    return '_GeneratedItemListElement(shape: $shape, seed: $seed)';
  }
}

class _GeneratedItemListScenario {
  const _GeneratedItemListScenario({
    required this.elements,
    required this.leadingSeparator,
    required this.trailingSeparator,
  });

  final List<_GeneratedItemListElement> elements;
  final bool leadingSeparator;
  final bool trailingSeparator;

  String get input {
    final body = elements.map((element) => element.rawSegment).join(', ');
    return [
      if (leadingSeparator) '',
      body,
      if (trailingSeparator) '',
    ].join(', ');
  }

  List<String> get expected =>
      elements.map((element) => element.expected).toList();

  @override
  String toString() {
    return '_GeneratedItemListScenario('
        'elements: $elements, '
        'leadingSeparator: $leadingSeparator, '
        'trailingSeparator: $trailingSeparator)';
  }
}

extension _AnyGeneratedItemListScenario on glados.Any {
  glados.Generator<_GeneratedItemListShape> get itemListShape =>
      glados.AnyUtils(this).choose(_GeneratedItemListShape.values);

  glados.Generator<_GeneratedItemListElement> get itemListElement =>
      glados.CombinableAny(this).combine2(
        itemListShape,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedItemListShape shape,
          int seed,
        ) => _GeneratedItemListElement(shape: shape, seed: seed),
      );

  glados.Generator<_GeneratedItemListScenario> get itemListScenario =>
      glados.CombinableAny(this).combine3(
        glados.ListAnys(this).listWithLengthInRange(0, 8, itemListElement),
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        (
          List<_GeneratedItemListElement> elements,
          bool leadingSeparator,
          bool trailingSeparator,
        ) => _GeneratedItemListScenario(
          elements: elements,
          leadingSeparator: leadingSeparator,
          trailingSeparator: trailingSeparator,
        ),
      );
}

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
      expect(parseItemListString('[item (with, nested), groups], next'), [
        '[item (with, nested), groups]',
        'next',
      ]);
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
      expect(parseItemListString('(unclosed, bracket, next'), [
        '(unclosed, bracket, next',
      ]);
    });

    test('quotes in the middle of items', () {
      expect(parseItemListString('item "middle, part" end, next'), [
        'item middle, part end',
        'next',
      ]);
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

    glados.Glados(
      glados.any.itemListScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('roundtrips generated escaped and grouped item lists', (scenario) {
      expect(
        parseItemListString(scenario.input),
        scenario.expected,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
}
