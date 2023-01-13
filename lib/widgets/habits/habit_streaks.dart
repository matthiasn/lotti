import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';

class HabitStreaksCounter extends StatelessWidget {
  const HabitStreaksCounter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final total = state.habitDefinitions.length;
        final todayCount = state.completedToday.length;

        return Column(
          children: [
            Text(
              '$total habits total',
              style: chartTitleStyle(),
            ),
            Text(
              '$todayCount completed today',
              style: chartTitleStyle(),
            ),
            Text(
              '${state.shortStreakCount} short streaks of 3+ days',
              style: chartTitleStyle(),
            ),
            Text(
              '${state.longStreakCount} long streaks of 7+ days',
              style: chartTitleStyle(),
            ),
          ],
        );
      },
    );
  }
}
