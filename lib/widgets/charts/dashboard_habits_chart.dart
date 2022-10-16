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
    this.tab = 'dashboard',
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
  List<JournalEntity> entities, {
  required HabitDefinition habitDefinition,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final resultsByDay = <String, String>{};
  final range = rangeEnd.difference(rangeStart);
  final dayStrings = List<String>.generate(range.inDays + 1, (days) {
    final day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  final activeFrom = habitDefinition.activeFrom ?? DateTime(0);
  final activeUntil = habitDefinition.activeUntil ?? DateTime(9999);

  final successColor = colorToCssHex(primaryColor);
  final failColor = colorToCssHex(alarm);
  final skipColor = colorToCssHex(
    styleConfig().secondaryTextColor.withOpacity(0.4),
  );

  for (final dayString in dayStrings) {
    final day = DateTime.parse(dayString);
    final hexColor = (day.isAfter(activeFrom) || day == activeFrom) &&
            day.isBefore(activeUntil)
        ? failColor
        : skipColor;

    resultsByDay[dayString] = hexColor;
  }

  for (final entity in entities.sortedBy((entity) => entity.meta.dateFrom)) {
    final dayString = ymd(entity.meta.dateFrom);
    final hexColor = entity.maybeMap(
      habitCompletion: (completion) {
        final completionType = completion.data.completionType;
        final hexColor = completionType == HabitCompletionType.fail
            ? failColor
            : completionType == HabitCompletionType.skip
                ? skipColor
                : successColor;
        if (completionType != null) {
          debugPrint('completion $dayString $completionType $hexColor');
        }

        return hexColor;
      },
      orElse: () => skipColor,
    );

    resultsByDay[dayString] = hexColor;
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

class HabitChartLine extends StatefulWidget {
  const HabitChartLine({
    super.key,
    required this.habitId,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final String habitId;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<HabitChartLine> createState() => _HabitChartLineState();
}

class _HabitChartLineState extends State<HabitChartLine> {
  final JournalDb _db = getIt<JournalDb>();

  void onTapAdd() {
    beamToNamed('/habits/complete/${widget.habitId}');
  }

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

            final days = widget.rangeEnd.difference(widget.rangeStart).inDays;

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 70),
                      ...results.map((res) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Container(
                            height: 25,
                            width: (MediaQuery.of(context).size.width - 300) /
                                days,
                            color: colorFromCssHex(res.hexColor),
                          ),
                        );
                      }),
                      const SizedBox(width: 30),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        height: 25,
                        padding: const EdgeInsets.only(
                          top: 1,
                          right: 10,
                          bottom: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              styleConfig().negspace.withOpacity(0.8),
                              styleConfig().negspace.withOpacity(0.4),
                              Colors.transparent,
                            ],
                            stops: const [0, 0.8, 1],
                          ),
                        ),
                        child: Text(
                          habitDefinition.name,
                          style: chartTitleStyle()
                              .copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onTapAdd,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: SvgPicture.asset(styleConfig().addIcon),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
