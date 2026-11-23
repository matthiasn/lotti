import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/logic/rewrite_word_marks.dart';
import 'package:lotti/features/documents/ui/widgets/review_block_cell.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpCell(
    WidgetTester tester, {
    required MarkdownBlockChange kind,
    String? block = 'Feed the penguins at noon.',
    bool quiet = false,
    Color? wordMark,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      ReviewBlockCell(
        kind: kind,
        block: block,
        emptyLabel: 'Not in v3',
        quiet: quiet,
        wordMark: wordMark,
      ),
    ),
  );

  Color? inkOf(WidgetTester tester, String text) => tester
      .widget<RichText>(
        find.descendant(
          of: find.byType(ReviewBlockCell),
          matching: find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains(text),
          ),
        ),
      )
      .text
      .style
      ?.color;

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(ReviewBlockCell)).designTokens;

  Color? surfaceOf(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(ReviewBlockCell),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return (box.decoration as BoxDecoration).color;
  }

  testWidgets('an unchanged block sits on no surface, in medium ink', (
    tester,
  ) async {
    await pumpCell(tester, kind: MarkdownBlockChange.same);

    expect(surfaceOf(tester), isNull);
    final text = tester.widget<RichText>(
      find.descendant(
        of: find.byType(ReviewBlockCell),
        matching: find.byType(RichText),
      ),
    );
    expect(
      text.text.style?.color,
      tokensOf(tester).colors.text.mediumEmphasis,
    );
  });

  for (final kind in [
    MarkdownBlockChange.added,
    MarkdownBlockChange.removed,
    MarkdownBlockChange.rewritten,
  ]) {
    testWidgets('a ${kind.name} block takes its diff surface', (tester) async {
      await pumpCell(tester, kind: kind);

      final diff = tokensOf(tester).colors.diff;
      expect(surfaceOf(tester), switch (kind) {
        MarkdownBlockChange.added => diff.added.surface,
        MarkdownBlockChange.removed => diff.removed.surface,
        _ => diff.replaced.surface,
      });
      expect(find.textContaining('Feed the penguins at noon.'), findsOneWidget);
    });
  }

  testWidgets('without a block, a dashed slot says which version lacks it', (
    tester,
  ) async {
    await pumpCell(tester, kind: MarkdownBlockChange.added, block: null);

    expect(find.byType(DsDashedBorder), findsOneWidget);
    expect(find.text('Not in v3'), findsOneWidget);
    expect(
      tester.widget<DsDashedBorder>(find.byType(DsDashedBorder)).color,
      tokensOf(tester).colors.decorative.level03,
    );
  });

  testWidgets('an unchanged heading keeps to the body size and the medium '
      'ink, never outranking the review', (tester) async {
    await pumpCell(
      tester,
      kind: MarkdownBlockChange.same,
      block: '## Feeding rounds',
    );

    final tokens = tokensOf(tester);
    TextStyle? headingStyle;
    for (final text in tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(ReviewBlockCell),
        matching: find.byType(RichText),
      ),
    )) {
      text.text.visitChildren((span) {
        if (span is TextSpan && (span.text ?? '').contains('Feeding')) {
          headingStyle = span.style;
          return false;
        }
        return true;
      });
    }
    // The heading's own span: at the body's size, in the cell's ink — not
    // the renderer's full-brightness heading colour.
    expect(headingStyle, isNotNull);
    expect(
      headingStyle!.fontSize,
      tokens.typography.styles.body.bodyMedium.fontSize,
    );
    expect(headingStyle!.color, tokens.colors.text.mediumEmphasis);
  });

  testWidgets('a quiet changed block, the old half of a stacked rewrite, '
      'is in medium ink', (tester) async {
    await pumpCell(tester, kind: MarkdownBlockChange.rewritten, quiet: true);

    expect(
      inkOf(tester, 'Feed the penguins'),
      tokensOf(tester).colors.text.mediumEmphasis,
    );
  });

  testWidgets(
    "a rewrite's marked words sit on the word-mark surface, the delimiters "
    'unseen',
    (tester) async {
      await pumpCell(
        tester,
        kind: MarkdownBlockChange.rewritten,
        // Emphasis stays outside a mark, as markRewrittenWords leaves it.
        block:
            'Feed the **${rewriteWordMarkOpen}young$rewriteWordMarkClose** '
            'penguins.',
        wordMark: Colors.pink,
      );

      TextSpan? marked;
      final text = tester.widget<RichText>(
        find.descendant(
          of: find.byType(ReviewBlockCell),
          matching: find.byType(RichText),
        ),
      );
      text.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'young') marked = span;
        return marked == null;
      });
      expect(marked?.style?.backgroundColor, Colors.pink);
      expect(text.text.toPlainText(), 'Feed the young penguins.');
    },
  );
}
