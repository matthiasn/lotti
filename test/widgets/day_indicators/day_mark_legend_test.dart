import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_legend.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

import '../../widget_test_utils.dart';

void main() {
  testWidgets('the legend keys the cells with their own fills, dot and ring', (
    tester,
  ) async {
    await tester.pumpWidget(makeTestableWidgetNoScroll(const DayMarkLegend()));
    final tokens = tester.element(find.byType(DayMarkLegend)).designTokens;

    for (final label in [
      'done · target met',
      'done · target not met yet',
      'No entry',
      'today',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.textContaining('ages out'), findsOneWidget);

    Color? fillBeside(String label) {
      final row = find
          .ancestor(of: find.text(label), matching: find.byType(Row))
          .first;
      final swatch = tester.widget<Container>(
        find.descendant(of: row, matching: find.byType(Container)).first,
      );
      return (swatch.decoration! as BoxDecoration).color;
    }

    expect(
      fillBeside('done · target met'),
      dayMarkStateFill(tokens, DayMarkState.full),
    );
    expect(
      fillBeside('done · target not met yet'),
      dayMarkStateFill(tokens, DayMarkState.partial),
    );
    expect(fillBeside('No entry'), dayMarkStateFill(tokens, DayMarkState.none));
    // The today swatch is dashed like the cell, in the same ink and stroke.
    final ring = tester.widget<DsDashedBorder>(find.byType(DsDashedBorder));
    expect(ring.color, todayRingInk(tokens));
    expect(ring.strokeWidth, BorderWidths.emphasis);
    // The partial swatch carries the dot: a circle inside the square.
    final partialRow = find
        .ancestor(
          of: find.text('done · target not met yet'),
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
}
