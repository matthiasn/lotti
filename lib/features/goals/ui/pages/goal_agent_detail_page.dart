import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/agent_conversation_log.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/features/goals/ui/goal_status_chip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// One goal agent: health header, active banners (including any that the
/// host strips' visible cap holds back), pending revision proposals for
/// approval, the standing report, and the durable interaction timeline.
/// The two-way check-in chat joins this page with the reusable chat
/// interface (its own increment); the timeline below is the same durable
/// history that chat will project.
class GoalAgentDetailPage extends ConsumerWidget {
  const GoalAgentDetailPage({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final healthAsync = ref.watch(goalAgentHealthProvider(agentId));
    // Stale-while-revalidate: `.value` keeps the last render across
    // background reloads; only a load that has never produced data gets
    // the spinner. An errored load must not claim "no report yet".
    if (!healthAsync.hasValue && !healthAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final health = healthAsync.value;
    final spec = health?.spec;
    final nudges = [
      for (final entry
          in ref.watch(activeGoalNudgesProvider).value ??
              const <GoalBannerEntry>[])
        if (entry.nudge.agentId == agentId) entry,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(spec?.title ?? '')),
      body: SafeArea(
        child: ListView(
          // The mobile shell keeps the bottom navigation overlaid on agents
          // subroutes, so the timeline's last entry must clear it.
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            tokens.spacing.step5,
            tokens.spacing.step5,
            tokens.spacing.step5 +
                DesignSystemBottomNavigationBar.occupiedHeight(context),
          ),
          children: [
            if (health?.trackStatus != null)
              Row(
                children: [
                  GoalStatusChip(status: health!.trackStatus!),
                  if (health.attainment != null) ...[
                    SizedBox(width: tokens.spacing.step3),
                    Text(
                      context.messages.goalAttainmentLabel(
                        (health.attainment! * 100).round(),
                      ),
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ],
              ),
            if (spec != null) ...[
              SizedBox(height: tokens.spacing.step3),
              Text(
                spec.statement,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ],
            // Every active banner, uncapped: this is where ads held back
            // by the host strips' visible limit stay reachable for
            // rating and dismissal.
            for (final entry in nudges) ...[
              SizedBox(height: tokens.spacing.step4),
              GoalBannerCard(entry: entry),
            ],
            SizedBox(height: tokens.spacing.step4),
            ChangeSetSummaryCard.selfTargeted(
              agentId: agentId,
              confirmationProvider: goalChangeSetConfirmationServiceProvider,
            ),
            SizedBox(height: tokens.spacing.step2),
            if (health?.reportOneLiner case final String oneLiner)
              Text(
                oneLiner,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              )
            else if (healthAsync.hasError)
              Text(
                context.messages.goalDetailHealthUnavailable,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              )
            else
              Text(
                context.messages.goalDetailNoReport,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            SizedBox(height: tokens.spacing.sectionGap),
            Text(
              context.messages.goalDetailTimelineTitle,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            AgentConversationLog(agentId: agentId),
          ],
        ),
      ),
    );
  }
}
