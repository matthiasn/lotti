import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habits_summary_line.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 5, 22);
  const todayYmd = '2026-05-22';

  HabitDefinition makeHabit(String id) => HabitDefinition(
    id: id,
    name: id,
    description: '',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: null,
    private: false,
    active: true,
    activeFrom: DateTime(2024),
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  );

  HabitsState makeState({
    int totalHabits = 8,
    int doneToday = 0,
    int failedToday = 0,
    int skippedToday = 0,
  }) {
    final defs = List<HabitDefinition>.generate(
      totalHabits,
      (i) => makeHabit('h-$i'),
    );
    final completedIds = <String>{
      for (var i = 0; i < doneToday; i++) 'h-$i',
    };
    return HabitsState.initial().copyWith(
      habitDefinitions: defs,
      completedToday: completedIds,
      failedByDay: {
        todayYmd: <String>{for (var i = 0; i < failedToday; i++) 'f-$i'},
      },
      skippedByDay: {
        todayYmd: <String>{for (var i = 0; i < skippedToday; i++) 's-$i'},
      },
    );
  }

  Future<void> pumpSummary(WidgetTester tester, HabitsState state) async {
    await tester.pumpWidget(
      makeTestableWidget(
        HabitsSummaryLine(todayOverride: today),
        overrides: [
          habitsControllerProvider.overrideWith(() => _StubController(state)),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'renders only the completion phrase when nothing failed/skipped',
    (
      tester,
    ) async {
      await pumpSummary(tester, makeState());

      expect(find.text('0 of 8 habits completed today'), findsOneWidget);
      expect(find.textContaining('failed'), findsNothing);
      expect(find.textContaining('skipped'), findsNothing);
    },
  );

  testWidgets('renders failed and skipped chunks only when counts > 0', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      makeState(doneToday: 3, failedToday: 2, skippedToday: 1),
    );

    expect(find.text('3 of 8 habits completed today'), findsOneWidget);
    expect(find.text('2 failed'), findsOneWidget);
    expect(find.text('1 skipped'), findsOneWidget);
  });

  testWidgets('hides skipped when only failed > 0', (tester) async {
    await pumpSummary(
      tester,
      makeState(totalHabits: 5, doneToday: 1, failedToday: 1),
    );

    // Note: skipped chunk should NOT appear.

    expect(find.text('1 of 5 habits completed today'), findsOneWidget);
    expect(find.text('1 failed'), findsOneWidget);
    expect(find.textContaining('skipped'), findsNothing);
  });
}

class _StubController extends HabitsController {
  _StubController(this._state);

  final HabitsState _state;

  @override
  HabitsState build() => _state;
}
