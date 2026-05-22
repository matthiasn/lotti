import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_day_strip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

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
  void _openDialog({String? dateString}) {
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );
    if (habitDefinition == null) {
      return;
    }

    final height = MediaQuery.of(context).size.height;
    final maxHeight = height * 0.8;

    ModalUtils.showBottomSheet<void>(
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

  Future<void> _logCompletion(HabitCompletionType type) async {
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );
    if (habitDefinition == null) {
      return;
    }

    final now = DateTime.now();
    await getIt<PersistenceLogic>().createHabitCompletionEntry(
      data: HabitCompletionData(
        habitId: habitDefinition.id,
        dateFrom: now,
        dateTo: now,
        completionType: type,
      ),
      habitDefinition: habitDefinition,
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

    final completedToday =
        results.isNotEmpty &&
        {
          HabitCompletionType.success,
          HabitCompletionType.skip,
        }.contains(results.last.completionType);

    final tokens = context.designTokens;

    final categoryName = getIt<EntitiesCacheService>()
        .getCategoryById(habitDefinition.categoryId)
        ?.name;

    final streak = _trailingSuccessStreak(results);
    final lastWeek = _lastWeekSuccessCount(results);

    return Opacity(
      opacity: completedToday ? 0.75 : 1,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
        child: Material(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.l),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openDialog,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CategoryIconCompact(
                        habitDefinition.categoryId,
                        size: CategoryIconConstants.iconSizeMedium,
                      ),
                      SizedBox(width: tokens.spacing.cardItemSpacing),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (habitDefinition.priority ?? false) ...[
                                  Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: tokens.colors.text.highEmphasis,
                                    semanticLabel: 'starred',
                                  ),
                                  SizedBox(width: tokens.spacing.step1),
                                ],
                                Flexible(
                                  child: Text(
                                    habitDefinition.name,
                                    style: tokens
                                        .typography
                                        .styles
                                        .subtitle
                                        .subtitle1
                                        .copyWith(
                                          color:
                                              tokens.colors.text.highEmphasis,
                                          decoration: completedToday
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          decorationThickness: 2,
                                          decorationColor:
                                              tokens.colors.text.lowEmphasis,
                                        ),
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: tokens.spacing.step1),
                            _HabitMeta(
                              categoryName: categoryName,
                              streak: streak,
                              lastWeek: lastWeek,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      _QuickActions(
                        onFail: () => _logCompletion(HabitCompletionType.fail),
                        onSkip: () => _logCompletion(HabitCompletionType.skip),
                        onSuccess: () =>
                            _logCompletion(HabitCompletionType.success),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.cardItemSpacing),
                  HabitDayStrip(
                    results: results,
                    showGaps: widget.showGaps,
                    showLabels: true,
                    semanticPrefix: habitDefinition.name,
                    onTapDay: (dayString) {
                      _openDialog(
                        dateString: DateTime.now().ymd != dayString
                            ? dayString
                            : DateTime.now().ymd,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int _trailingSuccessStreak(List<HabitResult> results) {
  var count = 0;
  for (var i = results.length - 1; i >= 0; i--) {
    if (results[i].completionType == HabitCompletionType.success) {
      count++;
    } else {
      break;
    }
  }
  return count;
}

int _lastWeekSuccessCount(List<HabitResult> results) {
  final tail = results.length <= 7
      ? results
      : results.sublist(results.length - 7);
  return tail
      .where((r) => r.completionType == HabitCompletionType.success)
      .length;
}

class _HabitMeta extends StatelessWidget {
  const _HabitMeta({
    required this.categoryName,
    required this.streak,
    required this.lastWeek,
  });

  final String? categoryName;
  final int streak;
  final int lastWeek;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dotStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final categoryStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.interactive.enabled,
      fontWeight: FontWeight.w500,
    );
    final streakStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.alert.warning.defaultColor,
      fontWeight: FontWeight.w500,
    );
    final neutralStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    final parts = <Widget>[];
    if (categoryName != null && categoryName!.isNotEmpty) {
      parts.add(Text(categoryName!, style: categoryStyle));
    }
    if (streak > 0) {
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: tokens.colors.alert.warning.defaultColor,
            ),
            SizedBox(width: tokens.spacing.step1),
            Text(
              context.messages.habitsCardStreakDays(streak),
              style: streakStyle,
            ),
          ],
        ),
      );
    }
    parts.add(
      Text(context.messages.habitsCardLastWeek(lastWeek), style: neutralStyle),
    );

    final separated = intersperse(
      Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step1),
        child: Text('·', style: dotStyle),
      ),
      parts,
    ).toList();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: separated,
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onFail,
    required this.onSkip,
    required this.onSuccess,
  });

  final VoidCallback onFail;
  final VoidCallback onSkip;
  final VoidCallback onSuccess;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuickActionButton(
          icon: Icons.close_rounded,
          color: tokens.colors.alert.error.defaultColor,
          filled: false,
          semanticLabel: context.messages.completeHabitFailButton,
          onPressed: onFail,
        ),
        SizedBox(width: tokens.spacing.step1),
        _QuickActionButton(
          icon: Icons.keyboard_double_arrow_right_rounded,
          color: tokens.colors.alert.warning.defaultColor,
          filled: false,
          semanticLabel: context.messages.completeHabitSkipButton,
          onPressed: onSkip,
        ),
        SizedBox(width: tokens.spacing.step1),
        _QuickActionButton(
          icon: Icons.check_rounded,
          color: tokens.colors.interactive.enabled,
          filled: true,
          semanticLabel: context.messages.completeHabitSuccessButton,
          onPressed: onSuccess,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.filled,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final bool filled;
  final String semanticLabel;
  final VoidCallback onPressed;

  static const double _hitSize = 36;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final onColor = filled ? tokens.colors.text.onInteractiveAlert : color;

    return SizedBox(
      width: _hitSize,
      height: _hitSize,
      child: Material(
        color: filled ? color : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.s),
          side: filled ? BorderSide.none : BorderSide(color: color, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: onColor,
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      ),
    );
  }
}
