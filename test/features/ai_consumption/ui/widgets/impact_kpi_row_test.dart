import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
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

  ConsumptionMetric? selected;

  Future<void> pumpRow(
    WidgetTester tester, {
    required Size surface,
    ConsumptionMetric selectedMetric = ConsumptionMetric.cost,
    ConsumptionMetrics? previousTotals,
    String? previousLabel,
  }) async {
    selected = null;
    // The row's breakpoint reads real layout constraints, so the test view
    // itself must be resized — MediaQuery data alone doesn't constrain it.
    tester.view
      ..physicalSize = surface
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidget(
        ImpactKpiRow(
          totals: totals,
          selectedMetric: selectedMetric,
          onSelectMetric: (m) => selected = m,
          previousTotals: previousTotals,
          previousLabel: previousLabel,
        ),
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

  testWidgets('tapping a tile selects that metric', (tester) async {
    await pumpRow(tester, surface: const Size(1280, 900));
    await tester.tap(find.text('ENERGY'));
    await tester.pump();
    expect(selected, ConsumptionMetric.energy);
  });

  testWidgets('the selected tile is marked selected for a11y, others are not', (
    tester,
  ) async {
    await pumpRow(
      tester,
      surface: const Size(1280, 900),
      selectedMetric: ConsumptionMetric.tokens,
    );
    // Exactly one tile carries selected: true — the tokens tile.
    final selectedTiles = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.selected ?? false)
        .toList();
    expect(selectedTiles, hasLength(1));
    expect(
      find.descendant(
        of: find.byWidget(selectedTiles.first),
        matching: find.text('TOKENS'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows a rising, clay-valence delta only on the selected cost tile',
    (tester) async {
      // Cost 1.23 vs 1.00 → +23%; only the cost tile (selected) shows it, with
      // an up arrow (rising cost is bad → the chip paints it the caution hue).
      await pumpRow(
        tester,
        surface: const Size(1280, 900),
        previousTotals: const ConsumptionMetrics(credits: 1),
        previousLabel: 'May',
      );
      expect(find.text('+23%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      // The baseline is named, and appears exactly once (selected tile only).
      expect(find.text('vs May'), findsOneWidget);
    },
  );

  testWidgets('omits the delta when there is no previous period', (
    tester,
  ) async {
    await pumpRow(tester, surface: const Size(1280, 900));
    expect(find.textContaining('vs'), findsNothing);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
  });

  testWidgets('omits the delta when the selected metric has no prior value', (
    tester,
  ) async {
    // Previous energy is 0 → the selected energy tile shows no delta.
    await pumpRow(
      tester,
      surface: const Size(1280, 900),
      selectedMetric: ConsumptionMetric.energy,
      previousTotals: const ConsumptionMetrics(credits: 1),
      previousLabel: 'May',
    );
    expect(find.text('vs May'), findsNothing);
  });
}
