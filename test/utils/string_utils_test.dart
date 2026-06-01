import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/string_utils.dart';

enum _GeneratedWhitespaceTokenShape {
  lower,
  upper,
  digits,
  symbol,
  mixed,
}

class _GeneratedWhitespaceToken {
  const _GeneratedWhitespaceToken({
    required this.seed,
    required this.shape,
  });

  final int seed;
  final _GeneratedWhitespaceTokenShape shape;

  String get text => switch (shape) {
    _GeneratedWhitespaceTokenShape.lower => 'alpha$seed',
    _GeneratedWhitespaceTokenShape.upper => 'VALUE$seed',
    _GeneratedWhitespaceTokenShape.digits => 'id${seed}42',
    _GeneratedWhitespaceTokenShape.symbol => 'C++$seed',
    _GeneratedWhitespaceTokenShape.mixed => 'task_${seed}_done',
  };

  @override
  String toString() {
    return '_GeneratedWhitespaceToken(seed: $seed, shape: $shape)';
  }
}

class _GeneratedWhitespaceScenario {
  const _GeneratedWhitespaceScenario({
    required this.tokens,
    required this.leading,
    required this.separator,
    required this.trailing,
  });

  final List<_GeneratedWhitespaceToken> tokens;
  final String leading;
  final String separator;
  final String trailing;

  String get input {
    if (tokens.isEmpty) return '$leading$trailing';
    return '$leading${tokens.map((token) => token.text).join(separator)}'
        '$trailing';
  }

  String get expected => tokens.map((token) => token.text).join(' ');

  @override
  String toString() {
    return '_GeneratedWhitespaceScenario('
        'tokens: $tokens, '
        'leading: ${leading.runes.toList()}, '
        'separator: ${separator.runes.toList()}, '
        'trailing: ${trailing.runes.toList()})';
  }
}

extension _AnyNormalizeWhitespace on glados.Any {
  glados.Generator<String> get whitespace =>
      glados.AnyUtils(this).choose(const [
        '',
        ' ',
        '  ',
        '\t',
        '\n',
        '\r\n',
        '\f',
        ' \t\n ',
      ]);

  glados.Generator<String> get interTokenWhitespace =>
      glados.AnyUtils(this).choose(const [
        ' ',
        '  ',
        '\t',
        '\n',
        '\r\n',
        '\f',
        ' \t\n ',
      ]);

  glados.Generator<_GeneratedWhitespaceTokenShape> get whitespaceTokenShape =>
      glados.AnyUtils(this).choose(_GeneratedWhitespaceTokenShape.values);

  glados.Generator<_GeneratedWhitespaceToken> get whitespaceToken =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 10000),
        whitespaceTokenShape,
        (
          int seed,
          _GeneratedWhitespaceTokenShape shape,
        ) => _GeneratedWhitespaceToken(seed: seed, shape: shape),
      );

  glados.Generator<_GeneratedWhitespaceScenario> get whitespaceScenario =>
      glados.CombinableAny(this).combine4(
        glados.ListAnys(this).listWithLengthInRange(0, 9, whitespaceToken),
        whitespace,
        interTokenWhitespace,
        whitespace,
        (
          List<_GeneratedWhitespaceToken> tokens,
          String leading,
          String separator,
          String trailing,
        ) => _GeneratedWhitespaceScenario(
          tokens: tokens,
          leading: leading,
          separator: separator,
          trailing: trailing,
        ),
      );
}

void main() {
  group('normalizeWhitespace', () {
    test('trims leading whitespace', () {
      expect(normalizeWhitespace('   hello'), equals('hello'));
    });

    test('trims trailing whitespace', () {
      expect(normalizeWhitespace('hello   '), equals('hello'));
    });

    test('trims both leading and trailing whitespace', () {
      expect(normalizeWhitespace('   hello   '), equals('hello'));
    });

    test('collapses multiple internal spaces to single space', () {
      expect(normalizeWhitespace('hello   world'), equals('hello world'));
    });

    test('collapses tabs to single space', () {
      expect(normalizeWhitespace('hello\t\tworld'), equals('hello world'));
    });

    test('collapses newlines to single space', () {
      expect(normalizeWhitespace('hello\n\nworld'), equals('hello world'));
    });

    test('collapses mixed whitespace to single space', () {
      expect(
        normalizeWhitespace('hello \t\n  world'),
        equals('hello world'),
      );
    });

    test('handles empty string', () {
      expect(normalizeWhitespace(''), equals(''));
    });

    test('handles whitespace-only string', () {
      expect(normalizeWhitespace('   '), equals(''));
    });

    test('handles single word', () {
      expect(normalizeWhitespace('hello'), equals('hello'));
    });

    test('handles multiple words correctly', () {
      expect(
        normalizeWhitespace('  hello   beautiful   world  '),
        equals('hello beautiful world'),
      );
    });

    test('preserves single spaces between words', () {
      expect(
        normalizeWhitespace('hello world'),
        equals('hello world'),
      );
    });

    test('handles special characters', () {
      expect(
        normalizeWhitespace('  C++  is   great  '),
        equals('C++ is great'),
      );
    });

    test('handles Unicode characters', () {
      expect(
        normalizeWhitespace('  Kirkjubæjarklaustur   is   in   Iceland  '),
        equals('Kirkjubæjarklaustur is in Iceland'),
      );
    });

    test('handles carriage return', () {
      expect(normalizeWhitespace('hello\r\nworld'), equals('hello world'));
    });

    test('handles form feed', () {
      expect(normalizeWhitespace('hello\fworld'), equals('hello world'));
    });

    glados.Glados(
      glados.any.whitespaceScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated token and whitespace model',
      (scenario) {
        expect(
          normalizeWhitespace(scenario.input),
          scenario.expected,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.stringOf(' abcXYZ123\t\n\r\f'),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'is idempotent and emits only trimmed single-space separators',
      (input) {
        final normalized = normalizeWhitespace(input);

        expect(
          normalizeWhitespace(normalized),
          normalized,
          reason: input,
        );
        expect(normalized.trim(), normalized, reason: input);
        expect(RegExp(r'\s{2,}').hasMatch(normalized), isFalse, reason: input);
        expect(
          RegExp(r'[\t\r\n\f]').hasMatch(normalized),
          isFalse,
          reason: input,
        );
      },
      tags: 'glados',
    );
  });
}
