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
    return HabitCompletionCard(
      habitId: widget.habitId,
      rangeStart: widget.rangeStart,
      rangeEnd: widget.rangeEnd,
      // This card is already rendered inside the habit's dashboard, so the
      // completion dialog must not re-embed that same dashboard.
      showLinkedDashboard: false,
    );
  }
}
