import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page_header.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/daily_os_next/ui/text_scale_policy.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/captures_panel.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/edge_fade.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_nudge.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

enum _QuickRefinement { tooMuch, moveLighter, addBuffer }

/// Hosts the two projections of the [DraftPlan] — Agenda (intent) and
/// Day (mechanics) — with a pill toggle at the top.
///
/// Agenda is the default surface per the prototype: it's the
/// "what today is about" view; Day is the "when does it happen"
/// projection a tap away. A footer pill opens the Refine screen for
/// voice-driven plan changes.
///
/// With no plan ([hasPlan] false — the route-level root passes a
/// synthetic empty [draft]) the page lands on the **Day** view so
/// recorded sessions are immediately visible on the timeline, and the
/// footer carries a single "Speak a check-in" CTA instead of
/// Refine/Commit (handoff v2 item 2).
class DayPage extends ConsumerStatefulWidget {
  const DayPage({
    required this.draft,
    this.hasPlan = true,
    this.onCheckIn,
    this.dateStrip,
    super.key,
  });

  final DraftPlan draft;

  /// False when [draft] is a synthetic empty aggregate for a day
  /// without a drafted plan.
  final bool hasPlan;

  /// Routes to the Capture screen — the empty-state footer CTA.
  final VoidCallback? onCheckIn;

  /// Optional widget rendered in place of the default static title.
  /// The route-level `DailyOsNextRoot` uses this to inject a date
  /// strip so the user can navigate between days without losing the
  /// Agenda/Day toggle in the trailing actions slot.
  final Widget? dateStrip;

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

class _DayPageState extends ConsumerState<DayPage> {
  late PlanView _view = widget.hasPlan ? PlanView.agenda : PlanView.day;

  Future<void> _openRefine({String? initialTranscript}) async {
    await showDayPlanningModal(
      context: context,
      dayDate: widget.draft.dayDate,
      intent: DayPlanningAdapt(
        widget.draft,
        initialTranscript: initialTranscript,
      ),
    );
    if (!mounted) return;
    ref.invalidate(currentDraftPlanProvider(widget.draft.dayDate));
  }

  void _openQuickRefinement(_QuickRefinement refinement) {
    final messages = context.messages;
    final transcript = switch (refinement) {
      _QuickRefinement.tooMuch => messages.dailyOsNextReviewTooMuchPrompt,
      _QuickRefinement.moveLighter =>
        messages.dailyOsNextReviewMoveLighterPrompt,
      _QuickRefinement.addBuffer => messages.dailyOsNextReviewAddBufferPrompt,
    };
    unawaited(_openRefine(initialTranscript: transcript));
  }

  void _openCommit() {
    nav_service.beamToNamed(
      dailyOsNextRoutePath(DailyOsNextRouteTarget.commit, widget.draft.dayDate),
    );
  }

  void _openShutdown() {
    nav_service.beamToNamed(
      dailyOsNextRoutePath(
        DailyOsNextRouteTarget.shutdown,
        widget.draft.dayDate,
      ),
    );
  }

  /// Resolves the day-agent identity for the current day and beams the
  /// Settings stack onto the existing agent detail page so the user can
  /// inspect the wake history, conversation log, observations, and
  /// token usage that produced this plan.
  Future<void> _openAgentInternals() async {
    final identity = await ref.read(
      agent_providers.dayAgentProvider(widget.draft.dayDate).future,
    );
    if (!mounted || identity == null) return;
    navigateToAgentInstance(identity.agentId);
  }

  /// Confirms intent then soft-deletes the persisted `DayPlanEntity`
  /// for this day via `DayAgentInterface.deletePlanForDate`. The
  /// route-level root watches `currentDraftPlanProvider`, which
  /// auto-invalidates on the agent's update stream, so the screen
  /// flips back to Capture for this date without a manual navigate.
  Future<void> _confirmDeletePlan() async {
    final messages = context.messages;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(messages.dailyOsNextDayDeleteDialogTitle),
        content: Text(messages.dailyOsNextDayDeleteDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(messages.dailyOsNextDayDeleteDialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(
                dialogContext,
              ).colorScheme.errorContainer,
              foregroundColor: Theme.of(
                dialogContext,
              ).colorScheme.onErrorContainer,
            ),
            child: Text(messages.dailyOsNextDayDeleteDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final agent = ref.read(dayAgentProvider);
    await agent.deletePlanForDate(widget.draft.dayDate);
  }

  /// Persists an inline rename of a standalone agenda item by renaming
  /// each of its linked blocks, then refreshes the plan projection.
  Future<void> _renameItem(AgendaItem item, String title) async {
    final agent = ref.read(dayAgentProvider);
    try {
      var plan = widget.draft;
      for (final blockId in item.linkedBlockIds) {
        plan = await agent.renameBlock(
          plan: plan,
          blockId: blockId,
          title: title,
        );
      }
    } catch (_) {
      _showRenameFailedToast();
      return;
    } finally {
      // Re-project even on partial failure so the UI reflects whatever
      // was persisted before the error.
      ref.invalidate(currentDraftPlanProvider(widget.draft.dayDate));
    }
  }

  Future<void> _renameBlock(TimeBlock block, String title) async {
    final agent = ref.read(dayAgentProvider);
    try {
      await agent.renameBlock(
        plan: widget.draft,
        blockId: block.id,
        title: title,
      );
    } catch (_) {
      _showRenameFailedToast();
      return;
    }
    ref.invalidate(currentDraftPlanProvider(widget.draft.dayDate));
  }

  void _showRenameFailedToast() {
    if (!mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.error,
      title: context.messages.dailyOsNextRenameFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final bottomNavHeight = DesignSystemBottomNavigationBar.occupiedHeight(
      context,
    );
    final actualBlocks = ref
        .watch(dailyOsActualTimeBlocksProvider(widget.draft.dayDate))
        .value;
    final prefs = ref.watch(dailyOsPreferencesControllerProvider);
    // Inline rename is only offered when a real plan backs the surface.
    final onRenameItem = widget.hasPlan
        ? (AgendaItem item, String title) => unawaited(_renameItem(item, title))
        : null;
    final onRenameBlock = widget.hasPlan
        ? (TimeBlock block, String title) =>
              unawaited(_renameBlock(block, title))
        : null;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomNavHeight),
          child: Column(
            children: [
              DayHeader(
                dateStrip: widget.dateStrip,
                date: widget.draft.dayDate,
                selectedView: _view,
                hasPlan: widget.hasPlan,
                onViewChanged: (next) => setState(() => _view = next),
                onBack: () => Navigator.of(context).maybePop(),
                onInspectAgent: () => unawaited(_openAgentInternals()),
                onDeletePlan: () => unawaited(_confirmDeletePlan()),
              ),
              CapturesPanel(date: widget.draft.dayDate),
              // Proposed learnings surface here on both views and both
              // form factors; renders nothing when there is nothing to
              // confirm.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step5,
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: KnowledgeNudge(),
                ),
              ),
              Expanded(
                // Rows meeting the fold dissolve instead of resting
                // razor-cut against the footer's glass edge.
                child: EdgeFade(
                  rampExtent: 36,
                  fadeTop: false,
                  minFraction: 0.04,
                  child: _view == PlanView.agenda
                      ? AgendaView(
                          draft: widget.draft,
                          actualBlocks: actualBlocks ?? const [],
                          hasPlan: widget.hasPlan,
                          onRenameItem: onRenameItem,
                        )
                      : DayTimeline(
                          draft: widget.draft,
                          actualBlocks: actualBlocks,
                          onRenameBlock: onRenameBlock,
                          showGestureHint: !prefs.timelineGesturesLearned,
                          onGesturesLearned: ref
                              .read(
                                dailyOsPreferencesControllerProvider.notifier,
                              )
                              .markTimelineGesturesLearned,
                        ),
                ),
              ),
              if (widget.hasPlan)
                _DayFooter(
                  draft: widget.draft,
                  showCoachHint: !prefs.dayFooterHintRetired,
                  onRefine: () => unawaited(_openRefine()),
                  onQuickRefinement: _openQuickRefinement,
                  onCommit: _openCommit,
                  onShutdown: _openShutdown,
                )
              else
                _NoPlanFooter(onCheckIn: widget.onCheckIn),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayFooter extends StatelessWidget {
  const _DayFooter({
    required this.draft,
    required this.showCoachHint,
    required this.onRefine,
    required this.onQuickRefinement,
    required this.onCommit,
    required this.onShutdown,
  });

  final DraftPlan draft;

  /// One-shot coaching line — retired permanently after the first
  /// lock-in (the promise has been experienced; chrome stops narrating).
  final bool showCoachHint;

  final VoidCallback onRefine;
  final ValueChanged<_QuickRefinement> onQuickRefinement;
  final VoidCallback onCommit;
  final VoidCallback onShutdown;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final isDesktop = isDesktopLayout(context);
    // Coaching copy yields the fold to actionable rows at large
    // accessibility text sizes, and retires for good after the first
    // lock-in.
    final showHint =
        showCoachHint &&
        draft.state != DayState.drafted &&
        dailyOsTextScaleOf(context) < kDailyOsHideCoachingScale;
    final hint = Text(
      context.messages.dailyOsNextDayRefineFooterHint,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.lowEmphasis,
      ),
    );
    final actions = _DayFooterActions(
      draft: draft,
      teal: teal,
      onRefine: onRefine,
      onShutdown: onShutdown,
      expand: !isDesktop,
    );
    final actionLayout = isDesktop
        // Constrained to the agenda's reading width so the commit
        // actions belong to the content column, not the page chrome.
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(
                children: [
                  if (showHint) ...[
                    Expanded(child: hint),
                    SizedBox(width: tokens.spacing.step4),
                  ] else
                    const Spacer(),
                  actions,
                ],
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHint) ...[
                hint,
                SizedBox(height: tokens.spacing.step3),
              ],
              actions,
            ],
          );
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (draft.state == DayState.drafted) ...[
              _PlanReviewStrip(
                draft: draft,
                onLooksGood: onCommit,
                onQuickRefinement: onQuickRefinement,
              ),
              SizedBox(height: tokens.spacing.step4),
            ],
            actionLayout,
          ],
        ),
      ),
    );
  }
}

class _PlanReviewStrip extends StatelessWidget {
  const _PlanReviewStrip({
    required this.draft,
    required this.onLooksGood,
    required this.onQuickRefinement,
  });

  final DraftPlan draft;
  final VoidCallback onLooksGood;
  final ValueChanged<_QuickRefinement> onQuickRefinement;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final reasons = _planReasons(draft);
    final compactActions =
        dailyOsTextScaleOf(context) >= kDailyOsHideCoachingScale;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (reasons.isNotEmpty) ...[
              Text(
                messages.dailyOsNextReviewWhyTitle,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step2),
              for (final reason in reasons) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: tokens.spacing.step4,
                      color: tokens.colors.interactive.enabled,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Expanded(
                      child: Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.step2),
              ],
              SizedBox(height: tokens.spacing.step2),
            ],
            if (compactActions)
              _CompactReviewActions(
                onLooksGood: onLooksGood,
                onQuickRefinement: onQuickRefinement,
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: tokens.spacing.step2,
                runSpacing: tokens.spacing.step2,
                children: [
                  FilledButton.icon(
                    onPressed: onLooksGood,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(messages.dailyOsNextReviewLooksGood),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        onQuickRefinement(_QuickRefinement.tooMuch),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    label: Text(messages.dailyOsNextReviewTooMuch),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        onQuickRefinement(_QuickRefinement.moveLighter),
                    icon: const Icon(Icons.low_priority_rounded),
                    label: Text(messages.dailyOsNextReviewMoveLighter),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        onQuickRefinement(_QuickRefinement.addBuffer),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(messages.dailyOsNextReviewAddBuffer),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<String> _planReasons(DraftPlan draft) {
    final reasons = <String>[];
    final seen = <String>{};
    for (final block in draft.blocks) {
      final reason = block.reason?.trim();
      if (reason == null || reason.isEmpty || !seen.add(reason)) continue;
      reasons.add(reason);
      if (reasons.length == 2) break;
    }
    return reasons;
  }
}

class _CompactReviewActions extends StatelessWidget {
  const _CompactReviewActions({
    required this.onLooksGood,
    required this.onQuickRefinement,
  });

  final VoidCallback onLooksGood;
  final ValueChanged<_QuickRefinement> onQuickRefinement;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onLooksGood,
          icon: const Icon(Icons.check_rounded),
          label: Text(
            messages.dailyOsNextReviewLooksGood,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        PopupMenuButton<_QuickRefinement>(
          tooltip: messages.dailyOsNextReviewAdjust,
          onSelected: onQuickRefinement,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _QuickRefinement.tooMuch,
              child: _QuickReviewMenuItem(
                icon: Icons.remove_circle_outline_rounded,
                label: messages.dailyOsNextReviewTooMuch,
              ),
            ),
            PopupMenuItem(
              value: _QuickRefinement.moveLighter,
              child: _QuickReviewMenuItem(
                icon: Icons.low_priority_rounded,
                label: messages.dailyOsNextReviewMoveLighter,
              ),
            ),
            PopupMenuItem(
              value: _QuickRefinement.addBuffer,
              child: _QuickReviewMenuItem(
                icon: Icons.add_rounded,
                label: messages.dailyOsNextReviewAddBuffer,
              ),
            ),
          ],
          child: _ReviewAdjustButton(label: messages.dailyOsNextReviewAdjust),
        ),
      ],
    );
  }
}

class _ReviewAdjustButton extends StatelessWidget {
  const _ReviewAdjustButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: teal.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune_rounded, size: 18, color: teal),
            SizedBox(width: tokens.spacing.step2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step1),
            Icon(Icons.expand_more_rounded, size: 18, color: teal),
          ],
        ),
      ),
    );
  }
}

class _QuickReviewMenuItem extends StatelessWidget {
  const _QuickReviewMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: tokens.colors.interactive.enabled),
        SizedBox(width: tokens.spacing.step3),
        Flexible(child: Text(label)),
      ],
    );
  }
}

/// The day footer's action row for a committed plan: refine / commit /
/// shutdown buttons. [expand] switches between the wide side-by-side layout
/// and a stacked layout on narrow widths.
class _DayFooterActions extends StatelessWidget {
  const _DayFooterActions({
    required this.draft,
    required this.teal,
    required this.onRefine,
    required this.onShutdown,
    required this.expand,
  });

  final DraftPlan draft;
  final Color teal;
  final VoidCallback onRefine;
  final VoidCallback onShutdown;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final refineButton = OutlinedButton.icon(
      onPressed: onRefine,
      icon: Icon(Icons.mic_rounded, size: 14, color: teal),
      label: Text(
        context.messages.dailyOsNextDayRefineCta,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: teal,
        side: BorderSide(color: teal.withValues(alpha: 0.32)),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
      ),
    );
    if (draft.state == DayState.drafted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (expand) Expanded(child: refineButton) else refineButton,
        ],
      );
    }
    final primaryButton = OutlinedButton.icon(
      onPressed: onShutdown,
      icon: Icon(
        Icons.nights_stay_outlined,
        size: 14,
        color: tokens.colors.text.mediumEmphasis,
      ),
      label: Text(
        context.messages.dailyOsNextDayWrapUpCta,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.colors.text.mediumEmphasis,
        side: BorderSide(color: tokens.colors.decorative.level01),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
      ),
    );

    return Row(
      children: [
        if (expand) Expanded(child: refineButton) else refineButton,
        SizedBox(width: tokens.spacing.step2),
        if (expand) Expanded(child: primaryButton) else primaryButton,
      ],
    );
  }
}

/// Footer for a day without a drafted plan: a single primary CTA that
/// routes to Capture so the assistant can draft a day around the
/// already-tracked time (handoff v2 item 2).
class _NoPlanFooter extends StatelessWidget {
  const _NoPlanFooter({required this.onCheckIn});

  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('daily_os_day_check_in_cta'),
              onPressed: onCheckIn,
              icon: const Icon(Icons.mic_rounded, size: 14),
              label: Text(
                context.messages.dailyOsNextDayCheckInCta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.colors.interactive.enabled,
                foregroundColor: tokens.colors.text.onInteractiveAlert,
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step5,
                  vertical: tokens.spacing.step2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    tokens.radii.badgesPills,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
