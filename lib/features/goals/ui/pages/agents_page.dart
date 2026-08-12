import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_banner_widgets.dart';
import 'package:lotti/features/goals/ui/goal_coarse_health.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// The flag-gated Agents tab (design handover 1c): one row per goal agent —
/// persona chip, active-spec goal title, coarse health chip, needs-you badge,
/// the agent's standing one-liner (events-and-time language, never a
/// percentage), and a direction arrow. The empty state is the only full-screen shell allowed:
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
    // On the settled-empty first-run screen the explainer's own CTA is the
    // sole creation affordance — the global FAB would route to the same
    // `/agents/create` and present the action twice.
    final settledEmpty = identities != null && identities.isEmpty;
    return Scaffold(
      floatingActionButton: settledEmpty
          ? null
          : DesignSystemBottomNavigationFabPadding(
              child: FloatingActionButton.extended(
                // Through NavService, not raw Beamer: keeps currentPath and
                // the persisted last route in sync (restart restores this
                // page).
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
    final healthAsync = ref.watch(goalAgentHealthProvider(identity.agentId));
    // Only a RESOLVED health record carries a verdict. While the per-agent
    // health is still loading — or after a load error with no prior value —
    // the row shows no health chip and a neutral persona hue, never a false
    // "Not enough data" (a genuine data condition reserved for a resolved
    // null status). Once a value has arrived, stale-while-revalidate keeps it
    // through background refreshes and transient errors.
    final health = healthAsync.value;
    final progress = health?.spec == null
        ? null
        : ref.watch(goalAgentProgressViewProvider(identity.agentId)).value;
    final coarse = healthAsync.hasValue
        ? coarseHealthOf(health?.trackStatus)
        : null;
    final color = coarse == null
        ? tokens.colors.text.lowEmphasis
        : goalCoarseHealthColor(coarse, tokens.colors);
    final direction = health?.direction;
    final dominantIssue = progress == null
        ? null
        : _dominantIssue(progress, health?.trackStatus);
    // A deterministic, factual hint for rolling-window habit goals: the
    // days-to-recovery when behind, or the buffer before the oldest success
    // ages out when at rate. Distinct from the agent's prose one-liner —
    // this is the evaluator's own arithmetic, in events-and-time language.
    final recoveryHint = switch ((health?.deficit, health?.buffer)) {
      (final int deficit, _) when deficit > 0 =>
        context.messages.goalDaysToRecover(deficit),
      (_, final int buffer) => context.messages.goalBufferDays(buffer),
      _ => null,
    };
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
                          health?.spec?.title ?? identity.displayName,
                          style: tokens.typography.styles.subtitle.subtitle1
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                        if (coarse != null)
                          GoalCoarseHealthChip(health: coarse),
                        if (direction != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                goalHealthDirectionIcon(direction),
                                size: tokens.spacing.step4,
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                              SizedBox(width: tokens.spacing.step1),
                              Text(
                                goalHealthDirectionLabel(
                                  context.messages,
                                  direction,
                                ),
                                style: tokens.typography.styles.others.caption
                                    .copyWith(
                                      color: tokens.colors.text.mediumEmphasis,
                                    ),
                              ),
                            ],
                          ),
                        if ((health?.pendingProposals ?? 0) > 0)
                          const _NeedsYouBadge()
                        else if (dominantIssue != null)
                          _AttentionBadge(dimensionName: dominantIssue),
                      ],
                    ),
                    // Executive summary: the agent's standing one-liner —
                    // events-and-time language, one line. Keeping percentages
                    // out is a matter for the agent's own instructions (and a
                    // conversation with it), not something worth policing in
                    // the widget.
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
                    if (recoveryHint != null) ...[
                      SizedBox(height: tokens.spacing.step1),
                      Text(
                        recoveryHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    ],
                    if (progress?.compactWindow case final days?
                        when days.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.step2),
                      GoalCompactWindowStrip(days: days),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _dominantIssue(
  GoalProgressView progress,
  GoalTrackStatus? trackStatus,
) {
  if (progress.rootOnTrack ||
      trackStatus == GoalTrackStatus.onTrack ||
      trackStatus == GoalTrackStatus.achieved ||
      trackStatus == GoalTrackStatus.insufficientData) {
    return null;
  }
  for (final metric in progress.metrics) {
    final observed = metric.days.where((day) => day.isObserved).toList();
    if (observed.isNotEmpty &&
        !metric.projectedOnTrack &&
        !metric.meetsTarget(observed.last)) {
      return metric.name;
    }
  }
  for (final habit in progress.habits) {
    if (habit.deficit > 0) return habit.name;
  }
  return null;
}

class _AttentionBadge extends StatelessWidget {
  const _AttentionBadge({required this.dimensionName});

  final String dimensionName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final info = tokens.colors.alert.info;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: info.defaultColor.withValues(alpha: SurfaceAlphas.washChip),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        context.messages.goalDominantIssueBadge(dimensionName),
        style: tokens.typography.styles.others.caption.copyWith(
          color: info.ink,
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
    final info = tokens.colors.alert.info;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: info.defaultColor.withValues(alpha: SurfaceAlphas.washChip),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      // The `ink` token is the design system's foreground for this alert's
      // wash; the full hue as caption text fails the 4.5:1 floor over its own
      // 22% wash (the same failure fixed on the coarse-health chip).
      child: Text(
        context.messages.goalPendingProposalBadge,
        style: tokens.typography.styles.others.caption.copyWith(
          color: info.ink,
        ),
      ),
    );
  }
}
