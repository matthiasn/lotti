import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_month_calendar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/utils/device_region.dart';

/// Desktop-sidebar month calendar wired to the Daily OS Next state:
/// plan-day dots come from [dailyOsPlanDaysProvider]; tapping a day
/// selects it via [dailyOsNextSelectedDateProvider].
///
/// Rendered through the Daily OS destination's `expandedChildBuilder`,
/// so it only exists while Daily OS is the active tab — the already
/// visible Daily OS surface reacts to the selection directly.
class DailyOsSidebarCalendar extends ConsumerStatefulWidget {
  const DailyOsSidebarCalendar({super.key});

  @override
  ConsumerState<DailyOsSidebarCalendar> createState() =>
      _DailyOsSidebarCalendarState();
}

class _DailyOsSidebarCalendarState
    extends ConsumerState<DailyOsSidebarCalendar> {
  late DateTime _month;
  DateTime? _lastSelected;

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
    // Snap the visible month whenever the selection changes — from this
    // calendar or from any other surface (date strip, picker) — so the
    // selected day never sits off-screen. Plain field writes during
    // build: the widget is already rebuilding from the watch above.
    if (_lastSelected != selectedDay) {
      _lastSelected = selectedDay;
      _month = DateTime(selectedDay.year, selectedDay.month);
    }
    final markedDays =
        ref.watch(dailyOsPlanDaysProvider(_month)).value ?? const <DateTime>{};
    // Week-start follows the device region (US → Sunday, Europe → Monday),
    // resolved natively because macOS hides the region from Flutter's locale
    // APIs. Defaults to Monday while the async lookup resolves.
    final firstDayOfWeekIndex =
        ref.watch(firstDayOfWeekIndexProvider).value ?? (DateTime.monday % 7);

    // Indent to the nav rows' inner content padding so the month title
    // lines up with the destination icons instead of hugging the
    // sidebar's outer edge; the top inset gives the month title some
    // breathing room below the active DailyOS row.
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        0,
      ),
      child: SidebarMonthCalendar(
        month: _month,
        today: clock.now(),
        selectedDay: selectedDay,
        markedDays: markedDays,
        firstDayOfWeekIndex: firstDayOfWeekIndex,
        onPreviousMonth: () => _shiftMonth(-1),
        onNextMonth: () => _shiftMonth(1),
        onDaySelected: ref
            .read(dailyOsNextSelectedDateProvider.notifier)
            .select,
      ),
    );
  }
}
