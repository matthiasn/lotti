import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/agent_conversation_log.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_status_chip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One goal agent: health header, pending revision proposals for
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
    final health = ref.watch(goalAgentHealthProvider(agentId)).value;
    final spec = health?.spec;
    return Scaffold(
      appBar: AppBar(title: Text(spec?.title ?? '')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spacing.step5),
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
