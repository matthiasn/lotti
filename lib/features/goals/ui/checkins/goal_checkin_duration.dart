import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/duration_quick_pick_chips.dart';
import 'package:lotti/features/design_system/components/time_pickers/duration_picker_modal.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:material_ui/material_ui.dart';

/// The lengths a goal check-in is usually corrected to. Check-ins are short —
/// a few minutes of reflection — so the row stops where a long conversation
/// would begin; the wheel below it reaches anything else.
const kGoalCheckInQuickPicks = <Duration>[
  Duration(minutes: 1),
  Duration(minutes: 3),
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
];

/// How a check-in's time reads: `3 min`, `< 1 min` for a few seconds, and
/// null for none at all, so the caller decides what "nothing yet" looks like.
String? goalCheckInDurationLabel(BuildContext context, Duration duration) {
  if (duration <= Duration.zero) return null;
  final minutes = duration.inMinutes;
  if (minutes == 0) return context.messages.goalCheckInUnderAMinute;
  return context.messages.goalCheckInMinutes(minutes);
}

/// Opens the duration picker on a check-in's time. Resolves to the chosen
/// length, or null when the user backed out without changing it.
Future<Duration?> showGoalCheckInDurationPicker({
  required BuildContext context,
  required Duration initialDuration,
}) async {
  final messages = context.messages;
  String labelOf(Duration duration) =>
      goalCheckInDurationLabel(context, duration) ??
      messages.goalCheckInAddTime;
  Duration? chosen;
  await showDurationPicker(
    context: context,
    title: messages.goalCheckInTimeSpentTitle,
    initialDuration: initialDuration,
    quickPicks: (context, current, onQuickPick) => DurationQuickPickChips(
      suggestions: kGoalCheckInQuickPicks,
      placeholder: kGoalCheckInQuickPicks,
      current: current,
      onPick: onQuickPick,
      hint: messages.goalCheckInTimeQuickPickHint,
      labelOf: labelOf,
      semanticsLabelOf: messages.goalCheckInTimeSemanticsLabel,
      keyPrefix: 'goal-checkin-time-pick',
    ),
    semanticsLabelOf: (duration) =>
        messages.goalCheckInTimeSemanticsLabel(labelOf(duration)),
    onDurationChanged: (duration) async => chosen = duration,
  );
  return chosen;
}

/// Stores a corrected time on a check-in entry. Returns whether it landed.
typedef GoalCheckInTimeWriter =
    Future<bool> Function(JournalEntity entity, Duration timeSpent);

/// The real writer: the check-in keeps its start and ends [timeSpent] later,
/// so the beat stays where it is on the rail and only its length changes.
Future<bool> writeGoalCheckInTime(
  JournalRepository repository,
  JournalEntity entity,
  Duration timeSpent,
) => repository.updateJournalEntityDate(
  entity.meta.id,
  dateFrom: entity.meta.dateFrom,
  dateTo: entity.meta.dateFrom.add(timeSpent),
);

/// The check-in beat's trailing chip: the time the check-in counts for, and
/// the one place to correct it. A check-in with no time yet offers to add
/// some instead of claiming "0 min".
class GoalCheckInTimeChip extends ConsumerWidget {
  const GoalCheckInTimeChip({
    required this.checkIn,
    this.writeTime,
    this.pickDuration = showGoalCheckInDurationPicker,
    super.key,
  });

  final GoalCheckIn checkIn;

  /// Seams for the picker and the write, defaulted to the real ones.
  final GoalCheckInTimeWriter? writeTime;
  final Future<Duration?> Function({
    required BuildContext context,
    required Duration initialDuration,
  })
  pickDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spent = checkIn.timeSpent;
    final label =
        goalCheckInDurationLabel(context, spent) ??
        context.messages.goalCheckInAddTime;
    // Caption-tier: the chip is metadata on the beat's header row, so it
    // reads as an action through its glyph and ink, never by out-weighing
    // the time and kind beside it.
    return DesignSystemButton(
      key: ValueKey('goal-checkin-time-${checkIn.id}'),
      label: label,
      leadingIcon: LottiIcons.timer,
      variant: DesignSystemButtonVariant.tertiary,
      size: DesignSystemButtonSize.dense,
      tabularFigures: true,
      semanticsLabel: context.messages.goalCheckInTimeSemanticsLabel(label),
      onPressed: () async {
        final chosen = await pickDuration(
          context: context,
          initialDuration: spent,
        );
        if (chosen == null || chosen == spent) return;
        final writer =
            writeTime ??
            (entity, timeSpent) => writeGoalCheckInTime(
              ref.read(journalRepositoryProvider),
              entity,
              timeSpent,
            );
        await writer(checkIn.entity, chosen);
      },
    );
  }
}
