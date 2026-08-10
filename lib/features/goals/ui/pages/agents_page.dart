import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_widgets.dart';
import 'package:lotti/features/goals/ui/goal_coarse_health.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// The flag-gated Agents tab (design handover 1c): one row per goal agent —
/// persona chip, name, coarse health chip, needs-you badge, the agent's
/// standing one-liner (events-and-time language, never a percentage), and a
/// direction arrow. The empty state is the only full-screen shell allowed:
/// a first-run explainer of what a goal agent is.
class AgentsPage extends ConsumerWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final agents = ref.watch(activeGoalAgentsProvider);
    // Stale-while-revalidate: background wake/sync notifications reload
    // the provider constantly; the established list must never flash
    // away (the repo's no-flash rule). Empty state only on a SETTLED
    // empty value; a failed FIRST load says so instead of rendering the
    // blank sliver a loading pass gets.
    final identities = agents.value;
    final failedFirstLoad = identities == null && agents.hasError;
    return Scaffold(
      floatingActionButton: DesignSystemBottomNavigationFabPadding(
        child: FloatingActionButton.extended(
          // Through NavService, not raw Beamer: keeps currentPath and the
          // persisted last route in sync (restart restores this page).
          onPressed: () => beamToNamed('/agents/create'),
          label: Text(context.messages.agentsCreateGoal),
          icon: const Icon(Icons.add_rounded),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(context.messages.agentsPageTitle),
            ),
            SliverPadding(
              // The last card must clear the overlaid bottom navigation
              // plus the lifted FAB's footprint (the projects-list
              // clearance idiom).
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step5,
                tokens.spacing.step5,
                tokens.spacing.step5 +
                    DesignSystemBottomNavigationBar.occupiedHeight(context) +
                    tokens.spacing.step12,
              ),
              sliver: switch (identities) {
                null when failedFirstLoad => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
                    child: Text(
                      context.messages.agentsPageLoadFailed,
                      textAlign: TextAlign.center,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                ),
                // A load that has never produced data gets the blank sliver
                // a loading pass renders, not the empty explainer.
                null => const SliverToBoxAdapter(child: SizedBox.shrink()),
                [] => const SliverToBoxAdapter(child: _FirstRunExplainer()),
                final list => SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: tokens.spacing.cardItemSpacing),
                  itemBuilder: (context, index) =>
                      _GoalAgentRow(identity: list[index]),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The first-run explainer — the only full-screen empty state the feature
/// allows (handover 1c): what a goal agent watches, how it speaks, the
/// dismissal contract, cost honesty, and the CTA to set the first goal.
class _FirstRunExplainer extends StatelessWidget {
  const _FirstRunExplainer();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    Widget paragraph(String text) => Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step4),
      child: Text(
        text,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messages.agentsFirstRunTitle,
            style: tokens.typography.styles.heading.heading3.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          paragraph(messages.agentsFirstRunWatches),
          paragraph(messages.agentsFirstRunSpeaks),
          paragraph(messages.agentsFirstRunControl),
          paragraph(messages.agentsFirstRunCost),
          SizedBox(height: tokens.spacing.sectionGap),
          FilledButton.icon(
            onPressed: () => beamToNamed('/agents/create'),
            icon: const Icon(Icons.add_rounded),
            label: Text(messages.agentsFirstRunCta),
          ),
        ],
      ),
    );
  }
}

class _GoalAgentRow extends ConsumerWidget {
  const _GoalAgentRow({required this.identity});

  final AgentIdentityEntity identity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final health = ref.watch(goalAgentHealthProvider(identity.agentId)).value;
    final coarse = coarseHealthOf(health?.trackStatus);
    final color = goalCoarseHealthColor(coarse, tokens.colors);
    final direction = health?.direction;
    return Material(
      color: tokens.colors.surface.enabled,
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.l),
        onTap: () => beamToNamed('/agents/details/${identity.agentId}'),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Row(
            children: [
              // The row's persona chip carries the goal's HEALTH hue (not a
              // banner accent) — the identity here belongs to the state.
              GoalBannerPersonaChip(
                monogram: GoalBannerPersonaChip.monogramFor(
                  identity.displayName,
                ),
                fill: color.withValues(alpha: SurfaceAlphas.washChip),
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + chip + needs-you badge fold under large text
                    // scales (Wrap, not Row).
                    Wrap(
                      spacing: tokens.spacing.step3,
                      runSpacing: tokens.spacing.step1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          identity.displayName,
                          style: tokens.typography.styles.subtitle.subtitle1
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                        GoalCoarseHealthChip(health: coarse),
                        if ((health?.pendingProposals ?? 0) > 0)
                          const _NeedsYouBadge(),
                      ],
                    ),
                    // Executive summary: the agent's standing one-liner,
                    // events-and-time language, one line, never a percentage.
                    if (health?.reportOneLiner case final String oneLiner) ...[
                      SizedBox(height: tokens.spacing.step1),
                      Text(
                        oneLiner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (direction != null) ...[
                SizedBox(width: tokens.spacing.step3),
                Icon(
                  goalHealthDirectionIcon(direction),
                  size: tokens.spacing.step5,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "needs you" pill: a pending goal-change proposal awaits review.
class _NeedsYouBadge extends StatelessWidget {
  const _NeedsYouBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = tokens.colors.alert.info.defaultColor;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: SurfaceAlphas.washChip),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        context.messages.goalPendingProposalBadge,
        style: tokens.typography.styles.others.caption.copyWith(color: color),
      ),
    );
  }
}
