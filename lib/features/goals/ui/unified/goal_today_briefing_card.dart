import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/logic/goal_today_briefing.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:material_ui/material_ui.dart';

/// The day's briefing across goals: for each, where it stands in its agent's
/// own words and the first thing to do next, the goals behind first.
///
/// Composed, not generated: every line is what that goal's agent already
/// wrote in its standing report — the daily briefing each one writes on the
/// day's first tick — so the card costs no inference of its own. A goal
/// whose agent has not written one yet is simply not listed, and with none
/// the card does not render at all.
class GoalTodayBriefingCard extends ConsumerWidget {
  const GoalTodayBriefingCard({required this.identities, super.key});

  final List<AgentIdentityEntity> identities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = goalTodayBriefingItems(
      todayPeriodKey: const GoalWindow.day().periodKey(clock.now()),
      [
        for (final identity in identities)
          if (ref.watch(goalAgentHealthProvider(identity.agentId)).value
              case final health?)
            (
              agentId: identity.agentId,
              title: health.spec?.title ?? identity.displayName,
              status: health.trackStatus,
              specVersionId: health.spec?.id,
              specCreatedAt: health.spec?.createdAt,
              report: switch (ref
                  .watch(agentReportProvider(identity.agentId))
                  .value) {
                final AgentReportEntity report => report,
                _ => null,
              },
            ),
      ],
    );
    if (items.isEmpty) return const SizedBox.shrink();

    final tokens = context.designTokens;
    // The gap below travels with the card: absent, it leaves no hole.
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.sectionGap),
      child: DesignSystemSectionCard(
        key: const ValueKey('goal-today-briefing'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.goalTodayBriefingTitle,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            for (final item in items) ...[
              SizedBox(height: tokens.spacing.cardItemSpacing),
              _BriefingRow(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

class _BriefingRow extends StatelessWidget {
  const _BriefingRow({required this.item});

  final GoalTodayBriefingItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final status = unifiedGoalStatusChip(
      item.status,
      hasStandingAssessment: true,
    );
    return DsQuietInk(
      key: ValueKey('goal-today-briefing-${item.agentId}'),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      onTap: () => beamToNamed(goalDetailPath(item.agentId)),
      builder: (context, highlighted) => Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                if (status != null) ...[
                  SizedBox(width: tokens.spacing.step2),
                  UnifiedGoalStatusPill(status: status),
                ],
              ],
            ),
            if (item.read.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step1),
              Text(
                item.read,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
            if (item.nextStep case final step?) ...[
              SizedBox(height: tokens.spacing.step1),
              Text(
                context.messages.goalTodayBriefingNext(step),
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.interactive.enabled,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
