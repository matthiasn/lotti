import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/drafting_controller.dart';
import 'package:lotti/features/daily_os_next/state/reconcile_controller.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/drafting_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_glass_action_bar.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_thinking_shader.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
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
    modalTypeBuilder: _dayPlanningModalType,
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

/// Full-height bottom sheet on phones (covers the nav), dialog on wide.
WoltModalType _dayPlanningModalType(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < WoltModalConfig.pageBreakpoint) {
    // Full-height bottom sheet so the layer covers the bottom nav and the
    // centered Capture/Drafting steps have a bounded viewport to fill.
    return const WoltBottomSheetType(forceMaxHeight: true);
  }
  return WoltModalType.dialog();
}

/// Bottom padding reserved under scrolling step content so the last rows
/// clear the sticky glass action bar.
const double _barClearance = 112;

/// Height given to step bodies that center/fill or scroll internally
/// (Capture, Drafting, Refine). Wolt lays page content in a
/// shrink-wrapping viewport (unbounded height), so those bodies — which
/// rely on a bounded box for `Expanded`/`SingleChildScrollView` — need an
/// explicit height rather than `SliverFillRemaining`. Sized as a fraction
/// of the screen so the full-height sheet reads as a calm, near-full layer
/// with the sticky bar docked below.
double _stepViewportHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height * 0.72;

DateTime _capturedAtForDay(DateTime day) {
  final now = clock.now();
  return DateTime(
    day.year,
    day.month,
    day.day,
    now.hour,
    now.minute,
    now.second,
    now.millisecond,
    now.microsecond,
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
          child: CaptureModalContent(forDate: day),
        ),
      ),
    ],
    stickyActionBar: _CaptureStepBar(day: day),
  );
}

class _CaptureStepBar extends ConsumerWidget {
  const _CaptureStepBar({required this.day});

  final DateTime day;

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final state = ref.read(captureControllerProvider);
    final transcript = state.transcript.trim();
    if (transcript.isEmpty) return;
    final agent = ref.read(dayAgentProvider);
    final captureId = await agent.submitCapture(
      transcript: transcript,
      capturedAt: _capturedAtForDay(day),
      audioId: state.audioId,
    );
    if (!context.mounted) return;
    WoltModalSheet.of(context).pushPage(
      _reconcileStepPage(context, day, captureId),
    );
    ref.read(captureControllerProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(captureControllerProvider);

    final Widget actions;
    switch (state.phase) {
      case CapturePhase.captured:
        final canContinue = state.transcript.trim().isNotEmpty;
        actions = Row(
          children: [
            Expanded(
              child: DsGlassPill(
                icon: Icons.mic_rounded,
                label: messages.dailyOsNextReconcileReRecord,
                onTap: () =>
                    ref.read(captureControllerProvider.notifier).reset(),
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Expanded(
              child: DsGlassPill(
                icon: Icons.arrow_forward_rounded,
                label: messages.dailyOsNextCaptureReconcileCta,
                fillColor: tokens.colors.interactive.enabled,
                foregroundColor: tokens.colors.text.onInteractiveAlert,
                onTap: canContinue ? () => _continue(context, ref) : () {},
              ),
            ),
          ],
        );
      case CapturePhase.idle:
      case CapturePhase.error:
        actions = DsGlassPill(
          icon: Icons.keyboard_rounded,
          label: messages.dailyOsNextCaptureTypeInstead,
          expand: true,
          onTap: () =>
              ref.read(captureControllerProvider.notifier).startTyping(),
        );
      case CapturePhase.listening:
      case CapturePhase.transcribing:
        actions = const SizedBox(width: double.infinity);
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
  CaptureId captureId,
) {
  final params = ReconcileParams(captureId: captureId, dayDate: day);
  return ModalUtils.sliverModalSheetPage(
    context: context,
    onTapBack: () => WoltModalSheet.of(context).popPage(),
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

class _ReconcileStepBar extends ConsumerWidget {
  const _ReconcileStepBar({required this.params, required this.day});

  final ReconcileParams params;
  final DateTime day;

  void _buildDay(BuildContext context, WidgetRef ref) {
    final data = ref.read(reconcileControllerProvider(params)).value;
    if (data == null) return;
    final selections = reconcileDraftingSelections(data);
    WoltModalSheet.of(context).pushPage(
      _draftingStepPage(
        context,
        day: day,
        captureId: params.captureId,
        selections: selections,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(reconcileControllerProvider(params));

    return DayPlanningGlassActionBar(
      topSlot: DayPlanningThinkingShader(
        isThinking: state.isLoading && !state.hasValue,
      ),
      actions: Row(
        children: [
          Expanded(
            child: DsGlassPill(
              icon: Icons.mic_rounded,
              label: messages.dailyOsNextReconcileReRecord,
              onTap: () => WoltModalSheet.of(context).popPage(),
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Expanded(
            child: DsGlassPill(
              icon: Icons.arrow_forward_rounded,
              label: messages.dailyOsNextReconcileBuildDayCta,
              fillColor: tokens.colors.interactive.enabled,
              foregroundColor: tokens.colors.text.onInteractiveAlert,
              onTap: () => _buildDay(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Drafting ──────────────────────────────

SliverWoltModalSheetPage _draftingStepPage(
  BuildContext context, {
  required DateTime day,
  required CaptureId captureId,
  required ({List<String> taskIds, List<String> captureItemIds}) selections,
}) {
  final params = DraftingParams(
    captureId: captureId,
    decidedTaskIds: selections.taskIds,
    decidedCaptureItemIds: selections.captureItemIds,
    dayDate: day,
  );
  return ModalUtils.sliverModalSheetPage(
    context: context,
    onTapBack: () => WoltModalSheet.of(context).popPage(),
    showCloseButton: false,
    slivers: [
      SliverToBoxAdapter(
        child: SizedBox(
          height: _stepViewportHeight(context),
          child: _DraftingStepContent(params: params, day: day),
        ),
      ),
    ],
    stickyActionBar: _DraftingStepBar(params: params),
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
            Navigator.of(context).pop();
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

class _DraftingStepBar extends ConsumerWidget {
  const _DraftingStepBar({required this.params});

  final DraftingParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(draftingControllerProvider(params));
    final isThinking =
        state.isLoading || state.value?.phase == DraftingPhase.drafting;
    return DayPlanningGlassActionBar(
      topSlot: DayPlanningThinkingShader(isThinking: isThinking),
      actions: const SizedBox(width: double.infinity),
    );
  }
}

// ──────────────────────────────── Refine ───────────────────────────────

SliverWoltModalSheetPage _refineStepPage(
  BuildContext context,
  DraftPlan draft,
) {
  return ModalUtils.sliverModalSheetPage(
    context: context,
    title: context.messages.dailyOsNextRefineTitle,
    slivers: [
      SliverToBoxAdapter(
        child: SizedBox(
          height: _stepViewportHeight(context),
          child: RefineModalContent(draft: draft),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: _barClearance)),
    ],
    stickyActionBar: _RefineStepBar(draft: draft),
  );
}

class _RefineStepBar extends ConsumerWidget {
  const _RefineStepBar({required this.draft});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(
      refineControllerProvider(draft).select((s) => s.phase),
    );
    return DayPlanningGlassActionBar(
      topSlot: DayPlanningThinkingShader(
        isThinking: phase == RefinePhase.thinking,
      ),
      actions: const SizedBox(width: double.infinity),
    );
  }
}
