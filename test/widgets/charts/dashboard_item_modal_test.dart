import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/widgets/charts/dashboard_item_modal.dart';

import '../../widget_test_utils.dart';

void main() {
  const item = DashboardMeasurementItem(
    id: 'measurable-1',
    aggregationType: AggregationType.dailySum,
  );

  Future<void> pumpModal(
    WidgetTester tester, {
    required void Function(DashboardItem item, int index) updateItemFn,
  }) {
    return tester.pumpWidget(
      makeTestableWidget2(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => DashboardItemModal(
                  index: 3,
                  item: item,
                  updateItemFn: updateItemFn,
                  title: 'Water',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  group('DashboardItemModal', () {
    testWidgets('renders title, label, and one chip per aggregation type '
        'with the current type selected', (tester) async {
      await pumpModal(tester, updateItemFn: (_, _) {});
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Aggregation Type:'), findsOneWidget);
      expect(
        find.byType(ChoiceChip),
        findsNWidgets(AggregationType.values.length),
      );

      const localizedLabels = {
        AggregationType.none: 'None',
        AggregationType.dailySum: 'Daily sum',
        AggregationType.dailyMax: 'Daily maximum',
        AggregationType.dailyAvg: 'Daily average',
        AggregationType.hourlySum: 'Hourly sum',
      };
      for (final type in AggregationType.values) {
        final chip = tester.widget<ChoiceChip>(
          find.ancestor(
            of: find.text(localizedLabels[type]!),
            matching: find.byType(ChoiceChip),
          ),
        );
        expect(chip.selected, type == AggregationType.dailySum);
      }
    });

    testWidgets(
      'selecting a chip calls updateItemFn with the new aggregation '
      'type and index, then closes the modal',
      (tester) async {
        final updates = <(DashboardItem, int)>[];
        await pumpModal(
          tester,
          updateItemFn: (item, index) => updates.add((item, index)),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Daily maximum'));
        await tester.pumpAndSettle();

        expect(updates, hasLength(1));
        final (updated, index) = updates.single;
        expect(
          updated,
          item.copyWith(aggregationType: AggregationType.dailyMax),
        );
        expect(index, 3);

        // Navigator.pop closed the sheet.
        expect(find.byType(DashboardItemModal), findsNothing);
      },
    );
  });
}
