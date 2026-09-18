import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/speech/helpers/transcript_term_corrector.dart';

void main() {
  group('correctTranscriptTerms', () {
    test('restores the names Whisper misheard', () {
      final result = correctTranscriptTerms(
        'Ich war mit Vanja bei Frieda Kellsen.',
        ['Frida Kjellsen', 'Wanja'],
      );

      expect(result.text, 'Ich war mit Wanja bei Frida Kjellsen.');
      expect(result.corrections, [
        (heard: 'Vanja', term: 'Wanja'),
        (heard: 'Frieda', term: 'Frida'),
        (heard: 'Kellsen', term: 'Kjellsen'),
      ]);
    });

    test('still corrects a name that starts a sentence', () {
      expect(
        correctTranscriptTerms('Vanja kommt auch.', ['Wanja']).text,
        'Wanja kommt auch.',
      );
    });

    test('folds umlauts both ways', () {
      expect(
        correctTranscriptTerms('Bjoern kommt.', ['Björn']).text,
        'Björn kommt.',
      );
    });

    // Each case shares a phonetic code with the term, so only the spelling
    // gate, the capital, the length floor or the ambiguity rule stops it.
    for (final (label, transcript, terms) in [
      ('a different word with the same code', 'Der Weg war lang.', ['Wiggo']),
      ('a lower-case word', 'das vanja ist offen', ['Wanja']),
      ('a word already known', 'Wanja und Vanja', ['Wanja', 'Vanja']),
      ('two equally close terms', 'Mit Maier.', ['Meier', 'Mayer']),
      ('a term too short to carry sound', 'Ada und Ida', ['Ida']),
      // Codex review on #4343: a sentence-initial capital is not a name.
      ('a common word starting a sentence', 'Dann gingen wir los.', ['Dan']),
      ('a German modal verb', 'Kann ich helfen?', ['Can']),
      ('an English one', 'Will you come?', ['Wil']),
    ]) {
      test('leaves $label alone', () {
        final result = correctTranscriptTerms(transcript, terms);

        expect(result.text, transcript);
        expect(result.corrections, isEmpty);
      });
    }

    test('returns the transcript untouched without terms', () {
      final result = correctTranscriptTerms('Vanja war da.', const []);

      expect(result.text, 'Vanja war da.');
      expect(result.corrections, isEmpty);
    });

    glados.Glados2(
      glados.any.nonEmptyList(glados.any.nonEmptyLetters),
      glados.any.list(glados.any.nonEmptyLetters),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'only ever swaps a word for a known term, and is idempotent',
      (words, terms) {
        final transcript = words.join(' ');
        final result = correctTranscriptTerms(transcript, terms);
        final outWords = result.text.split(' ');
        final knownWords = {
          for (final term in terms) term.toLowerCase(),
        };

        expect(outWords, hasLength(words.length));
        for (var i = 0; i < words.length; i++) {
          if (outWords[i] != words[i]) {
            expect(knownWords, contains(outWords[i].toLowerCase()));
          }
        }
        expect(
          result.corrections.length,
          [
            for (var i = 0; i < words.length; i++)
              if (outWords[i] != words[i]) i,
          ].length,
        );
        expect(correctTranscriptTerms(result.text, terms).text, result.text);
      },
      tags: 'glados',
    );
  });

  group('mergeSpeechTerms', () {
    test('keeps the leading list first and drops blanks and repeats', () {
      expect(
        mergeSpeechTerms(
          [' Frida Kjellsen ', 'Wanja', ''],
          ['wanja', 'Waddle One', '  ', 'Frida kjellsen'],
        ),
        ['Frida Kjellsen', 'Wanja', 'Waddle One'],
      );
    });
  });

  group('colognePhonetics', () {
    for (final (word, code) in [
      ('Müller-Lüdenscheidt', '65752682'),
      ('Wikipedia', '3412'),
      ('Breschnew', '17863'),
      ('Wanja', '36'),
      ('Vanja', '36'),
      ('Kjellsen', '4586'),
      ('Kellsen', '4586'),
      ('Xaver', '4837'),
      ('Christoph', '47823'),
      ('Anna', '06'),
    ]) {
      test('encodes $word as $code', () {
        expect(colognePhonetics(word), code);
      });
    }
  });

  group('soundAlikeSpelling', () {
    for (final (a, b) in [
      ('Wanja', 'Vanja'),
      ('Frieda', 'Frida'),
      ('Philipp', 'Filip'),
      ('Björn', 'Bjoern'),
    ]) {
      test('spells $a and $b alike', () {
        expect(soundAlikeSpelling(a), soundAlikeSpelling(b));
      });
    }

    test('keeps sch and ch distinct from a bare c', () {
      expect(soundAlikeSpelling('Schack'), 'schak');
      expect(soundAlikeSpelling('Michael'), 'michael');
    });
  });

  group('levenshteinDistance', () {
    for (final (a, b, distance) in [
      ('', '', 0),
      ('abc', '', 3),
      ('', 'abc', 3),
      ('kitten', 'sitting', 3),
      ('kjelsen', 'kelsen', 1),
    ]) {
      test('between "$a" and "$b" is $distance', () {
        expect(levenshteinDistance(a, b), distance);
      });
    }
  });
}
