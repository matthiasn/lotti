import 'dart:core';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';

class DashboardHabitsChart extends StatefulWidget {
  const DashboardHabitsChart({
    super.key,
    required this.habitId,
    required this.dashboardId,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final String habitId;
  final String? dashboardId;
  final DateTime rangeStart;
  final DateTime rangeEnd;

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

        return StreamBuilder<List<JournalEntity?>>(
          stream: _db.watchMeasurementsByType(
            type: habitDefinition.id,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
          ),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<JournalEntity?>> measurementsSnapshot,
          ) {
            return DashboardChart(
              topMargin: 10,
              chart: Container(
                color: Colors.white,
                height: 80,
                width: MediaQuery.of(context).size.width - 20,
              ),
              chartHeader: HabitChartInfoWidget(
                habitDefinition,
                dashboardId: widget.dashboardId,
              ),
              height: 136,
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
    super.key,
  });

  final HabitDefinition habitDefinition;
  final String? dashboardId;

  void onTapAdd() {
    final beamState =
        dashboardsBeamerDelegate.currentBeamLocation.state as BeamState;

    final id =
        beamState.uri.path.contains('carousel') ? 'carousel' : dashboardId;

    beamToNamed('/dashboards/$id/complete_habit/${habitDefinition.id}');
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
                  hoverColor: Colors.transparent,
                  icon: SvgPicture.asset(styleConfig().addIcon),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
