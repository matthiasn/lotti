import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_kpi_row.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const totals = ConsumptionMetrics(
    callCount: 5,
    totalTokens: 12345,
    credits: 1.23,
    energyKwh: 0.5,
    carbonGCo2: 250,
    waterLiters: 0.1,
  );

  Future<void> pumpRow(
    WidgetTester tester, {
    required Size surface,
    ConsumptionMetrics? previousTotals,
  }) async {
    // The row's breakpoint reads real layout constraints, so the test view
    // itself must be resized — MediaQuery data alone doesn't constrain it.
    tester.view
      ..physicalSize = surface
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidget(
        ImpactKpiRow(totals: totals, previousTotals: previousTotals),
        mediaQueryData: MediaQueryData(size: surface),
      ),
    );
    await tester.pump();
  }

  void expectAllFigures() {
    // Figures must be the exact formatter outputs, unit suffix included.
    expect(formatCredits(1.23), '€1.23');
    expect(find.text('€1.23'), findsOneWidget);
    expect(formatEnergyKwh(0.5), '500 Wh');
    expect(find.text('500 Wh'), findsOneWidget);
    expect(formatCarbonGrams(250), '250 g');
    expect(find.text('250 g'), findsOneWidget);
    expect(find.text(formatTokenCount(12345)), findsOneWidget);
    expect(find.text(formatCallCount(5)), findsOneWidget); // requests

    // Eyebrow labels name each tile.
    expect(find.text('COST'), findsOneWidget);
    expect(find.text('ENERGY'), findsOneWidget);
    expect(find.text('CO₂E'), findsOneWidget);
    expect(find.text('TOKENS'), findsOneWidget);
    expect(find.text('REQUESTS'), findsOneWidget);

    // Coverage note keeps the cloud-only measurement honest.
    expect(
      find.textContaining('measured for cloud models only'),
      findsOneWidget,
    );
  }

  testWidgets('desktop width renders all five metric tiles in one row', (
    tester,
  ) async {
    await pumpRow(tester, surface: const Size(1280, 900));
    expectAllFigures();
    // Wide layout (≥900): all five tiles share one equal-height row.
    expect(find.byType(IntrinsicHeight), findsOneWidget);
  });

  testWidgets('medium width wraps into three-per-row with the same figures', (
    tester,
  ) async {
    await pumpRow(tester, surface: const Size(720, 900));
    expectAllFigures();
    // 560–900: three-per-row → two equal-height rows (3 + 2).
    expect(find.byType(IntrinsicHeight), findsNWidgets(2));
  });

  testWidgets('narrow width wraps into a two-per-row grid with same figures', (
    tester,
  ) async {
    await pumpRow(tester, surface: const Size(390, 844));
    expectAllFigures();
    // Narrow (<560): two-per-row → three equal-height rows (2 + 2 + 1).
    expect(find.byType(IntrinsicHeight), findsNWidgets(3));
  });

  testWidgets('shows a period-over-period delta when previous totals given', (
    tester,
  ) async {
    // Current cost 1.23, previous 1.00 → +23%; energy 0.5 vs 1.0 → -50%.
    await pumpRow(
      tester,
      surface: const Size(1280, 900),
      previousTotals: const ConsumptionMetrics(
        callCount: 5,
        totalTokens: 12345,
        credits: 1,
        energyKwh: 1,
      ),
    );
    expect(find.textContaining('▲ 23% vs prev'), findsOneWidget);
    expect(find.textContaining('▼ 50% vs prev'), findsOneWidget);
  });

  testWidgets('omits the delta for metrics with no prior value', (
    tester,
  ) async {
    // Previous carbon is 0 → its tile shows no delta.
    await pumpRow(
      tester,
      surface: const Size(1280, 900),
      previousTotals: const ConsumptionMetrics(credits: 1),
    );
    // Cost has a prior (+23%); carbon/tokens/requests do not.
    expect(find.textContaining('▲ 23% vs prev'), findsOneWidget);
    // Exactly one delta line (only cost had a prior value).
    expect(find.textContaining('vs prev'), findsOneWidget);
  });
}
