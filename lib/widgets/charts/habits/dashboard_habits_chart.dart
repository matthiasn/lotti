import 'dart:core';

import 'package:flutter/material.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';

class DashboardHabitsChart extends StatefulWidget {
  const DashboardHabitsChart({
    required this.habitId,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final String habitId;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<DashboardHabitsChart> createState() => _DashboardHabitsChartState();
}

class _DashboardHabitsChartState extends State<DashboardHabitsChart> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: HabitCompletionCard(
        habitId: widget.habitId,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      ),
    );
  }
}
