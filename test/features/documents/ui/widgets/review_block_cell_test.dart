import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/ui/widgets/review_block_cell.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpCell(
    WidgetTester tester, {
    required MarkdownBlockChange kind,
    String? block = 'Feed the penguins at noon.',
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      ReviewBlockCell(kind: kind, block: block, emptyLabel: 'Not in v3'),
    ),
  );

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
}
