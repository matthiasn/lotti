import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/text_preprocessing.dart';

void main() {
  group('applyNfkdDecomposition', () {
    test('leaves plain ASCII untouched', () {
      expect(applyNfkdDecomposition('hello'), 'hello');
    });

    test('decomposes an accented Latin char into base + combining mark', () {
      // á (U+00E1) → a (U+0061) + combining acute (U+0301).
      final out = applyNfkdDecomposition('á');
      expect(out.runes.toList(), [0x0061, 0x0301]);
    });

    test('decomposes a Hangul syllable into Jamo', () {
      // 한 (U+D55C) → leading ㅎ + vowel ㅏ + trailing ㄴ (3 jamo).
      final out = applyNfkdDecomposition('한');
      expect(out.runes.length, 3);
      expect(out.runes.first, greaterThanOrEqualTo(0x1100));
    });
  });

  group('preprocessText', () {
    test('wraps the result in language tags', () {
      expect(preprocessText('hello', 'en'), '<en>hello.</en>');
    });

    test('adds a terminal period only when missing', () {
      expect(preprocessText('hi', 'en'), '<en>hi.</en>');
      expect(preprocessText('hi!', 'en'), '<en>hi!</en>');
      expect(preprocessText('really?', 'en'), '<en>really?</en>');
    });

    test('collapses whitespace and normalizes curly quotes', () {
      expect(preprocessText('a   b', 'en'), '<en>a b.</en>');
      // Ends in a double quote, which already counts as terminal punctuation,
      // so no period is appended.
      expect(preprocessText('“x”', 'en'), '<en>"x"</en>');
    });

    test('expands known abbreviations and @', () {
      expect(preprocessText('e.g., x', 'en'), '<en>for example, x.</en>');
      expect(preprocessText('a@b', 'en'), '<en>a at b.</en>');
    });

    test('strips emoji', () {
      expect(preprocessText('hi 😀', 'en'), '<en>hi.</en>');
    });

    test('accepts the language-agnostic na tag', () {
      expect(preprocessText('x', 'na'), '<na>x.</na>');
    });

    test('throws on an unsupported language', () {
      expect(() => preprocessText('x', 'xx'), throwsArgumentError);
    });
  });

  group('isValidSupertonicLang', () {
    test('accepts shipped languages including na, rejects others', () {
      expect(isValidSupertonicLang('en'), isTrue);
      expect(isValidSupertonicLang('na'), isTrue);
      expect(isValidSupertonicLang('xx'), isFalse);
    });
  });

  group('quote normalization', () {
    test('collapses doubled straight quotes', () {
      expect(preprocessText('say ""hi""', 'en'), isNot(contains('""')));
    });

    test('collapses doubled apostrophes', () {
      expect(preprocessText("it''s", 'en'), isNot(contains("''")));
    });

    test('collapses doubled backticks', () {
      expect(preprocessText('a``b', 'en'), isNot(contains('``')));
    });
  });
}
