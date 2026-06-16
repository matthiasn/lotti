import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';

/// One-line summary of today's progress: "N out of M habits completed today".
///
/// `M` is the total number of active habit definitions and `N` is the size of
/// `state.completedToday` (habits with any completion entry dated today).
class HabitStreaksCounter extends ConsumerWidget {
  const HabitStreaksCounter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsControllerProvider);
    final total = state.habitDefinitions.length;
    final todayCount = state.completedToday.length;

    return Column(
      children: [
        InfoLabel('$todayCount out of $total habits completed today'),
      ],
    );
  }
}
