import 'dart:core';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';

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

        return StreamBuilder<List<JournalEntity>>(
          stream: _db.watchHabitCompletionsByHabitId(
            habitId: habitDefinition.id,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
          ),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<JournalEntity>> snapshot,
          ) {
            final entities = snapshot.data ?? [];

            final results = habitResultsByDay(
              entities,
              habitDefinition: habitDefinition,
              rangeStart: widget.rangeStart,
              rangeEnd: widget.rangeEnd,
            );

            final days =
                widget.rangeEnd.difference(widget.rangeStart).inDays + 1;

            return DashboardChart(
              topMargin: 10,
              transparent: true,
              chart: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  ...results.map((res) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 15,
                        width: (MediaQuery.of(context).size.width - 200) / days,
                        color: habitCompletionColor(res.completionType),
                      ),
                    );
                  }),
                  const SizedBox(width: 30),
                ],
              ),
              chartHeader: HabitChartInfoWidget(
                habitDefinition,
                dashboardId: widget.dashboardId,
                tab: widget.tab,
              ),
              height: 50,
            );
          },
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

  void onTapAdd() {
    final beamState =
        dashboardsBeamerDelegate.currentBeamLocation.state as BeamState;

    final id =
        beamState.uri.path.contains('carousel') ? 'carousel' : dashboardId;

    beamToNamed('/$tab/$id/complete_habit/${habitDefinition.id}');
  }

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
            width: MediaQuery.of(context).size.width - 20,
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
