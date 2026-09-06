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
  const PeopleSummaryCard({required this.summary, super.key});

  final PeopleSummary summary;

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
    final nextDueLabel = nextDueName == null || nextDueAt == null
        ? messages.relationshipsSummaryNoneDue
        : messages.relationshipsSummaryNextDue(
            nextDueName,
            relationshipDayLabelOf(context, nextDueAt),
          );

    return DesignSystemSectionCard(
      key: const ValueKey('people-summary-card'),
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Row(
        children: [
          Column(
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
                    style: styles.heading.heading1.copyWith(
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
            child: DesignSystemDivider(
              orientation: DesignSystemDividerOrientation.vertical,
              length: tokens.spacing.step10,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nextDueLabel,
                  key: const ValueKey('people-summary-next-due'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.highEmphasis,
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
        ],
      ),
    );
  }
}
