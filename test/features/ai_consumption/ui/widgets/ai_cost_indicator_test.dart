import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_cost_indicator.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  final measured = makeConsumptionTotals(
    callCount: 3,
    impactCallCount: 2,
    inputTokens: 1200,
    outputTokens: 800,
    totalTokens: 2000,
    credits: 0.42,
    energyKwh: 0.012,
    carbonGCo2: 3.4,
    waterLiters: 0.012,
    durationMs: 60000,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget indicator,
  ) => tester.pumpWidget(
    makeTestableWidgetNoScroll(Scaffold(body: Center(child: indicator))),
  );

  testWidgets('compact density shows the cost alone beside the leaf', (
    tester,
  ) async {
    await pump(tester, AiCostIndicator(totals: measured));

    expect(find.text('€0.42'), findsOneWidget);
    expect(find.byIcon(LottiIcons.eco), findsOneWidget);
    // The energy and carbon belong to the detail density, not this one.
    expect(find.textContaining('Wh'), findsNothing);
  });

  testWidgets('detail density spells cost, energy and carbon out', (
    tester,
  ) async {
    await pump(
      tester,
      AiCostIndicator(totals: measured, density: AiCostDensity.detail),
    );

    expect(find.text('€0.42 · 12 Wh · 3.4 g'), findsOneWidget);
  });

  testWidgets('falls back to a token count where no impact was measured', (
    tester,
  ) async {
    await pump(
      tester,
      AiCostIndicator(
        totals: makeConsumptionTotals(callCount: 2, totalTokens: 2000),
      ),
    );

    expect(find.text('${formatTokenCount(2000)} tokens'), findsOneWidget);
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('renders nothing at all without recorded calls', (tester) async {
    await pump(tester, AiCostIndicator(totals: makeConsumptionTotals()));

    expect(find.byType(DsPill), findsNothing);
    expect(find.byIcon(LottiIcons.eco), findsNothing);
  });

  testWidgets('a tap target takes the interactive pill shape and fires', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      AiCostIndicator(totals: measured, onTap: () => taps++),
    );

    expect(
      tester.widget<DsPill>(find.byType(DsPill)).shape,
      DsPillShape.pill,
    );
    await tester.tap(find.text('€0.42'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('without a tap it keeps the tight read-out corners', (
    tester,
  ) async {
    await pump(tester, AiCostIndicator(totals: measured));

    expect(
      tester.widget<DsPill>(find.byType(DsPill)).shape,
      DsPillShape.tag,
    );
    expect(tester.widget<DsPill>(find.byType(DsPill)).onTap, isNull);
  });

  testWidgets('the tooltip carries the full breakdown at every density', (
    tester,
  ) async {
    await pump(tester, AiCostIndicator(totals: measured));

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('AI calls: 3'));
    expect(tooltip.message, contains(formatWaterLiters(0.012)));
    expect(tooltip.message, contains(formatCredits(0.42)));
  });

  testWidgets('announces itself as the task AI spend', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, AiCostIndicator(totals: measured, onTap: () {}));

    expect(
      tester.getSemantics(find.byType(AiCostIndicator)),
      matchesSemantics(
        label: 'AI spend\n€0.42',
        hasTapAction: true,
        isButton: true,
        isFocusable: true,
        hasFocusAction: true,
        tooltip: tester.widget<Tooltip>(find.byType(Tooltip)).message,
      ),
    );
    handle.dispose();
  });
}
