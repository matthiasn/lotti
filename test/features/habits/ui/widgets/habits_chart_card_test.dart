import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The card overrides the controller and reads only design tokens, l10n and
  // the (overridden) provider state during build. We still register the core
  // services so any incidental getIt lookup resolves instead of throwing.
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  /// Pumps the [HabitsChartCard] backed by a [FakeHabitsController] serving
  /// [state], returning the recording fake so callers can assert on the
  /// mutation methods it captured.
  Future<FakeHabitsController> pump(
    WidgetTester tester,
    HabitsState state,
  ) async {
    final controller = FakeHabitsController(state);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const HabitsChartCard(),
        overrides: [
          habitsControllerProvider.overrideWith(() => controller),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return controller;
  }

  testWidgets('renders the completion-rate title', (tester) async {
    await pump(tester, HabitsState.initial());

    expect(find.text('Completion rate'), findsOneWidget);
  });

  testWidgets(
    'renders the time-span control with 7d / 14d / 30d segments',
    (tester) async {
      await pump(tester, HabitsState.initial());

      expect(find.byType(TimeSpanSegmentedControl), findsOneWidget);
      // Each segment label is rendered twice (a hidden width-reserving ghost
      // plus the visible label), so assert two matches per span.
      expect(find.text('7d'), findsNWidgets(2));
      expect(find.text('14d'), findsNWidgets(2));
      expect(find.text('30d'), findsNWidgets(2));
    },
  );

  testWidgets(
    'tapping the 30d segment calls setTimeSpan(30)',
    (tester) async {
      final controller = await pump(tester, HabitsState.initial());

      expect(controller.setTimeSpanCalled, isFalse);

      // The '30d' label lives inside a single segment InkWell (alongside a
      // hidden width-reserving ghost of the same text); tap that InkWell so
      // the hit lands on the segment's tappable centre.
      final segmentInkWell = find
          .ancestor(
            of: find.text('30d').first,
            matching: find.byType(InkWell),
          )
          .first;
      await tester.tap(segmentInkWell);
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.setTimeSpanCalled, isTrue);
      expect(controller.lastTimeSpan, 30);
    },
  );

  testWidgets(
    'zero-baseline IconButton is absent when minY <= 20',
    (tester) async {
      await pump(
        tester,
        HabitsState.initial().copyWith(minY: 20),
      );

      expect(find.byType(IconButton), findsNothing);
    },
  );

  testWidgets(
    'zero-baseline IconButton is present when minY > 20 and toggles on tap',
    (tester) async {
      final controller = await pump(
        tester,
        HabitsState.initial().copyWith(minY: 21),
      );

      final iconButton = find.byType(IconButton);
      expect(iconButton, findsOneWidget);
      expect(controller.toggleZeroBasedCalls, 0);

      await tester.tap(iconButton);
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.toggleZeroBasedCalls, 1);
    },
  );

  testWidgets('renders the HabitCompletionRateChart', (tester) async {
    await pump(tester, HabitsState.initial());

    expect(find.byType(HabitCompletionRateChart), findsOneWidget);
  });
}
