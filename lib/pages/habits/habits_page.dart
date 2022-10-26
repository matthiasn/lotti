import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
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

    return StreamBuilder<List<HabitDefinition>>(
      stream: getIt<JournalDb>().watchHabitDefinitions(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<HabitDefinition>> snapshot,
      ) {
        final rangeStart = getStartOfDay(
          DateTime.now().subtract(Duration(days: timeSpanDays - 1)),
        );

        final rangeEnd = getEndOfToday();
        final habitItems = snapshot.data ?? [];

        final landscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        return StreamBuilder<List<JournalEntity>>(
          stream: getIt<JournalDb>().watchHabitCompletionsInRange(
            rangeStart: getStartOfDay(DateTime.now()),
            rangeEnd: rangeEnd,
          ),
          builder: (context, completionsSnapshot) {
            final completedToday = <String>{};

            completionsSnapshot.data?.forEach((item) {
              if (item is HabitCompletionEntry) {
                completedToday.add(item.data.habitId);
              }
            });

            final openHabits = habitItems
                .where((item) => !completedToday.contains(item.id))
                .sorted(habitSorter);

            final openNow = openHabits.where(showHabit);
            final pendingLater = openHabits.where((item) => !showHabit(item));

            final completedHabits = habitItems
                .where((item) => completedToday.contains(item.id))
                .sorted(habitSorter);

            final showGaps = timeSpanDays < 180;

            return Scaffold(
              appBar: HabitsPageAppBar(
                habitItems: habitItems,
                completedToday: completedToday,
              ),
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
                      if (openNow.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            localizations.habitsOpenHeader,
                            style: chartTitleStyle(),
                          ),
                        ),
                      const SizedBox(height: 15),
                      ...openNow.map((habitDefinition) {
                        return HabitChartLine(
                          habitId: habitDefinition.id,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                          showGaps: showGaps,
                        );
                      }),
                      if (completedHabits.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            localizations.habitsCompletedHeader,
                            style: chartTitleStyle(),
                          ),
                        ),
                      const SizedBox(height: 15),
                      ...completedHabits.map((habitDefinition) {
                        return HabitChartLine(
                          habitId: habitDefinition.id,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                          showGaps: showGaps,
                        );
                      }),
                      if (pendingLater.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            localizations.habitsPendingLaterHeader,
                            style: chartTitleStyle(),
                          ),
                        ),
                      const SizedBox(height: 15),
                      ...pendingLater.map((habitDefinition) {
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
                      ...habitItems.map((habitDefinition) {
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
                      ...habitItems.map((habitDefinition) {
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
      },
    );
  }
}

class HabitsPageAppBar extends StatelessWidget with PreferredSizeWidget {
  HabitsPageAppBar({
    required this.habitItems,
    required this.completedToday,
    super.key,
  });

  final List<HabitDefinition> habitItems;
  final Set<String> completedToday;

  final rangeStart = getStartOfDay(
    DateTime.now().subtract(const Duration(days: 7)),
  );

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final title = localizations.settingsHabitsTitle;
    final total = habitItems.length;
    final todayCount = completedToday.length;

    final rangeStart = getStartOfDay(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    final rangeEnd = getEndOfToday();

    return StreamBuilder<List<JournalEntity>>(
      stream: getIt<JournalDb>().watchHabitCompletionsInRange(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
      builder: (context, completionsSnapshot) {
        final now = DateTime.now();
        final shortStreakDays = daysInRange(
          rangeStart: now.subtract(const Duration(days: 3)),
          rangeEnd: now,
        );

        final longStreakDays = daysInRange(
          rangeStart: now.subtract(const Duration(days: 7)),
          rangeEnd: now,
        );

        final habitSuccessDays = <String, Set<String>>{};

        completionsSnapshot.data?.forEach((item) {
          if (item is HabitCompletionEntry &&
              (item.data.completionType == HabitCompletionType.success ||
                  item.data.completionType == HabitCompletionType.skip ||
                  item.data.completionType == null)) {
            final day = ymd(item.meta.dateFrom);
            final successDays =
                habitSuccessDays[item.data.habitId] ?? <String>{}
                  ..add(day);
            habitSuccessDays[item.data.habitId] = successDays;
          }
        });

        var shortStreakCount = 0;
        var longStreakCount = 0;

        habitSuccessDays.forEach((habitId, days) {
          if (days.containsAll(shortStreakDays)) {
            shortStreakCount++;
          }

          if (days.containsAll(longStreakDays)) {
            longStreakCount++;
          }
        });

        final habitCounters =
            '($total / $todayCount / $shortStreakCount / $longStreakCount)';

        return TitleAppBar(
          title: '$title $habitCounters',
          showBackButton: false,
        );
      },
    );
  }
}
