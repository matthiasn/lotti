import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

import '../../widget_test_utils.dart';

void main() {
  Future<DsTokens> tokens(WidgetTester tester) async {
    late DsTokens tokens;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            tokens = context.designTokens;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return tokens;
  }

  testWidgets('state fills: success family for kept days, error for a miss, '
      'neutral for skip and empty', (tester) async {
    final t = await tokens(tester);
    final success = t.colors.alert.success.defaultColor;
    expect(dayMarkStateFill(t, DayMarkState.full), success);
    expect(
      dayMarkStateFill(t, DayMarkState.partial),
      success.withValues(alpha: SurfaceAlphas.muted),
    );
    expect(
      dayMarkStateFill(t, DayMarkState.missed),
      t.colors.alert.error.defaultColor,
    );
    expect(
      dayMarkStateFill(t, DayMarkState.skipped),
      t.colors.background.level03,
    );
    expect(
      dayMarkStateFill(t, DayMarkState.none),
      t.colors.background.level03,
    );
    // Data never wears the interactive teal.
    for (final state in DayMarkState.values) {
      expect(dayMarkStateFill(t, state), isNot(t.colors.interactive.enabled));
    }
  });

  testWidgets('only recorded outcomes carry a state glyph, in their own ink', (
    tester,
  ) async {
    final t = await tokens(tester);
    expect(dayMarkStateGlyph(DayMarkState.missed), LottiIcons.close);
    expect(dayMarkStateGlyph(DayMarkState.skipped), LottiIcons.remove);
    for (final state in [
      DayMarkState.none,
      DayMarkState.partial,
      DayMarkState.full,
    ]) {
      expect(dayMarkStateGlyph(state), isNull);
    }
    expect(
      dayMarkStateGlyphInk(t, DayMarkState.missed),
      t.colors.alert.error.ink,
    );
    expect(
      dayMarkStateGlyphInk(t, DayMarkState.skipped),
      t.colors.text.mediumEmphasis,
    );
  });

  testWidgets('every verdict has a distinct fill, shape and surface ink', (
    tester,
  ) async {
    final t = await tokens(tester);
    expect(
      DayVerdict.values.map((v) => dayVerdictFill(t, v)).toSet().length,
      DayVerdict.values.length,
    );
    expect(
      DayVerdict.values.map(dayVerdictGlyph).toSet().length,
      DayVerdict.values.length,
    );
    expect(
      DayVerdict.values.map((v) => dayVerdictSurfaceInk(t, v)).toSet().length,
      DayVerdict.values.length,
    );
    expect(
      dayVerdictFill(t, DayVerdict.met),
      dayMarkStateFill(t, DayMarkState.full),
      reason: 'met and measured-full are the same green',
    );
    expect(
      dayVerdictFill(t, DayVerdict.missed),
      isNot(dayMarkStateFill(t, DayMarkState.none)),
      reason: 'a judged miss is never the empty-day grey',
    );
    for (final verdict in DayVerdict.values) {
      expect(dayVerdictInk(t, verdict), t.colors.text.onInteractiveAlert);
    }
  });

  testWidgets('labels are localized per state and verdict', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(
      DayMarkState.values.map((s) => dayMarkStateLabel(ctx, s)).toSet().length,
      DayMarkState.values.length,
    );
    expect(dayMarkStateLabel(ctx, DayMarkState.skipped), 'Skip');
    expect(dayMarkStateLabel(ctx, DayMarkState.missed), 'Missed');
    expect(dayVerdictLabel(ctx, DayVerdict.met), 'Met');
    expect(dayVerdictLabel(ctx, DayVerdict.improving), 'Improving');
    expect(dayVerdictLabel(ctx, DayVerdict.mixed), 'Mixed');
    expect(dayVerdictLabel(ctx, DayVerdict.missed), 'Missed');
  });

  testWidgets('the corner letter yields on cells too small to hold it and '
      'follows the fill for ink', (tester) async {
    final t = await tokens(tester);
    expect(
      dayCellLetter(t, letter: 'M', cellSize: IconSizes.xs, filled: false),
      isNull,
    );
    expect(
      dayCellLetter(t, letter: null, cellSize: IconSizes.l, filled: false),
      isNull,
    );
    final tag = dayCellLetter(t, letter: 'M', cellSize: 28, filled: true);
    expect(tag, isA<PositionedDirectional>());
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SizedBox.square(dimension: 28, child: Stack(children: [tag!])),
      ),
    );
    final text = tester.widget<Text>(find.text('M'));
    expect(text.style?.color, t.colors.text.onInteractiveAlert);
    final positioned = tester.widget<PositionedDirectional>(
      find.byType(PositionedDirectional),
    );
    expect(positioned.start, 28 * DayCellLetter.insetStart);
    expect(positioned.bottom, 28 * DayCellLetter.insetBottom);
  });

  testWidgets(
    'the today ring and partial dot draw in quiet, non-interactive ink',
    (
      tester,
    ) async {
      final t = await tokens(tester);
      expect(todayRingInk(t), t.colors.text.mediumEmphasis);
      expect(dayCellRadius(t), t.radii.s);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(Center(child: partialDayDot(t, 6))),
      );
      final dot = tester.widget<Container>(find.byType(Container));
      expect(tester.getSize(find.byType(Container)), const Size(6, 6));
      expect(
        (dot.decoration! as BoxDecoration).color,
        t.colors.alert.success.ink,
      );
    },
  );
}
