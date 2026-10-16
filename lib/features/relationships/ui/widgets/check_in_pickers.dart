import 'package:clock/clock.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/check_in_interaction_icon.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// The interaction-type picker behind the *How* row and the page's type tag:
/// every kind as an
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

/// The sentiment picker behind the *How it felt* row and the page's feeling
/// tag: every feeling as
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
        // The radio glyph says which is chosen to the eye; the selected
        // flag says it to a screen reader.
        MergeSemantics(
          child: Semantics(
            selected: sentiment == current,
            inMutuallyExclusiveGroup: true,
            child: DsActionRow(
              key: ValueKey('check-in-sentiment-option-${sentiment.name}'),
              title: checkInSentimentLabel(sheetContext, sentiment),
              icon: sentiment == current
                  ? LottiIcons.radioSelected
                  : LottiIcons.radioUnselected,
              onTap: () =>
                  Navigator.of(sheetContext).pop((sentiment: sentiment)),
            ),
          ),
        ),
      if (current != null)
        DsActionRow(
          key: const ValueKey('check-in-sentiment-clear'),
          title: sheetContext.messages.clearButton,
          icon: LottiIcons.close,
          onTap: () => Navigator.of(sheetContext).pop((sentiment: null)),
        ),
      // Said where the feeling is chosen, not as a row's value: optional,
      // and the user's alone (ADR 0038).
      Padding(
        key: const ValueKey('check-in-sentiment-note'),
        padding: EdgeInsets.symmetric(
          horizontal: sheetContext.designTokens.spacing.step4,
          vertical: sheetContext.designTokens.spacing.step3,
        ),
        child: Text(
          sheetContext.messages.checkInSentimentOptional,
          style: sheetContext.designTokens.typography.styles.others.caption
              .copyWith(
                color: sheetContext.designTokens.colors.text.mediumEmphasis,
              ),
        ),
      ),
    ],
  ),
);

/// `Now · 14:55` while the start is the current minute, else the day and
/// the time — the *Started* row's value, in the form and on a saved check-in
/// alike.
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
  return '$day · ${relationshipTimeLabel(at)}';
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
  final time = await _pickTime(
    context,
    day,
    title: messages.checkInStartedLabel,
    key: const ValueKey('check-in-time-picker'),
  );
  if (!context.mounted || time == null) return day;
  return _notAfterNow(
    DateTime(day.year, day.month, day.day, time.hour, time.minute),
  );
}

/// When a meeting starts: the day, then the time, as [pickCheckInStart]
/// asks them — but looking ahead, from today on, since a meeting is planned
/// rather than logged. Resolves to the new start, or null when the day was
/// dismissed; a dismissed time keeps the picked day.
Future<DateTime?> pickMeetingStart({
  required BuildContext context,
  required DateTime initial,
}) async {
  final messages = context.messages;
  final now = clock.now();
  final today = DateTime(now.year, now.month, now.day);
  final result = await showDesignSystemDatePicker(
    context: context,
    title: messages.relationshipMeetingStartsLabel,
    initialDate: initial,
    firstDate: today,
    lastDate: DateTime(today.year + 5, today.month, today.day),
  );
  final picked = result?.date;
  if (!context.mounted || picked == null) return null;
  final day = DateTime(
    picked.year,
    picked.month,
    picked.day,
    initial.hour,
    initial.minute,
  );
  final time = await _pickTime(
    context,
    day,
    title: messages.relationshipMeetingStartsLabel,
    key: const ValueKey('meeting-time-picker'),
  );
  if (!context.mounted || time == null) return day;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
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

Future<TimeOfDay?> _pickTime(
  BuildContext context,
  DateTime initial, {
  required String title,
  required Key key,
}) {
  var chosen = TimeOfDay.fromDateTime(initial);
  return ModalUtils.showSinglePageModal<TimeOfDay>(
    context: context,
    title: title,
    // A step of air above and below, so the wheel's outer rows are not
    // sliced by the sheet's top bar and its pinned Done.
    builder: (modalContext) => Padding(
      padding: EdgeInsets.symmetric(
        vertical: modalContext.designTokens.spacing.step4,
      ),
      child: DesignSystemTimeWheel(
        key: key,
        initialDateTime: initial,
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(modalContext),
        semanticsLabel: title,
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
