import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_conversation_log.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/features/goals/ui/goal_banner_exposure_tracker.dart';
import 'package:lotti/features/goals/ui/goal_status_chip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
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
    final health = healthAsync.value;
    final spec = health?.spec;
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
    return popSafe(
      Scaffold(
        appBar: AppBar(
          leading: backToList,
          title: Text(spec?.title ?? ''),
          actions: [_GoalDeleteMenuButton(agentId: agentId)],
        ),
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
                // Wrap, not Row: a long localized status plus the
                // attainment label must fold to a second line under
                // large text scales instead of overflowing.
                Wrap(
                  spacing: tokens.spacing.step3,
                  runSpacing: tokens.spacing.step1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GoalStatusChip(status: health!.trackStatus!),
                    if (health.attainment != null) ...[
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
                GoalBannerExposureTracker(
                  key: ValueKey(
                    '${entry.nudge.id}:${entry.nudge.activationCount}',
                  ),
                  nudgeId: entry.nudge.id,
                  child: GoalBannerCard(entry: entry),
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
              // Past ads stay part of the durable history (ADR 0055): once
              // dismissed/retired/expired/superseded they leave the banner
              // list, so the timeline is where their outcomes remain
              // browsable.
              for (final past
                  in ref.watch(goalNudgeHistoryProvider(agentId)).value ??
                      const <GoalNudgeEntity>[]) ...[
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.step2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          past.brief.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      Text(
                        goalNudgeStatusLabel(context, past.status),
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              AgentConversationLog(agentId: agentId),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single overflow-menu action on the goal detail page.
enum _GoalDetailMenuAction { delete }

/// The goal detail page's destructive action: an overflow menu whose sole
/// item retires the goal agent. Deletion is confirmed first, then routed
/// through `GoalAgentService.deleteGoalAgent` (the shared `destroyed`
/// lifecycle transition — synced, soft, audit-preserving). On success it
/// leaves the detail page for the Agents root: the goal no longer surfaces
/// on any active-lifecycle provider, so there is nothing left to show here.
class _GoalDeleteMenuButton extends ConsumerWidget {
  const _GoalDeleteMenuButton({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final danger = tokens.colors.alert.error.defaultColor;
    // onSelected (not PopupMenuItem.onTap): it fires after the menu route
    // has popped, with this button's stable context, so the confirmation
    // dialog never races the closing menu.
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
        final tokens = dialogContext.designTokens;
        final messages = dialogContext.messages;
        return AlertDialog(
          title: Text(messages.goalDeleteDialogTitle),
          content: Text(messages.goalDeleteDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(messages.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.colors.alert.error.defaultColor,
              ),
              child: Text(messages.goalDeleteConfirmButton),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await ref.read(goalAgentServiceProvider).deleteGoalAgent(agentId);
      // Through NavService — same idiom as every pop on this page — so
      // currentPath and the persisted last route return to the Agents root.
      beamToNamed('/agents');
    }
  }
}
