import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:lotti/utils/first_day_of_week_picker.dart';

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

  Future<void> _pickDate() async {
    // Anchor the picker window to the current selection (not `_today`)
    // so the prev/next chevrons can never drift past `firstDate` or
    // `lastDate` and trip a `showDatePicker` assertion. Day arithmetic
    // via the `DateTime` constructor stays DST-safe.
    final selected = ref.read(dailyOsNextSelectedDateProvider);
    final firstDayOfWeekIndex = await ref.read(
      firstDayOfWeekIndexProvider.future,
    );
    if (!mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(
        selected.year - 1,
        selected.month,
        selected.day,
      ),
      lastDate: DateTime(
        selected.year + 1,
        selected.month,
        selected.day,
      ),
      builder: firstDayOfWeekPickerBuilder(firstDayOfWeekIndex),
    );
    if (picked != null) {
      ref.read(dailyOsNextSelectedDateProvider.notifier).select(picked);
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
    final strip = _DateStrip(
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
      onCheckIn: () => unawaited(
        showDayPlanningModal(
          context: context,
          dayDate: selectedDate,
          intent: const DayPlanningCreate(),
        ),
      ),
      dateStrip: strip,
    );
  }
}

/// Compact date strip — prev arrow, tappable date label that opens a
/// date picker, next arrow.
///
/// Layout is intentionally stable across dates: the same three
/// components render regardless of which day is selected, so chevrons
/// and the label never shift horizontally as the user navigates. The
/// picker is the way back to "today" (or any other day) — no separate
/// reset chip.
class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.selected,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  final DateTime selected;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final material = MaterialLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: material.previousPageTooltip,
          onPressed: onPrev,
        ),
        Flexible(
          child: InkWell(
            onTap: onPick,
            onLongPress: onToday,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step2,
              ),
              child: Text(
                _formatDate(
                  context,
                  selected,
                  isToday: isToday,
                  todayLabel: messages.dailyOsTodayButton,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: material.nextPageTooltip,
          onPressed: onNext,
        ),
      ],
    );
  }

  String _formatDate(
    BuildContext context,
    DateTime date, {
    required bool isToday,
    required String todayLabel,
  }) {
    if (isToday) return todayLabel;
    final locale = Localizations.localeOf(context).toString();
    // Weekday included on every concrete date in the Daily OS.
    return DateFormat.yMMMEd(locale).format(date);
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
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        ),
      ),
    );
  }
}
