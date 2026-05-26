import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Entry point for the Daily OS Next surface.
///
/// Routes between [CapturePage] (no drafted plan yet) and [DayPage]
/// (plan exists) based on the currently selected date. Surfaces a
/// small date picker on the Day path so the user can jump to past
/// days they already drafted plans for.
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
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday => _selectedDate.isAtSameMomentAs(_today);

  void _shiftDay(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _today.subtract(const Duration(days: 365)),
      lastDate: _today.add(const Duration(days: 365)),
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
    return asyncPlan.when(
      loading: () => const _LoadingShell(),
      error: (e, _) => _ErrorShell(error: '$e'),
      data: (plan) {
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
          forDate: _isToday ? null : _selectedDate,
          dateStrip: _isToday ? null : strip,
        );
      },
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous day',
          onPressed: onPrev,
        ),
        InkWell(
          onTap: onPick,
          onLongPress: onToday,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step3,
              vertical: tokens.spacing.step2,
            ),
            child: Text(
              _formatDate(selected, isToday: isToday),
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next day',
          onPressed: onNext,
        ),
      ],
    );
  }

  String _formatDate(DateTime date, {required bool isToday}) {
    if (isToday) return 'Today';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
