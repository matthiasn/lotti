import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/features/goals/ui/goal_banner_exposure_tracker.dart';
import 'package:lotti/features/goals/ui/goal_banner_widgets.dart';
import 'package:lotti/features/goals/ui/goal_coarse_health.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/features/goals/ui/goal_status_chip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// One goal agent: rolling progress, active banners (including any that the
/// host strips' visible cap holds back), pending revision proposals, watching
/// metadata and outcome history. Desktop gives the durable conversation a
/// peer pane; mobile opens the same projection as a pushed page.
class GoalAgentDetailPage extends ConsumerWidget {
  const GoalAgentDetailPage({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final healthAsync = ref.watch(goalAgentHealthProvider(agentId));
    // Stale-while-revalidate: `.value` keeps the last render across
    // background reloads; only a load that has never produced data gets
    // the spinner. An errored load must not claim "no report yet".
    // EVERY pop — AppBar button, Android system back, iOS gesture —
    // routes through NavService so currentPath and the persisted route
    // return to the Agents root instead of pinning this child.
    final backToList = BackButton(onPressed: () => beamToNamed('/agents'));
    Widget popSafe(Widget child) => PopScope(
      // canPop stays TRUE: false would disable the iOS swipe-back
      // gesture entirely. The route pops normally; the completed pop
      // then persists the Agents root through NavService.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Post-frame: the pop is mid-router-update — persisting the root
        // synchronously would re-enter the delegate while it notifies.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => beamToNamed('/agents'),
        );
      },
      child: child,
    );
    if ((!healthAsync.hasValue && !healthAsync.hasError) ||
        (!identityAsync.hasValue && !identityAsync.hasError)) {
      return popSafe(
        Scaffold(
          appBar: AppBar(leading: backToList, title: const Text('')),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    // A stale link, a foreign route, OR a FIRST identity load that
    // failed: none of these may mount proposals and history as if the
    // goal were healthy. A background reload error with a retained
    // identity keeps the established page (the no-flash rule).
    final identity = identityAsync.value;
    if ((identityAsync.hasError && !identityAsync.hasValue) ||
        (identityAsync.hasValue &&
            (identity is! AgentIdentityEntity ||
                identity.kind != AgentKinds.goalAgent))) {
      return popSafe(
        Scaffold(
          appBar: AppBar(leading: backToList, title: const Text('')),
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step5),
              child: Text(
                identityAsync.hasError && !identityAsync.hasValue
                    ? context.messages.goalDetailHealthUnavailable
                    : context.messages.goalDetailNotFound,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final goalIdentity = identity! as AgentIdentityEntity;
    final health = healthAsync.value;
    final spec = health?.spec;
    final progress = spec == null
        ? null
        : ref.watch(goalAgentProgressViewProvider(agentId)).value;
    // Same render-time staleness contract as the strip: retained data
    // from a failed deadline reload keeps fresh banners (no-flash) but
    // never expired copy — whose tracker would keep counting exposure.
    final bannerNow = clock.now();
    final locallyDismissed = ref.watch(locallyDismissedNudgeIdsProvider);
    final nudges = [
      for (final entry
          in ref.watch(activeGoalNudgesProvider).value ??
              const <GoalBannerEntry>[])
        if (entry.nudge.agentId == agentId &&
            (entry.nudge.staleAt == null ||
                bannerNow.isBefore(entry.nudge.staleAt!)) &&
            !locallyDismissed.contains(entry.nudge.id))
          entry,
    ];
    final history =
        ref.watch(goalNudgeHistoryProvider(agentId)).value ??
        const <GoalNudgeEntity>[];
    Widget detailList({required bool showChatAction}) => ListView(
      // The mobile shell keeps the bottom navigation overlaid on agents
      // subroutes, so the final content must clear it.
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5 +
            DesignSystemBottomNavigationBar.occupiedHeight(context),
      ),
      children: [
        _GoalHeader(identity: goalIdentity, health: health, spec: spec),
        if (progress != null) ...[
          SizedBox(height: tokens.spacing.cardItemSpacing),
          GoalProgressCard(progress: progress),
        ],
        SizedBox(height: tokens.spacing.cardItemSpacing),
        _AgentSayingSection(
          healthAsync: healthAsync,
          nudges: nudges,
        ),
        SizedBox(height: tokens.spacing.cardItemSpacing),
        ChangeSetSummaryCard.selfTargeted(
          agentId: agentId,
          confirmationProvider: goalChangeSetConfirmationServiceProvider,
        ),
        if (progress != null && progress.habits.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.cardItemSpacing),
          _WatchingSection(progress: progress),
        ],
        if (showChatAction) ...[
          SizedBox(height: tokens.spacing.cardItemSpacing),
          DesignSystemButton(
            label: context.messages.goalChatTalkTo(goalIdentity.displayName),
            onPressed: () => beamToNamed('/agents/details/$agentId/chat'),
            leadingIcon: Icons.chat_bubble_outline_rounded,
            size: DesignSystemButtonSize.medium,
            fullWidth: true,
          ),
        ],
        if (history.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.cardItemSpacing),
          _GoalHistorySection(history: history),
        ],
      ],
    );
    final desktop = isDesktopLayout(context);
    return popSafe(
      Scaffold(
        appBar: AppBar(
          leading: backToList,
          title: Text(spec?.title ?? goalIdentity.displayName),
          actions: [_GoalDeleteMenuButton(agentId: agentId)],
        ),
        body: SafeArea(
          child: desktop
              ? Row(
                  children: [
                    Expanded(flex: 3, child: detailList(showChatAction: false)),
                    VerticalDivider(
                      color: tokens.colors.decorative.level01,
                    ),
                    Expanded(
                      flex: 2,
                      child: GoalAgentChatPane(agentId: agentId),
                    ),
                  ],
                )
              : detailList(showChatAction: true),
        ),
      ),
    );
  }
}

class _GoalHeader extends StatelessWidget {
  const _GoalHeader({
    required this.identity,
    required this.health,
    required this.spec,
  });

  final AgentIdentityEntity identity;
  final GoalAgentHealth? health;
  final GoalSpecVersionEntity? spec;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final coarse = coarseHealthOf(health?.trackStatus);
    final color = goalCoarseHealthColor(coarse, tokens.colors);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GoalBannerPersonaChip(
              monogram: GoalBannerPersonaChip.monogramFor(
                identity.displayName,
              ),
              fill: color.withValues(alpha: SurfaceAlphas.washChip),
            ),
            Text(
              spec?.title ?? identity.displayName,
              style: tokens.typography.styles.heading.heading3.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            GoalCoarseHealthChip(health: coarse),
          ],
        ),
        if (spec?.statement case final statement?) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            '“$statement”',
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _AgentSayingSection extends StatelessWidget {
  const _AgentSayingSection({
    required this.healthAsync,
    required this.nudges,
  });

  final AsyncValue<GoalAgentHealth> healthAsync;
  final List<GoalBannerEntry> nudges;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final oneLiner = healthAsync.value?.reportOneLiner;
    final label = Text(
      context.messages.goalDetailSayingTitle,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.alert.warning.ink,
      ),
    );
    if (nudges.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          SizedBox(height: tokens.spacing.step2),
          // Every active banner remains reachable here, uncapped. The shell
          // rotates one slot; this goal-owned surface does not.
          for (var index = 0; index < nudges.length; index++) ...[
            if (index > 0) SizedBox(height: tokens.spacing.step3),
            GoalBannerExposureTracker(
              key: ValueKey(
                '${nudges[index].nudge.id}:'
                '${nudges[index].nudge.activationCount}',
              ),
              nudgeId: nudges[index].nudge.id,
              child: GoalBannerCard(entry: nudges[index]),
            ),
          ],
        ],
      );
    }
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          SizedBox(height: tokens.spacing.step3),
          Text(
            oneLiner ??
                (healthAsync.hasError
                    ? context.messages.goalDetailHealthUnavailable
                    : context.messages.goalDetailNoReport),
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: oneLiner == null
                  ? tokens.colors.text.lowEmphasis
                  : tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchingSection extends StatelessWidget {
  const _WatchingSection({required this.progress});

  final GoalProgressView progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.goalDetailWatchingTitle,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          for (final habit in progress.habits) ...[
            Wrap(
              spacing: tokens.spacing.step2,
              runSpacing: tokens.spacing.step1,
              children: [
                Text(
                  habit.name,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                Text(
                  '${context.messages.goalProgressHabitTarget(habit.targetCount)}'
                  ' · ${habit.successfulWeeks} / 6',
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
          ],
          SizedBox(height: tokens.spacing.step2),
          Text(
            context.messages.goalDetailWatchingSignals,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalHistorySection extends StatelessWidget {
  const _GoalHistorySection({required this.history});

  final List<GoalNudgeEntity> history;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.goalDetailTimelineTitle,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          for (var index = 0; index < history.length; index++) ...[
            if (index > 0)
              Divider(
                height: tokens.spacing.step4,
                color: tokens.colors.decorative.level01,
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '“${history[index].brief.headline}”',
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Text(
                  goalNudgeStatusLabel(context, history[index].status),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _GoalDetailMenuAction { delete }

class _GoalDeleteMenuButton extends ConsumerWidget {
  const _GoalDeleteMenuButton({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final danger = tokens.colors.alert.error.ink;
    return PopupMenuButton<_GoalDetailMenuAction>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) {
        switch (action) {
          case _GoalDetailMenuAction.delete:
            _confirmAndDelete(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_GoalDetailMenuAction>(
          value: _GoalDetailMenuAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: danger),
              SizedBox(width: tokens.spacing.step3),
              Text(
                context.messages.goalDeleteMenuItem,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: danger,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final messages = dialogContext.messages;
        return AlertDialog(
          title: Text(messages.goalDeleteDialogTitle),
          content: Text(messages.goalDeleteDialogContent),
          actions: [
            DesignSystemButton(
              label: messages.cancelButton,
              variant: DesignSystemButtonVariant.tertiary,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            DesignSystemButton(
              label: messages.goalDeleteConfirmButton,
              variant: DesignSystemButtonVariant.danger,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await ref.read(goalAgentServiceProvider).deleteGoalAgent(agentId);
      beamToNamed('/agents');
    }
  }
}
