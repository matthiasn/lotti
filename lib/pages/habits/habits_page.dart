import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/charts/dashboard_habits_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class HabitsTabPage extends StatefulWidget {
  const HabitsTabPage({super.key});

  @override
  State<HabitsTabPage> createState() => _HabitsTabPageState();
}

class _HabitsTabPageState extends State<HabitsTabPage> {
  @override
  void initState() {
    super.initState();
  }

  int timeSpanDays = isDesktop ? 14 : 7;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final rangeStart = getStartOfDay(
          DateTime.now().subtract(Duration(days: timeSpanDays - 1)),
        );

        final rangeEnd = getEndOfToday();

        final landscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        final showGaps = timeSpanDays < 180;

        return Scaffold(
          appBar: HabitsPageAppBar(),
          backgroundColor: styleConfig().negspace,
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
                top: 5,
              ),
              child: Column(
                children: [
                  Center(
                    child: CupertinoSegmentedControl(
                      selectedColor: styleConfig().primaryColor,
                      unselectedColor: styleConfig().negspace,
                      borderColor: styleConfig().primaryColor,
                      groupValue: timeSpanDays,
                      onValueChanged: (int value) {
                        setState(() {
                          timeSpanDays = value;
                        });
                      },
                      children: {
                        if (isMobile) 7: const DaysSegment('7'),
                        14: const DaysSegment('14'),
                        30: const DaysSegment('30'),
                        90: const DaysSegment('90'),
                        if (isDesktop || landscape)
                          180: const DaysSegment('180'),
                      },
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
                      habitId: habitDefinition.id,
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
                      habitId: habitDefinition.id,
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
                      habitId: habitDefinition.id,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      showGaps: showGaps,
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      localizations.habitsShortStreaksHeader,
                      style: chartTitleStyle(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ...state.habitDefinitions.map((habitDefinition) {
                    return HabitChartLine(
                      habitId: habitDefinition.id,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      streakDuration: 2,
                      showGaps: showGaps,
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      localizations.habitsLongerStreaksHeader,
                      style: chartTitleStyle(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ...state.habitDefinitions.map((habitDefinition) {
                    return HabitChartLine(
                      habitId: habitDefinition.id,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      streakDuration: 6,
                      showGaps: days < 180,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class HabitsPageAppBar extends StatelessWidget with PreferredSizeWidget {
  HabitsPageAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final title = localizations.settingsHabitsTitle;

    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final total = state.habitDefinitions.length;
        final todayCount = state.completedToday.length;

        final habitCounters =
            '($total / $todayCount / ${state.shortStreakCount} / ${state.longStreakCount})';

        return TitleAppBar(
          title: '$title $habitCounters',
          showBackButton: false,
        );
      },
    );
  }
}
