import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habits_state.dart';

// ---------------------------------------------------------------------------
// Helpers shared by the Glados property groups below.
// ---------------------------------------------------------------------------

/// Creates a minimal HabitDefinition active from [activeFrom]
/// (null exercises the `?? DateTime(0)` fallback in [activeBy]).
HabitDefinition hMakeHabitForActiveBy(String id, DateTime? activeFrom) {
  final created = activeFrom ?? DateTime(2019);
  return HabitDefinition(
    id: id,
    name: 'Habit $id',
    description: '',
    createdAt: created,
    updatedAt: created,
    vectorClock: null,
    private: false,
    active: true,
    activeFrom: activeFrom,
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  );
}

/// Builds a [HabitsState] with [n] habits whose activeFrom precedes
/// '2025-01-01' and whose selectedInfoYmd is '2025-01-01'.
HabitsState hStateWithHabits(
  int n, {
  Map<String, Set<String>> byDay = const {},
  Map<String, Set<String>> successfulByDay = const {},
}) {
  final activeDate = DateTime(2019);
  final definitions = <HabitDefinition>[
    for (var i = 0; i < n; i++) hMakeHabitForActiveBy('h$i', activeDate),
  ];
  return HabitsState.initial().copyWith(
    habitDefinitions: definitions,
    selectedInfoYmd: '2025-01-01',
    allByDay: byDay,
    successfulByDay: successfulByDay,
  );
}
