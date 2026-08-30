import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  BoxDecoration decoration(WidgetTester tester) =>
      square(tester).decoration! as BoxDecoration;

  testWidgets('an undated square is one size at the xs radius, with a glyph '
      'inside it only for a kept or missed day', (tester) async {
    for (final state in DayMarkState.values) {
      await pump(tester, DayMarkCell(mark: DayMark(state: state)));
      final tokens = tester.element(find.byType(DayMarkCell)).designTokens;
      expect(
        tester.getSize(find.byType(DayMarkCell)),
        const Size.square(kDaySquareSize),
        reason: '$state',
      );
      expect(
        decoration(tester).borderRadius,
        BorderRadius.circular(tokens.radii.xs),
        reason: '$state',
      );
      expect(decoration(tester).border, isNull, reason: '$state');
      if (state == DayMarkState.missed) {
        // A recorded miss and an empty day share the grey; the cross is
        // what tells them apart. The reflections history's own glyph, in
        // the quiet ink, inset one step so it sits inside the square.
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, dayVerdictGlyph(DayVerdict.missed));
        expect(icon.color, tokens.colors.text.mediumEmphasis);
        expect(icon.size, kDaySquareSize - tokens.spacing.step2);
      } else if (state == DayMarkState.full || state == DayMarkState.partial) {
        expect(
          tester.widget<Icon>(find.byType(Icon)).icon,
          dayVerdictGlyph(DayVerdict.met),
        );
      } else {
        expect(square(tester).child, isNull, reason: '$state');
        expect(find.byType(Icon), findsNothing, reason: '$state');
      }
      expect(find.byType(Text), findsNothing, reason: '$state');
      expect(find.byType(DsDashedBorder), findsNothing, reason: '$state');
    }
  });

  testWidgets('a verdict paints over a measured miss with its own glyph', (
    tester,
  ) async {
    await pump(
      tester,
      const DayMarkCell(
        mark: DayMark(state: DayMarkState.missed, verdict: DayVerdict.met),
      ),
    );
    expect(
      tester.widget<Icon>(find.byType(Icon)).icon,
      dayVerdictGlyph(DayVerdict.met),
    );
  });

  testWidgets('on a desktop window the square and the placeholder are one '
      'spacing step up', (tester) async {
    for (final cell in [
      const DayMarkCell(mark: DayMark(state: DayMarkState.full)),
      const PlaceholderDayCell(),
    ]) {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Align(alignment: Alignment.topLeft, child: cell),
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        ),
      );
      final tokens = tester.element(find.byWidget(cell)).designTokens;
      expect(
        tester.getSize(find.byWidget(cell)),
        Size.square(kDaySquareSize + tokens.spacing.step1),
        reason: '$cell',
      );
    }
  });

  testWidgets('the measured state decides the fill', (tester) async {
    for (final state in DayMarkState.values) {
      await pump(tester, DayMarkCell(mark: DayMark(state: state)));
      final tokens = tester.element(find.byType(DayMarkCell)).designTokens;
      expect(
        decoration(tester).color,
        dayMarkStateFill(tokens, state),
        reason: '$state',
      );
    }
  });

  testWidgets('an open today is the dashed unresolved square, and answers '
      'hover and taps like any other', (tester) async {
    var taps = 0;
    await pump(
      tester,
      DayMarkCell(
        mark: const DayMark(state: DayMarkState.none, isToday: true),
        label: 'Tue, Aug 11: No entry',
        tooltipDay: 'Tue, Aug 11',
        tooltipOutcome: 'No entry',
        onTap: () => taps++,
      ),
    );
    expect(find.byType(PlaceholderDayCell), findsOneWidget);
    expect(find.byType(DsDashedBorder), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DayMarkCell),
        matching: find.byType(Container),
      ),
      findsNothing,
      reason: 'no fill under the outline',
    );
    await tester.tap(find.byType(DayMarkCell));
    expect(taps, 1);
    // A kept today is an ordinary filled square.
    await pump(
      tester,
      const DayMarkCell(mark: DayMark(state: DayMarkState.full, isToday: true)),
    );
    expect(find.byType(DsDashedBorder), findsNothing);
  });

  testWidgets('a verdict outranks the state for the fill', (tester) async {
    await pump(
      tester,
      const DayMarkCell(
        mark: DayMark(state: DayMarkState.none, verdict: DayVerdict.mixed),
      ),
    );
    final tokens = tester.element(find.byType(DayMarkCell)).designTokens;
    expect(decoration(tester).color, dayVerdictFill(tokens, DayVerdict.mixed));
    expect(
      decoration(tester).color,
      isNot(dayMarkStateFill(tokens, DayMarkState.none)),
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
    expect(
      tester.getSize(find.byType(Container)),
      const Size.square(kDaySquareSize),
      reason: 'the hit slot grows, the square does not',
    );
    expect(find.byType(Text), findsNothing, reason: 'no caption asked for');
    final tooltip = tester.widget<DsTooltip>(find.byType(DsTooltip));
    expect(tooltip.title, 'Mon, Aug 10');
    expect(tooltip.message, 'done');
    await tester.tap(find.bySemanticsLabel('Mon, Aug 10: done'));
    expect(taps, 1);
    // The ink well's own node is excluded, so the activation action has to
    // be published on the labelled button itself.
    final node = tester.getSemantics(
      find.bySemanticsLabel('Mon, Aug 10: done'),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    // The test binding's semantics owner still lives on the legacy
    // pipeline owner; the root owner has none in widget tests.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.tap,
    );
    expect(taps, 2);
    handle.dispose();
  });

  testWidgets('an unresolved dated square carries its two-letter weekday '
      'inside itself, quiet on the neutral fill; an undated one carries '
      'nothing', (tester) async {
    final monday = DateTime.utc(2026, 8, 10);
    for (final state in [DayMarkState.none, DayMarkState.skipped]) {
      await pump(
        tester,
        DayMarkCell(
          mark: DayMark(state: state, day: monday),
        ),
      );
      final tokens = tester.element(find.byType(DayMarkCell)).designTokens;
      final letter = find.descendant(
        of: find.byType(Container),
        matching: find.text('Mo'),
      );
      expect(letter, findsOneWidget, reason: '$state');
      expect(find.byType(Icon), findsNothing, reason: '$state');
      expect(
        tester.widget<Text>(letter).style?.color,
        tokens.colors.text.lowEmphasis,
        reason: '$state',
      );
      expect(
        tester.getCenter(letter),
        tester.getCenter(find.byType(Container)),
        reason: '$state sits centred in its square',
      );
    }
    await pump(
      tester,
      const DayMarkCell(mark: DayMark(state: DayMarkState.none)),
    );
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('a kept day draws the tick and a verdict its own glyph, in the '
      'on-accent ink, instead of the letter', (tester) async {
    final monday = DateTime.utc(2026, 8, 10);
    await pump(
      tester,
      DayMarkCell(
        mark: DayMark(state: DayMarkState.full, day: monday),
      ),
    );
    var tokens = tester.element(find.byType(DayMarkCell)).designTokens;
    var icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, dayVerdictGlyph(DayVerdict.met));
    expect(icon.color, tokens.colors.text.onInteractiveAlert);
    expect(find.text('Mo'), findsNothing);
    // A partial day was kept too; its tick wears the kept hue on the wash.
    await pump(
      tester,
      DayMarkCell(
        mark: DayMark(state: DayMarkState.partial, day: monday),
      ),
    );
    tokens = tester.element(find.byType(DayMarkCell)).designTokens;
    icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, dayVerdictGlyph(DayVerdict.met));
    expect(icon.color, tokens.colors.interactive.enabled);
    expect(find.text('Mo'), findsNothing);
    for (final verdict in DayVerdict.values) {
      await pump(
        tester,
        DayMarkCell(
          mark: DayMark(
            state: DayMarkState.none,
            day: monday,
            verdict: verdict,
          ),
        ),
      );
      tokens = tester.element(find.byType(DayMarkCell)).designTokens;
      icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, dayVerdictGlyph(verdict), reason: '$verdict');
      expect(icon.color, tokens.colors.text.onInteractiveAlert);
      expect(find.text('Mo'), findsNothing, reason: '$verdict');
    }
  });

  testWidgets('the weekday is the first two characters of the localized '
      'abbreviation', (tester) async {
    final tuesday = DateTime.utc(2026, 8, 11);
    final thursday = DateTime.utc(2026, 8, 13);
    final saturday = DateTime.utc(2026, 8, 15);
    final sunday = DateTime.utc(2026, 8, 16);
    expect(
      [
        tuesday,
        thursday,
        saturday,
        sunday,
      ].map((day) => dayMarkWeekdayLabel('en', day)).toList(),
      ['Tu', 'Th', 'Sa', 'Su'],
    );
    expect(
      [
        tuesday,
        thursday,
        saturday,
        sunday,
      ].map((day) => dayMarkWeekdayLabel('de', day)).toList(),
      ['Di', 'Do', 'Sa', 'So'],
    );
    expect(dayMarkWeekdayLabel('ja', tuesday), '火');
  });

  testWidgets('a dated open today keeps its weekday inside the dashed '
      'outline', (tester) async {
    await pump(
      tester,
      DayMarkCell(
        mark: DayMark(
          state: DayMarkState.none,
          day: DateTime.utc(2026, 8, 10),
          isToday: true,
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(DsDashedBorder),
        matching: find.text('Mo'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a read-only dated cell still answers hover with its day and '
      'outcome, without becoming a button', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const DayMarkCell(
        mark: DayMark(state: DayMarkState.full),
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
      const DayMarkCell(mark: DayMark(state: DayMarkState.full)),
    );
    expect(find.byType(DsTooltip), findsNothing);
  });

  testWidgets('a placeholder cell is a dashed outline at the square size', (
    tester,
  ) async {
    await pump(tester, const PlaceholderDayCell());
    expect(find.byType(DsDashedBorder), findsOneWidget);
    expect(
      tester.getSize(find.byType(PlaceholderDayCell)),
      const Size.square(kDaySquareSize),
    );
  });
}
