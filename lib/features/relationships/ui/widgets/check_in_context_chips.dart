import 'package:clock/clock.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Type · started · duration as one chip row (design 2026-09-13): each chip
/// reads its current value and opens the picker for it. Wraps, so large
/// text and a long locale get a second row rather than a truncated chip.
class CheckInContextChips extends StatelessWidget {
  const CheckInContextChips({
    required this.type,
    required this.startedLabel,
    required this.durationLabel,
    required this.onPickType,
    required this.onPickStart,
    required this.onPickDuration,
    this.sentiment,
    this.onPickSentiment,
    this.enabled = true,
    super.key,
  });

  final CheckInInteractionType type;

  /// `Now · 14:55`, or the day and the time.
  final String startedLabel;

  /// `0:23` / `11 min`, or the *Duration* prompt when there is none yet.
  final String durationLabel;
  final VoidCallback onPickType;
  final VoidCallback onPickStart;
  final VoidCallback onPickDuration;

  /// How it felt, when set. The chip is shown only where [onPickSentiment]
  /// is: the saved check-in's header edits it in place, while the composer
  /// keeps it under *More*.
  final CheckInSentiment? sentiment;
  final VoidCallback? onPickSentiment;

  /// False while the recorder or the transcript owns the field: the chips
  /// stay visible so the context is never lost, and go quiet.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final typeLabel = checkInInteractionLabel(context, type);
    return Wrap(
      key: const ValueKey('check-in-context-chips'),
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        DesignSystemChip(
          key: const ValueKey('check-in-type'),
          label: typeLabel,
          leadingIcon: checkInInteractionIcon(type),
          trailing: const Icon(LottiIcons.chevronDown, size: IconSizes.s),
          // Not `selected`: in the chip grammar that means "chosen among
          // peers", which the sentiment row uses; here every chip holds a
          // value, and the glyph says which.
          size: DesignSystemChipSize.touch,
          semanticsLabel: messages.checkInTypeChipSemantics(typeLabel),
          onPressed: enabled ? onPickType : null,
        ),
        DesignSystemChip(
          key: const ValueKey('check-in-started'),
          label: startedLabel,
          trailing: const Icon(LottiIcons.chevronDown, size: IconSizes.s),
          size: DesignSystemChipSize.touch,
          semanticsLabel: messages.checkInTimeChipSemantics(startedLabel),
          onPressed: enabled ? onPickStart : null,
        ),
        DesignSystemChip(
          key: const ValueKey('check-in-duration'),
          label: durationLabel,
          trailing: const Icon(LottiIcons.chevronDown, size: IconSizes.s),
          size: DesignSystemChipSize.touch,
          semanticsLabel: messages.checkInDurationChipSemantics(durationLabel),
          onPressed: enabled ? onPickDuration : null,
        ),
        if (onPickSentiment case final onPick?)
          DesignSystemChip(
            key: const ValueKey('check-in-sentiment-chip'),
            label: sentiment == null
                ? messages.checkInSentimentLabel
                : checkInSentimentLabel(context, sentiment!),
            trailing: const Icon(LottiIcons.chevronDown, size: IconSizes.s),
            size: DesignSystemChipSize.touch,
            onPressed: enabled ? onPick : null,
          ),
      ],
    );
  }
}

/// The interaction-type picker behind the first chip: every kind as an
/// action row, the current one marked. Resolves to the chosen kind, or
/// null when dismissed.
Future<CheckInInteractionType?> showCheckInTypePicker({
  required BuildContext context,
  required CheckInInteractionType current,
}) => DsActionModal.show<CheckInInteractionType>(
  context: context,
  title: context.messages.checkInInteractionLabel,
  builder: (sheetContext) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final type in CheckInInteractionType.values)
        DsActionRow(
          key: ValueKey('check-in-type-${type.name}'),
          title: checkInInteractionLabel(sheetContext, type),
          icon: checkInInteractionIcon(type),
          onTap: () => Navigator.of(sheetContext).pop(type),
        ),
    ],
  ),
);

/// The sentiment picker behind the header's feeling chip: every feeling as
/// an action row, and *Clear* when one is set — sentiment is optional and
/// the user's own (ADR 0038). Resolves to the choice as a record, so a
/// cleared feeling (`(sentiment: null)`) is told apart from a dismissal
/// (`null`).
Future<({CheckInSentiment? sentiment})?> showCheckInSentimentPicker({
  required BuildContext context,
  required CheckInSentiment? current,
}) => DsActionModal.show<({CheckInSentiment? sentiment})>(
  context: context,
  title: context.messages.checkInSentimentLabel,
  builder: (sheetContext) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final sentiment in CheckInSentiment.values)
        DsActionRow(
          key: ValueKey('check-in-sentiment-option-${sentiment.name}'),
          title: checkInSentimentLabel(sheetContext, sentiment),
          icon: sentiment == current
              ? LottiIcons.radioSelected
              : LottiIcons.radioUnselected,
          onTap: () => Navigator.of(sheetContext).pop((sentiment: sentiment)),
        ),
      if (current != null)
        DsActionRow(
          key: const ValueKey('check-in-sentiment-clear'),
          title: sheetContext.messages.clearButton,
          icon: LottiIcons.close,
          onTap: () => Navigator.of(sheetContext).pop((sentiment: null)),
        ),
    ],
  ),
);

/// `Now · 14:55` while the start is the current minute, else the day and
/// the time — the started chip's label, in the composer and on a saved
/// check-in alike.
String checkInStartedLabelOf(BuildContext context, DateTime at) {
  final now = clock.now();
  final sameMinute =
      at.year == now.year &&
      at.month == now.month &&
      at.day == now.day &&
      at.hour == now.hour &&
      at.minute == now.minute;
  final day = sameMinute
      ? context.messages.journalDateNowButton
      : relationshipDayLabelOf(context, at);
  return '$day · ${relationshipTimeLabelOf(context, at)}';
}

/// *Started*: the day, then the time, as two design-system pickers — a
/// check-in moved to another day keeps its time of day, and one moved to
/// another time keeps its day. Resolves to the new start, or null when the
/// day was dismissed; a dismissed time keeps the picked day.
Future<DateTime?> pickCheckInStart({
  required BuildContext context,
  required DateTime initial,
}) async {
  final messages = context.messages;
  final now = clock.now();
  final today = DateTime(now.year, now.month, now.day);
  final result = await showDesignSystemDatePicker(
    context: context,
    title: messages.checkInStartedLabel,
    initialDate: initial,
    firstDate: DateTime(today.year - 50),
    lastDate: today,
  );
  final picked = result?.date;
  if (!context.mounted || picked == null) return null;
  final day = _notAfterNow(
    DateTime(
      picked.year,
      picked.month,
      picked.day,
      initial.hour,
      initial.minute,
    ),
  );
  final time = await _pickCheckInTime(context, day);
  if (!context.mounted || time == null) return day;
  return _notAfterNow(
    DateTime(day.year, day.month, day.day, time.hour, time.minute),
  );
}

/// A check-in started in the past by definition: the date picker stops at
/// today, and this stops today's time of day at the current minute, so a
/// future start can never become the person's "last contact".
DateTime _notAfterNow(DateTime candidate) {
  final now = clock.now();
  final nowMinute = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  );
  return candidate.isAfter(nowMinute) ? nowMinute : candidate;
}

Future<TimeOfDay?> _pickCheckInTime(BuildContext context, DateTime initial) {
  var chosen = TimeOfDay.fromDateTime(initial);
  return ModalUtils.showSinglePageModal<TimeOfDay>(
    context: context,
    title: context.messages.checkInStartedLabel,
    // A step of air above and below, so the wheel's outer rows are not
    // sliced by the sheet's top bar and its pinned Done.
    builder: (modalContext) => Padding(
      padding: EdgeInsets.symmetric(
        vertical: modalContext.designTokens.spacing.step4,
      ),
      child: DesignSystemTimeWheel(
        key: const ValueKey('check-in-time-picker'),
        initialDateTime: initial,
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(modalContext),
        semanticsLabel: modalContext.messages.checkInStartedLabel,
        onDateTimeChanged: (time) => chosen = TimeOfDay.fromDateTime(time),
      ),
    ),
    stickyActionBarBuilder: (modalContext) => DesignSystemModalActionBar(
      glass: true,
      padding: EdgeInsets.all(modalContext.designTokens.spacing.step5),
      primary: DesignSystemButton(
        key: const ValueKey('check-in-time-done'),
        label: modalContext.messages.doneButton,
        leadingIcon: LottiIcons.confirm,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: () => Navigator.of(modalContext).pop(chosen),
      ),
    ),
  );
}
