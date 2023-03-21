import 'dart:core';

import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

class HabitCompletionCard extends StatefulWidget {
  const HabitCompletionCard({
    required this.habitDefinition,
    required this.rangeStart,
    required this.rangeEnd,
    required this.showGaps,
    super.key,
  });

  final HabitDefinition habitDefinition;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool showGaps;

  @override
  State<HabitCompletionCard> createState() => _HabitCompletionCardState();
}

class _HabitCompletionCardState extends State<HabitCompletionCard> {
  final JournalDb _db = getIt<JournalDb>();

  void onTapAdd() {
    beamToNamed(
      '/habits/complete/${widget.habitDefinition.id}',
      data: ymd(DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JournalEntity>>(
      stream: _db.watchHabitCompletionsByHabitId(
        habitId: widget.habitDefinition.id,
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
          habitDefinition: widget.habitDefinition,
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
        );

        final completedToday = results.isNotEmpty &&
            {HabitCompletionType.success, HabitCompletionType.skip}
                .contains(results.last.completionType);

        final days = widget.rangeEnd.difference(widget.rangeStart).inDays;

        return Opacity(
          opacity: completedToday ? 0.75 : 1,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 5,
                bottom: 10,
                left: 15,
                right: 15,
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          Visibility(
                              visible: widget.habitDefinition.priority ?? false,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: Icon(
                                  Icons.star,
                                  color: styleConfig().starredGold,
                                ),
                              )),
                          Text(
                            widget.habitDefinition.name,
                            style: completedToday
                                ? chartTitleStyle().copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor:
                                        Theme.of(context).primaryColor,
                                    decorationThickness: 3,
                                  )
                                : chartTitleStyle(),
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ...intersperse(
                            widget.showGaps
                                ? SizedBox(
                                    width: days < 20
                                        ? 6
                                        : days < 40
                                            ? 4
                                            : 1,
                                  )
                                : const SizedBox.shrink(),
                            results.map((res) {
                              return Flexible(
                                child: Tooltip(
                                  excludeFromSemantics: true,
                                  message: chartDateFormatter(res.dayString),
                                  child: GestureDetector(
                                    onTap: () {
                                      beamToNamed(
                                        '/habits/complete/${widget.habitDefinition.id}',
                                        data:
                                            ymd(DateTime.now()) != res.dayString
                                                ? res.dayString
                                                : ymd(DateTime.now()),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        widget.showGaps ? 2 : 0,
                                      ),
                                      child: Container(
                                        height: 25,
                                        color: habitCompletionColor(
                                          res.completionType,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 50),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: onTapAdd,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Icon(
                            Icons.check_circle_outline,
                            color: primaryColor,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
