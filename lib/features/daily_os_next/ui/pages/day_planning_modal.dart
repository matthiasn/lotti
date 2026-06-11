import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/drafting_controller.dart';
import 'package:lotti/features/daily_os_next/state/reconcile_controller.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/drafting_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/text_scale_policy.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_glass_action_bar.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_thinking_shader.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// What the day-planning modal opens to.
sealed class DayPlanningIntent {
  const DayPlanningIntent();
}

/// Start a brand-new plan: Capture → Reconcile → Drafting.
class DayPlanningCreate extends DayPlanningIntent {
  const DayPlanningCreate();
}

/// Adapt an existing plan via the voice-driven Refine step.
class DayPlanningAdapt extends DayPlanningIntent {
  const DayPlanningAdapt(this.draft);

  final DraftPlan draft;
}

/// Opens the day-planning interaction as a full-height modal layer that
/// covers the app's bottom navigation.
///
/// The interaction is a Wolt multi-page sheet pushed on the **root**
/// navigator with [WoltModalType.bottomSheet] `forceMaxHeight`, so it sits
/// above the shell (mobile) or renders as a dialog (wide). Each step is a
/// page whose `stickyActionBar` is a [DayPlanningGlassActionBar] carrying
/// the AI thinking shader at its top edge; the step bodies are the
/// scaffold-free `*ModalContent` widgets. Steps advance via
/// `WoltModalSheet.of(context).pushPage(...)` and retreat via `popPage()`.
///
/// On create, the Drafting step closes the whole modal once the plan is
/// ready and invalidates [currentDraftPlanProvider] so the day surface
/// shows the new plan.
Future<void> showDayPlanningModal({
  required BuildContext context,
  required DateTime dayDate,
  required DayPlanningIntent intent,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final day = DateTime(dayDate.year, dayDate.month, dayDate.day);

  return WoltModalSheet.show<void>(
    context: context,
    useRootNavigator: true,
    modalTypeBuilder: (modalContext) =>
        _dayPlanningModalType(modalContext, intent),
    barrierDismissible: true,
    modalBarrierColor: ModalUtils.getModalBarrierColor(
      isDark: isDark,
      context: context,
    ),
    pageListBuilder: (modalContext) => [
      switch (intent) {
        DayPlanningCreate() => _captureStepPage(modalContext, day),
        DayPlanningAdapt(:final draft) => _refineStepPage(modalContext, draft),
      },
    ],
  );
}

/// Bottom sheet on phones (covers the nav), full-height side panel on wide.
///
/// The Create ritual (Capture → Reconcile → Drafting) runs as a calm
/// full-height bottom sheet so it reads as a near-full layer; the Adapt
/// (Refine) flow is a compact, content-sized panel that shouldn't stretch
/// to fill the screen for its sparse voice content. On desktop both run in
/// a right-anchored [SizedWoltSideSheetType]: full height suits the
/// conversational back-and-forth far better than a height-capped dialog,
/// and the day surface stays visible beside it.
WoltModalType _dayPlanningModalType(
  BuildContext context,
  DayPlanningIntent intent,
) {
  final width = MediaQuery.of(context).size.width;
  if (width < WoltModalConfig.pageBreakpoint) {
    // Both intents run full height: the anchored voice template pins the
    // orb above the action bar and lets the middle zone breathe.
    return const WoltBottomSheetType(forceMaxHeight: true);
  }
  return const SizedWoltSideSheetType();
}

/// Bottom padding reserved under scrolling step content so the last rows
/// clear the sticky glass action bar.
const double _barClearance = 112;

/// Height given to step bodies that center/fill or scroll internally
/// (Capture, Drafting, Refine). Wolt lays page content in a
/// shrink-wrapping viewport (unbounded height), so those bodies — which
/// rely on a bounded box for `Expanded`/`SingleChildScrollView` — need an
/// explicit height rather than `SliverFillRemaining`.
///
/// Both planning containers are full height (bottom sheet on phones, side
/// sheet on desktop), so the body height is the screen minus the modal
/// chrome: the sheet's top inset + nav bar above the body, and the sticky
/// glass action bar below it. Slightly undershooting is fine (a little
/// breathing room above the bar); overshooting would push the
/// bottom-anchored orb under the bar.
double _stepViewportHeight(BuildContext context, {bool hasBar = true}) {
  final size = MediaQuery.sizeOf(context);
  final isBottomSheet = size.width < WoltModalConfig.pageBreakpoint;
  // Bottom sheets keep a visible sliver of the underlying page above the
  // sheet; the side sheet starts at the window's top edge. Steps without a
  // sticky bar (Drafting) reclaim its allowance so their content reaches
  // the sheet edge instead of stopping short of it.
  // At large text scales the bar stacks its pills vertically, so its
  // allowance grows.
  final stackedBarExtra =
      hasBar && dailyOsTextScaleOf(context) >= kDailyOsStackBarPillsScale
      ? 64.0
      : 0.0;
  final chrome =
      (isBottomSheet ? (hasBar ? 250.0 : 170.0) : (hasBar ? 180.0 : 100.0)) +
      stackedBarExtra;
  // A low floor: the step bodies handle squeeze themselves (the capture
  // template falls back to a reverse scroll that keeps the orb above the
  // fold) — a tall floor would instead shove the bottom-anchored orb
  // under the sticky bar on short windows.
  return math.max(280, size.height - chrome);
}

DateTime _capturedAtForDay(DateTime day) {
  final now = clock.now();
  // Preserve [day]'s timezone by adding the elapsed time since midnight,
  // rather than mixing [day]'s date with [now]'s wall-clock components.
  // `clock.now()` is always local here, so local midnight is correct.
  return day.add(now.difference(DateTime(now.year, now.month, now.day)));
}

/// Lays out action-bar pills for the host container: phones get
/// edge-to-edge pills (each wrapped in [Expanded]); the desktop side sheet
/// gets intrinsic-width pills aligned to the trailing edge so they read as
/// buttons rather than full-width slabs. At large accessibility text
/// scales a phone row can no longer fit two readable labels, so the pills
/// stack vertically instead — the last (primary) pill lands closest to
/// the thumb.
Widget _layoutBarPills(BuildContext context, List<Widget> pills) {
  final tokens = context.designTokens;
  final textScale = dailyOsTextScaleOf(context);
  return LayoutBuilder(
    builder: (context, constraints) {
      // Decide from the bar's own width, not the screen: the desktop side
      // sheet is 480–720px wide on an arbitrarily wide screen.
      final wide = constraints.maxWidth >= WoltModalConfig.pageBreakpoint;
      // Large accessibility text stacks multi-pill rows on ANY host —
      // intrinsic side-by-side pills overflow narrow panels and verbose
      // locales alike.
      if (pills.length > 1 && textScale >= kDailyOsStackBarPillsScale) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < pills.length; i++) ...[
              if (i > 0) SizedBox(height: tokens.spacing.step3),
              pills[i],
            ],
          ],
        );
      }
      return Row(
        mainAxisAlignment: wide
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          for (var i = 0; i < pills.length; i++) ...[
            if (i > 0) SizedBox(width: tokens.spacing.step3),
            if (wide) Flexible(child: pills[i]) else Expanded(child: pills[i]),
          ],
        ],
      );
    },
  );
}

// ─────────────────────────────── Capture ───────────────────────────────

SliverWoltModalSheetPage _captureStepPage(
  BuildContext context,
  DateTime day,
) {
  return ModalUtils.sliverModalSheetPage(
    context: context,
    slivers: [
      SliverToBoxAdapter(
        child: SizedBox(
          height: _stepViewportHeight(context),
          child: _CaptureStepBody(day: day),
        ),
      ),
    ],
    stickyActionBar: _CaptureStepBar(day: day),
  );
}

/// Capture step body: feeds [CaptureModalContent] the day's already-tracked
/// time so the "Today so far" card (handoff v2 item 1) appears in the modal,
/// matching the standalone capture surface. A loading/error projection falls
/// through as "no tracked time" rather than blocking the ritual.
class _CaptureStepBody extends ConsumerWidget {
  const _CaptureStepBody({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actualBlocks =
        ref.watch(dailyOsActualTimeBlocksProvider(day)).value ?? const [];
    return CaptureModalContent(forDate: day, actualBlocks: actualBlocks);
  }
}

class _CaptureStepBar extends ConsumerStatefulWidget {
  const _CaptureStepBar({required this.day});

  final DateTime day;

  @override
  ConsumerState<_CaptureStepBar> createState() => _CaptureStepBarState();
}

class _CaptureStepBarState extends ConsumerState<_CaptureStepBar> {
  /// True while `submitCapture` is in flight — guards against a double tap
  /// creating two captures and pushing two Reconcile pages, and disables the
  /// bar's pills for the duration.
  bool _submitting = false;

  Future<void> _continue() async {
    if (_submitting) return;
    final state = ref.read(captureControllerProvider);
    final transcript = state.transcript.trim();
    if (transcript.isEmpty) return;
    setState(() => _submitting = true);
    final agent = ref.read(dayAgentProvider);
    try {
      final captureId = await agent.submitCapture(
        transcript: transcript,
        capturedAt: _capturedAtForDay(widget.day),
        audioId: state.audioId,
      );
      if (!mounted) return;
      // Capture the sheet state here (a live context): the pushed page's
      // back action must not close over this bar's context, which is defunct
      // once the Reconcile page replaces it.
      final sheet = WoltModalSheet.of(context);
      sheet.pushPage(
        _reconcileStepPage(
          context,
          widget.day,
          captureId,
          onBack: sheet.popPage,
        ),
      );
      ref.read(captureControllerProvider.notifier).reset();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // The bar only cares about phase/transcript; meter ticks (amplitudes
    // at stream rate) must not rebuild the sticky bar.
    final state = ref.watch(
      captureControllerProvider.select((s) => s.withoutMeter),
    );

    final Widget actions;
    switch (state.phase) {
      case CapturePhase.captured:
        final canContinue = state.transcript.trim().isNotEmpty && !_submitting;
        actions = _layoutBarPills(context, [
          DsGlassPill(
            icon: Icons.mic_rounded,
            label: messages.dailyOsNextReconcileReRecord,
            fillColor: tokens.colors.surface.focusPressed,
            enabled: !_submitting,
            onTap: () => ref.read(captureControllerProvider.notifier).reset(),
          ),
          DsGlassPill(
            icon: Icons.arrow_forward_rounded,
            label: messages.dailyOsNextCaptureReconcileCta,
            fillColor: tokens.colors.interactive.enabled,
            foregroundColor: tokens.colors.text.onInteractiveAlert,
            enabled: canContinue,
            onTap: _continue,
          ),
        ]);
      case CapturePhase.idle:
      case CapturePhase.error:
        actions = _layoutBarPills(context, [
          DsGlassPill(
            icon: Icons.keyboard_alt_outlined,
            label: messages.dailyOsNextCaptureTypeInstead,
            fillColor: tokens.colors.surface.focusPressed,
            onTap: () =>
                ref.read(captureControllerProvider.notifier).startTyping(),
          ),
        ]);
      case CapturePhase.listening:
        // Mirrors the orb's stop action in the thumb zone, so finishing a
        // capture never requires reaching back up to the orb.
        actions = _layoutBarPills(context, [
          DsGlassPill(
            icon: Icons.check_rounded,
            label: messages.dailyOsNextCaptureDoneCta,
            fillColor: tokens.colors.interactive.enabled,
            foregroundColor: tokens.colors.text.onInteractiveAlert,
            onTap: () => ref.read(captureControllerProvider.notifier).toggle(),
          ),
        ]);
      case CapturePhase.transcribing:
        // One honest action while working: a quiet Cancel that discards the
        // in-flight transcription (controller reset). The thinking shader on
        // the bar's top edge carries the busy signal.
        // No leading ✕ glyph: the modal's close button already shows one,
        // and two ✕ affordances in one viewport read as competing exits.
        actions = _layoutBarPills(context, [
          DsGlassPill(
            label: messages.cancelButton,
            fillColor: tokens.colors.surface.focusPressed,
            onTap: () => ref.read(captureControllerProvider.notifier).reset(),
          ),
        ]);
    }

    return DayPlanningGlassActionBar(
      topSlot: DayPlanningThinkingShader(
        isThinking: state.phase == CapturePhase.transcribing,
      ),
      actions: actions,
    );
  }
}

// ────────────────────────────── Reconcile ──────────────────────────────

SliverWoltModalSheetPage _reconcileStepPage(
  BuildContext context,
  DateTime day,
  CaptureId captureId, {
  required VoidCallback onBack,
}) {
  final params = ReconcileParams(captureId: captureId, dayDate: day);
  return ModalUtils.sliverModalSheetPage(
    context: context,
    onTapBack: onBack,
    slivers: [
      SliverToBoxAdapter(child: _ReconcileStepContent(params: params)),
      const SliverToBoxAdapter(child: SizedBox(height: _barClearance)),
    ],
    stickyActionBar: _ReconcileStepBar(params: params, day: day),
  );
}

class _ReconcileStepContent extends ConsumerWidget {
  const _ReconcileStepContent({required this.params});

  final ReconcileParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final state = ref.watch(reconcileControllerProvider(params));
    return switch (state) {
      _ when state.hasValue => ReconcileModalContent(
        params: params,
        data: state.requireValue,
      ),
      _ when state.hasError => Padding(
        padding: EdgeInsets.all(tokens.spacing.step8),
        child: Center(
          child: Text(
            context.messages.dailyOsNextGenericError,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ),
      _ => Padding(
        padding: EdgeInsets.all(tokens.spacing.step10),
        child: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _ReconcileStepBar extends ConsumerStatefulWidget {
  const _ReconcileStepBar({required this.params, required this.day});

  final ReconcileParams params;
  final DateTime day;

  @override
  ConsumerState<_ReconcileStepBar> createState() => _ReconcileStepBarState();
}

class _ReconcileStepBarState extends ConsumerState<_ReconcileStepBar> {
  /// True once "Build my day" has pushed the Drafting page — guards against
  /// rapid re-taps stacking duplicate Drafting steps on the modal navigator.
  bool _pushing = false;

  void _buildDay() {
    if (_pushing) return;
    final data = ref.read(reconcileControllerProvider(widget.params)).value;
    if (data == null) return;
    setState(() => _pushing = true);
    final selections = reconcileDraftingSelections(data);
    final sheet = WoltModalSheet.of(context);
    sheet.pushPage(
      _draftingStepPage(
        context,
        day: widget.day,
        captureId: widget.params.captureId,
        selections: selections,
        onBack: sheet.popPage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(reconcileControllerProvider(widget.params));
    final canBuild = state.hasValue && !_pushing;

    return DayPlanningGlassActionBar(
      topSlot: DayPlanningThinkingShader(
        isThinking: state.isLoading && !state.hasValue,
      ),
      actions: _layoutBarPills(context, [
        DsGlassPill(
          icon: Icons.mic_rounded,
          label: messages.dailyOsNextReconcileReRecord,
          fillColor: tokens.colors.surface.focusPressed,
          enabled: !_pushing,
          onTap: () => WoltModalSheet.of(context).popPage(),
        ),
        DsGlassPill(
          icon: Icons.arrow_forward_rounded,
          label: messages.dailyOsNextReconcileBuildDayCta,
          fillColor: tokens.colors.interactive.enabled,
          foregroundColor: tokens.colors.text.onInteractiveAlert,
          enabled: canBuild,
          onTap: _buildDay,
        ),
      ]),
    );
  }
}

// ─────────────────────────────── Drafting ──────────────────────────────

SliverWoltModalSheetPage _draftingStepPage(
  BuildContext context, {
  required DateTime day,
  required CaptureId captureId,
  required ({List<String> taskIds, List<String> captureItemIds}) selections,
  required VoidCallback onBack,
}) {
  final params = DraftingParams(
    captureId: captureId,
    decidedTaskIds: selections.taskIds,
    decidedCaptureItemIds: selections.captureItemIds,
    dayDate: day,
  );
  // No sticky action bar: drafting offers no actions (it auto-advances when
  // the draft is ready), and the step body carries its own hero thinking
  // shader — a bar would be a dead strip duplicating that signal.
  return ModalUtils.sliverModalSheetPage(
    context: context,
    onTapBack: onBack,
    showCloseButton: false,
    slivers: [
      SliverToBoxAdapter(
        child: SizedBox(
          height: _stepViewportHeight(context, hasBar: false),
          child: _DraftingStepContent(params: params, day: day),
        ),
      ),
    ],
  );
}

class _DraftingStepContent extends ConsumerStatefulWidget {
  const _DraftingStepContent({required this.params, required this.day});

  final DraftingParams params;
  final DateTime day;

  @override
  ConsumerState<_DraftingStepContent> createState() =>
      _DraftingStepContentState();
}

class _DraftingStepContentState extends ConsumerState<_DraftingStepContent> {
  bool _advanced = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    ref.listen<AsyncValue<DraftingState>>(
      draftingControllerProvider(widget.params),
      (previous, next) {
        final value = next.value;
        if (value == null || _advanced) return;
        if (value.phase == DraftingPhase.ready && value.draft != null) {
          _advanced = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.invalidate(currentDraftPlanProvider(widget.day));
            // Only auto-close if the modal is still the current route — a
            // competing dismissal (close button / barrier tap) within the
            // same frame can already be popping it, and a second pop would
            // target the surface beneath.
            final route = ModalRoute.of(context);
            if (route?.isCurrent ?? false) {
              Navigator.of(context).pop();
            }
          });
        }
      },
    );

    final asyncState = ref.watch(draftingControllerProvider(widget.params));
    return switch (asyncState) {
      _ when asyncState.hasValue => DraftingModalContent(
        state: asyncState.requireValue,
      ),
      _ when asyncState.hasError => Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step8),
          child: Text(
            context.messages.dailyOsNextGenericError,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

// ──────────────────────────────── Refine ───────────────────────────────

SliverWoltModalSheetPage _refineStepPage(
  BuildContext context,
  DraftPlan draft,
) {
  // No top-bar title: like the other steps, the conversational body
  // headline ("What should change?") is the only title — a second label in
  // the nav bar reads as a double header.
  return ModalUtils.sliverModalSheetPage(
    context: context,
    slivers: [
      // Same anchored voice template as Capture: a bounded viewport pins
      // the orb above the sticky bar while the refine zone breathes.
      SliverToBoxAdapter(
        child: SizedBox(
          height: _stepViewportHeight(context),
          child: RefineModalContent(draft: draft),
        ),
      ),
    ],
    stickyActionBar: _RefineStepBar(draft: draft),
  );
}

class _RefineStepBar extends ConsumerWidget {
  const _RefineStepBar({required this.draft});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(refineControllerProvider(draft));
    final notifier = ref.read(refineControllerProvider(draft).notifier);
    // Reviewing also blocks "Looks good": tapping it there would silently
    // discard a recorded-but-unsubmitted transcript. An in-flight accept
    // blocks it too — a second tap would double-pop the host route.
    final busy =
        state.phase == RefinePhase.listening ||
        state.phase == RefinePhase.thinking ||
        state.phase == RefinePhase.reviewing ||
        state.accepting;
    final hasPendingDiff =
        state.diff != null && state.phase == RefinePhase.diffReady;

    return DayPlanningGlassActionBar(
      topSlot: DayPlanningThinkingShader(
        isThinking: state.phase == RefinePhase.thinking,
      ),
      actions: _layoutBarPills(context, [
        DsGlassPill(
          icon: Icons.undo_rounded,
          label: messages.dailyOsNextRefineRevert,
          fillColor: tokens.colors.surface.focusPressed,
          // Disabled during an in-flight accept too — the controller
          // no-ops the race anyway; the pill shouldn't look tappable.
          enabled: hasPendingDiff && !state.accepting,
          onTap: notifier.revert,
        ),
        DsGlassPill(
          icon: Icons.check_rounded,
          label: messages.dailyOsNextRefineLooksGood,
          fillColor: tokens.colors.interactive.enabled,
          foregroundColor: tokens.colors.text.onInteractiveAlert,
          enabled: !busy,
          // With a pending diff on screen, "Looks good" must PERSIST it —
          // accept() resolves all pending rows via the agent and flips to
          // accepted, whose listener pops with the final plan. A bare pop
          // would silently discard everything the user just approved.
          onTap: hasPendingDiff
              ? () => unawaited(notifier.accept())
              : () => Navigator.of(context).pop(),
        ),
      ]),
    );
  }
}
