import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_section_header.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

Future<void> _pump(WidgetTester tester, {String? summary}) => tester.pumpWidget(
  makeTestableWidgetNoScroll(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 400,
        child: DaySectionHeader(label: 'Needs you', summary: summary),
      ),
    ),
  ),
);

void main() {
  group('DaySectionHeader', () {
    testWidgets('names the group in a high-emphasis subtitle', (tester) async {
      await _pump(tester);
      final tokens = tester.element(find.byType(DaySectionHeader)).designTokens;

      final label = tester.widget<Text>(find.text('Needs you'));
      expect(
        label.style!.fontSize,
        tokens.typography.styles.subtitle.subtitle2.fontSize,
      );
      expect(label.style!.color, tokens.colors.text.highEmphasis);
      // Only the label: no summary without one.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('a summary sits at the end in quiet tabular figures', (
      tester,
    ) async {
      await _pump(tester, summary: '4h 35m · 3 done');
      final tokens = tester.element(find.byType(DaySectionHeader)).designTokens;

      final summary = tester.widget<Text>(find.text('4h 35m · 3 done'));
      expect(summary.style!.color, tokens.colors.text.lowEmphasis);
      expect(summary.style!.fontFeatures, dayFigures);
      expect(tester.getTopRight(find.text('4h 35m · 3 done')).dx, 400);
    });

    testWidgets('keeps a step2 between itself and the card below', (
      tester,
    ) async {
      await _pump(tester);
      final tokens = tester.element(find.byType(DaySectionHeader)).designTokens;

      expect(
        tester.getBottomLeft(find.byType(DaySectionHeader)).dy -
            tester.getBottomLeft(find.text('Needs you')).dy,
        tokens.spacing.step2,
      );
    });
  });
}
