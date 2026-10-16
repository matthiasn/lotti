import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/relationships/model/person_timeline.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What to know before the next conversation, as one card with one thing
/// that leads (design review 2026-10-16): the note the user left themselves
/// to bring up, set as the card's headline; what to leave alone under it,
/// quiet and marked by its glyph rather than a second label; then the next
/// meeting as a row of its own. It replaced a stack of label-over-line pairs
/// in which every line weighed the same and nothing read first.
///
/// [meeting] is passed on a phone only: on a wide pane the timeline's own
/// *Upcoming* row sits beside the rail and says it already. Renders nothing
/// when there is neither a note nor a meeting.
class PersonBriefCard extends StatelessWidget {
  const PersonBriefCard({
    required this.source,
    required this.meeting,
    required this.now,
    this.onOpenSource,
    this.onOpenMeeting,
    super.key,
  });

  /// The newest check-in that carries notes for next time ([sourceOf]), or
  /// null.
  final CheckInEntry? source;
  final TimelineMeeting? meeting;
  final DateTime now;
  final VoidCallback? onOpenSource;
  final VoidCallback? onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final source = this.source;
    final attention = _nonBlank(source?.data.payAttentionTo);
    final avoid = _nonBlank(source?.data.avoid);
    final hasNotes = source != null && (attention != null || avoid != null);
    final meeting = this.meeting;
    if (!hasNotes && meeting == null) return const SizedBox.shrink();

    final quiet = tokens.colors.text.mediumEmphasis;
    return DesignSystemSectionCard(
      key: const ValueKey('person-brief'),
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasNotes) ...[
            if (attention != null) ...[
              Text(
                messages.relationshipPayAttentionTo,
                style: captionLabelStyle(tokens),
              ),
              SizedBox(height: tokens.spacing.step2),
              // The headline: the one line the card exists for.
              Text(
                attention,
                key: const ValueKey('person-next-time-attention'),
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ],
            if (avoid != null) ...[
              if (attention != null) SizedBox(height: tokens.spacing.step3),
              Semantics(
                label: '${messages.checkInAvoidLabel}: $avoid',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step1),
                      child: Icon(
                        LottiIcons.block,
                        size: IconSizes.s,
                        color: quiet,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Expanded(
                      child: Text(
                        avoid,
                        key: const ValueKey('person-next-time-avoid'),
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: quiet,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: tokens.spacing.step2),
            _Provenance(source: source, onOpen: onOpenSource),
          ],
          if (meeting != null) ...[
            if (hasNotes) ...[
              SizedBox(height: tokens.spacing.step3),
              const DesignSystemDivider(),
              SizedBox(height: tokens.spacing.step3),
            ],
            _MeetingRow(meeting: meeting, now: now, onOpen: onOpenMeeting),
          ],
        ],
      ),
    );
  }

  /// The newest of [checkIns] (newest first) that carries notes for next
  /// time — not simply the newest check-in. The two fields sit under the
  /// composer's *More*, so a ten-second check-in leaves them blank, and blank
  /// there means "I did not get to it", not "forget what I wrote last time".
  static CheckInEntry? sourceOf(List<CheckInEntry> checkIns) {
    for (final checkIn in checkIns) {
      if (hasContent(checkIn)) return checkIn;
    }
    return null;
  }

  /// Whether [checkIn] carries a note to bring up or one to avoid.
  static bool hasContent(CheckInEntry? checkIn) =>
      _nonBlank(checkIn?.data.payAttentionTo) != null ||
      _nonBlank(checkIn?.data.avoid) != null;

  /// The line naming the check-in [source] is from — *From your check-in on
  /// Sat 1 Aug* — set on the notes it describes: undated notes would read as
  /// written after a conversation they predate.
  static Widget provenanceOf(BuildContext context, CheckInEntry source) {
    final tokens = context.designTokens;
    final day = relationshipDayLabelOf(context, source.meta.dateFrom);
    return RelationshipLineWithDate(
      key: const ValueKey('person-next-time-from'),
      text: context.messages.relationshipNextTimeFromEarlier(day),
      date: day,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }

  static String? _nonBlank(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Where the notes came from, as a way into that check-in.
class _Provenance extends StatelessWidget {
  const _Provenance({required this.source, required this.onOpen});

  final CheckInEntry source;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final open = onOpen;
    if (open == null) return PersonBriefCard.provenanceOf(context, source);
    return DesignSystemButton(
      key: const ValueKey('person-next-time-open'),
      label: context.messages.relationshipNextTimeFromEarlier(
        relationshipDayLabelOf(context, source.meta.dateFrom),
      ),
      trailingIcon: LottiIcons.chevronRight,
      variant: DesignSystemButtonVariant.quiet,
      size: DesignSystemButtonSize.dense,
      alignsLabelToLeadingEdge: true,
      onPressed: open,
    );
  }
}

/// The next meeting as a row: the timeline's tile, what it is over when.
class _MeetingRow extends StatelessWidget {
  const _MeetingRow({
    required this.meeting,
    required this.now,
    required this.onOpen,
  });

  final TimelineMeeting meeting;
  final DateTime now;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final title = meeting.event.data.title.trim();
    final when = relationshipTimestampLabelOf(
      context,
      meeting.event.meta.dateFrom,
      now: now,
    );
    final quiet = tokens.colors.text.mediumEmphasis;
    return DsQuietInk(
      key: const ValueKey('person-next-meeting'),
      onTap: onOpen,
      builder: (BuildContext context, bool highlighted) => Semantics(
        button: onOpen != null,
        label:
            '${messages.relationshipNextMeetingLabel}: '
            '${title.isEmpty ? when : '$title, $when'}',
        excludeSemantics: true,
        child: Row(
          children: [
            const DesignSystemTimelineTile(icon: LottiIcons.calendar),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty
                        ? messages.relationshipNextMeetingLabel
                        : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: highlighted
                          ? tokens.colors.interactive.enabled
                          : tokens.colors.text.highEmphasis,
                    ),
                  ),
                  Text(
                    when,
                    key: const ValueKey('person-next-meeting-when'),
                    style: relationshipTimestampStyle(tokens, color: quiet),
                  ),
                ],
              ),
            ),
            if (onOpen != null)
              Icon(LottiIcons.chevronRight, size: IconSizes.s, color: quiet),
          ],
        ),
      ),
    );
  }
}
