import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_model_table.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final entries = [
    const MapEntry<String?, double>('glm-5.2', 3),
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
            child: ImpactModelTable(entries: rows, metric: metric),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1000, 800)),
      ),
    );
    await tester.pump();
  }

  testWidgets('rows show model names, formatted values, and shares', (
    tester,
  ) async {
    await pumpTable(tester, rows: entries);

    expect(find.text('Model breakdown'), findsOneWidget);
    expect(find.text('MODEL'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('SHARE'), findsOneWidget);
    expect(find.text('glm-5.2'), findsOneWidget);
    expect(find.text('€3.00'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Unknown model'), findsOneWidget);
    expect(find.text('€1.00'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('values format through the selected metric', (tester) async {
    await pumpTable(
      tester,
      rows: [const MapEntry<String?, double>('voxtral-small-24b-2507', 0.25)],
      metric: ConsumptionMetric.energy,
    );

    expect(find.text('voxtral-small-24b-2507'), findsOneWidget);
    expect(find.text('250 Wh'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
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
}
