import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_result.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_date_strip.dart';
import 'package:lotti/features/daily_os_next/util/day_arithmetic.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:material_ui/material_ui.dart';

/// Entry point for the Daily OS Next surface.
///
/// Shows the [DayPage] for the selected date: the real plan when one
/// exists, otherwise the empty Day surface (its timeline still reflects
/// any tracked time) whose footer CTA opens the day-planning modal
/// ([showDayPlanningModal]) for the Capture → Reconcile → Drafting ritual.
/// A small date strip lets the user pick the day first.
class DailyOsNextRoot extends ConsumerStatefulWidget {
  const DailyOsNextRoot({super.key});

  @override
  ConsumerState<DailyOsNextRoot> createState() => _DailyOsNextRootState();
}

class _DailyOsNextRootState extends ConsumerState<DailyOsNextRoot> {
  DateTime get _today {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _shiftDay(int days) {
    ref.read(dailyOsNextSelectedDateProvider.notifier).shiftDays(days);
  }

  /// Opens the create ritual and routes its typed outcome through the Daily OS
  /// onboarding session controller.
  ///
  /// For an ordinary user (no active walkthrough session) both branches are
  /// no-ops — `complete`/`dismiss` return immediately — so this behaves exactly
  /// like the previous fire-and-forget open. During a walkthrough it records
  /// completion (retiring the auto-show cadence) or a dismissal skip.
  Future<void> _runCheckIn(
    DateTime date, {
    DayPlanningIntent intent = const DayPlanningCreate(),
  }) async {
    if (!await _hasInferenceRoute()) return;
    if (!mounted) return;
    final result = await showDayPlanningModal(
      context: context,
      dayDate: date,
      intent: intent,
    );
    if (!mounted) return;
    final controller = ref.read(
      dailyOsOnboardingSessionControllerProvider.notifier,
    );
    if (result is DayPlanningCreated) {
      await controller.complete(createdTaskIds: result.createdTaskIds);
    } else {
      controller.dismiss();
    }
  }

  /// Whether Daily OS can plan at all; sends the user to its settings when it
  /// cannot (the route was lost after the Day surface rendered).
  Future<bool> _hasInferenceRoute() async {
    final setupStatus = await ref.read(dailyOsSetupStatusProvider.future);
    if (setupStatus.hasInferenceRoute) return true;
    nav_service.beamToNamed('/settings/daily-os');
    return false;
  }

  /// Continues a check-in spoken or typed into the Day composer: submits it
  /// as a capture for [date] — with the recording behind it, when spoken —
  /// and opens the planning sheet straight at Reconcile. The composer was
  /// the capture, so there is no Capture step in front of it.
  ///
  /// A submit that fails leaves the words in the composer and says so.
  Future<void> _submitCheckIn(
    DateTime date,
    String transcript, {
    String? audioId,
  }) async {
    if (!await _hasInferenceRoute()) return;
    final CaptureId captureId;
    try {
      captureId = await ref
          .read(dayAgentProvider)
          .submitCapture(
            transcript: transcript,
            capturedAt: capturedAtForDay(date, clock.now()),
            dayDate: date,
            audioId: audioId,
          );
    } on Object {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.dailyOsNextGenericError,
        );
      }
      return;
    }
    if (!mounted) return;
    await _runCheckIn(date, intent: DayPlanningReconcile(captureId));
  }

  /// Opens the design-system date picker.
  ///
  /// Opens the shared Daily OS date picker and applies the pick. The
  /// picker window and its own Today quick action are documented on
  /// [showDailyOsDayPicker].
  Future<void> _pickDate() async {
    final selected = ref.read(dailyOsNextSelectedDateProvider);
    final date = await showDailyOsDayPicker(context, selected: selected);
    // The surface can be torn down while the sheet is up (tab switch,
    // sign-out); a `ref.read` on a disposed state would throw.
    if (!mounted) return;
    if (date != null) {
      ref.read(dailyOsNextSelectedDateProvider.notifier).select(date);
    }
  }

  void _goToToday() {
    ref.read(dailyOsNextSelectedDateProvider.notifier).goToToday();
  }

  @override
  Widget build(BuildContext context) {
    // Day selection lives in a provider so the desktop sidebar's
    // month calendar can drive it.
    final selectedDate = ref.watch(dailyOsNextSelectedDateProvider);
    final asyncPlan = ref.watch(currentDraftPlanProvider(selectedDate));
    if (asyncPlan.hasValue) {
      return _buildSurface(selectedDate, asyncPlan.requireValue);
    }
    if (asyncPlan.hasError) return _ErrorShell(error: '${asyncPlan.error}');
    return const _LoadingShell();
  }

  Widget _buildSurface(DateTime selectedDate, DraftPlan? plan) {
    final strip = DailyOsDateStrip(
      selected: selectedDate,
      isToday: selectedDate.isAtSameMomentAs(_today),
      onPrev: () => _shiftDay(-1),
      onNext: () => _shiftDay(1),
      onPick: _pickDate,
      onToday: _goToToday,
    );
    if (plan != null) {
      return DayPage(
        key: ValueKey(selectedDate.toIso8601String()),
        draft: plan,
        dateStrip: strip,
      );
    }
    // No plan for the selected date — show the Day surface in its empty
    // mode so any recorded sessions are still visible on the timeline.
    // The footer composer is the check-in; sending it opens the planning
    // sheet at Reconcile → Drafting, a full-height layer over the bottom nav.
    // The onboarding spotlight still opens the whole ritual from Capture.
    return DayPage(
      key: ValueKey('empty-${selectedDate.toIso8601String()}'),
      draft: DraftPlan.emptyForDay(selectedDate),
      hasPlan: false,
      onCheckIn: () => unawaited(_runCheckIn(selectedDate)),
      onSubmitCheckIn: (words, {audioId}) =>
          _submitCheckIn(selectedDate, words, audioId: audioId),
      dateStrip: strip,
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorShell extends StatelessWidget {
  const _ErrorShell({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step6),
          child: Text(
            error,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.ink,
            ),
          ),
        ),
      ),
    );
  }
}
