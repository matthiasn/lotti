import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/tone_reader.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';

/// The approval of the single cue [text] reads as.
int? _one(String text) {
  final cues = readTones(text);
  expect(cues, hasLength(1), reason: text);
  return cues.single.approval;
}

/// The beat [text] turns on: that of its one cue with a beat, or null.
SassBeat? _beat(String text) {
  final beats = readTones(text).where((c) => c.beat != null);
  expect(beats.length, lessThanOrEqualTo(1), reason: text);
  return beats.singleOrNull?.beat;
}

void main() {
  group('a sentence on its own', () {
    test('praise reads as approval, the stronger the higher', () {
      expect(_one('Good progress on the parser.'), greaterThan(0));
      expect(
        _one('You finished the migration, well done!'),
        greaterThan(_one('Good progress on the parser.')!),
      );
    });

    test('work that landed reads as approval', () {
      expect(_one('The parser shipped.'), greaterThan(0));
      expect(_one('The fix is merged and released.'), greaterThan(0));
      expect(_one('The crash is resolved.'), greaterThan(0));
      expect(_one('The parser is not merged.'), lessThan(0));
    });

    test('what needs work reads as disapproval', () {
      expect(_one('The review is overdue.'), lessThan(0));
      expect(_one('The tests are falling behind.'), lessThan(0));
      expect(_one('This needs another pass.'), lessThan(0));
    });

    test('a plain fact reads neither way', () {
      expect(_one('Four things today.'), isNull);
      expect(readTones(''), isEmpty);
    });

    test('praise denied is a concern; trouble denied is good news', () {
      expect(_one('The migration is not done.'), lessThan(0));
      expect(_one('No blockers this week.'), greaterThan(0));
      expect(_one('Keine Probleme.'), greaterThan(0));
    });

    test('a phrase denied is denied too', () {
      expect(_one('We are not falling behind.'), greaterThan(0));
      expect(_one('The launch is not at risk.'), greaterThan(0));
      expect(_one('Das Projekt ist nicht im Verzug.'), greaterThan(0));
    });

    test('a phrase counts once, not again for its words', () {
      // "well done" alone weighs what "great" does, not that plus "done".
      expect(_one('Well done.'), _one('Great.'));
      expect(_one('The launch is at risk.'), _one('The launch has a risk.'));
    });

    test('a whole word, never a part of one', () {
      // "done" inside "Doneck" is not done.
      expect(_one('Meet Doneck at ten.'), isNull);
      // "im Plan" inside "im Planungsmeeting" is no plan kept.
      expect(_one('Wir sprechen im Planungsmeeting.'), isNull);
    });

    test('German reads too', () {
      expect(_one('Die Migration ist erledigt, gut gemacht!'), greaterThan(0));
      expect(_one('Der Bericht ist überfällig.'), lessThan(0));
    });

    test('emoji read the same in any language', () {
      expect(_one('✅ Il est terminé'), greaterThan(0));
      expect(_one('⚠️ Il retardo'), lessThan(0));
    });

    test('however much praise piles up, it stays on the scale', () {
      expect(
        _one('🎉 Excellent, outstanding, fantastic: completed and achieved!'),
        3,
      );
      expect(_one('❌ Overdue, blocked, missed and failed.'), -3);
    });
  });

  test('each sentence of a line is cued at its first character', () {
    const text = 'Four things today. The review is overdue. Well done!';
    final cues = readTones(text);
    expect(cues.map((c) => c.offset), [
      0,
      text.indexOf(' The review'),
      text.indexOf(' Well done'),
    ]);
    expect(cues[0].approval, isNull);
    expect(cues[1].approval, lessThan(0));
    expect(cues[2].approval, greaterThan(0));
  });

  test('a neutral sentence takes the tone of the heading above it', () {
    const text =
        '## ✅ Achieved\n'
        'The parser ships today.\n'
        '## ⚠️ Risks\n'
        'The vendor answers on Friday.\n';
    final cues = readTones(text);
    // The heading's cue covers the line below it, which reads neither way.
    expect(cues.map((c) => c.offset), [0, text.indexOf('## ⚠️')]);
    expect(cues.first.approval, greaterThan(0));
    expect(cues.last.approval, lessThan(0));
  });

  test('a sentence of its own tone overrides its section', () {
    const text =
        '## ✅ Achieved\n'
        'The parser ships today.\n'
        'The docs are overdue.\n';
    final cues = readTones(text);
    expect(cues.last.offset, text.indexOf('The docs'));
    expect(cues.last.approval, lessThan(0));
  });

  test('a cue that repeats the one before it is left out', () {
    final cues = readTones('Four things. Three meetings. One walk.');
    expect(cues, [(offset: 0, approval: null, beat: null)]);
  });

  group('beats', () {
    test('a question, an exclamation', () {
      expect(_beat('Did you look at the docs?'), SassBeat.question);
      expect(_beat('Four things today!'), SassBeat.exclaim);
      expect(_beat('Four things today.'), isNull);
    });

    test('the catch after a "but", in English and German', () {
      expect(_beat('The parser ships, but the docs wait.'), SassBeat.turn);
      expect(_beat('However, the vendor answers on Friday.'), SassBeat.turn);
      expect(_beat('Der Parser läuft, aber die Doku fehlt.'), SassBeat.turn);
    });

    test('the same thing again, and the wait over', () {
      expect(_beat('The docs are late again.'), SassBeat.again);
      expect(_beat('The tests are still red.'), SassBeat.again);
      expect(_beat('Die Doku ist immer noch offen.'), SassBeat.again);
      expect(_beat('The parser finally shipped.'), SassBeat.atLast);
      expect(_beat('At last, the parser shipped.'), SassBeat.atLast);
      expect(_beat('Der Parser ist endlich fertig.'), SassBeat.atLast);
    });

    test('words outrank the stop: "finally" before a question', () {
      expect(_beat('Is it finally done?'), SassBeat.atLast);
      expect(_beat('But why?'), SassBeat.turn);
    });

    test('a whole word, never a part of one', () {
      // "but" inside "button", "still" inside "stillness", "at last"
      // inside "at lasting".
      expect(_beat('Press the button.'), isNull);
      expect(_beat('Enjoy the stillness.'), isNull);
      expect(_beat('Aim at lasting change.'), isNull);
    });

    test('a beat is kept in the same tone, so a run of praise gets faces', () {
      final cues = readTones(
        'Well done. Great job! You finally finished it.',
      );
      expect(cues.map((c) => c.beat), [
        null,
        SassBeat.exclaim,
        SassBeat.atLast,
      ]);
      expect(cues.every((c) => (c.approval ?? 0) > 0), isTrue);
    });

    group('timing', () {
      test("a word's beat is cued at the word, the tone at the sentence", () {
        const text =
            'The migration completed after a long wait, but the tests failed.';
        final cues = readTones(text);
        expect(cues.map((c) => (c.offset, c.beat)), [
          (0, null),
          (text.indexOf('but'), SassBeat.turn),
        ]);
        // Both carry the sentence's tone.
        expect(cues.first.approval, cues.last.approval);
      });

      test('a phrase is cued at its first word', () {
        const atLast = 'The parser shipped at last.';
        expect(readTones(atLast).last.offset, atLast.indexOf('at last'));
        const still = 'Die Doku ist immer noch offen.';
        expect(readTones(still).last.offset, still.indexOf('immer'));
      });

      test('the first time a word turns up is its beat', () {
        const text = 'Again the docs, and again the tests.';
        expect(readTones(text).last.offset, 0);
        const later = 'The docs again, and again the tests.';
        expect(readTones(later).last.offset, later.indexOf('again'));
      });

      test('a beat on the first word is one cue, not two', () {
        expect(readTones('But why?'), [
          (offset: 0, approval: null, beat: SassBeat.turn),
        ]);
      });

      test('a question or an exclamation is cued at its start', () {
        const text = 'Four things today. Did you look at them?';
        expect(readTones(text).last, (
          offset: text.indexOf(' Did'),
          approval: null,
          beat: SassBeat.question,
        ));
      });

      test('a word beat in a later sentence counts from that sentence', () {
        const text = 'Four things today. The docs are late again.';
        expect(readTones(text).last.offset, text.indexOf('again'));
      });
    });

    test('a heading is never a beat', () {
      expect(readTones('## Done again?\n').single.beat, isNull);
    });
  });
}
