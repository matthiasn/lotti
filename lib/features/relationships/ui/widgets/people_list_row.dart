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
/// avatar, the name with a sparkle for an important person, one mono status
/// line (`Call · Today 12:44 · Weekly`), and the truthful cadence pill.
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
            children: [
              PersonaAvatar(
                initial: personaInitial(data.title),
                id: relationship.id,
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.body.bodyLarge
                                .copyWith(
                                  fontWeight: tokens.typography.weight.semiBold,
                                  color: tokens.colors.text.highEmphasis,
                                ),
                          ),
                        ),
                        if (data.important) ...[
                          SizedBox(width: tokens.spacing.step2),
                          Icon(
                            LottiIcons.aiSpark,
                            key: const ValueKey('people-row-important'),
                            size: tokens.spacing.step3,
                            color: tokens.colors.interactive.enabled,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      peopleStatusLineOf(context, item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: relationshipTimestampStyle(
                        tokens,
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              PeopleCadencePillWidget(pill: peopleCadencePillOf(item)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The row's status line: the last contact (`Call · Today 12:44`) or `Just
/// added`, then the cadence, then — for a person not yet contacted — when the
/// first check-in falls due.
String peopleStatusLineOf(BuildContext context, RelationshipListItem item) {
  final messages = context.messages;
  final cadence = relationshipCadenceLabel(
    context,
    item.relationship.data.checkInCadenceDays,
  );
  final last = item.lastCheckIn;
  if (last != null) {
    return [
      checkInInteractionLabel(context, last.data.interactionType),
      relationshipTimestampLabelOf(context, last.meta.dateFrom),
      cadence,
    ].join(' · ');
  }
  final firstDue = peopleDueDateOf(item);
  return [
    messages.relationshipJustAdded,
    cadence,
    if (firstDue != null)
      messages.relationshipFirstDue(relationshipDayLabelOf(context, firstDue)),
  ].join(' · ');
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
        // identity rides the tint (the health chip's rule).
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
