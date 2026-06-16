import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habits_summary_card.dart';

import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

/// Builds a [HabitsState] from the dimensions the card actually reads.
///
/// The card derives `total` from `habitDefinitions.length` and `done` from
/// `completedToday.length`, so a `completedCount` of completed ids and a
/// `definitionCount` of definitions is all that matters here — the concrete
/// habit identities are irrelevant to the rendered KPIs.
HabitsState _state({
  int definitionCount = 0,
  int completedCount = 0,
  int shortStreakCount = 0,
  int longStreakCount = 0,
}) {
  final definitions = List.generate(
    definitionCount,
    (i) => habitFlossing.copyWith(id: 'def-$i'),
  );
  final completed = {for (var i = 0; i < completedCount; i++) 'done-$i'};

  return HabitsState.initial().copyWith(
    habitDefinitions: definitions,
    completedToday: completed,
    shortStreakCount: shortStreakCount,
    longStreakCount: longStreakCount,
  );
}

Future<void> _pump(WidgetTester tester, HabitsState state) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      const HabitsSummaryCard(),
      overrides: [
        habitsControllerProvider.overrideWith(
          () => FakeHabitsController(state),
        ),
      ],
    ),
  );
  await tester.pump();
}

void main() {
  group('HabitsSummaryCard', () {
    testWidgets('renders the completed-today count as the headline number', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(definitionCount: 3, completedCount: 2),
      );

      // The big accent number is the size of completedToday, not the total.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('shows "{n} to go" while habits remain, n = total - done', (
      tester,
    ) async {
      // 3 definitions, 1 done -> remaining 2.
      await _pump(
        tester,
        _state(definitionCount: 3, completedCount: 1),
      );

      expect(find.text('2 to go'), findsOneWidget);
      expect(find.text('All done today'), findsNothing);
    });

    testWidgets('shows "All done today" once done == total (total > 0)', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(definitionCount: 3, completedCount: 3),
      );

      expect(find.text('All done today'), findsOneWidget);
      // No "to go" caption should leak through.
      expect(find.textContaining('to go'), findsNothing);
    });

    group('streak badge', () {
      // Each case asserts exactly which streak label the badge resolves to,
      // covering the long > short > nudge precedence in one place.
      final cases =
          <
            ({
              String name,
              int shortStreakCount,
              int longStreakCount,
              String expected,
              String absent,
            })
          >[
            (
              name: 'long streak takes precedence and reads the 7-day label',
              shortStreakCount: 4,
              longStreakCount: 2,
              expected: '2 on a 7-day streak',
              absent: '4 on a 3-day streak',
            ),
            (
              name: 'falls back to the 3-day label when only short > 0',
              shortStreakCount: 5,
              longStreakCount: 0,
              expected: '5 on a 3-day streak',
              absent: 'Start a streak today',
            ),
            (
              name: 'nudges to start a streak when both counts are zero',
              shortStreakCount: 0,
              longStreakCount: 0,
              expected: 'Start a streak today',
              absent: 'on a',
            ),
          ];

      for (final c in cases) {
        testWidgets(c.name, (tester) async {
          await _pump(
            tester,
            _state(
              definitionCount: 2,
              completedCount: 1,
              shortStreakCount: c.shortStreakCount,
              longStreakCount: c.longStreakCount,
            ),
          );

          expect(find.text(c.expected), findsOneWidget);
          expect(find.textContaining(c.absent), findsNothing);
        });
      }
    });

    group('progress bar', () {
      testWidgets('widthFactor equals done / total', (tester) async {
        // 1 of 4 done -> 0.25.
        await _pump(
          tester,
          _state(definitionCount: 4, completedCount: 1),
        );

        final box = tester.widget<FractionallySizedBox>(
          find.byType(FractionallySizedBox),
        );
        expect(box.widthFactor, 0.25);
      });

      testWidgets('clamps to 1.0 when fully complete', (tester) async {
        await _pump(
          tester,
          _state(definitionCount: 2, completedCount: 2),
        );

        final box = tester.widget<FractionallySizedBox>(
          find.byType(FractionallySizedBox),
        );
        expect(box.widthFactor, 1.0);
      });

      testWidgets('widthFactor is 0 with no habits and does not crash', (
        tester,
      ) async {
        await _pump(tester, _state());

        final box = tester.widget<FractionallySizedBox>(
          find.byType(FractionallySizedBox),
        );
        expect(box.widthFactor, 0.0);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
