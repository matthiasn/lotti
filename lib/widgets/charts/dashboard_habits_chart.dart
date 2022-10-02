import 'dart:core';

import 'package:beamer/beamer.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

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
          stream: _db.watchHabitCompletionsByHabitId(
            habitId: habitDefinition.id,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
          ),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<JournalEntity?>> snapshot,
          ) {
            final entities = snapshot.data ?? [];

            final results = habitResultsByDay(
              entities,
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
                        color: colorFromCssHex(res.hexColor),
                      ),
                    );
                  }),
                  const SizedBox(width: 30),
                ],
              ),
              chartHeader: HabitChartInfoWidget(
                habitDefinition,
                dashboardId: widget.dashboardId,
              ),
              height: 50,
            );
          },
        );
      },
    );
  }
}

class HabitResult extends Equatable {
  const HabitResult(this.dayString, this.hexColor);

  final String dayString;
  final String hexColor;

  @override
  String toString() {
    return '$dayString $hexColor}';
  }

  @override
  List<Object?> get props => [dayString, hexColor];
}

List<HabitResult> habitResultsByDay(
  List<JournalEntity?> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final resultsByDay = <String, String>{};
  final range = rangeEnd.difference(rangeStart);
  final dayStrings = List<String>.generate(range.inDays, (days) {
    final day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  for (final dayString in dayStrings) {
    resultsByDay[dayString] = colorToCssHex(alarm);
  }

  for (final entity in entities) {
    final dayString = ymd(entity!.meta.dateFrom);
    resultsByDay[dayString] = colorToCssHex(primaryColor);
  }

  final aggregated = <HabitResult>[];
  for (final dayString in resultsByDay.keys.sorted()) {
    aggregated.add(HabitResult(dayString, resultsByDay[dayString]!));
  }

  return aggregated;
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
