import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
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
      LottiIcons.edit,
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

  testWidgets('cells stay top-aligned and keep their own heights', (
    tester,
  ) async {
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
    expect(right.height, greaterThan(left.height * 2));
    expect(left.right, lessThan(right.left));
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

    testWidgets('a rewritten block shows its old text above its new one, '
        'on the removed and added surfaces, under one mark', (tester) async {
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

      expect(cells(tester).map((cell) => (cell.kind, cell.block)), [
        (MarkdownBlockChange.removed, feed),
        (MarkdownBlockChange.added, one),
      ]);
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
}
