import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/logic/rewrite_word_marks.dart';
import 'package:lotti/features/documents/ui/widgets/review_block_cell.dart';
import 'package:lotti/features/documents/ui/widgets/review_block_row.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester,
    MarkdownBlockPair pair, {
    int? baseVersion = 3,
    int? proposedVersion = 4,
    bool stacked = false,
    bool stale = false,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(
        width: 960,
        child: ReviewBlockRow(
          pair: pair,
          baseVersion: baseVersion,
          proposedVersion: proposedVersion,
          noTextLabel: 'No text yet',
          stacked: stacked,
          stale: stale,
        ),
      ),
    ),
  );

  const feed = 'Feed the penguins at noon.';

  testWidgets('an unchanged row has no mark and nothing extra to say', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRow(
      tester,
      const MarkdownBlockPair(
        kind: MarkdownBlockChange.same,
        base: feed,
        proposed: feed,
      ),
    );

    expect(find.byKey(ReviewBlockRowKeys.gutter), findsNothing);
    expect(find.textContaining(feed), findsNWidgets(2));
    expect(find.bySemanticsLabel(RegExp('proposed version')), findsNothing);
    semantics.dispose();
  });

  for (final (pair, icon, label, slot) in [
    (
      const MarkdownBlockPair(kind: MarkdownBlockChange.added, proposed: feed),
      LottiIcons.add,
      'Added in the proposed version',
      'Not in v3',
    ),
    (
      const MarkdownBlockPair(kind: MarkdownBlockChange.removed, base: feed),
      LottiIcons.remove,
      'Removed in the proposed version',
      'Not in v4',
    ),
    (
      const MarkdownBlockPair(
        kind: MarkdownBlockChange.rewritten,
        base: feed,
        proposed: 'Feed the penguins at one.',
      ),
      LottiIcons.compare,
      'Rewritten in the proposed version',
      null,
    ),
  ]) {
    testWidgets('a ${pair.kind.name} row carries its mark and says so', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpRow(tester, pair);

      final gutter = tester.widget<Icon>(find.byKey(ReviewBlockRowKeys.gutter));
      expect(gutter.icon, icon);
      final diff = tester
          .element(find.byType(ReviewBlockRow))
          .designTokens
          .colors
          .diff;
      expect(gutter.color, switch (pair.kind) {
        MarkdownBlockChange.added => diff.added.color,
        MarkdownBlockChange.removed => diff.removed.color,
        _ => diff.replaced.color,
      });
      // The row's node leads with what changed, then reads its text.
      expect(find.bySemanticsLabel(RegExp('^$label')), findsOneWidget);
      if (slot != null) expect(find.text(slot), findsOneWidget);
      semantics.dispose();
    });
  }

  testWidgets('over a document with no text, the empty side says so', (
    tester,
  ) async {
    await pumpRow(
      tester,
      const MarkdownBlockPair(kind: MarkdownBlockChange.added, proposed: feed),
      baseVersion: null,
    );

    expect(find.text('No text yet'), findsOneWidget);
  });

  testWidgets('a draft that would not become the next version says its '
      'slot is not in the draft', (tester) async {
    await pumpRow(
      tester,
      const MarkdownBlockPair(kind: MarkdownBlockChange.removed, base: feed),
      proposedVersion: null,
    );

    expect(find.text('Not in the draft'), findsOneWidget);
    expect(find.textContaining('Not in v'), findsNothing);
  });

  testWidgets('a rewritten row is one band: a short side stands as tall as '
      'a long one, side by side', (tester) async {
    await pumpRow(
      tester,
      MarkdownBlockPair(
        kind: MarkdownBlockChange.rewritten,
        base: feed,
        proposed: List.filled(12, 'Feed the penguins at one.').join(' '),
      ),
    );

    final cells = find.byType(ReviewBlockCell);
    final left = tester.getRect(cells.at(0));
    final right = tester.getRect(cells.at(1));
    expect(left.top, right.top);
    expect(left.bottom, right.bottom);
    expect(left.right, lessThan(right.left));
  });

  testWidgets('an unchanged row keeps each side its own height', (
    tester,
  ) async {
    await pumpRow(
      tester,
      const MarkdownBlockPair(
        kind: MarkdownBlockChange.same,
        base: feed,
        proposed: feed,
      ),
    );

    expect(find.byType(IntrinsicHeight), findsNothing);
  });

  group('stacked, for a pane too narrow for two columns', () {
    List<ReviewBlockCell> cells(WidgetTester tester) => tester
        .widgetList<ReviewBlockCell>(find.byType(ReviewBlockCell))
        .toList();

    testWidgets('an unchanged block shows once, on no surface', (
      tester,
    ) async {
      await pumpRow(
        tester,
        const MarkdownBlockPair(
          kind: MarkdownBlockChange.same,
          base: feed,
          proposed: feed,
        ),
        stacked: true,
      );

      expect(
        cells(tester).map((cell) => (cell.kind, cell.block)),
        [(MarkdownBlockChange.same, feed)],
      );
    });

    testWidgets('a rewritten block shows its old text, quiet, under '
        '"Current" above its new text under "Proposed" — both on the rewrite '
        'surface, under one mark', (tester) async {
      const one = 'Feed the penguins at one.';
      await pumpRow(
        tester,
        const MarkdownBlockPair(
          kind: MarkdownBlockChange.rewritten,
          base: feed,
          proposed: one,
        ),
        stacked: true,
      );

      // Red and green keep meaning removed and added at every width.
      final marked = markRewrittenWords(feed, one);
      expect(
        cells(tester).map((cell) => (cell.kind, cell.block, cell.quiet)),
        [
          (MarkdownBlockChange.rewritten, marked.base, true),
          (MarkdownBlockChange.rewritten, marked.proposed, false),
        ],
      );
      expect(
        tester.getTopLeft(find.text('Current')).dy,
        lessThan(tester.getTopLeft(find.byType(ReviewBlockCell).at(0)).dy),
      );
      expect(
        tester.getTopLeft(find.text('Proposed')).dy,
        lessThan(tester.getTopLeft(find.byType(ReviewBlockCell).at(1)).dy),
      );
      final found = find.byType(ReviewBlockCell);
      expect(
        tester.getRect(found.at(0)).bottom,
        lessThanOrEqualTo(tester.getRect(found.at(1)).top),
      );
      expect(find.byKey(ReviewBlockRowKeys.gutter), findsOneWidget);
    });

    for (final pair in const [
      MarkdownBlockPair(kind: MarkdownBlockChange.added, proposed: feed),
      MarkdownBlockPair(kind: MarkdownBlockChange.removed, base: feed),
    ]) {
      testWidgets('${pair.kind.name}: its one block, and no empty slot', (
        tester,
      ) async {
        await pumpRow(tester, pair, stacked: true);

        expect(
          cells(tester).map((cell) => (cell.kind, cell.block)),
          [(pair.kind, feed)],
        );
        expect(find.textContaining('Not in'), findsNothing);
      });
    }
  });

  testWidgets('an added or removed row stands as one band: its empty slot '
      'is as tall as the block beside it', (tester) async {
    await pumpRow(
      tester,
      MarkdownBlockPair(
        kind: MarkdownBlockChange.removed,
        base: List.filled(8, feed).join(' '),
      ),
    );

    final cells = find.byType(ReviewBlockCell);
    expect(
      tester.getSize(cells.at(1)).height,
      tester.getSize(cells.at(0)).height,
    );
  });

  testWidgets("stacked, a stale draft's old half is headed by the version "
      'it was drafted over, not "Current"', (tester) async {
    await pumpRow(
      tester,
      const MarkdownBlockPair(
        kind: MarkdownBlockChange.rewritten,
        base: feed,
        proposed: 'Feed the penguins at one.',
      ),
      stacked: true,
      stale: true,
    );

    expect(find.text('Drafted over'), findsOneWidget);
    expect(find.text('Current'), findsNothing);
  });

  for (final stacked in [false, true]) {
    testWidgets(
      'a rewrite marks the words it dropped on the removed surface and the '
      'ones it brought on the added surface${stacked ? ', stacked' : ''}',
      (tester) async {
        await pumpRow(
          tester,
          const MarkdownBlockPair(
            kind: MarkdownBlockChange.rewritten,
            base: 'The colony of 37 penguins.',
            proposed: 'The colony of 38 penguins.',
          ),
          stacked: stacked,
        );

        Color? markOf(String word) {
          Color? found;
          for (final text in tester.widgetList<RichText>(
            find.descendant(
              of: find.byType(ReviewBlockCell),
              matching: find.byType(RichText),
            ),
          )) {
            text.text.visitChildren((span) {
              if (span is TextSpan && span.text == word) {
                found = span.style?.backgroundColor;
              }
              return found == null;
            });
          }
          return found;
        }

        final diff = tester
            .element(find.byType(ReviewBlockRow))
            .designTokens
            .colors
            .diff;
        expect(markOf('37'), diff.removed.surface);
        expect(markOf('38'), diff.added.surface);
      },
    );
  }
}
