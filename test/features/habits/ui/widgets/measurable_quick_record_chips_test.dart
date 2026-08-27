import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/habits/ui/widgets/measurable_quick_record_chips.dart';

import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

class _FixedSuggestions extends MeasurableSuggestionsController {
  _FixedSuggestions(this.values) : super(measurableWater.id);
  final List<num>? values;
  @override
  Future<List<num>?> build() async => values;
}

void main() {
  final recorded = <num>[];
  var more = 0;

  Future<void> pump(WidgetTester tester, List<num>? values, {num? selected}) {
    recorded.clear();
    more = 0;
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        MeasurableQuickRecordChips(
          dataType: measurableWater,
          recordedValue: selected,
          onRecord: recorded.add,
          onMore: () => more++,
        ),
        overrides: [
          measurableSuggestionsControllerProvider(
            measurableWater.id,
          ).overrideWith(() => _FixedSuggestions(values)),
        ],
      ),
    );
  }

  testWidgets('shows at most three popular values plus Other', (tester) async {
    await pump(tester, [250, 500, 750, 1000, 1250]);
    await tester.pump();
    for (final value in [250, 500, 750]) {
      expect(
        find.byKey(ValueKey('habit-quick-record-${measurableWater.id}-$value')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(ValueKey('habit-quick-record-${measurableWater.id}-1000')),
      findsNothing,
    );
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('tapping a chip records its value; Other opens the dialog', (
    tester,
  ) async {
    await pump(tester, [250, 500]);
    await tester.pump();
    await tester.tap(find.text('500 ${measurableWater.unitName}'));
    expect(recorded, [500]);
    await tester.tap(find.text('Other'));
    expect(more, 1);
  });

  testWidgets('no suggestions still offers Other', (tester) async {
    await pump(tester, null);
    await tester.pump();
    expect(find.text('Other'), findsOneWidget);
  });
}
