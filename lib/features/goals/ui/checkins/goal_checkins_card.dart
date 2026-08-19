import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_timeline.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The goal surface's check-ins block: a header carrying the count and the
/// always-available create action, a bounded preview of the rail, and a way
/// through to the rest.
///
/// One composition, rendered in two places — inline on the detail list on a
/// phone, hoisted into the desktop rail — so the two can never drift.
class GoalCheckInsCard extends ConsumerWidget {
  const GoalCheckInsCard({
    required this.agentId,
    required this.onCreate,
    this.onSeeAll,
    this.onOpenReflection,
    this.maxBeats,
    super.key,
  });

  final String agentId;

  /// Opens the composer. Null on a dormant goal, where creating is not
  /// offered — mirroring how the reflect row gates itself today.
  final VoidCallback? onCreate;

  /// Pushes the full timeline. Null hides the row, which is what the desktop
  /// rail wants since it is already showing everything.
  final VoidCallback? onSeeAll;

  final ValueChanged<DateTime>? onOpenReflection;
  final int? maxBeats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final total = ref.watch(goalTimelineItemsProvider(agentId)).length;
    final hasMore = maxBeats != null && total > maxBeats!;

    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // One localized message rather than a Dart-side join: the
                  // separator and the word order are translators' business.
                  total == 0
                      ? context.messages.goalCheckInsTitle
                      : context.messages.goalCheckInsTitleWithCount(total),
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              if (onCreate != null)
                IconButton(
                  key: const ValueKey('goal-checkin-create'),
                  onPressed: onCreate,
                  tooltip: context.messages.goalCheckInRecordCta,
                  icon: Icon(
                    LottiIcons.addCircled,
                    color: tokens.colors.interactive.enabled,
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          GoalCheckInTimeline(
            agentId: agentId,
            maxBeats: maxBeats,
            onOpenReflection: onOpenReflection,
            emptyAction: onCreate == null
                ? null
                : DesignSystemButton(
                    key: const ValueKey('goal-checkin-empty-cta'),
                    label: context.messages.goalCheckInRecordCta,
                    leadingIcon: LottiIcons.mic,
                    onPressed: onCreate,
                  ),
          ),
          if (hasMore && onSeeAll != null) ...[
            SizedBox(height: tokens.spacing.step2),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey('goal-checkin-see-all'),
                onTap: onSeeAll,
                hoverColor: tokens.colors.surface.hover,
                borderRadius: BorderRadius.circular(tokens.radii.s),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.messages.goalCheckInsSeeAll,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.interactive.enabled,
                        ),
                      ),
                      Icon(
                        LottiIcons.chevronRight,
                        size: IconSizes.xs,
                        color: tokens.colors.interactive.enabled,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
