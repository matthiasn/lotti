import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_legend.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

import '../../widget_test_utils.dart';

void main() {
  Color? fillBeside(WidgetTester tester, String label) {
    final row = find
        .ancestor(of: find.text(label), matching: find.byType(Row))
        .first;
    final swatch = tester.widget<Container>(
      find.descendant(of: row, matching: find.byType(Container)).first,
    );
    return (swatch.decoration! as BoxDecoration).color;
  }

  Icon iconBeside(WidgetTester tester, String label) {
    for (final row in tester.widgetList<Row>(find.byType(Row))) {
      final texts = find.descendant(
        of: find.byWidget(row),
        matching: find.text(label),
      );
      if (texts.evaluate().isEmpty) continue;
      return tester.widget<Icon>(
        find.descendant(of: find.byWidget(row), matching: find.byType(Icon)),
      );
    }
    throw StateError('no legend row labelled $label');
  }

  testWidgets("keys only the colour-only states present, with the cells' "
      'own fills, dot and ring', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const DayMarkLegend(
          states: {DayMarkState.full, DayMarkState.partial},
          showToday: true,
        ),
      ),
    );
    final tokens = tester.element(find.byType(DayMarkLegend)).designTokens;
    expect(find.text('Done · target met'), findsOneWidget);
    expect(find.text('Done · target not met yet'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('No entry'), findsNothing, reason: 'not on the strip');
    expect(find.textContaining('ges out'), findsNothing);
    expect(
      fillBeside(tester, 'Done · target met'),
      dayMarkStateFill(tokens, DayMarkState.full),
    );
    // The today swatch is dashed like the cell, in the same ink and stroke.
    final ring = tester.widget<DsDashedBorder>(find.byType(DsDashedBorder));
    expect(ring.color, todayRingInk(tokens));
    expect(ring.strokeWidth, BorderWidths.emphasis);
    // The partial swatch carries the dot: a circle inside the square.
    final partialRow = find
        .ancestor(
          of: find.text('Done · target not met yet'),
          matching: find.byType(Row),
        )
        .first;
    final containers = tester.widgetList<Container>(
      find.descendant(of: partialRow, matching: find.byType(Container)),
    );
    expect(
      containers.any(
        (c) => (c.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
      isTrue,
    );
  });

  testWidgets('outcome glyphs are never keyed — the dash and cross name '
      'themselves — while present verdicts are, with their own glyph and ink', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const DayMarkLegend(
          states: {
            DayMarkState.skipped,
            DayMarkState.missed,
            DayMarkState.none,
          },
          verdicts: {DayVerdict.improving},
          showAgesOut: true,
        ),
      ),
    );
    final tokens = tester.element(find.byType(DayMarkLegend)).designTokens;
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Missed'), findsNothing);
    expect(find.text('No entry'), findsOneWidget);
    expect(find.text('Judged Improving'), findsOneWidget);
    expect(find.text('Judged Met'), findsNothing);
    expect(find.textContaining('ges out'), findsOneWidget);
    final icon = iconBeside(tester, 'Judged Improving');
    expect(icon.icon, dayVerdictGlyph(DayVerdict.improving));
    expect(icon.color, dayVerdictInk(tokens, DayVerdict.improving));
    expect(icon.size, dayMarkGlyphSize(IconSizes.s));
  });

  testWidgets('with nothing to key it renders nothing', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Align(
          alignment: Alignment.topLeft,
          child: DayMarkLegend(
            states: {DayMarkState.skipped, DayMarkState.missed},
          ),
        ),
      ),
    );
    expect(
      tester.widget<DayMarkLegend>(find.byType(DayMarkLegend)).isEmpty,
      isTrue,
    );
    expect(tester.getSize(find.byType(DayMarkLegend)), Size.zero);
  });
}
