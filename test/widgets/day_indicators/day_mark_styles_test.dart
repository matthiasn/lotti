import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';
import 'package:material_ui/material_ui.dart';

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

  testWidgets('state fills separate kept, partial, untouched and recorded '
      'outcome days without alert-colored fills', (
    tester,
  ) async {
    final t = await tokens(tester);
    final kept = t.colors.interactive.enabled;
    expect(dayMarkStateFill(t, DayMarkState.full), kept);
    expect(
      dayMarkStateFill(t, DayMarkState.partial),
      kept.withValues(alpha: SurfaceAlphas.muted),
    );
    expect(
      dayMarkStateFill(t, DayMarkState.none),
      t.colors.background.level03,
    );
    for (final state in [DayMarkState.missed, DayMarkState.skipped]) {
      expect(
        dayMarkStateFill(t, state),
        t.colors.background.level02,
        reason: '$state is not painted in an alert hue',
      );
    }
  });

  testWidgets('only recorded skip and miss states receive an outcome outline', (
    tester,
  ) async {
    final t = await tokens(tester);
    for (final state in DayMarkState.values) {
      final border = dayMarkStateBorder(t, state);
      if (state == DayMarkState.skipped || state == DayMarkState.missed) {
        expect(
          border,
          Border.all(color: t.colors.background.level03),
          reason: '$state keeps its rounded neutral container visible',
        );
        expect((border! as Border).top.width, BorderWidths.hairline);
      } else {
        expect(border, isNull, reason: '$state');
      }
    }
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
      dayVerdictFill(t, DayVerdict.missed),
      isNot(dayMarkStateFill(t, DayMarkState.none)),
      reason: 'a judged miss is never the empty-day grey',
    );
    expect(
      dayVerdictFill(t, DayVerdict.met),
      dayMarkStateFill(t, DayMarkState.full),
      reason: 'one green for good on every track',
    );
    for (final verdict in DayVerdict.values.where((v) => v != DayVerdict.met)) {
      expect(
        dayVerdictFill(t, verdict),
        isNot(dayMarkStateFill(t, DayMarkState.full)),
        reason: 'a non-met verdict is never mistaken for a kept day',
      );
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
}
