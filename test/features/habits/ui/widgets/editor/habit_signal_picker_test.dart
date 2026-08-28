import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_picker.dart';

import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  final water = measurableWater.copyWith(
    id: 'water',
    displayName: 'Water',
    unitName: 'ml',
  );
  final toggles = <(HabitSignalKind, String, bool)>[];

  Future<void> pump(
    WidgetTester tester, {
    Set<(HabitSignalKind, String)> selected = const {},
  }) async {
    toggles.clear();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitSignalPicker(
          measurables: [water],
          workoutTypes: const ['running', 'swimming'],
          selected: selected,
          onToggle: (kind, id, {required selected}) =>
              toggles.add((kind, id, selected)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists measurables, health data and workouts in sections', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Measurables'), findsOneWidget);
    expect(find.text('Health data'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Steps'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Steps'), findsOneWidget);
    // The list is lazy; the workouts section sits below the health types.
    await tester.scrollUntilVisible(
      find.text('running'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Workouts'), findsOneWidget);
    expect(find.text('running'), findsOneWidget);
  });

  testWidgets('toggling reports selection both ways and mirrors locally', (
    tester,
  ) async {
    await pump(tester, selected: {(HabitSignalKind.workout, 'running')});
    await tester.tap(find.text('Water'));
    await tester.pump();
    expect(toggles.last, (HabitSignalKind.measurable, 'water', true));
    // The list is lazy; the workouts section sits below the health types.
    await tester.scrollUntilVisible(
      find.text('running'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('running'));
    await tester.pump();
    expect(toggles.last, (HabitSignalKind.workout, 'running', false));
  });

  testWidgets('search narrows every section; nothing matching says so', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('habit-signal-picker-search')),
      'swim',
    );
    await tester.pump();
    expect(find.text('swimming'), findsOneWidget);
    expect(find.text('Water'), findsNothing);
    expect(find.text('Measurables'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('habit-signal-picker-search')),
      'zzz',
    );
    await tester.pump();
    expect(find.text('Nothing matches'), findsOneWidget);
  });

  testWidgets('dashboard-only health keys are not offered', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('habit-signal-picker-search')),
      'blood',
    );
    await tester.pump();
    // The two real series, not the combined-chart key.
    expect(find.text('Systolic blood pressure'), findsOneWidget);
    expect(find.text('Diastolic blood pressure'), findsOneWidget);
    expect(find.text('Blood Pressure'), findsNothing);
    expect(
      find.byKey(
        const ValueKey('habit-signal-option-health-BLOOD_PRESSURE'),
      ),
      findsNothing,
    );
  });
}
