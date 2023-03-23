import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/habits/habit_completion_card.dart';
import 'package:lotti/widgets/habits/habit_page_app_bar.dart';
import 'package:lotti/widgets/habits/habit_streaks.dart';
import 'package:lotti/widgets/habits/habits_filter.dart';
import 'package:lotti/widgets/habits/status_segmented_control.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

class HabitsTabPage extends StatelessWidget {
  const HabitsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<CategoryDefinition>>(
      stream: getIt<JournalDb>().watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? <CategoryDefinition>[];
        final categoriesById = <String, CategoryDefinition>{};

        for (final category in categories) {
          categoriesById[category.id] = category;
        }

        return BlocBuilder<HabitsCubit, HabitsState>(
          builder: (context, HabitsState state) {
            final cubit = context.read<HabitsCubit>();
            final timeSpanDays = state.timeSpanDays;

            final rangeStart = getStartOfDay(
              DateTime.now().subtract(Duration(days: timeSpanDays - 1)),
            );

            final rangeEnd = getEndOfToday();
            final showGaps = timeSpanDays < 180;

            final displayFilter = state.displayFilter;
            final showAll = displayFilter == HabitDisplayFilter.all;

            List<HabitDefinition> filterMatching(List<HabitDefinition> items) {
              return items
                  .where(
                    (item) =>
                        item.name.toLowerCase().contains(state.searchString) ||
                        item.description
                            .toLowerCase()
                            .contains(state.searchString),
                  )
                  .toList();
            }

            final openNow = state.showSearch
                ? filterMatching(state.openNow)
                : state.openNow;

            final completed = state.showSearch
                ? filterMatching(state.completed)
                : state.completed;

            final pendingLater = state.showSearch
                ? filterMatching(state.pendingLater)
                : state.pendingLater;

            final showOpenNow = openNow.isNotEmpty &&
                (displayFilter == HabitDisplayFilter.openNow || showAll);
            final showCompleted = completed.isNotEmpty &&
                (displayFilter == HabitDisplayFilter.completed || showAll);
            final showPendingLater = pendingLater.isNotEmpty &&
                (displayFilter == HabitDisplayFilter.pendingLater || showAll);

            final styleActive = searchFieldStyle();
            final styleHint = searchFieldHintStyle();
            final style = state.searchString.isEmpty ? styleHint : styleActive;

            return Scaffold(
              appBar: const HabitsPageAppBar(),
              backgroundColor: styleConfig().negspace,
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          HabitStatusSegmentedControl(
                            filter: state.displayFilter,
                            onValueChanged: cubit.setDisplayFilter,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: cubit.toggleShowSearch,
                                icon: Icon(
                                  Icons.search,
                                  color: state.showSearch
                                      ? styleConfig().primaryColor
                                      : styleConfig().secondaryTextColor,
                                ),
                              ),
                              IconButton(
                                onPressed: cubit.toggleShowTimeSpan,
                                icon: Icon(
                                  Icons.calendar_month,
                                  color: state.showTimeSpan
                                      ? styleConfig().primaryColor
                                      : styleConfig().secondaryTextColor,
                                ),
                              ),
                              const HabitsFilter(),
                            ],
                          ),
                        ],
                      ),
                      if (state.showTimeSpan)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: TimeSpanSegmentedControl(
                              timeSpanDays: timeSpanDays,
                              onValueChanged: cubit.setTimeSpan,
                            ),
                          ),
                        ),
                      if (state.showSearch)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: styleConfig()
                                    .secondaryTextColor
                                    .withOpacity(0.4),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: TextField(
                                decoration: InputDecoration(
                                  icon: Icon(Icons.search, color: style.color),
                                  suffixIcon: GestureDetector(
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: style.color,
                                    ),
                                    onTap: () {
                                      cubit.setSearchString('');
                                      FocusScope.of(context)
                                          .requestFocus(FocusNode());
                                    },
                                  ),
                                  hintText: localizations.habitsSearchHint,
                                  hintStyle: style,
                                  border: InputBorder.none,
                                ),
                                style: style,
                                onChanged: cubit.setSearchString,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (showAll)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Text(
                            localizations.habitsOpenHeader,
                            style: chartTitleStyle(),
                          ),
                        ),
                      if (showOpenNow)
                        ...openNow.map((habitDefinition) {
                          final category =
                              categoriesById[habitDefinition.categoryId];

                          return HabitCompletionCard(
                            habitDefinition: habitDefinition,
                            rangeStart: rangeStart,
                            rangeEnd: rangeEnd,
                            showGaps: showGaps,
                            category: category,
                          );
                        }),
                      if (showAll)
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 15),
                          child: Text(
                            localizations.habitsPendingLaterHeader,
                            style: chartTitleStyle(),
                          ),
                        ),
                      if (showPendingLater)
                        ...pendingLater.map((habitDefinition) {
                          final category =
                              categoriesById[habitDefinition.categoryId];

                          return HabitCompletionCard(
                            habitDefinition: habitDefinition,
                            rangeStart: rangeStart,
                            rangeEnd: rangeEnd,
                            showGaps: showGaps,
                            category: category,
                          );
                        }),
                      if (showAll)
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 15),
                          child: Text(
                            localizations.habitsCompletedHeader,
                            style: chartTitleStyle(),
                          ),
                        ),
                      if (showCompleted)
                        ...completed.map((habitDefinition) {
                          final category =
                              categoriesById[habitDefinition.categoryId];

                          return HabitCompletionCard(
                            habitDefinition: habitDefinition,
                            rangeStart: rangeStart,
                            rangeEnd: rangeEnd,
                            showGaps: showGaps,
                            category: category,
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
      },
    );
  }
}
