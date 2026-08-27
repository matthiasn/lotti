import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_card.dart';

import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  final water = measurableWater.copyWith(
    id: 'water',
    displayName: 'Water',
    unitName: 'ml',
  );
  const waterAny = HabitSignalForm(
    kind: HabitSignalKind.measurable,
    id: 'water',
  );
  const steps = HabitSignalForm(
    kind: HabitSignalKind.health,
    id: 'cumulative_step_count',
    mode: HabitSignalMode.atLeast,
    threshold: 6000,
  );
  const run = HabitSignalForm(kind: HabitSignalKind.workout, id: 'running');

  final changes = <HabitSignalsForm>[];
  var adds = 0;
  var composites = 0;

  Future<void> pump(WidgetTester tester, HabitSignalsForm form) async {
    changes.clear();
    adds = 0;
    composites = 0;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitSignalCard(
          form: form,
          measurablesById: {'water': water},
          onChanged: changes.add,
          onAddSignal: () => adds++,
          onChangeComposite: () => composites++,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the manual row is fixed and the add row opens the picker', (
    tester,
  ) async {
    await pump(tester, const HabitSignalsForm());
    expect(find.text("I'll tick it myself"), findsOneWidget);
    expect(
      find.byKey(const ValueKey('habit-signal-composite-row')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('habit-signal-add-row')));
    expect(adds, 1);
  });

  testWidgets(
    'a measurable row offers any / total ≥ / total ≤ and a threshold',
    (
      tester,
    ) async {
      await pump(tester, const HabitSignalsForm(signals: [waterAny]));
      expect(find.text('Water'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('habit-signal-threshold-measurable-water')),
        findsNothing,
      );

      await tester.tap(find.text('Total ≥').first);
      await tester.pump();
      expect(changes.last.signals.single.mode, HabitSignalMode.atLeast);

      await pump(
        tester,
        HabitSignalsForm(
          signals: [waterAny.copyWith(mode: HabitSignalMode.atLeast)],
        ),
      );
      final field = find.byKey(
        const ValueKey('habit-signal-threshold-measurable-water'),
      );
      expect(field, findsOneWidget);
      expect(find.text('ml'), findsOneWidget);
      await tester.enterText(field, '1,5');
      await tester.pump();
      expect(changes.last.signals.single.threshold, 1.5);
      await tester.enterText(field, '');
      await tester.pump();
      expect(changes.last.signals.single.threshold, isNull);

      await tester.tap(find.text('Any entry').first);
      await tester.pump();
      expect(changes.last.signals.single, waterAny);
    },
  );

  testWidgets('a health row uses reading / daily wording', (tester) async {
    await pump(tester, const HabitSignalsForm(signals: [steps]));
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Daily ≥'), findsWidgets);
    expect(find.text('Any reading'), findsWidgets);
    await tester.tap(find.text('Daily ≤').first);
    await tester.pump();
    expect(changes.last.signals.single.mode, HabitSignalMode.atMost);
  });

  testWidgets('a workout row picks a dimension, or any session', (
    tester,
  ) async {
    await pump(tester, const HabitSignalsForm(signals: [run]));
    await tester.tap(find.text('Distance ≥').first);
    await tester.pump();
    final distance = changes.last.signals.single;
    expect(distance.mode, HabitSignalMode.atLeast);
    expect(distance.workoutValueType, WorkoutValueType.distance);

    await pump(tester, HabitSignalsForm(signals: [distance]));
    expect(find.text('km'), findsOneWidget);
    await tester.tap(find.text('Any workout').first);
    await tester.pump();
    expect(changes.last.signals.single, run);
  });

  testWidgets('unchecking removes the row; two rows show the composite', (
    tester,
  ) async {
    await pump(
      tester,
      const HabitSignalsForm(
        signals: [waterAny, steps],
        composite: HabitCompositeRule.atLeast,
        requiredCount: 2,
      ),
    );
    expect(find.text('At least 2 of 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('habit-signal-composite-row')));
    expect(composites, 1);

    await tester.tap(
      find.byKey(const ValueKey('habit-signal-check-measurable-water')),
    );
    await tester.pump();
    expect(changes.last.signals, [steps]);
  });
}
