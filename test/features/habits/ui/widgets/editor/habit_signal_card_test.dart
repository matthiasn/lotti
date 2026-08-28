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
          signals: [
            waterAny.copyWith(mode: HabitSignalMode.atLeast, threshold: 1000),
          ],
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
    await tester.tap(find.text('Distance').first);
    await tester.pump();
    final distance = changes.last.signals.single;
    expect(distance.mode, HabitSignalMode.atLeast);
    expect(distance.workoutValueType, WorkoutValueType.distance);

    await pump(
      tester,
      HabitSignalsForm(signals: [distance.copyWith(threshold: 5)]),
    );
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

  group('threshold and mode stay together', () {
    testWidgets('switching to any clears the field; back keeps what it shows', (
      tester,
    ) async {
      final bounded = waterAny.copyWith(
        mode: HabitSignalMode.atLeast,
        threshold: 1000,
      );
      await pump(tester, HabitSignalsForm(signals: [bounded]));
      final field = find.byKey(
        const ValueKey('habit-signal-threshold-measurable-water'),
      );
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('Enter a value for this rule'), findsNothing);

      await tester.tap(find.text('Any entry').first);
      await tester.pump();
      expect(changes.last.signals.single, waterAny);
      // The card is rebuilt by its parent with the new form in the app;
      // here the field is gone with the bounded mode either way.
      // The parent rebuilds the card with the new form in the app; the
      // field's own text is cleared regardless, so a later bounded mode
      // cannot pick up a stale number.
      final input = tester.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      );
      expect(input.controller!.text, isEmpty);
    });

    testWidgets('a bounded mode adopts the number already in the field', (
      tester,
    ) async {
      final bounded = waterAny.copyWith(
        mode: HabitSignalMode.atLeast,
        threshold: 1000,
      );
      await pump(tester, HabitSignalsForm(signals: [bounded]));
      await tester.tap(find.text('Total ≤').first);
      await tester.pump();
      final switched = changes.last.signals.single;
      expect(switched.mode, HabitSignalMode.atMost);
      expect(switched.threshold, 1000);
    });

    testWidgets('a bounded mode without a value says so', (tester) async {
      await pump(
        tester,
        HabitSignalsForm(
          signals: [waterAny.copyWith(mode: HabitSignalMode.atLeast)],
        ),
      );
      expect(find.text('Enter a value for this rule'), findsOneWidget);
    });

    testWidgets('a workout back to any drops its dimension too', (
      tester,
    ) async {
      final distance = run.copyWith(
        mode: HabitSignalMode.atLeast,
        threshold: 5,
        workoutValueType: WorkoutValueType.distance,
      );
      await pump(tester, HabitSignalsForm(signals: [distance]));
      await tester.tap(find.text('Any workout').first);
      await tester.pump();
      expect(changes.last.signals.single, run);
    });
  });

  testWidgets('a threshold handed in by the parent replaces stale text', (
    tester,
  ) async {
    final bounded = waterAny.copyWith(
      mode: HabitSignalMode.atLeast,
      threshold: 1000,
    );
    await pump(tester, HabitSignalsForm(signals: [bounded]));
    expect(find.text('1000'), findsOneWidget);
    // Same row identity, new threshold from above (e.g. an example pill).
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitSignalCard(
          form: HabitSignalsForm(signals: [bounded.copyWith(threshold: 250)]),
          measurablesById: {'water': water},
          onChanged: changes.add,
          onAddSignal: () {},
          onChangeComposite: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('250'), findsOneWidget);
    expect(find.text('1000'), findsNothing);
  });

  group('workout direction', () {
    testWidgets('a persisted maximum shows "at most", never a ≥ segment', (
      tester,
    ) async {
      final atMost = run.copyWith(
        mode: HabitSignalMode.atMost,
        threshold: 5,
        workoutValueType: WorkoutValueType.distance,
      );
      await pump(tester, HabitSignalsForm(signals: [atMost]));
      expect(find.text('at most'), findsWidgets);
      expect(find.textContaining('≥'), findsNothing);
      // Switching the dimension keeps the direction.
      await tester.tap(find.text('Duration').first);
      await tester.pump();
      final switched = changes.last.signals.single;
      expect(switched.mode, HabitSignalMode.atMost);
      expect(switched.workoutValueType, WorkoutValueType.duration);
      // The direction control flips it explicitly.
      await tester.tap(find.text('at least').first);
      await tester.pump();
      expect(changes.last.signals.single.mode, HabitSignalMode.atLeast);
    });
  });

  testWidgets('removing a signal clamps an at-least count to what is left', (
    tester,
  ) async {
    await pump(
      tester,
      const HabitSignalsForm(
        signals: [waterAny, steps, run],
        composite: HabitCompositeRule.atLeast,
        requiredCount: 3,
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('habit-signal-check-workout-running')),
    );
    await tester.pump();
    expect(changes.last.signals, [waterAny, steps]);
    expect(changes.last.requiredCount, 2);
  });
}
