import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_month_calendar.dart';

/// Desktop-sidebar month calendar wired to the Daily OS Next state:
/// plan-day dots come from [dailyOsPlanDaysProvider]; tapping a day
/// selects it via [dailyOsNextSelectedDateProvider] and asks the host
/// (via [onOpenDay]) to surface the Daily OS tab.
class DailyOsSidebarCalendar extends ConsumerStatefulWidget {
  const DailyOsSidebarCalendar({required this.onOpenDay, super.key});

  /// Called after the day selection is updated — the app shell uses
  /// this to switch to the Daily OS navigation tab.
  final ValueChanged<DateTime> onOpenDay;

  @override
  ConsumerState<DailyOsSidebarCalendar> createState() =>
      _DailyOsSidebarCalendarState();
}

class _DailyOsSidebarCalendarState
    extends ConsumerState<DailyOsSidebarCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final selected = ref.read(dailyOsNextSelectedDateProvider);
    _month = DateTime(selected.year, selected.month);
  }

  void _shiftMonth(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(dailyOsNextSelectedDateProvider);
    final markedDays =
        ref.watch(dailyOsPlanDaysProvider(_month)).value ?? const <DateTime>{};

    return SidebarMonthCalendar(
      month: _month,
      today: clock.now(),
      selectedDay: selectedDay,
      markedDays: markedDays,
      onPreviousMonth: () => _shiftMonth(-1),
      onNextMonth: () => _shiftMonth(1),
      onDaySelected: (day) {
        ref.read(dailyOsNextSelectedDateProvider.notifier).select(day);
        widget.onOpenDay(day);
      },
    );
  }
}
