import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_status_chip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The flag-gated Agents tab: every running goal agent with its health
/// at a glance — track status, attainment, the standing report's
/// one-liner and a pending-proposal badge — plus creation.
class AgentsPage extends ConsumerWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final agents = ref.watch(activeGoalAgentsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.beamToNamed('/agents/create'),
        label: Text(context.messages.agentsCreateGoal),
        icon: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(context.messages.agentsPageTitle),
            ),
            SliverPadding(
              padding: EdgeInsets.all(tokens.spacing.step5),
              sliver: switch (agents) {
                AsyncData(value: final identities) when identities.isEmpty =>
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
                      child: Text(
                        context.messages.agentsPageEmpty,
                        textAlign: TextAlign.center,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(color: tokens.colors.text.mediumEmphasis),
                      ),
                    ),
                  ),
                AsyncData(value: final identities) => SliverList.separated(
                  itemCount: identities.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: tokens.spacing.cardItemSpacing),
                  itemBuilder: (context, index) =>
                      _GoalAgentCard(identity: identities[index]),
                ),
                _ => const SliverToBoxAdapter(child: SizedBox.shrink()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalAgentCard extends ConsumerWidget {
  const _GoalAgentCard({required this.identity});

  final AgentIdentityEntity identity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final health = ref.watch(goalAgentHealthProvider(identity.agentId)).value;
    final attainment = health?.attainment;
    return Material(
      color: tokens.colors.surface.enabled,
      borderRadius: BorderRadius.circular(tokens.radii.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.m),
        onTap: () => context.beamToNamed('/agents/details/${identity.agentId}'),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      identity.displayName,
                      style: tokens.typography.styles.subtitle.subtitle1
                          .copyWith(color: tokens.colors.text.highEmphasis),
                    ),
                  ),
                  if (health?.trackStatus != null)
                    GoalStatusChip(status: health!.trackStatus!),
                ],
              ),
              if (attainment != null) ...[
                SizedBox(height: tokens.spacing.step2),
                Text(
                  context.messages.goalAttainmentLabel(
                    (attainment * 100).round(),
                  ),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
              if (health?.reportOneLiner != null) ...[
                SizedBox(height: tokens.spacing.step1),
                Text(
                  health!.reportOneLiner!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
              if ((health?.pendingProposals ?? 0) > 0) ...[
                SizedBox(height: tokens.spacing.step2),
                Text(
                  context.messages.goalPendingProposalBadge,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.alert.info.defaultColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
