import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habit_streaks.dart';

import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  testWidgets('shows completed-today count out of total habits', (
    tester,
  ) async {
    final state = HabitsState.initial().copyWith(
      habitDefinitions: [habitFlossing, habitFlossingDueLater],
      completedToday: {habitFlossing.id},
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const HabitStreaksCounter(),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(state),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('1 out of 2 habits completed today'), findsOneWidget);
  });

  testWidgets('shows zero counts for the initial empty state', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const HabitStreaksCounter(),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => FakeHabitsController(HabitsState.initial()),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('0 out of 0 habits completed today'), findsOneWidget);
  });
}
