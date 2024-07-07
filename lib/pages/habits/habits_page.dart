import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/habit_page_app_bar.dart';
import 'package:lotti/widgets/app_bar/sliver_title_bar.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/habits/habit_completion_card.dart';
import 'package:lotti/widgets/habits/habit_streaks.dart';
import 'package:lotti/widgets/habits/habits_search.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:visibility_detector/visibility_detector.dart';

class HabitsTabPage extends StatelessWidget {
  const HabitsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HabitsCubit>();

    return VisibilityDetector(
      key: const Key('habits_page'),
      onVisibilityChanged: cubit.updateVisibility,
      child: BlocBuilder<HabitsCubit, HabitsState>(
        builder: (context, HabitsState state) {
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

          final openNow =
              state.showSearch ? filterMatching(state.openNow) : state.openNow;

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

          return Scaffold(
            body: SafeArea(
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverTitleBar(context.messages.settingsHabitsTitle),
                  const HabitsSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        children: [
                          if (state.showTimeSpan)
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: TimeSpanSegmentedControl(
                                  timeSpanDays: timeSpanDays,
                                  onValueChanged: cubit.setTimeSpan,
                                ),
                              ),
                            ),
                          if (state.showSearch) const HabitsSearchWidget(),
                          const SizedBox(height: 20),
                          if (showAll)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: Text(
                                context.messages.habitsOpenHeader,
                                style: chartTitleStyle,
                              ),
                            ),
                          if (showOpenNow && state.isVisible)
                            ...openNow.map((habitDefinition) {
                              return HabitCompletionCard(
                                habitDefinition: habitDefinition,
                                rangeStart: rangeStart,
                                rangeEnd: rangeEnd,
                                showGaps: showGaps,
                              );
                            }),
                          if (showAll)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 20, bottom: 15),
                              child: Text(
                                context.messages.habitsPendingLaterHeader,
                                style: chartTitleStyle,
                              ),
                            ),
                          if (showPendingLater && state.isVisible)
                            ...pendingLater.map((habitDefinition) {
                              return HabitCompletionCard(
                                habitDefinition: habitDefinition,
                                rangeStart: rangeStart,
                                rangeEnd: rangeEnd,
                                showGaps: showGaps,
                              );
                            }),
                          if (showAll)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 20, bottom: 15),
                              child: Text(
                                context.messages.habitsCompletedHeader,
                                style: chartTitleStyle,
                              ),
                            ),
                          if (showCompleted && state.isVisible)
                            ...completed.map((habitDefinition) {
                              return HabitCompletionCard(
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
