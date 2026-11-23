import 'package:glados/glados.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';

MarkdownBlockPair _same(String block) => MarkdownBlockPair(
  kind: MarkdownBlockChange.same,
  base: block,
  proposed: block,
);

MarkdownBlockPair _added(String block) =>
    MarkdownBlockPair(kind: MarkdownBlockChange.added, proposed: block);

MarkdownBlockPair _removed(String block) =>
    MarkdownBlockPair(kind: MarkdownBlockChange.removed, base: block);

MarkdownBlockPair _rewritten(String base, String proposed) => MarkdownBlockPair(
  kind: MarkdownBlockChange.rewritten,
  base: base,
  proposed: proposed,
);

/// Blocks drawn from a small vocabulary, so generated documents share,
/// repeat and nearly match each other's blocks.
extension _AnyBlocks on Any {
  Generator<List<String>> get blocks => any.listWithLengthInRange(
    0,
    8,
    any.choose([
      'Feed the penguins at noon.',
      'Feed the penguins at one.',
      'The north feeder jams twice a week.',
      '## Next steps',
      '- Replace the auger',
      'Send the colony council the notes.',
      'Risks are low.',
    ]),
  );
}

void main() {
  group('splitMarkdownBlocks', () {
    test('splits paragraphs on blank lines and keeps headings apart', () {
      expect(
        splitMarkdownBlocks(
          '# Habitat\nAll 37 penguins counted.\nThe feeder jams.\n\n\n'
          'Next steps follow.\n',
        ),
        [
          '# Habitat',
          'All 37 penguins counted.\nThe feeder jams.',
          'Next steps follow.',
        ],
      );
    });

    test('normalises CRLF and CR line endings', () {
      expect(splitMarkdownBlocks('One\r\nline\r\n\r\nTwo\rthree'), [
        'One\nline',
        'Two\nthree',
      ]);
    });

    test('keeps a fenced code block whole, blank lines and all', () {
      expect(
        splitMarkdownBlocks(
          'Before.\n```dart\nfinal a = 1;\n\n\nfinal b = 2;\n```\nAfter.',
        ),
        ['Before.', '```dart\nfinal a = 1;\n\n\nfinal b = 2;\n```', 'After.'],
      );
    });

    test('a tilde fence closes only on tildes, at least as long', () {
      expect(
        splitMarkdownBlocks('~~~~\n```\n\n~~~\n~~~~\nAfter.'),
        ['~~~~\n```\n\n~~~\n~~~~', 'After.'],
      );
    });

    test('an unclosed fence runs to the end', () {
      expect(splitMarkdownBlocks('```\ncode\n\nmore'), ['```\ncode\n\nmore']);
    });

    for (final (name, list) in [
      ('bulleted', '- Feed\n\n- Count\n\n- Report'),
      ('ordered', '1. Feed\n\n2. Count\n\n3. Report'),
      ('ordered with a continuation', '1. Feed\n\n   at noon\n2. Count'),
    ]) {
      test('a loose $name list stays one block', () {
        expect(splitMarkdownBlocks('$list\n\nAfter the list.'), [
          list,
          'After the list.',
        ]);
      });
    }

    test('a list ends at a blank line followed by a paragraph', () {
      expect(splitMarkdownBlocks('- Feed\n- Count\n\nDone.'), [
        '- Feed\n- Count',
        'Done.',
      ]);
    });

    test('nothing but blank lines is no block at all', () {
      expect(splitMarkdownBlocks(''), isEmpty);
      expect(splitMarkdownBlocks('\n \n\t\n'), isEmpty);
    });
  });

  group('alignMarkdownBlocks', () {
    test('past the cell cap, the changed middle is rows removed then added, '
        'and the unchanged start and end still match', () {
      const n = 600;
      final base = [
        'Intro.',
        for (var k = 0; k < n; k++) 'old $k',
        'Outro.',
      ];
      final proposed = [
        'Intro.',
        for (var k = 0; k < n; k++) 'new $k',
        'Outro.',
      ];
      expect((n + 1) * (n + 1), greaterThan(markdownBlockAlignMaxCells));

      final kinds = alignMarkdownBlocks(
        base,
        proposed,
      ).map((pair) => pair.kind).toList();

      expect(kinds, [
        MarkdownBlockChange.same,
        ...List.filled(n, MarkdownBlockChange.removed),
        ...List.filled(n, MarkdownBlockChange.added),
        MarkdownBlockChange.same,
      ]);
    });

    const intro = 'All 37 penguins were counted at roll call.';
    const feeder = 'The north feeder jams twice a week.';
    const steps = '## Next steps';

    test('identical documents are all same rows', () {
      final pairs = alignMarkdownBlocks(
        [intro, feeder],
        [intro, feeder],
      );
      expect(pairs, [_same(intro), _same(feeder)]);
      expect(MarkdownBlockDiffStats.of(pairs).isUnchanged, isTrue);
    });

    test('whitespace alone does not change a block', () {
      final pairs = alignMarkdownBlocks(
        [intro],
        ['All 37  penguins were\ncounted at roll call.'],
      );
      expect(pairs.single.kind, MarkdownBlockChange.same);
    });

    test('a pure insert is one added row in place', () {
      expect(alignMarkdownBlocks([intro, steps], [intro, feeder, steps]), [
        _same(intro),
        _added(feeder),
        _same(steps),
      ]);
    });

    test('a pure delete is one removed row in place', () {
      expect(alignMarkdownBlocks([intro, feeder, steps], [intro, steps]), [
        _same(intro),
        _removed(feeder),
        _same(steps),
      ]);
    });

    test('a similar replacement is one rewritten row', () {
      const shorter = 'The north feeder jams every week.';
      final pairs = alignMarkdownBlocks(
        [intro, feeder, steps],
        [intro, shorter, steps],
      );
      expect(pairs, [_same(intro), _rewritten(feeder, shorter), _same(steps)]);
      expect(
        MarkdownBlockDiffStats.of(pairs),
        const MarkdownBlockDiffStats(added: 0, removed: 0, rewritten: 1),
      );
    });

    test('an unrelated replacement is a removed row and an added row', () {
      const other = 'Send the colony council the inspection notes.';
      expect(alignMarkdownBlocks([feeder], [other]), [
        _removed(feeder),
        _added(other),
      ]);
    });

    test('a rewrite after an unrelated insert keeps both sides in order', () {
      const inserted = 'Risks are low this season.';
      const shorter = 'The north feeder jams every week.';
      expect(alignMarkdownBlocks([feeder], [inserted, shorter]), [
        _added(inserted),
        _rewritten(feeder, shorter),
      ]);
    });

    test('a moved block reads as removed in one place, added in another', () {
      final pairs = alignMarkdownBlocks(
        [intro, feeder, steps],
        [feeder, steps, intro],
      );
      expect(pairs, [
        _removed(intro),
        _same(feeder),
        _same(steps),
        _added(intro),
      ]);
    });

    test('an item added inside a list rewrites that list block', () {
      final pairs = alignMarkdownBlocks(
        splitMarkdownBlocks('- Feed the penguins\n- Count the penguins'),
        splitMarkdownBlocks(
          '- Feed the penguins\n- Count the penguins\n- Report the count',
        ),
      );
      expect(pairs.single.kind, MarkdownBlockChange.rewritten);
    });

    test('a first draft over an empty document is all added', () {
      final pairs = alignMarkdownBlocks(const [], [intro, feeder]);
      expect(pairs, [_added(intro), _added(feeder)]);
      expect(
        MarkdownBlockDiffStats.of(pairs),
        const MarkdownBlockDiffStats(added: 2, removed: 0, rewritten: 0),
      );
    });

    Glados2<List<String>, List<String>>(any.blocks, any.blocks).test(
      'every block of each side appears in exactly one row, in its order',
      (base, proposed) {
        final pairs = alignMarkdownBlocks(base, proposed);
        expect([for (final p in pairs) ?p.base], base);
        expect([for (final p in pairs) ?p.proposed], proposed);
        for (final pair in pairs) {
          if (pair.kind == MarkdownBlockChange.same) {
            expect(pair.base, pair.proposed);
          }
        }
      },
      tags: 'glados',
    );
  });
}
