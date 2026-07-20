import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_plan_availability.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page_header.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/text_scale_policy.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_activity_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_block_edit_modal.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_check_in_spotlight_host.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/edge_fade.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_nudge.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
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
/// synthetic empty [draft]) the page lands on **Activity** so every saved or
/// recoverable recording remains immediately visible, and the
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
  late PlanView _view = widget.hasPlan ? PlanView.agenda : PlanView.activity;

  /// Measurement anchor for the onboarding spotlight over the empty-Day CTA.
  final GlobalKey _checkInCtaKey = GlobalKey();

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

  Future<void> _useActivityEntry(DayActivityEntry entry) async {
    final transcript = entry.transcript?.trim();
    if (transcript == null || transcript.isEmpty) return;
    if (widget.hasPlan) {
      await _openRefine(initialTranscript: transcript);
      return;
    }
    final captureId = entry.capture == null
        ? await ref
              .read(dayAgentProvider)
              .submitCapture(
                transcript: transcript,
                capturedAt: entry.createdAt,
                dayDate: widget.draft.dayDate,
                audioId: entry.audio?.meta.id,
              )
        : CaptureId(entry.capture!.id);
    if (entry.capture != null) {
      await ref
          .read(agent_providers.dayAgentCaptureServiceProvider)
          .retryCapture(entry.capture!.id);
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReconcilePage(
          captureId: captureId,
          dayDate: widget.draft.dayDate,
        ),
      ),
    );
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

  Future<void> _openBlockEditor(TimeBlock block) async {
    final taskId = block.taskId?.trim();
    final categoryOptions = getIt.isRegistered<EntitiesCacheService>()
        ? filterDayPlanCategories(
            getIt<EntitiesCacheService>().sortedCategories,
          )
        : null;
    final result = await DayBlockEditModal.show(
      context: context,
      block: block,
      categoryOptions: categoryOptions,
      onOpenTask: taskId == null || taskId.isEmpty
          ? null
          : () => nav_service.beamToNamed('/tasks/$taskId'),
    );
    if (!mounted || result == null) return;
    await _persistBlockEdit(block: block, result: result);
  }

  Future<bool> _persistBlockEdit({
    required TimeBlock block,
    required DayBlockEditResult result,
  }) async {
    final agent = ref.read(dayAgentProvider);
    final identityEditable = _identityEditable(block);
    try {
      await agent.editBlock(
        plan: widget.draft,
        blockId: block.id,
        start: result.start,
        end: result.end,
        title: identityEditable ? result.title : null,
        category: identityEditable ? result.category : null,
      );
    } catch (_) {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.dailyOsNextBlockEditFailed,
          replaceCurrent: true,
        );
      }
      return false;
    }
    ref.invalidate(currentDraftPlanProvider(widget.draft.dayDate));
    if (!mounted) return true;
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.dailyOsNextBlockEditSaved,
      action: ToastAction(
        label: context.messages.designSystemUndoLabel,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          unawaited(_undoBlockEdit(block));
        },
      ),
      countdown: true,
      replaceCurrent: true,
    );
    return true;
  }

  Future<bool> _rescheduleBlock(
    TimeBlock block,
    DateTime start,
    DateTime end,
  ) => _persistBlockEdit(
    block: block,
    result: DayBlockEditResult(
      title: block.title,
      category: block.category,
      start: start,
      end: end,
    ),
  );

  Future<void> _undoBlockEdit(TimeBlock original) async {
    final agent = ref.read(dayAgentProvider);
    final identityEditable = _identityEditable(original);
    try {
      await agent.editBlock(
        plan: widget.draft,
        blockId: original.id,
        start: original.start,
        end: original.end,
        title: identityEditable ? original.title : null,
        category: identityEditable ? original.category : null,
      );
    } catch (_) {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.dailyOsNextBlockEditFailed,
          replaceCurrent: true,
        );
      }
      return;
    }
    ref.invalidate(currentDraftPlanProvider(widget.draft.dayDate));
  }

  bool _identityEditable(TimeBlock block) =>
      !(block.taskId?.trim().isNotEmpty ?? false) &&
      block.type != TimeBlockType.buffer;

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
    final setupStatus = ref.watch(dailyOsSetupStatusProvider).value;
    // Inline rename is only offered when a real plan backs the surface.
    final onRenameItem = widget.hasPlan
        ? (AgendaItem item, String title) => unawaited(_renameItem(item, title))
        : null;
    final onRenameBlock = widget.hasPlan
        ? (TimeBlock block, String title) =>
              unawaited(_renameBlock(block, title))
        : null;
    final onEditBlock = widget.hasPlan
        ? (TimeBlock block) => unawaited(_openBlockEditor(block))
        : null;
    final onRescheduleBlock = widget.hasPlan ? _rescheduleBlock : null;
    final body = SafeArea(
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
              onSettings: () => nav_service.beamToNamed('/settings/daily-os'),
              onDeletePlan: () => unawaited(_confirmDeletePlan()),
            ),
            if (setupStatus?.needsAttention ?? false)
              _DailyOsSetupNudge(
                status: setupStatus!,
                onOpenSettings: () =>
                    nav_service.beamToNamed('/settings/daily-os'),
              ),
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
                child: switch (_view) {
                  PlanView.agenda => AgendaView(
                    draft: widget.draft,
                    actualBlocks: actualBlocks ?? const [],
                    hasPlan: widget.hasPlan,
                    onRenameItem: onRenameItem,
                  ),
                  PlanView.day => DayTimeline(
                    draft: widget.draft,
                    actualBlocks: actualBlocks,
                    onRenameBlock: onRenameBlock,
                    onEditBlock: onEditBlock,
                    onRescheduleBlock: onRescheduleBlock,
                    showGestureHint: !prefs.timelineGesturesLearned,
                    onGesturesLearned: ref
                        .read(
                          dailyOsPreferencesControllerProvider.notifier,
                        )
                        .markTimelineGesturesLearned,
                  ),
                  PlanView.activity => DayActivityView(
                    date: widget.draft.dayDate,
                    hasPlan: widget.hasPlan,
                    actualBlocks: actualBlocks ?? const [],
                    onUseEntry: (entry) => unawaited(_useActivityEntry(entry)),
                  ),
                },
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
              _NoPlanFooter(
                onCheckIn: setupStatus?.hasInferenceRoute == false
                    ? () => nav_service.beamToNamed('/settings/daily-os')
                    : widget.onCheckIn,
                needsInferenceSetup: setupStatus?.hasInferenceRoute == false,
                ctaKey: _checkInCtaKey,
              ),
          ],
        ),
      ),
    );
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: Stack(
        children: [
          body,
          // Onboarding spotlight over the empty-Day CTA. Renders nothing for
          // normal users (no active walkthrough session) or once the day has a
          // plan, so it never affects the ordinary Day surface.
          Positioned.fill(
            child: DayCheckInSpotlightHost(
              ctaKey: _checkInCtaKey,
              date: widget.draft.dayDate,
              enabled: !widget.hasPlan,
              onCheckIn: widget.onCheckIn,
            ),
          ),
        ],
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
  const _NoPlanFooter({
    required this.onCheckIn,
    required this.needsInferenceSetup,
    this.ctaKey,
  });

  final VoidCallback? onCheckIn;
  final bool needsInferenceSetup;

  /// Measurement key for the onboarding spotlight to anchor to. The stable
  /// [Key] used as a test finder stays on the button regardless.
  final GlobalKey? ctaKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final button = FilledButton.icon(
      key: const Key('daily_os_day_check_in_cta'),
      onPressed: onCheckIn,
      icon: Icon(
        needsInferenceSetup ? Icons.settings_outlined : Icons.mic_rounded,
        size: 14,
      ),
      label: Text(
        needsInferenceSetup
            ? context.messages.dailyOsSettingsSetupAction
            : context.messages.dailyOsNextDayCheckInCta,
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
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
      ),
    );
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The onboarding spotlight measures the CTA through this wrapper
            // key; the stable Key on the button stays put for test finders.
            if (ctaKey != null)
              KeyedSubtree(key: ctaKey, child: button)
            else
              button,
          ],
        ),
      ),
    );
  }
}

class _DailyOsSetupNudge extends StatelessWidget {
  const _DailyOsSetupNudge({
    required this.status,
    required this.onOpenSettings,
  });

  final DailyOsSetupStatus status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final inferenceMissing = !status.hasInferenceRoute;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Row(
            children: [
              Icon(
                inferenceMissing
                    ? Icons.warning_amber_rounded
                    : Icons.person_add_alt_1_outlined,
                color: tokens.colors.interactive.enabled,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inferenceMissing
                          ? context.messages.dailyOsSettingsSetupRequiredTitle
                          : context.messages.dailyOsSettingsNameNudgeTitle,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      inferenceMissing
                          ? [
                              context.messages.dailyOsSettingsSetupRequiredBody,
                              if (!status.hasPreferredName)
                                context.messages.dailyOsSettingsNameNudgeBody,
                            ].join(' ')
                          : context.messages.dailyOsSettingsNameNudgeBody,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              TextButton(
                onPressed: onOpenSettings,
                child: Text(
                  inferenceMissing
                      ? context.messages.dailyOsSettingsSetupAction
                      : context.messages.dailyOsSettingsNameNudgeAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
