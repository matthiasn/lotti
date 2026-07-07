import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_location_table.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final entries = [
    MapEntry(
      ConsumptionLocationKey.fromDataCenter('FI-HEL1'),
      const ConsumptionLocationMetrics(
        metrics: ConsumptionMetrics(energyKwh: 0.04, carbonGCo2: 8),
        renewablePercentSum: 180,
        renewableSampleCount: 2,
        renewableEnergyKwh: 0.04,
        renewableWeightedPercentKwh: 3.8,
      ),
    ),
    MapEntry(
      ConsumptionLocationKey.fromDataCenter('stockholm'),
      const ConsumptionLocationMetrics(
        metrics: ConsumptionMetrics(energyKwh: 0.01, carbonGCo2: 1),
      ),
    ),
  ];

  Future<void> pumpTable(
    WidgetTester tester, {
    required List<MapEntry<ConsumptionLocationKey, ConsumptionLocationMetrics>>
    rows,
    double width = 900,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: ImpactLocationTable(entries: rows),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1000, 800)),
      ),
    );
    await tester.pump();
  }

  testWidgets('rows show country, data center, energy, carbon, and renewable', (
    tester,
  ) async {
    await pumpTable(tester, rows: entries);

    expect(find.text('Impact by location'), findsOneWidget);
    expect(find.text('LOCATION'), findsOneWidget);
    expect(find.text('ENERGY'), findsOneWidget);
    expect(find.text('CO₂E'), findsOneWidget);
    expect(find.text('RENEWABLE'), findsOneWidget);

    expect(find.text('FI'), findsOneWidget);
    expect(find.text('FI-HEL1'), findsOneWidget);
    expect(find.text('40 Wh'), findsOneWidget);
    expect(find.text('8.0 g'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);

    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('STOCKHOLM'), findsOneWidget);
    expect(find.text('10 Wh'), findsOneWidget);
    expect(find.text('Not reported'), findsOneWidget);
  });

  testWidgets('narrow panes keep renewable visible before carbon', (
    tester,
  ) async {
    await pumpTable(tester, rows: entries.take(1).toList(), width: 340);

    expect(find.text('FI'), findsOneWidget);
    expect(find.text('40 Wh'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);
    expect(find.text('CO₂E'), findsNothing);
    expect(find.text('8.0 g'), findsNothing);
  });

  testWidgets(
    'narrow renewable column keeps the not-reported fallback stable',
    (
      tester,
    ) async {
      await pumpTable(tester, rows: entries.skip(1).toList(), width: 300);

      expect(tester.takeException(), isNull);
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('10 Wh'), findsOneWidget);
      expect(find.text('Not reported'), findsOneWidget);
      expect(find.text('CO₂E'), findsNothing);
    },
  );

  testWidgets('very narrow panes drop renewable too', (tester) async {
    await pumpTable(tester, rows: entries.take(1).toList(), width: 260);

    expect(find.text('FI'), findsOneWidget);
    expect(find.text('40 Wh'), findsOneWidget);
    expect(find.text('95%'), findsNothing);
    expect(find.text('RENEWABLE'), findsNothing);
  });

  testWidgets('renders nothing for empty location totals', (tester) async {
    await pumpTable(tester, rows: const []);

    expect(find.text('Impact by location'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ImpactLocationTable),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });
}
