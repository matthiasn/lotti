import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
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
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;

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
  Future<void> _runCheckIn(DateTime date) async {
    final setupStatus = await ref.read(dailyOsSetupStatusProvider.future);
    if (!mounted) return;
    if (!setupStatus.hasInferenceRoute) {
      nav_service.beamToNamed('/settings/daily-os');
      return;
    }
    final result = await showDayPlanningModal(
      context: context,
      dayDate: date,
      intent: const DayPlanningCreate(),
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

  /// Opens the design-system date picker.
  ///
  /// The shared modal carries its own "Today" quick action in the header,
  /// which is what lets the phone header drop the standalone Today button
  /// without losing the way back to today.
  /// Opens the shared Daily OS date picker and applies the pick.
  Future<void> _pickDate() async {
    final selected = ref.read(dailyOsNextSelectedDateProvider);
    final date = await showDailyOsDayPicker(context, selected: selected);
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
    // The footer CTA opens the day-planning modal (Capture → Reconcile →
    // Drafting), a full-height layer that covers the bottom nav.
    return DayPage(
      key: ValueKey('empty-${selectedDate.toIso8601String()}'),
      draft: DraftPlan.emptyForDay(selectedDate),
      hasPlan: false,
      onCheckIn: () => unawaited(_runCheckIn(selectedDate)),
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
