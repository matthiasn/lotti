import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_habit_completion_service.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The banner CTA's capture surface: one row per loggable dimension of the
/// goal, so "Log today" performs the verb it names instead of navigating.
///
/// Habit dimensions get a one-tap Mark done through the shared
/// [GoalHabitCompletionService] path (privacy, sync and reminders included);
/// data dimensions are listed read-only with their update source, so the
/// sheet never pretends a health import can be typed in here.
class GoalLogTodaySheet extends ConsumerStatefulWidget {
  const GoalLogTodaySheet({
    required this.agentId,
    required this.progress,
    super.key,
  });

  final String agentId;
  final GoalProgressView progress;

  @override
  ConsumerState<GoalLogTodaySheet> createState() => _GoalLogTodaySheetState();
}

class _GoalLogTodaySheetState extends ConsumerState<GoalLogTodaySheet> {
  final Set<String> _saving = {};
  final Set<String> _recorded = {};
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    // The sheet is a snapshot of ONE day. When the local day rolls over,
    // its rows, date label and recorded set all describe yesterday — close
    // it rather than let a stale surface offer misleading state (the detail
    // page behind it refreshes at the same boundary).
    final now = clock.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  bool _doneToday(GoalHabitProgressView habit) {
    final today = widget.progress.today;
    if (_recorded.contains(habit.habitId)) return true;
    return habit.days.any(
      (entry) => entry.day == today && entry.hasValue,
    );
  }

  Future<void> _markDone(GoalHabitProgressView habit) async {
    setState(() => _saving.add(habit.habitId));
    var saved = false;
    try {
      // The day is derived at SUBMISSION time: a sheet opened before local
      // midnight must not silently write yesterday's date after it.
      saved = await ref
          .read(goalHabitCompletionServiceProvider)
          .record(
            agentId: widget.agentId,
            habitId: habit.habitId,
            day: GoalWindow.dayUtc(clock.now()),
            outcome: HabitCompletionType.success,
          );
    } on Object {
      saved = false;
    } finally {
      if (mounted) setState(() => _saving.remove(habit.habitId));
    }
    if (!mounted) return;
    if (saved) {
      setState(() => _recorded.add(habit.habitId));
      ref
        ..invalidate(goalAgentProgressViewProvider(widget.agentId))
        ..invalidate(goalAgentProgressViewForSpanProvider);
    } else {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.messages.saveFailedRetry)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = DateFormat.MMMMEEEEd(
      locale,
    ).format(widget.progress.today);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.goalLogTodayTitle,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step1),
            Text(
              dateLabel,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            for (final habit in widget.progress.habits) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      habit.name,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  if (_doneToday(habit))
                    Semantics(
                      label: context.messages.completeHabitSuccessButton,
                      child: Icon(
                        LottiIcons.confirmCircled,
                        key: ValueKey('goal-log-today-done-${habit.habitId}'),
                        size: IconSizes.s,
                        color: tokens.colors.alert.success.defaultColor,
                      ),
                    )
                  else
                    DesignSystemButton(
                      key: ValueKey('goal-log-today-mark-${habit.habitId}'),
                      label: context.messages.goalHabitCheckOffAction,
                      onPressed: _saving.contains(habit.habitId)
                          ? null
                          : () => _markDone(habit),
                      variant: DesignSystemButtonVariant.secondary,
                      size: DesignSystemButtonSize.dense,
                      leadingIcon: LottiIcons.confirm,
                    ),
                ],
              ),
              SizedBox(height: tokens.spacing.step3),
            ],
            for (final metric in widget.progress.metrics) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric.name,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Text(
                    context.messages.goalLogTodayLinkedHint,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.step3),
            ],
          ],
        ),
      ),
    );
  }
}
