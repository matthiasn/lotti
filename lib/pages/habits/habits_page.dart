import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/habits/habit_page_app_bar.dart';
import 'package:lotti/widgets/habits/habit_streaks.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

class HabitsTabPage extends StatelessWidget {
  const HabitsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final cubit = context.read<HabitsCubit>();
        final timeSpanDays = state.timeSpanDays;

        final rangeStart = getStartOfDay(
          DateTime.now().subtract(Duration(days: timeSpanDays - 1)),
        );

        final rangeEnd = getEndOfToday();
        final showGaps = timeSpanDays < 180;

        return Scaffold(
          appBar: const HabitsPageAppBar(),
          backgroundColor: styleConfig().negspace,
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                children: [
                  Center(
                    child: TimeSpanSegmentedControl(
                      timeSpanDays: timeSpanDays,
                      onValueChanged: cubit.setTimeSpan,
                    ),
                  ),
                  if (state.openNow.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        localizations.habitsOpenHeader,
                        style: chartTitleStyle(),
                      ),
                    ),
                  const SizedBox(height: 15),
                  ...state.openNow.map((habitDefinition) {
                    return HabitChartLine(
                      habitDefinition: habitDefinition,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      showGaps: showGaps,
                    );
                  }),
                  if (state.completed.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        localizations.habitsCompletedHeader,
                        style: chartTitleStyle(),
                      ),
                    ),
                  const SizedBox(height: 15),
                  ...state.completed.map((habitDefinition) {
                    return HabitChartLine(
                      habitDefinition: habitDefinition,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      showGaps: showGaps,
                    );
                  }),
                  if (state.pendingLater.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        localizations.habitsPendingLaterHeader,
                        style: chartTitleStyle(),
                      ),
                    ),
                  const SizedBox(height: 15),
                  ...state.pendingLater.map((habitDefinition) {
                    return HabitChartLine(
                      habitDefinition: habitDefinition,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      showGaps: showGaps,
                    );
                  }),
                  const SizedBox(height: 20),
                  const HabitStreaksCounter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
