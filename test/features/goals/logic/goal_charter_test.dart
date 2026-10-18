import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/goals/logic/goal_charter.dart';

void main() {
  GoalCharterEntry entry(String id, String text, {int day = 1}) =>
      GoalCharterEntry(
        entryId: id,
        writtenAt: DateTime(2026, 8, day),
        text: text,
      );

  String words(int count) => List.filled(count, 'krill').join(' ');
  int tokens(String text) => TextChunker.estimateTokens(text);

  group('goalCharterSelection', () {
    test('reads the charter in the order it was written', () {
      final selection = goalCharterSelection([
        entry('refine', 'Coach me gently.', day: 9),
        entry('purpose', 'This goal is my journal.', day: 2),
      ]);

      expect(selection.kept.map((e) => e.entryId), ['purpose', 'refine']);
      expect(selection.omitted, 0);
      expect(selection.truncated, isFalse);
    });

    test('stops at the first entry that would overflow and counts the rest '
        'as omitted', () {
      final ten = words(10);
      final selection = goalCharterSelection(
        [
          entry('a', ten),
          entry('b', ten, day: 2),
          entry('c', ten, day: 3),
          // Small enough to fit after `b`, but the charter is read in order:
          // a later entry never jumps a gap an earlier one left.
          entry('d', 'ok', day: 4),
        ],
        budget: tokens(ten) * 2 + tokens('ok'),
      );

      expect(selection.kept.map((e) => e.entryId), ['a', 'b']);
      expect(selection.omitted, 2);
      expect(selection.truncated, isFalse);
    });

    test('cuts a first entry larger than the whole budget instead of '
        'dropping it', () {
      final selection = goalCharterSelection([
        entry('long', 'word ' * 200),
        entry('next', 'More.', day: 2),
      ], budget: 20);

      expect(selection.kept.single.entryId, 'long');
      expect(selection.kept.single.text, endsWith('…'));
      expect(
        TextChunker.estimateTokens(selection.kept.single.text),
        lessThanOrEqualTo(20),
      );
      expect(selection.truncated, isTrue);
      expect(selection.omitted, 1);
    });

    glados.Glados2(
      glados.any.listWithLengthInRange(
        0,
        12,
        glados.any.intInRange(1, 40),
      ),
      // From "only the ellipsis fits" upwards: a one-token budget cannot hold
      // even the ellipsis a cut entry ends in.
      glados.any.intInRange(2, 120),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'what is kept fits the budget and is a prefix of the written order',
      (lengths, budget) {
        final entries = [
          for (var i = 0; i < lengths.length; i++)
            entry('e$i', words(lengths[i]), day: i + 1),
        ];

        final selection = goalCharterSelection(entries, budget: budget);
        final kept = selection.kept;

        expect(
          kept.fold<int>(0, (sum, e) => sum + tokens(e.text)),
          lessThanOrEqualTo(budget),
        );
        expect(
          kept.map((e) => e.entryId),
          [for (var i = 0; i < kept.length; i++) 'e$i'],
        );
        expect(kept.length + selection.omitted, entries.length);
        expect(kept.isEmpty, entries.isEmpty);
      },
      tags: 'glados',
    );
  });

  group('goalCharterFacts', () {
    test('is null for a goal without a charter, so its FACTS stay as they '
        'were', () {
      expect(goalCharterFacts(const []), isNull);
    });

    test('carries the entries verbatim with the date written and the '
        'policy that bounds them', () {
      final facts = goalCharterFacts([
        entry(
          'purpose',
          'Ask me one guided question each morning, based on what I wrote.',
        ),
      ])!;

      expect(facts['entries'], [
        {
          'writtenAtLocal': DateTime(2026, 8).toIso8601String(),
          'text':
              'Ask me one guided question each morning, based on what I '
              'wrote.',
        },
      ]);
      expect(facts['interpretationPolicy'], goalCharterInterpretationPolicy);
      expect(facts.containsKey('omittedEntries'), isFalse);
      expect(facts.containsKey('firstEntryTruncated'), isFalse);
    });

    test('says what did not fit', () {
      final facts = goalCharterFacts([
        entry('long', 'word ' * 200),
        entry('next', 'More.', day: 2),
      ], budget: 20)!;

      expect(facts['omittedEntries'], 1);
      expect(facts['firstEntryTruncated'], isTrue);
    });

    test('the policy keeps measurement above the charter', () {
      expect(goalCharterInterpretationPolicy, contains('never changes track'));
      expect(goalCharterInterpretationPolicy, contains('FACTS win'));
    });
  });
}
