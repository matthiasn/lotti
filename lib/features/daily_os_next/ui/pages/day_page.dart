import 'dart:async';

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
import 'package:lotti/features/daily_os_next/state/plan_view_provider.dart';
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
import 'package:material_ui/material_ui.dart';

part 'day_page_plan_review_strip_part.dart';

class _DayPageState extends ConsumerState<DayPage> {
  /// The projection to render: the user's explicit pick when there is one,
  /// otherwise the Day timeline. The pick lives in
  /// [dailyOsNextPlanViewProvider] so stepping to another day — which re-keys
  /// this page — does not throw it away.
  PlanView get _view => ref.watch(dailyOsNextPlanViewProvider) ?? PlanView.day;

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
                // The journal row can lag behind the outbox job (e.g. a
                // sync race), so fall back to the job's audio reference.
                audioId: entry.audio?.meta.id ?? entry.processingJob?.audioId,
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
              onViewChanged: ref
                  .read(dailyOsNextPlanViewProvider.notifier)
                  .select,
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
            // Goal-agent voices now live in the shell-level dock (one
            // rotating slot at the bottom of the content region), not
            // in-page — the day page no longer mounts a banner strip.
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
