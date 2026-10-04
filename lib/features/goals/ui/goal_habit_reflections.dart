import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_habit_watchers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The goals feature's reflection actions for a habit's completion sheet
/// (wired into `habitReflectionsProvider`): one per goal watching [habitId],
/// each opening that goal's reflection for the day [day] answers when pressed.
List<Widget> goalHabitReflections(
  WidgetRef ref,
  BuildContext context, {
  required String habitId,
  required DateTime Function() day,
}) => [
  for (final watcher
      in ref.watch(goalsWatchingHabitProvider(habitId)).value ??
          const <GoalHabitWatcher>[])
    DesignSystemButton(
      key: ValueKey('habit-reflect-${watcher.identity.agentId}'),
      label: context.messages.habitReflectInGoal(watcher.spec.title),
      leadingIcon: LottiIcons.note,
      variant: DesignSystemButtonVariant.tertiary,
      size: DesignSystemButtonSize.dense,
      onPressed: () => _reflect(ref, context, watcher, day()),
    ),
];

/// Opens the day's reflection for one of the goals watching a habit.
///
/// The reflection is the goal's: it needs the goal's spec, its progress view
/// (the sheet lists every dimension's evidence) and its history (so a judged
/// day reopens showing what was recorded). The habit sheet only contributes
/// the day — the one the user picked there, so reflecting on a backfilled day
/// judges that day, not today.
Future<void> _reflect(
  WidgetRef ref,
  BuildContext context,
  GoalHabitWatcher watcher,
  DateTime day,
) async {
  final agentId = watcher.identity.agentId;
  // A projection that reaches back to the picked day: the authored window
  // alone stops short of a backfilled day, and the reflection sheet would
  // then present that day's evidence as absent and invite a verdict on
  // nothing. Never shorter than a week, so a recent day keeps the goal's
  // usual picture around it.
  final progress = await ref.read(
    goalAgentProgressViewForSpanProvider((
      agentId: agentId,
      historyDays: reflectionSpanDays(from: day, today: clock.now()),
    )).future,
  );
  final assessments = await ref.read(
    goalAssessmentHistoryProvider(agentId).future,
  );
  if (!context.mounted || progress == null) return;
  showGoalDayAssessmentSheet(
    context,
    agentId: agentId,
    spec: watcher.spec,
    progress: progress,
    assessments: assessments,
    day: day,
  );
}

/// How many days of history a reflection opened for [from] needs so that
/// the day itself is inside the projection: the days back to today plus the
/// day, never fewer than seven.
int reflectionSpanDays({required DateTime from, required DateTime today}) {
  final back = DateUtils.dateOnly(
    today,
  ).difference(DateUtils.dateOnly(from)).inDays;
  return math.max(7, back + 1);
}
