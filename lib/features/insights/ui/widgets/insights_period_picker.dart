import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_month_calendar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Opens the "jump to a date" calendar sheet for Time Analysis.
///
/// Picking a day snaps the dashboard to the period (of the current
/// granularity) that contains it. The sheet stays open and the page updates
/// live behind the dimmed scrim, so you can browse days and watch the data
/// change without dismissing — close with the sheet's button or the barrier.
Future<void> showInsightsPeriodPicker({required BuildContext context}) {
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.insightsPeriodJump,
    builder: (_) => const InsightsPeriodPickerBody(),
  );
}

/// Calendar body of the period picker. Public for widget testing.
class InsightsPeriodPickerBody extends ConsumerStatefulWidget {
  const InsightsPeriodPickerBody({super.key});

  @override
  ConsumerState<InsightsPeriodPickerBody> createState() =>
      _InsightsPeriodPickerBodyState();
}

class _InsightsPeriodPickerBodyState
    extends ConsumerState<InsightsPeriodPickerBody> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final start = dayStart(
      ref.read(insightsRangeControllerProvider).range.startDay,
    );
    _month = DateTime(start.year, start.month);
  }

  void _shiftMonth(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final selectedStart = dayStart(
      ref.watch(insightsRangeControllerProvider).range.startDay,
    );
    // Same region-aware first weekday as the period weeks and the rest of
    // the app (Monday in Europe, Sunday in the US).
    final firstDayOfWeekIndex =
        ref.watch(firstDayOfWeekIndexProvider).value ??
        defaultFirstDayOfWeekIndex;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
          child: SidebarMonthCalendar(
            month: _month,
            today: clock.now(),
            selectedDay: selectedStart,
            firstDayOfWeekIndex: firstDayOfWeekIndex,
            onPreviousMonth: () => _shiftMonth(-1),
            onNextMonth: () => _shiftMonth(1),
            onDaySelected: (day) {
              ref.read(insightsRangeControllerProvider.notifier).jumpTo(day);
            },
          ),
        ),
      ),
    );
  }
}
