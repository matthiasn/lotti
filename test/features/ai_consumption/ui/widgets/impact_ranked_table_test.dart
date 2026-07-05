import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_ranked_table.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';

import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  final resolver = InsightsCategoryResolver(
    categoriesById: {
      'cat-a': CategoryTestUtils.createTestCategory(
        id: 'cat-a',
        name: 'Agents',
        color: '#3B82F6',
      ),
    },
    uncategorizedLabel: 'Uncategorized',
    otherLabel: 'Other',
    deletedLabel: 'Deleted category',
  );

  final entries = [
    const MapEntry<String?, double>('cat-a', 3),
    const MapEntry<String?, double>(null, 1),
  ];

  Future<void> pumpTable(
    WidgetTester tester, {
    required List<MapEntry<String?, double>> rows,
    double width = 900,
    ConsumptionMetric metric = ConsumptionMetric.cost,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: ImpactRankedTable(
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

  testWidgets('rows show resolved names, formatted values, and shares', (
    tester,
  ) async {
    await pumpTable(tester, rows: entries);

    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('SHARE'), findsOneWidget);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('€3.00'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.text('€1.00'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('values format through the selected metric', (tester) async {
    await pumpTable(
      tester,
      rows: [const MapEntry<String?, double>('cat-a', 0.25)],
      metric: ConsumptionMetric.energy,
    );
    // 0.25 kWh degrades to Wh via the energy formatter.
    expect(find.text('250 Wh'), findsOneWidget);
    // Single entry owns the whole period.
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('narrow panes drop the share, then the value column', (
    tester,
  ) async {
    await pumpTable(tester, rows: entries, width: 220);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('€3.00'), findsOneWidget);
    expect(find.text('75%'), findsNothing);
    expect(find.text('SHARE'), findsNothing);

    await pumpTable(tester, rows: entries, width: 160);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('€3.00'), findsNothing);
    expect(find.text('TOTAL'), findsNothing);
  });

  testWidgets('renders nothing at all for an empty ranking', (tester) async {
    await pumpTable(tester, rows: const []);
    expect(find.text('CATEGORY'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ImpactRankedTable),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });
}
