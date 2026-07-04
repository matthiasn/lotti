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

  Future<void> pumpRow(WidgetTester tester, {required Size surface}) async {
    // The row's breakpoint reads real layout constraints, so the test view
    // itself must be resized — MediaQuery data alone doesn't constrain it.
    tester.view
      ..physicalSize = surface
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidget(
        const ImpactKpiRow(totals: totals),
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

    // Eyebrow labels name each tile.
    expect(find.text('COST'), findsOneWidget);
    expect(find.text('ENERGY'), findsOneWidget);
    expect(find.text('CO₂E'), findsOneWidget);
    expect(find.text('TOKENS'), findsOneWidget);
  }

  testWidgets('desktop width renders all four metric tiles in one row', (
    tester,
  ) async {
    await pumpRow(tester, surface: const Size(1280, 900));
    expectAllFigures();
    // Wide layout: all four tiles share one equal-height row.
    expect(find.byType(IntrinsicHeight), findsOneWidget);
  });

  testWidgets('narrow width wraps into a 2x2 grid with the same figures', (
    tester,
  ) async {
    await pumpRow(tester, surface: const Size(390, 844));
    expectAllFigures();
    // Narrow layout: two stacked equal-height rows of two tiles.
    expect(find.byType(IntrinsicHeight), findsNWidgets(2));
  });
}
