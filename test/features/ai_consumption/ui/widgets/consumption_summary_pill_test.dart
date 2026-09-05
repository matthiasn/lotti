import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  const foreground = Colors.white;

  testWidgets('shows Melious credits and environmental impact with the full '
      'tooltip', (tester) async {
    final totals = makeConsumptionTotals(
      callCount: 3,
      impactCallCount: 2,
      inputTokens: 1200,
      outputTokens: 800,
      totalTokens: 2000,
      credits: 0.42,
      energyKwh: 0.012,
      carbonGCo2: 3.4,
      waterLiters: 0.012,
      durationMs: 3660000,
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: ConsumptionSummaryPill(
            totals: totals,
            foregroundColor: foreground,
          ),
        ),
      ),
    );

    expect(find.text('€0.42 · 12 Wh · 3.4 g'), findsOneWidget);
    expect(find.byIcon(LottiIcons.eco), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(
      tooltip.message,
      'AI calls: 3 · impact measured for 2\n'
      'Tokens: ${formatTokenCount(1200)} in · ${formatTokenCount(800)} out\n'
      'Compute time: 1h 1m\n'
      'Impact: ${formatEnergyKwh(0.012)} · ${formatCarbonGrams(3.4)} CO₂e · '
      '${formatWaterLiters(0.012)} water\n'
      'Cost: ${formatCredits(0.42)}',
    );
  });

  testWidgets('localizes a non-zero sub-minute compute duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: ConsumptionSummaryPill(
            totals: makeConsumptionTotals(
              callCount: 1,
              durationMs: 1200,
            ),
            foregroundColor: foreground,
          ),
        ),
        locale: const Locale('de'),
      ),
    );

    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      contains('Rechenzeit: Unter 1 Min.'),
    );
  });

  testWidgets('falls back to tokens and hides zero-call totals', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Column(
            children: [
              ConsumptionSummaryPill(
                totals: makeConsumptionTotals(
                  callCount: 2,
                  totalTokens: 12300,
                ),
                foregroundColor: foreground,
              ),
              ConsumptionSummaryPill(
                totals: makeConsumptionTotals(),
                foregroundColor: foreground,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('12.3K tokens'), findsOneWidget);
    expect(find.byType(DsPill), findsOneWidget);
    // A read-out, not a control: informational pills wear the tight tag
    // corners per the corner-radius convention.
    expect(
      tester.widget<DsPill>(find.byType(DsPill)).shape,
      DsPillShape.tag,
    );
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      isNot(contains('Compute time')),
    );
  });
}
