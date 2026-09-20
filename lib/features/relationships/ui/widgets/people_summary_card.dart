import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The card above the People list (design 2026-09-06 §2, the Goals list's
/// summary card): how many enrolled people are due right now, who lapses
/// next and when, and how many people the agent is not watching at all.
///
/// The due count carries the warning ink only while it is non-zero — a calm
/// morning reads as a quiet `0 / 4 enrolled`, not as a warning about nothing.
class PeopleSummaryCard extends StatelessWidget {
  const PeopleSummaryCard({
    required this.summary,
    this.onOpenNextDue,
    super.key,
  });

  final PeopleSummary summary;

  /// Opens one of the two people the card is about. The card was the
  /// largest, most saturated block on the tab and did nothing at all — it
  /// named a person and then made the reader go and find them.
  ///
  /// Each half opens its own subject: the count opens the person it is
  /// counting (the longest lapse), the right half opens the one it names.
  final void Function(String relationshipId)? onOpenNextDue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final styles = tokens.typography.styles;
    final nextDue = summary.nextDue;
    final nextDueAt = summary.nextDueAt;
    // The nickname where there is one: the card names a person the way the
    // user talks about them ("Next due Bo"), and a full name wraps the line.
    final nextDueName =
        nextDue?.relationship.data.nickname ?? nextDue?.relationship.data.title;
    // Kept apart so the day can wear the mono face the rows already give
    // a date: the card sat directly above a column of mono timestamps and
    // set its own date in proportional type.
    final nextDueDay = nextDueAt == null
        ? null
        : relationshipDayLabelOf(context, nextDueAt);
    final nextDueLabel = nextDueName == null || nextDueDay == null
        ? messages.relationshipsSummaryNoneDue
        : messages.relationshipsSummaryNextDue(nextDueName, nextDueDay);

    return DesignSystemSectionCard(
      key: const ValueKey('people-summary-card'),
      child: Row(
        children: [
          _SummaryDoor(
            relationshipId: summary.mostOverdue?.relationship.meta.id,
            onOpen: onOpenNextDue,
            keyValue: const ValueKey('people-summary-due-open'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  messages.relationshipsSummaryDueNow,
                  style: styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${summary.dueNow}',
                      key: const ValueKey('people-summary-due-count'),
                      // heading2, not heading1: at 35/700 the loudest glyph
                      // on the People tab was a KPI, outweighing the page
                      // title and every person's name on it.
                      style: styles.heading.heading2.copyWith(
                        color: summary.dueNow > 0
                            ? tokens.colors.alert.warning.defaultColor
                            : tokens.colors.text.highEmphasis,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Text(
                      messages.relationshipsSummaryEnrolled(summary.enrolled),
                      style: styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
            child: DesignSystemDivider(
              orientation: DesignSystemDividerOrientation.vertical,
              length: tokens.spacing.step10,
            ),
          ),
          Expanded(
            child: _SummaryDoor(
              relationshipId: nextDue?.relationship.meta.id,
              onOpen: onOpenNextDue,
              keyValue: const ValueKey('people-summary-next-due-open'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RelationshipLineWithDate(
                    key: const ValueKey('people-summary-next-due'),
                    text: nextDueLabel,
                    date: nextDueDay,
                    maxLines: 2,
                    style: styles.body.bodyMedium.copyWith(
                      color: nextDue == null
                          ? tokens.colors.text.highEmphasis
                          : tokens.colors.interactive.enabled,
                    ),
                  ),
                  if (summary.notEnrolled > 0) ...[
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      messages.relationshipsSummaryNotEnrolled(
                        summary.notEnrolled,
                      ),
                      style: styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the card, made the door it already looked like — with a
/// chevron, so it *looks* like one.
///
/// Wraps [child] in a tap target that opens the person that half is about,
/// but only when there is one and the caller wants the behaviour: a card
/// reading "Nobody is due" stays inert rather than offering a tap that goes
/// nowhere. The chevron only appears on the live half, so the affordance
/// and the behaviour cannot disagree.
class _SummaryDoor extends StatelessWidget {
  const _SummaryDoor({
    required this.relationshipId,
    required this.onOpen,
    required this.keyValue,
    required this.child,
  });

  final String? relationshipId;
  final void Function(String relationshipId)? onOpen;
  final Key keyValue;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final id = relationshipId;
    final open = onOpen;
    if (id == null || open == null) return child;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: keyValue,
        onTap: () => open(id),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: child),
              SizedBox(width: tokens.spacing.step1),
              Icon(
                LottiIcons.chevronRight,
                size: IconSizes.s,
                color: tokens.colors.text.lowEmphasis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
