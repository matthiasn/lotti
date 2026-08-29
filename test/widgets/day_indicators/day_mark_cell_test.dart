import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/tooltips/ds_tooltip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

import '../../widget_test_utils.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Align(alignment: Alignment.topLeft, child: child),
    ),
  );

  Container square(WidgetTester tester) => tester.widget<Container>(
    find
        .descendant(
          of: find.byType(DayMarkCell),
          matching: find.byType(Container),
        )
        .first,
  );

  testWidgets('a verdict outranks the state for fill and glyph', (
    tester,
  ) async {
    await pump(
      tester,
      const DayMarkCell(
        mark: DayMark(state: DayMarkState.none, verdict: DayVerdict.mixed),
        size: 28,
        weekdayLetter: 'M',
      ),
    );
    final tokens = tester.element(find.byType(DayMarkCell)).designTokens;
    expect(
      (square(tester).decoration! as BoxDecoration).color,
      dayVerdictFill(tokens, DayVerdict.mixed),
    );
    expect(find.byIcon(dayVerdictGlyph(DayVerdict.mixed)), findsOneWidget);
    expect(
      find.text('M'),
      findsNothing,
      reason: 'the glyph outranks the letter',
    );
  });

  testWidgets('a plain full cell carries the weekday letter; a partial one '
      'carries the dot instead', (tester) async {
    await pump(
      tester,
      const DayMarkCell(
        mark: DayMark(state: DayMarkState.full),
        size: 28,
        weekdayLetter: 'T',
      ),
    );
    expect(find.text('T'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);

    await pump(
      tester,
      const DayMarkCell(
        mark: DayMark(state: DayMarkState.partial),
        size: 28,
        weekdayLetter: 'T',
      ),
    );
    expect(find.text('T'), findsNothing);
    // The dot is the innermost Container inside the cell.
    final dot = find
        .descendant(
          of: find.byType(DayMarkCell),
          matching: find.byType(Container),
        )
        .last;
    expect(
      (tester.widget<Container>(dot).decoration! as BoxDecoration).shape,
      BoxShape.circle,
    );
  });

  testWidgets('recorded outcomes show their shape without a verdict', (
    tester,
  ) async {
    await pump(
      tester,
      const DayMarkCell(mark: DayMark(state: DayMarkState.missed), size: 20),
    );
    expect(find.byIcon(LottiIcons.close), findsOneWidget);
    await pump(
      tester,
      const DayMarkCell(mark: DayMark(state: DayMarkState.skipped), size: 20),
    );
    expect(find.byIcon(LottiIcons.remove), findsOneWidget);
  });

  testWidgets('today wears the dashed ring inside the shared footprint', (
    tester,
  ) async {
    await pump(
      tester,
      const DayMarkCell(mark: DayMark(state: DayMarkState.none), size: 20),
    );
    final plain = tester.getSize(find.byType(DayMarkCell));
    expect(find.byType(DsDashedBorder), findsNothing);

    await pump(
      tester,
      const DayMarkCell(
        mark: DayMark(state: DayMarkState.none, isToday: true),
        size: 20,
      ),
    );
    expect(find.byType(DsDashedBorder), findsOneWidget);
    expect(
      tester.getSize(find.byType(DayMarkCell)),
      plain,
      reason: 'the ring never bulges the rhythm',
    );
  });

  testWidgets('a tappable cell is a labelled button that clears the touch '
      'floor and answers hover with the day and outcome', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pump(
      tester,
      DayMarkCell(
        mark: const DayMark(state: DayMarkState.full),
        size: 20,
        label: 'Mon, Aug 10: done',
        tooltipDay: 'Mon, Aug 10',
        tooltipOutcome: 'done',
        onTap: () => taps++,
      ),
    );
    expect(
      tester.getSize(find.byType(DayMarkCell)).height,
      greaterThanOrEqualTo(TapTargets.minimum),
    );
    final tooltip = tester.widget<DsTooltip>(find.byType(DsTooltip));
    expect(tooltip.title, 'Mon, Aug 10');
    expect(tooltip.message, 'done');
    await tester.tap(find.bySemanticsLabel('Mon, Aug 10: done'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a read-only dated cell still answers hover with its day and '
      'outcome, without becoming a button', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const DayMarkCell(
        mark: DayMark(state: DayMarkState.full),
        size: 20,
        tooltipDay: 'Tue, Aug 11',
        tooltipOutcome: 'done',
      ),
    );
    final tooltip = tester.widget<DsTooltip>(find.byType(DsTooltip));
    expect(tooltip.title, 'Tue, Aug 11');
    expect(tooltip.message, 'done');
    expect(find.byType(DsQuietInk), findsNothing);
    expect(
      find.bySemanticsLabel('Tue, Aug 11: done'),
      findsNothing,
      reason: 'a read-only cell is not a button; the strip summarises it',
    );
    handle.dispose();
  });

  testWidgets('an undated read-only cell carries no tooltip', (tester) async {
    await pump(
      tester,
      const DayMarkCell(mark: DayMark(state: DayMarkState.full), size: 20),
    );
    expect(find.byType(DsTooltip), findsNothing);
  });

  testWidgets('a placeholder cell is a dashed outline at the cell size', (
    tester,
  ) async {
    await pump(tester, const PlaceholderDayCell(size: 18));
    expect(find.byType(DsDashedBorder), findsOneWidget);
    expect(
      tester.getSize(
        find
            .descendant(
              of: find.byType(DsDashedBorder),
              matching: find.byType(SizedBox),
            )
            .first,
      ),
      const Size(18, 18),
    );
  });
}
