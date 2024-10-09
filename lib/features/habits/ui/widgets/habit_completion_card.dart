import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';

class HabitCompletionCard extends ConsumerStatefulWidget {
  const HabitCompletionCard({
    required this.habitId,
    required this.rangeStart,
    required this.rangeEnd,
    this.showGaps = true,
    super.key,
  });

  final String habitId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool showGaps;

  @override
  ConsumerState<HabitCompletionCard> createState() =>
      _HabitCompletionCardState();
}

class _HabitCompletionCardState extends ConsumerState<HabitCompletionCard> {
  void onTapAdd({String? dateString}) {
    final height = MediaQuery.of(context).size.height;
    final maxHeight = height * 0.8;
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );

    if (habitDefinition == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: maxHeight),
      backgroundColor: habitDefinition.dashboardId != null
          ? Theme.of(context).bottomSheetTheme.backgroundColor
          : Colors.transparent,
      builder: (BuildContext context) {
        return HabitDialog(
          habitId: habitDefinition.id,
          themeData: Theme.of(context),
          dateString: dateString,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );

    if (habitDefinition == null) {
      return const SizedBox.shrink();
    }

    final results = ref
        .watch(
          habitCompletionControllerProvider(
            habitId: habitDefinition.id,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
          ),
        )
        .value;

    if (results == null) {
      return const SizedBox.shrink();
    }

    final completedToday = results.isNotEmpty &&
        {HabitCompletionType.success, HabitCompletionType.skip}
            .contains(results.last.completionType);

    final days = widget.rangeEnd.difference(widget.rangeStart).inDays;

    return Opacity(
      opacity: completedToday ? 0.75 : 1,
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.only(
            left: 10,
            right: 10,
          ),
          title: Column(
            children: [
              Row(
                children: [
                  Visibility(
                    visible: habitDefinition.priority ?? false,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(
                        Icons.star,
                        color: starredGold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      habitDefinition.name,
                      style: completedToday
                          ? habitTitleStyle.copyWith(
                              decoration: TextDecoration.lineThrough,
                              decorationColor:
                                  context.textTheme.titleLarge?.color,
                              decorationThickness: 2,
                            )
                          : habitTitleStyle,
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
                                dateString: DateTime.now().ymd != res.dayString
                                    ? res.dayString
                                    : DateTime.now().ymd,
                              );
                            },
                            child: Semantics(
                              label:
                                  'Complete ${habitDefinition.name} -$daysAgo',
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
          leading: CategoryColorIcon(habitDefinition.categoryId),
          trailing: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onTapAdd,
            icon: Icon(
              Icons.check_circle_outline,
              color: oldPrimaryColor,
              size: 30,
              semanticLabel: 'Complete ${habitDefinition.name}',
            ),
          ),
        ),
      ),
    );
  }
}
