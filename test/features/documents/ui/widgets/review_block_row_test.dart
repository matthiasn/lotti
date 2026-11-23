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
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(
        width: 960,
        child: ReviewBlockRow(
          pair: pair,
          baseVersion: baseVersion,
          proposedVersion: 4,
          noTextLabel: 'No text yet',
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
}
