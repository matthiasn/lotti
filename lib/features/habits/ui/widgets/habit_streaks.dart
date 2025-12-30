import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';

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
        // TODO: bring back display of streaks
        // Text(
        //   '${state.shortStreakCount} short streaks of 3+ days',
        //   style: chartTitleStyle,
        // ),
        // Text(
        //   '${state.longStreakCount} long streaks of 7+ days',
        //   style: chartTitleStyle,
        // ),
      ],
    );
  }
}
