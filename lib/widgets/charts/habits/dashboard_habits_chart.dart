import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/habits/habit_completion_card.dart';

class DashboardHabitsChart extends StatefulWidget {
  const DashboardHabitsChart({
    required this.habitId,
    required this.dashboardId,
    required this.rangeStart,
    required this.rangeEnd,
    this.tab = 'dashboard',
    super.key,
  });

  final String habitId;
  final String? dashboardId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String tab;

  @override
  State<DashboardHabitsChart> createState() => _DashboardHabitsChartState();
}

class _DashboardHabitsChartState extends State<DashboardHabitsChart> {
  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HabitDefinition?>(
      stream: _db.watchHabitById(widget.habitId),
      builder: (
        BuildContext context,
        AsyncSnapshot<HabitDefinition?> typeSnapshot,
      ) {
        final habitDefinition = typeSnapshot.data;

        if (habitDefinition == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: HabitCompletionCard(
            habitDefinition: habitDefinition,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
          ),
        );
      },
    );
  }
}

class HabitChartInfoWidget extends StatelessWidget {
  const HabitChartInfoWidget(
    this.habitDefinition, {
    required this.dashboardId,
    required this.tab,
    super.key,
  });

  final HabitDefinition habitDefinition;
  final String? dashboardId;
  final String tab;

  void onTapAdd() {}

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HabitDefinition?>(
      stream: getIt<JournalDb>().watchHabitById(habitDefinition.id),
      builder: (
        BuildContext context,
        AsyncSnapshot<HabitDefinition?> typeSnapshot,
      ) {
        final habitDefinition = typeSnapshot.data;

        if (habitDefinition == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 0,
          left: 10,
          child: SizedBox(
            width: max(MediaQuery.of(context).size.width, 300) - 20,
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width / 2,
                  ),
                  child: Text(
                    habitDefinition.name,
                    style: chartTitleStyle(),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                const Spacer(),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  onPressed: onTapAdd,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
