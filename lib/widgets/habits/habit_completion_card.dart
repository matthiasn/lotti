import 'dart:core';

import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';

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

  void onTapAdd({String? dateString}) {
    final height = MediaQuery.of(context).size.height;
    final maxHeight = height * 0.9;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (BuildContext context) {
        return HabitDialog(
          habitId: widget.habitDefinition.id,
          dateString: dateString,
        );
      },
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
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 5,
                horizontal: 10,
              ),
              title: Column(
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
                        ),
                      ),
                      Flexible(
                        child: Text(
                          widget.habitDefinition.name,
                          style: completedToday
                              ? chartTitleStyle().copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor:
                                      Theme.of(context).primaryColor,
                                  decorationThickness: 3,
                                )
                              : chartTitleStyle(),
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
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
                          final daysAgo = DateTime.now()
                              .difference(DateTime.parse(res.dayString))
                              .inDays;

                          return Flexible(
                            child: Tooltip(
                              excludeFromSemantics: true,
                              message: chartDateFormatter(res.dayString),
                              child: GestureDetector(
                                onTap: () {
                                  onTapAdd(
                                    dateString:
                                        ymd(DateTime.now()) != res.dayString
                                            ? res.dayString
                                            : ymd(DateTime.now()),
                                  );
                                },
                                child: Semantics(
                                  label:
                                      'Complete ${widget.habitDefinition.name} -$daysAgo',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      widget.showGaps ? 2 : 0,
                                    ),
                                    child: Container(
                                      height: 14,
                                      color: habitCompletionColor(
                                        res.completionType,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              leading: CategoryColorIcon(widget.habitDefinition.categoryId),
              trailing: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onTapAdd,
                icon: Icon(
                  Icons.check_circle_outline,
                  color: primaryColor,
                  size: 30,
                  semanticLabel: 'Complete ${widget.habitDefinition.name}',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
