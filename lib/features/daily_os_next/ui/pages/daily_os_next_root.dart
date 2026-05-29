import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
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
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = clock.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  DateTime get _today {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday => _selectedDate.isAtSameMomentAs(_today);

  void _shiftDay(int days) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + days,
      );
    });
  }

  Future<void> _pickDate() async {
    // Anchor the picker window to the current selection (not `_today`)
    // so the prev/next chevrons can never drift past `firstDate` or
    // `lastDate` and trip a `showDatePicker` assertion. Day arithmetic
    // via the `DateTime` constructor stays DST-safe.
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(
        _selectedDate.year - 1,
        _selectedDate.month,
        _selectedDate.day,
      ),
      lastDate: DateTime(
        _selectedDate.year + 1,
        _selectedDate.month,
        _selectedDate.day,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _goToToday() {
    setState(() => _selectedDate = _today);
  }

  @override
  Widget build(BuildContext context) {
    final asyncPlan = ref.watch(currentDraftPlanProvider(_selectedDate));
    if (asyncPlan.hasValue) return _buildSurface(asyncPlan.requireValue);
    if (asyncPlan.hasError) return _ErrorShell(error: '${asyncPlan.error}');
    return const _LoadingShell();
  }

  Widget _buildSurface(DraftPlan? plan) {
    final strip = _DateStrip(
      selected: _selectedDate,
      isToday: _isToday,
      onPrev: () => _shiftDay(-1),
      onNext: () => _shiftDay(1),
      onPick: _pickDate,
      onToday: _goToToday,
    );
    if (plan != null) {
      return DayPage(
        key: ValueKey(_selectedDate.toIso8601String()),
        draft: plan,
        dateStrip: strip,
      );
    }
    // No plan for the selected date — drop into Capture so the
    // user can start one for that day. Capture is keyed on
    // [_selectedDate] so the submitted capture lands on the
    // chosen day's day-agent.
    return CapturePage(
      key: ValueKey('capture-${_selectedDate.toIso8601String()}'),
      forDate: _selectedDate,
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
