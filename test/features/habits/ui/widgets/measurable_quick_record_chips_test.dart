import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
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
  final recorded = <MeasurableQuickValue>[];
  var more = 0;

  Future<void> pump(
    WidgetTester tester,
    List<num>? values, {
    MeasurableQuickValue? selected,
    MeasurableDataType? dataType,
  }) {
    recorded.clear();
    more = 0;
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        MeasurableQuickRecordChips(
          dataType: dataType ?? measurableWater,
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
    expect(recorded, [(value: 500, choiceId: null)]);
    await tester.tap(find.text('Other'));
    expect(more, 1);
  });

  testWidgets('no suggestions still offers Other', (tester) async {
    await pump(tester, null);
    await tester.pump();
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('the recorded numeric value reads as selected', (tester) async {
    await pump(tester, [250, 500], selected: (value: 500, choiceId: null));
    await tester.pump();
    DsPill pill(num value) => tester.widget<DsPill>(
      find.byKey(ValueKey('habit-quick-record-${measurableWater.id}-$value')),
    );
    expect(pill(500).selected, isTrue);
    expect(pill(250).selected, isFalse);
  });

  group('choice measurable', () {
    Finder chip(MeasurableChoice choice) => find.byKey(
      ValueKey('habit-quick-record-${measurableHydration.id}-${choice.id}'),
    );

    testWidgets(
      'offers every active choice in order — never a suggestion — plus Other',
      (tester) async {
        // No suggestion override for the hydration id: a choice measurable
        // must not consult the popularity ranking at all.
        await pump(tester, null, dataType: measurableHydration);
        await tester.pump();

        final labels = tester
            .widgetList<DsPill>(find.byType(DsPill))
            .map((pill) => pill.label)
            .toList();
        expect(labels, ['Clear', 'Pale', 'Dark', 'Other']);
        expect(chip(hydrationBrown), findsNothing);
      },
    );

    testWidgets('tapping a choice records one occurrence of it', (
      tester,
    ) async {
      await pump(tester, null, dataType: measurableHydration);
      await tester.pump();
      await tester.tap(chip(hydrationPale));
      expect(recorded, [(value: 1, choiceId: hydrationPale.id)]);
      await tester.tap(find.text('Other'));
      expect(more, 1);
    });

    testWidgets('the recorded choice reads as selected', (tester) async {
      await pump(
        tester,
        null,
        dataType: measurableHydration,
        selected: (value: 1, choiceId: hydrationDark.id),
      );
      await tester.pump();
      expect(tester.widget<DsPill>(chip(hydrationDark)).selected, isTrue);
      expect(tester.widget<DsPill>(chip(hydrationClear)).selected, isFalse);
    });
  });
}
