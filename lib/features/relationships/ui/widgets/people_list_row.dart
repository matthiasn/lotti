import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// One person on the People list, in the task row's anatomy (DESIGN.md,
/// *People Row*): the persona avatar, then two tiers so one thing leads —
/// the name in Subtitle 1, alone on its line, and one caption line under it.
///
/// The caption line opens with the person's state when the band heading has
/// not already said it ([peopleCadencePillRestatesBand]): *5 days overdue*
/// behind the warning glyph in the warning ink, or a quiet *Due Wed*,
/// *Dormant*, *Archived*. The status line follows
/// (`Call · Today 12:44 · Weekly`). The state used to be a tag on the name's
/// line, where it took the name's width and outweighed the person it
/// belonged to; as a glyph and a word it reads the way a task row's status
/// and due date do.
///
/// The row is a [GroupedCardRowSurface]: one button to assistive tech,
/// `selected` while the person's page fills the desktop detail pane, and the
/// shared hover and focus fill. Its label is one sentence — name, state,
/// status line — rather than three fragments read one by one.
class PeopleListRow extends StatelessWidget {
  const PeopleListRow({
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    super.key,
  });

  final RelationshipListItem item;
  final VoidCallback onTap;

  /// A long press speaks a check-in for the person straight from the list.
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final relationship = item.relationship;
    final data = relationship.data;
    final pill = peopleCadencePillOf(item);
    final state = peopleCadencePillRestatesBand(pill.kind)
        ? null
        : peopleCadencePillLabel(context, pill);
    final status = peopleStatusPartsOf(context, item);
    final overdue = pill.kind == PeopleCadencePillKind.overdue;
    // At large text the status line takes a second line rather than
    // ending in an ellipsis (DESIGN.md: re-flow, never clip).
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) >= TextScales.large;

    final row = GroupedCardRowSurface(
      rowKey: ValueKey('people-row-surface-${relationship.id}'),
      selected: selected,
      hoverColor: tokens.colors.surface.hover,
      selectedColor: tokens.colors.surface.selected,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step4,
      ),
      onTap: onTap,
      child: Semantics(
        label: [data.title, ?state, status.text].join(', '),
        excludeSemantics: true,
        child: Row(
          // The avatar is centred on the text block — the Check-ins rows'
          // rule.
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
                  Text(
                    data.title,
                    key: const ValueKey('people-row-name'),
                    // The name is the row. It wraps rather than truncating,
                    // because `Commander Pip Fr…` is the one string on this
                    // row the reader cannot reconstruct from anything else.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  // step2: the design system's gap between a row's title
                  // and its caption (design_system_list_item.dart).
                  SizedBox(height: tokens.spacing.step2),
                  // A Wrap, like the task row's meta line: when the state
                  // and the status line do not share one line — a narrow
                  // pane, German, large text — the status line takes the
                  // next one whole instead of being cut to an ellipsis.
                  Wrap(
                    spacing: tokens.spacing.step4,
                    runSpacing: tokens.spacing.step2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (state != null)
                        _StateSegment(label: state, overdue: overdue),
                      RelationshipLineWithDate(
                        key: const ValueKey('people-row-status'),
                        text: status.text,
                        date: status.date,
                        maxLines: largeText ? 2 : 1,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final pressable = onLongPress == null
        ? row
        : GestureDetector(onLongPress: onLongPress, child: row);
    // One node: the surface's button and selected flags, the tap, the long
    // press and the sentence above.
    final merged = MergeSemantics(child: pressable);

    // In the desktop split the expand command opens the person and moves
    // focus into their page, as it does on a task or project row.
    final detailFocus = ListDetailFocusTraversal.maybeOf(context);
    if (detailFocus == null) return merged;
    return AppCommandScope(
      handlers: {
        AppCommandId.expand: AppCommandHandler(
          invoke: (_) {
            onTap();
            detailFocus.focusDetails();
          },
        ),
      },
      child: merged,
    );
  }
}

/// The row's state at the head of its caption line. Overdue wears the
/// warning glyph and the warning ink — the timeline's overdue task line and
/// the person page's pill use the same — and every other state is a quiet
/// word in the line's medium ink.
class _StateSegment extends StatelessWidget {
  const _StateSegment({required this.label, required this.overdue});

  final String label;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ink = overdue
        ? tokens.colors.alert.warning.ink
        : tokens.colors.text.mediumEmphasis;
    return Row(
      key: ValueKey(overdue ? 'people-row-overdue' : 'people-row-state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (overdue) ...[
          Icon(LottiIcons.warning, size: IconSizes.xs, color: ink),
          SizedBox(width: tokens.spacing.step2),
        ],
        // Flexible: a long label (German, large text, a narrow pane) wraps in
        // the room left beside the glyph instead of running past the row.
        Flexible(
          child: Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: ink,
              fontWeight: overdue ? tokens.typography.weight.semiBold : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// The status line and the date inside it: the last contact
/// (`Call · Today 12:44 · Weekly`) or `Just added · Monthly · first due
/// Sun 16 Aug`. Each line is one catalog message, so a locale can reorder
/// its parts — which is why the date is handed back as the substring to
/// find rather than as a position.
typedef PeopleStatusLine = ({String text, String? date});

/// [PeopleStatusLine] for one row.
///
/// The cadence named is the one the runtime applies: an enrolled person
/// without a stored cadence reads as the production default. A person who
/// is not enrolled reads their stored setting — a dormant person's rhythm is
/// still theirs — and is never given a first-due day, because the runtime
/// schedules none for them. With no cadence at all the line simply leaves
/// it out: the band the row sits in already says "No reminders", and "No
/// cadence" under it was a second, stranger word for the same fact.
PeopleStatusLine peopleStatusPartsOf(
  BuildContext context,
  RelationshipListItem item,
) {
  final messages = context.messages;
  final relationship = item.relationship;
  final cadenceDays =
      effectiveCadenceDaysOf(relationship) ??
      relationship.data.checkInCadenceDays;
  final cadence = cadenceDays == null
      ? null
      : relationshipCadenceLabel(context, cadenceDays);
  final last = item.lastCheckIn;
  if (last != null) {
    final at = relationshipTimestampLabelOf(context, last.meta.dateFrom);
    final type = checkInInteractionLabel(context, last.data.interactionType);
    return (
      text: cadence == null
          ? messages.relationshipStatusLineContactedNoCadence(type, at)
          : messages.relationshipStatusLineContacted(type, at, cadence),
      date: at,
    );
  }
  final firstDue = peopleDueDateOf(item);
  // No first-due day means not enrolled, so there may be no cadence either.
  if (firstDue == null || cadence == null) {
    return (
      text: cadence == null
          ? messages.relationshipStatusLineAddedNoCadence
          : messages.relationshipStatusLineAdded(cadence),
      date: null,
    );
  }
  final day = relationshipDayLabelOf(context, firstDue);
  return (
    text: messages.relationshipStatusLineAddedFirstDue(cadence, day),
    date: day,
  );
}

/// The words for a row's cadence state: `5 days overdue` (or `Due today`
/// the day it lapses), `Due Thu` within the week, and the plain status
/// words otherwise.
String peopleCadencePillLabel(BuildContext context, PeopleCadencePill pill) {
  final messages = context.messages;
  return switch (pill.kind) {
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
}
