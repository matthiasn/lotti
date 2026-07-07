import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_model_table.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/series_resolver.dart';

import '../../../../widget_test_utils.dart';

void main() {
  ConsumptionMetrics m({
    int callCount = 1,
    int totalTokens = 0,
    double credits = 0,
    double energyKwh = 0,
  }) => ConsumptionMetrics(
    callCount: callCount,
    totalTokens: totalTokens,
    credits: credits,
    energyKwh: energyKwh,
  );

  // glm-5.2: €3 over 600k tokens across 12 calls → €5.00/1M tok.
  // unknown: €1, no tokens → calls only, no rate.
  final entries = [
    MapEntry<String?, ConsumptionMetrics>(
      'glm-5.2',
      m(callCount: 12, totalTokens: 600000, credits: 3),
    ),
    MapEntry<String?, ConsumptionMetrics>(null, m(callCount: 4, credits: 1)),
  ];

  Future<void> pumpTable(
    WidgetTester tester, {
    required List<MapEntry<String?, ConsumptionMetrics>> rows,
    double width = 900,
    ConsumptionMetric metric = ConsumptionMetric.cost,
  }) async {
    final resolver = PaletteSeriesResolver(
      orderedKeys: rows.map((e) => e.key).whereType<String>().toList()..sort(),
      unknownLabel: 'Unknown model',
      otherLabel: 'Other models',
    );
    await tester.pumpWidget(
      makeTestableWidget(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: ImpactModelTable(
              entries: rows,
              resolver: resolver,
              metric: metric,
            ),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1000, 800)),
      ),
    );
    await tester.pump();
  }

  testWidgets('rows show names, values, shares and unit economics', (
    tester,
  ) async {
    await pumpTable(tester, rows: entries);

    expect(find.text('Model breakdown'), findsOneWidget);
    expect(find.text('MODEL'), findsOneWidget);
    expect(find.text('glm-5.2'), findsOneWidget);
    expect(find.text('€3.00'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Unknown model'), findsOneWidget);
    expect(find.text('€1.00'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    // Unit-economics meta line: calls + cost per million tokens; the
    // tokenless unknown model shows calls only (no rate).
    expect(find.text('12 calls · €5.00/1M tok'), findsOneWidget);
    expect(find.text('4 calls'), findsOneWidget);
  });

  testWidgets('values format through the selected metric', (tester) async {
    await pumpTable(
      tester,
      rows: [
        MapEntry<String?, ConsumptionMetrics>(
          'voxtral-small-24b-2507',
          m(callCount: 5, energyKwh: 0.25),
        ),
      ],
      metric: ConsumptionMetric.energy,
    );

    expect(find.text('voxtral-small-24b-2507'), findsOneWidget);
    expect(find.text('250 Wh'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    // No cost/tokens → the rate is dropped, calls remain.
    expect(find.text('5 calls'), findsOneWidget);
  });

  testWidgets('narrow panes drop the share, then the value column', (
    tester,
  ) async {
    await pumpTable(tester, rows: entries, width: 220);
    expect(find.text('glm-5.2'), findsOneWidget);
    expect(find.text('€3.00'), findsOneWidget);
    expect(find.text('75%'), findsNothing);
    expect(find.text('SHARE'), findsNothing);

    await pumpTable(tester, rows: entries, width: 160);
    expect(find.text('glm-5.2'), findsOneWidget);
    expect(find.text('€3.00'), findsNothing);
    expect(find.text('TOTAL'), findsNothing);
  });

  testWidgets('a row is tappable to toggle isolation of that model', (
    tester,
  ) async {
    String? toggled;
    final resolver = PaletteSeriesResolver(
      orderedKeys: const ['glm-5.2'],
      unknownLabel: 'Unknown model',
      otherLabel: 'Other models',
    );
    await tester.pumpWidget(
      makeTestableWidget(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 900,
            child: ImpactModelTable(
              entries: entries,
              resolver: resolver,
              metric: ConsumptionMetric.cost,
              onToggleSeries: (k) => toggled = k,
            ),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1000, 800)),
      ),
    );
    await tester.pump();

    // Interactive rows carry a chevron; tapping one isolates that model.
    expect(find.byIcon(Icons.chevron_right), findsWidgets);
    await tester.tap(find.text('glm-5.2'));
    await tester.pump();
    expect(toggled, 'glm-5.2');
  });

  testWidgets('renders nothing for empty model totals', (tester) async {
    await pumpTable(tester, rows: const []);

    expect(find.text('Model breakdown'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ImpactModelTable),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'flags the model whose spend share outstrips its request share',
    (tester) async {
      // pricey: €10 over 2 calls; cheap: €1 over 18 calls. pricey's cost share
      // (10/11 ≈ 91%) dwarfs its request share (2/20 = 10%) → cost-heavy.
      final rows = [
        MapEntry<String?, ConsumptionMetrics>(
          'pricey',
          m(callCount: 2, totalTokens: 4000, credits: 10),
        ),
        MapEntry<String?, ConsumptionMetrics>(
          'cheap',
          m(callCount: 18, totalTokens: 36000, credits: 1),
        ),
      ];
      await pumpTable(tester, rows: rows);

      // The badge appears exactly once — on the outlier.
      expect(find.text('cost-heavy'), findsOneWidget);
      // …and it rides the pricey row (the badge + 'pricey' share a Row).
      final badgeRow = find
          .ancestor(of: find.text('cost-heavy'), matching: find.byType(Row))
          .first;
      expect(
        find.descendant(of: badgeRow, matching: find.text('pricey')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows no cost-heavy badge when spend tracks requests', (
    tester,
  ) async {
    // Two identical models — cost share equals request share, no outlier.
    final rows = [
      MapEntry<String?, ConsumptionMetrics>(
        'a',
        m(callCount: 10, totalTokens: 10000, credits: 5),
      ),
      MapEntry<String?, ConsumptionMetrics>(
        'b',
        m(callCount: 10, totalTokens: 10000, credits: 5),
      ),
    ];
    await pumpTable(tester, rows: rows);

    expect(find.text('cost-heavy'), findsNothing);
  });
}
