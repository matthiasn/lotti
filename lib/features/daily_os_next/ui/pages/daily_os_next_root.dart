import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Entry point for the Daily OS Next surface.
///
/// Routes between [CapturePage] (no drafted plan yet) and [DayPage]
/// (plan exists) based on the currently selected date. Surfaces a
/// small date picker on both paths so the user can choose the day
/// before recording the planning capture.
class DailyOsNextRoot extends ConsumerStatefulWidget {
  const DailyOsNextRoot({super.key});

  @override
  ConsumerState<DailyOsNextRoot> createState() => _DailyOsNextRootState();
}

class _DailyOsNextRootState extends ConsumerState<DailyOsNextRoot> {
  /// Set when the user taps the empty Day surface's "Speak a check-in"
  /// CTA — forces Capture even though the day has tracked time.
  /// Cleared whenever the selected date changes.
  bool _checkInRequested = false;

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
    // month calendar can drive it; the check-in override resets on
    // every selection change.
    ref.listen(dailyOsNextSelectedDateProvider, (previous, next) {
      if (previous != next && _checkInRequested) {
        setState(() => _checkInRequested = false);
      }
    });
    final selectedDate = ref.watch(dailyOsNextSelectedDateProvider);
    final asyncPlan = ref.watch(currentDraftPlanProvider(selectedDate));
    if (asyncPlan.hasValue) {
      final plan = asyncPlan.requireValue;
      if (plan != null) return _buildSurface(selectedDate, plan);

      final actualBlocks = ref.watch(
        dailyOsActualTimeBlocksProvider(selectedDate),
      );
      return _buildSurface(
        selectedDate,
        null,
        actualBlocks: actualBlocks.value ?? const [],
      );
    }
    if (asyncPlan.hasError) return _ErrorShell(error: '${asyncPlan.error}');
    return const _LoadingShell();
  }

  Widget _buildSurface(
    DateTime selectedDate,
    DraftPlan? plan, {
    List<TimeBlock> actualBlocks = const [],
  }) {
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
    // No plan, but the day already has tracked time — land on the Day
    // surface in its empty mode so the recorded sessions are visible
    // on the timeline without creating a plan first (handoff v2 item
    // 2). The footer CTA routes into Capture.
    if (actualBlocks.isNotEmpty && !_checkInRequested) {
      return DayPage(
        key: ValueKey('empty-${selectedDate.toIso8601String()}'),
        draft: DraftPlan.emptyForDay(selectedDate),
        hasPlan: false,
        onCheckIn: () => setState(() => _checkInRequested = true),
        dateStrip: strip,
      );
    }
    // No plan for the selected date — drop into Capture so the
    // user can start one for that day. Capture is keyed on
    // [selectedDate] so the submitted capture lands on the
    // chosen day's day-agent.
    return CapturePage(
      key: ValueKey('capture-${selectedDate.toIso8601String()}'),
      forDate: selectedDate,
      actualBlocks: actualBlocks,
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
    return DateFormat.yMMMd(locale).format(date);
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
