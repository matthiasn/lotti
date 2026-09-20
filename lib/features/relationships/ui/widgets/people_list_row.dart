import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// One person on the People list (design 2026-09-06 §2): the persona
/// avatar, the name with a sparkle for an important person, one status line
/// (`Call · Today 12:44 · Weekly`) whose timestamp alone wears the mono
/// voice, and the truthful cadence pill — shown only when it says something
/// the band heading has not ([peopleCadencePillRestatesBand]).
///
/// The row is top-aligned and its status line is capped at one line, so the
/// pill sits on the name's own line box and rows stack at a steady rhythm
/// instead of each one finding its own height.
///
/// On desktop the row of the person whose page fills the detail pane wears
/// the selected wash; on phones nothing is ever selected.
class PeopleListRow extends StatelessWidget {
  const PeopleListRow({
    required this.item,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final RelationshipListItem item;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final relationship = item.relationship;
    final data = relationship.data;
    final pill = peopleCadencePillOf(item);

    return Material(
      color: selected
          ? tokens.colors.surface.selected
          : tokens.colors.background.level01,
      borderRadius: BorderRadius.circular(tokens.radii.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            // The pill labels the name, so it rides the name's line box
            // rather than floating against the centre of a two-line row.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonaAvatar(
                initial: personaInitial(data.title),
                id: relationship.id,
                imageId: data.avatarImageId,
                crop: data.avatarCrop,
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The sparkle rides *inside* the name, as the last
                    // thing on its last line. Beside it in a Row it was
                    // pushed to the far right of a full-width column, so a
                    // wrapped name left it stranded in the gap between the
                    // name and the pill, marking neither.
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: data.title),
                          if (data.important)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              // The only thing that marks an enrolled
                              // person on this row, so it carries the word
                              // too: colour alone says nothing to a screen
                              // reader, and the import page already labels
                              // the same concept.
                              child: Padding(
                                padding: EdgeInsetsDirectional.only(
                                  start: tokens.spacing.step2,
                                ),
                                child: Semantics(
                                  label: context
                                      .messages
                                      .relationshipImportantLabel,
                                  child: Icon(
                                    LottiIcons.aiSpark,
                                    key: const ValueKey('people-row-important'),
                                    size: IconSizes.xs,
                                    color: tokens.colors.interactive.enabled,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // The name is the row. It wraps rather than
                      // truncating, because `Commander Pip Fr…` is the one
                      // string on this row the reader cannot reconstruct
                      // from anything else on it.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.body.bodyLarge.copyWith(
                        fontWeight: tokens.typography.weight.semiBold,
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    _StatusLine(item: item),
                  ],
                ),
              ),
              if (!peopleCadencePillRestatesBand(pill.kind)) ...[
                SizedBox(width: tokens.spacing.step3),
                PeopleCadencePillWidget(pill: pill),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The row's status line and the date inside it: the last contact
/// (`Call · Today 12:44 · Weekly`) or `Just added · Monthly · first due
/// Sun 16 Aug`. Each line is one catalog message, so a locale can reorder
/// its parts — which is why the date is handed back as the substring to
/// find rather than as a position.
typedef PeopleStatusLine = ({String text, String? date});

/// [PeopleStatusLine] for one row.
///
/// The cadence named is the one the runtime applies: an enrolled person
/// without a stored cadence reads as the production default, not as "no
/// cadence"; a person who is not enrolled reads their stored setting and is
/// never given a first-due day, because the runtime schedules none for them.
PeopleStatusLine peopleStatusPartsOf(
  BuildContext context,
  RelationshipListItem item,
) {
  final messages = context.messages;
  final relationship = item.relationship;
  final cadence = relationshipCadenceLabel(
    context,
    effectiveCadenceDaysOf(relationship) ??
        relationship.data.checkInCadenceDays,
  );
  final last = item.lastCheckIn;
  if (last != null) {
    final at = relationshipTimestampLabelOf(context, last.meta.dateFrom);
    return (
      text: messages.relationshipStatusLineContacted(
        checkInInteractionLabel(context, last.data.interactionType),
        at,
        cadence,
      ),
      date: at,
    );
  }
  final firstDue = peopleDueDateOf(item);
  if (firstDue == null) {
    return (text: messages.relationshipStatusLineAdded(cadence), date: null);
  }
  final day = relationshipDayLabelOf(context, firstDue);
  return (
    text: messages.relationshipStatusLineAddedFirstDue(cadence, day),
    date: day,
  );
}

/// The row's status line as one plain string — what a screen reader and the
/// tests read.
String peopleStatusLineOf(BuildContext context, RelationshipListItem item) =>
    peopleStatusPartsOf(context, item).text;

/// The status line with the mono voice confined to the date.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.item});

  final RelationshipListItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final parts = peopleStatusPartsOf(context, item);
    return RelationshipLineWithDate(
      key: const ValueKey('people-row-status'),
      text: parts.text,
      date: parts.date,
      maxLines: 1,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}

/// The truthful cadence pill: warning-tinted `{n} days over` when the cadence
/// lapsed, and a quiet read-out otherwise (`Due Thu`, `On track`,
/// `Not enrolled`, `Dormant`, `Archived`).
class PeopleCadencePillWidget extends StatelessWidget {
  const PeopleCadencePillWidget({required this.pill, super.key});

  final PeopleCadencePill pill;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final label = switch (pill.kind) {
      PeopleCadencePillKind.overdue when pill.daysOver == 0 =>
        messages.relationshipDueToday,
      PeopleCadencePillKind.overdue => messages.relationshipDaysOver(
        pill.daysOver,
      ),
      PeopleCadencePillKind.dueSoon => messages.relationshipDueDay(
        relationshipWeekdayLabelOf(context, pill.dueAt!),
      ),
      PeopleCadencePillKind.onTrack => messages.relationshipCadenceOnTrack,
      PeopleCadencePillKind.notEnrolled => messages.relationshipNotEnrolled,
      PeopleCadencePillKind.dormant => messages.relationshipStatusDormant,
      PeopleCadencePillKind.archived => messages.relationshipStatusArchived,
    };
    if (pill.kind == PeopleCadencePillKind.overdue) {
      return DsPill(
        key: const ValueKey('people-row-pill-overdue'),
        variant: DsPillVariant.tinted,
        shape: DsPillShape.tag,
        color: tokens.colors.alert.warning.defaultColor,
        // The warning hue as ink on its own wash fails contrast; the colour
        // identity rides the tint (the health chip's rule). On the dark
        // ground that tint alone reads as an inert brown next to the
        // neutral chip, so the glyph carries the urgency at glance
        // distance — the same one the briefing card's out-of-date line
        // uses, so "needs attention" is drawn one way across the feature.
        leading: Icon(
          LottiIcons.warning,
          size: IconSizes.xs,
          color: tokens.colors.alert.warning.ink,
        ),
        labelColor: tokens.colors.text.highEmphasis,
        label: label,
      );
    }
    // A quiet read-out on the solid surface fill, never the dashed `muted`
    // shell — that one says "unset", and a cadence that is on track is set.
    return DsPill(
      variant: DsPillVariant.filled,
      shape: DsPillShape.tag,
      labelColor: tokens.colors.text.mediumEmphasis,
      label: label,
    );
  }
}
