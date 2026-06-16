import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/features/habits/ui/widgets/habits_header.dart';
import 'package:lotti/features/habits/ui/widgets/habits_search.dart';
import 'package:lotti/features/habits/ui/widgets/habits_section_header.dart';
import 'package:lotti/features/habits/ui/widgets/habits_summary_card.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Top-level habits tab: a [CustomScrollView] on the calm [dsPageSurface]
/// canvas, driven by [HabitsController].
///
/// Renders, in order, a [HabitsHeader] (title + status filter + tools), a
/// [HabitsSummaryCard] (today's progress + streaks), the optional
/// [HabitsSearchWidget], the three habit buckets — open now, pending later,
/// completed — each a list of [HabitCompletionCard]s grouped under a
/// [HabitsSectionHeader] in the `all` filter, and finally the [HabitsChartCard].
/// The visible buckets depend on the active [HabitDisplayFilter]; when search is
/// active each bucket is filtered by a name/description substring match against
/// `state.searchString`. Content is centred on a reading-width column on wide
/// windows, and scroll activity is reported to the `UserActivityService`.
class HabitsTabPage extends ConsumerStatefulWidget {
  const HabitsTabPage({super.key});

  @override
  ConsumerState<HabitsTabPage> createState() => _HabitsTabPageState();
}

class _HabitsTabPageState extends ConsumerState<HabitsTabPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(habitsControllerProvider);

    // Centre the content on a comfortable reading column on wide windows so the
    // rows don't stretch edge-to-edge into a sparse, low-density desktop layout.
    const maxContentWidth = 720.0;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width > maxContentWidth + tokens.spacing.step6 * 2
        ? (width - maxContentWidth) / 2
        : tokens.spacing.step6;

    final timeSpanDays = state.timeSpanDays;
    final rangeStart = DateTime.now().dayAtMidnight.subtract(
      Duration(days: timeSpanDays - 1),
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
                item.description.toLowerCase().contains(state.searchString),
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

    final showOpenNow =
        openNow.isNotEmpty &&
        (displayFilter == HabitDisplayFilter.openNow || showAll);
    final showCompleted =
        completed.isNotEmpty &&
        (displayFilter == HabitDisplayFilter.completed || showAll);
    final showPendingLater =
        pendingLater.isNotEmpty &&
        (displayFilter == HabitDisplayFilter.pendingLater || showAll);

    HabitCompletionCard buildCard(HabitDefinition habitDefinition) {
      return HabitCompletionCard(
        key: Key(habitDefinition.id),
        habitId: habitDefinition.id,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        showGaps: showGaps,
      );
    }

    return Scaffold(
      backgroundColor: dsPageSurface(context),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: tokens.spacing.step5,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const HabitsHeader(),
                  SizedBox(height: tokens.spacing.sectionGap),
                  const HabitsSummaryCard(),
                  if (state.showSearch) ...[
                    SizedBox(height: tokens.spacing.step4),
                    const HabitsSearchWidget(),
                  ],
                  if (showOpenNow) ...[
                    if (showAll)
                      HabitsSectionHeader(
                        label: messages.habitsOpenHeader,
                        count: openNow.length,
                      )
                    else
                      SizedBox(height: tokens.spacing.step5),
                    ...openNow.map(buildCard),
                  ],
                  if (showPendingLater) ...[
                    if (showAll)
                      HabitsSectionHeader(
                        label: messages.habitsPendingLaterHeader,
                        count: pendingLater.length,
                      )
                    else
                      SizedBox(height: tokens.spacing.step5),
                    ...pendingLater.map(buildCard),
                  ],
                  if (showCompleted) ...[
                    if (showAll)
                      HabitsSectionHeader(
                        label: messages.habitsCompletedHeader,
                        count: completed.length,
                      )
                    else
                      SizedBox(height: tokens.spacing.step5),
                    ...completed.map(buildCard),
                  ],
                  SizedBox(height: tokens.spacing.sectionGap),
                  const HabitsChartCard(),
                  SizedBox(height: tokens.spacing.step6),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
