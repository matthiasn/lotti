import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class HabitsStreaks extends StatelessWidget {
  const HabitsStreaks({
    required this.header,
    required this.days,
    super.key,
  });

  final String header;
  final int days;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final timeSpanDays = state.timeSpanDays;

        final rangeStart = getStartOfDay(
          DateTime.now().subtract(Duration(days: timeSpanDays - 1)),
        );

        final rangeEnd = getEndOfToday();
        final showGaps = timeSpanDays < 180;

        final streakItems = state.habitDefinitions.map((habitDefinition) {
          return HabitChartLine(
            habitDefinition: habitDefinition,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            streakDuration: days,
            showGaps: showGaps,
          );
        });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                header,
                style: chartTitleStyle(),
              ),
            ),
            const SizedBox(height: 15),
            ...streakItems,
          ],
        );
      },
    );
  }
}

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
