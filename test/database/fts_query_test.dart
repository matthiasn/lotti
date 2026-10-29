import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/fts_query.dart';

void main() {
  group('ftsMatchExpression', () {
    test('every word is a required phrase, the last one also a prefix '
        'while it is being typed', () {
      expect(ftsMatchExpression('penguin census'), '"penguin" "census"*');
      expect(ftsMatchExpression('penguin census '), '"penguin" "census"');
    });

    test('a one-letter last word matches whole, not as a prefix', () {
      expect(ftsMatchExpression('plan a'), '"plan" "a"');
    });

    test('punctuation splits a word the way the tokenizer does', () {
      expect(ftsMatchExpression("don't self-care"), '"don t" "self care"*');
      expect(
        ftsMatchExpression("self-care don't"),
        '"self care" "don t"',
        reason: 'the last token, "t", is too short to be a prefix',
      );
      expect(ftsMatchExpression('v1.4.10'), '"v1 4 10"*');
    });

    test('quoted text stays one exact phrase', () {
      expect(
        ftsMatchExpression('"ice shelf" colony'),
        '"ice shelf" "colony"*',
      );
      expect(ftsMatchExpression('colony "ice shelf"'), '"colony" "ice shelf"');
      expect(
        ftsMatchExpression('colony "ice sh'),
        '"colony" "ice sh"',
        reason: 'an unclosed quote is still an exact phrase',
      );
    });

    test('FTS5 syntax a user types is matched as words, never run', () {
      expect(
        ftsMatchExpression('title:krill OR NOT (pad*) ^start NEAR'),
        '"title krill" "OR" "NOT" "pad" "start" "NEAR"*',
      );
    });

    test('non-Latin scripts keep their letters and marks', () {
      expect(ftsMatchExpression('Pingüine'), '"Pingüine"*');
      expect(ftsMatchExpression('पेंगुइन'), '"पेंगुइन"*');
    });

    test('nothing to match gives no expression', () {
      for (final input in ['', '   ', '""', '-- ** ()', '"']) {
        expect(ftsMatchExpression(input), isNull, reason: input);
      }
    });

    test('anyTerm joins the phrases with OR', () {
      expect(
        ftsMatchExpression('krill squid', anyTerm: true),
        '"krill" OR "squid"*',
      );
    });

    test('prefixLastWord false matches the last word whole', () {
      expect(
        ftsMatchExpression('krill squid', prefixLastWord: false),
        '"krill" "squid"',
      );
    });

    test('a pasted paragraph is cut to maxPhrases phrases', () {
      final words = List.generate(40, (i) => 'w$i').join(' ');
      final expression = ftsMatchExpression(words, maxPhrases: 3);
      expect(expression, '"w0" "w1" "w2"');
    });
  });
}
