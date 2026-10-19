import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/tone_reader.dart';

/// The approval of the single cue [text] reads as.
int? _one(String text) {
  final cues = readTones(text);
  expect(cues, hasLength(1), reason: text);
  return cues.single.approval;
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

    test('a whole word, never a part of one', () {
      // "done" inside "Doneck" is not done.
      expect(_one('Meet Doneck at ten.'), isNull);
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
    expect(cues, [(offset: 0, approval: null)]);
  });
}
