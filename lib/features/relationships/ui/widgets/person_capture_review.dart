import 'package:clock/clock.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/model/person_capture_flow.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_duration_picker.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_meta_summary_line.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_pickers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/check_in_interaction_icon.dart';
import 'package:material_ui/material_ui.dart';

/// The review of a sorted capture (plan 2026-10-15, *Speak your mind*,
/// step 4): what was heard, in two quiet lines, then one card per proposed
/// item. Every card is accepted until the user sets it aside, and its facts
/// open the same pickers the check-in composer and the meeting sheet use.
/// Nothing is filed until the sheet's Save.
class PersonCaptureReviewView extends StatelessWidget {
  const PersonCaptureReviewView({
    required this.review,
    required this.now,
    required this.onToggle,
    required this.onEdit,
    this.enabled = true,
    this.error,
    super.key,
  });

  final PersonCaptureReview review;
  final DateTime now;
  final ValueChanged<int> onToggle;
  final void Function(int index, PersonCaptureItem item) onEdit;

  /// False while filing: the cards stay readable and take no tap.
  final bool enabled;

  /// Why the last Save did not file everything, or null.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          messages.relationshipCaptureHeard,
          style: captionLabelStyle(tokens),
        ),
        SizedBox(height: tokens.spacing.step2),
        // The words are the evidence, not the subject: quiet, and cut to two
        // lines so the cards lead.
        Text(
          review.transcript,
          key: const ValueKey('person-capture-transcript'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        for (final (index, entry) in review.items.indexed) ...[
          SizedBox(height: tokens.spacing.step4),
          PersonCaptureItemCard(
            key: ValueKey('person-capture-item-$index'),
            item: entry.item,
            accepted: entry.accepted,
            now: now,
            enabled: enabled,
            onToggle: () => onToggle(index),
            onChanged: (item) => onEdit(index, item),
          ),
        ],
        if (error case final error?) ...[
          SizedBox(height: tokens.spacing.step4),
          Text(
            error,
            key: const ValueKey('person-capture-error'),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// One proposed item: what it would be filed as and whether it will be,
/// then its words — the one thing on the card that leads — then the facts
/// it would be filed with, each a tag that opens its picker.
class PersonCaptureItemCard extends StatelessWidget {
  const PersonCaptureItemCard({
    required this.item,
    required this.accepted,
    required this.now,
    required this.onToggle,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final PersonCaptureItem item;
  final bool accepted;
  final DateTime now;
  final VoidCallback onToggle;
  final ValueChanged<PersonCaptureItem> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final (kind, words) = switch (item) {
      PersonCaptureCheckIn(:final summary) => (
        messages.relationshipCaptureCheckIn,
        summary,
      ),
      PersonCaptureNote(:final text) => (
        messages.relationshipCaptureNote,
        text,
      ),
      PersonCaptureMeeting(:final title) => (
        messages.relationshipCaptureMeeting,
        title,
      ),
      PersonCaptureTask(:final title) => (
        messages.relationshipCaptureTask,
        title,
      ),
    };
    final facts = _facts(context);
    final next = switch (item) {
      PersonCaptureCheckIn(:final bringUp, :final avoid) => [
        if (bringUp != null) (messages.checkInPayAttentionLabel, bringUp),
        if (avoid != null) (messages.checkInAvoidLabel, avoid),
      ],
      _ => const <(String, String)>[],
    };
    // Set aside, the card stays — the toggle is how it comes back — but its
    // words step down, so what will be filed reads first.
    final ink = accepted
        ? tokens.colors.text.highEmphasis
        : tokens.colors.text.lowEmphasis;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: tokens.colors.decorative.level01),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(kind, style: captionLabelStyle(tokens))),
                DesignSystemToggle(
                  key: const ValueKey('person-capture-item-toggle'),
                  value: accepted,
                  enabled: enabled,
                  semanticsLabel: kind,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              words,
              key: const ValueKey('person-capture-item-words'),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: ink,
              ),
            ),
            for (final (label, text) in next) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                '$label: $text',
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
            if (facts.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step3),
              Wrap(
                spacing: tokens.spacing.step2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: facts,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _facts(BuildContext context) {
    final messages = context.messages;
    final live = enabled && accepted;
    VoidCallback? tap(Future<void> Function() pick) =>
        live ? () => pick() : null;
    String at(DateTime time) =>
        '${relationshipDayLabelOf(context, time)} · ${relationshipTimeLabel(time)}';
    switch (item) {
      case final PersonCaptureCheckIn checkIn:
        final typeLabel = checkInInteractionLabel(
          context,
          checkIn.interactionType,
        );
        final started = checkIn.startedAt;
        final duration = checkIn.duration ?? Duration.zero;
        return [
          FactTag(
            key: const ValueKey('person-capture-check-in-type'),
            semanticsLabel: messages.checkInTypeChipSemantics(typeLabel),
            icon: checkInInteractionIcon(checkIn.interactionType),
            label: typeLabel,
            emphasised: true,
            onTap: tap(() async {
              final picked = await showCheckInTypePicker(
                context: context,
                current: checkIn.interactionType,
              );
              if (picked != null) {
                onChanged(checkIn.copyWith(interactionType: picked));
              }
            }),
          ),
          FactTag(
            key: const ValueKey('person-capture-check-in-start'),
            semanticsLabel: messages.checkInTimeChipSemantics(
              started == null
                  ? messages.relationshipTimestampToday
                  : at(started),
            ),
            icon: LottiIcons.today,
            label: started == null
                ? messages.relationshipTimestampToday
                : at(started),
            emphasised: true,
            onTap: tap(() async {
              final picked = await pickCheckInStart(
                context: context,
                initial: started ?? now,
              );
              if (picked != null) {
                onChanged(checkIn.copyWith(startedAt: picked));
              }
            }),
          ),
          FactTag(
            key: const ValueKey('person-capture-check-in-duration'),
            semanticsLabel: messages.checkInDurationChipSemantics(
              checkInDurationLabel(context, duration),
            ),
            icon: LottiIcons.timer,
            label: checkInDurationLabel(context, duration),
            emphasised: duration > Duration.zero,
            onTap: tap(() async {
              final picked = await showCheckInDurationPicker(
                context: context,
                initialDuration: duration,
              );
              if (picked != null) onChanged(checkIn.copyWith(duration: picked));
            }),
          ),
        ];
      case final PersonCaptureMeeting meeting:
        final start = meeting.start ?? personMeetingDefaultStart(now);
        final duration = meeting.duration ?? personMeetingDefaultDuration;
        return [
          FactTag(
            key: const ValueKey('person-capture-meeting-start'),
            semanticsLabel: messages.relationshipMeetingStartsSemantics(
              at(start),
            ),
            icon: LottiIcons.calendar,
            label: at(start),
            emphasised: true,
            onTap: tap(() async {
              final picked = await pickMeetingStart(
                context: context,
                initial: start,
              );
              if (picked != null) onChanged(meeting.copyWith(start: picked));
            }),
          ),
          FactTag(
            key: const ValueKey('person-capture-meeting-duration'),
            semanticsLabel: messages.checkInDurationChipSemantics(
              checkInDurationLabel(context, duration),
            ),
            icon: LottiIcons.timer,
            label: checkInDurationLabel(context, duration),
            emphasised: true,
            onTap: tap(() async {
              final picked = await showCheckInDurationPicker(
                context: context,
                initialDuration: duration,
              );
              if (picked != null && picked > Duration.zero) {
                onChanged(meeting.copyWith(duration: picked));
              }
            }),
          ),
        ];
      case final PersonCaptureTask task:
        final due = task.due;
        final label = due == null
            ? messages.relationshipCaptureNoDue
            : messages.relationshipCaptureDue(
                relationshipDayLabelOf(context, due),
              );
        return [
          FactTag(
            key: const ValueKey('person-capture-task-due'),
            semanticsLabel: label,
            icon: LottiIcons.today,
            label: label,
            emphasised: due != null,
            onTap: tap(() async {
              final today = DateTime(
                clock.now().year,
                clock.now().month,
                clock.now().day,
              );
              final result = await showDesignSystemDatePicker(
                context: context,
                title: messages.relationshipCaptureTask,
                initialDate: due ?? today,
                firstDate: today,
                lastDate: DateTime(today.year + 5, today.month, today.day),
                allowClear: true,
              );
              if (result == null) return;
              onChanged(PersonCaptureTask(title: task.title, due: result.date));
            }),
          ),
        ];
      case PersonCaptureNote():
        return const [];
    }
  }
}
