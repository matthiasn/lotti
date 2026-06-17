import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/features/habits/ui/widgets/habits_header.dart';
import 'package:lotti/features/habits/ui/widgets/habits_search.dart';
import 'package:lotti/features/habits/ui/widgets/habits_section_header.dart';
import 'package:lotti/features/habits/ui/widgets/habits_summary_card.dart';
import 'package:lotti/features/habits/ui/widgets/heatmap/habit_heatmap_card.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Top-level habits tab: a dashboard on the calm [dsPageSurface] canvas, driven
/// by [HabitsController].
///
/// Renders, in order, a [HabitsHeader] (title + status filter + tools), a
/// [HabitsSummaryCard] (today's progress + streaks), the optional
/// [HabitsSearchWidget], the three habit buckets — open now, pending later,
/// completed — as lean single-column [HabitActionRow]s grouped under a
/// [HabitsSectionHeader] in the `all` filter, then the dashboard band: the
/// scrollable [HabitHeatmapCard] (rendered full-width so it can use the whole
/// window) and the [HabitsChartCard]. Each action row's done-state comes from
/// the controller's `successfulToday` bucket and its streak chip from the
/// heatmap controller's deep-history `streaksByHabit`. The reading content is
/// centred on a comfortable column on wide windows; the heatmap band spans the
/// full width. Scroll activity is reported to the `UserActivityService`.
class HabitsTabPage extends ConsumerStatefulWidget {
  const HabitsTabPage({super.key});

  @override
  ConsumerState<HabitsTabPage> createState() => _HabitsTabPageState();
}

class _HabitsTabPageState extends ConsumerState<HabitsTabPage> {
  final _scrollController = ScrollController();

  /// The reading content (header, summary, list, chart) is centred on this
  /// column on wide windows; the heatmap band breaks out to the full width.
  static const _maxReadingWidth = 820.0;

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
    final streaks = ref.watch(habitHeatmapControllerProvider).streaksByHabit;

    final width = MediaQuery.sizeOf(context).width;
    final readingPadding = width > _maxReadingWidth + tokens.spacing.step6 * 2
        ? (width - _maxReadingWidth) / 2
        : tokens.spacing.step6;
    final bandPadding = tokens.spacing.step6;

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

    HabitActionRow buildRow(HabitDefinition habitDefinition) {
      return HabitActionRow(
        key: Key(habitDefinition.id),
        habitId: habitDefinition.id,
        completedToday: state.successfulToday.contains(habitDefinition.id),
        currentStreak: streaks[habitDefinition.id] ?? 0,
      );
    }

    return Scaffold(
      backgroundColor: dsPageSurface(context),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                readingPadding,
                tokens.spacing.step5,
                readingPadding,
                0,
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
                    ...openNow.map(buildRow),
                  ],
                  if (showPendingLater) ...[
                    if (showAll)
                      HabitsSectionHeader(
                        label: messages.habitsPendingLaterHeader,
                        count: pendingLater.length,
                      )
                    else
                      SizedBox(height: tokens.spacing.step5),
                    ...pendingLater.map(buildRow),
                  ],
                  if (showCompleted) ...[
                    if (showAll)
                      HabitsSectionHeader(
                        label: messages.habitsCompletedHeader,
                        count: completed.length,
                      )
                    else
                      SizedBox(height: tokens.spacing.step5),
                    ...completed.map(buildRow),
                  ],
                ]),
              ),
            ),
            // The heatmap is the width-using centrepiece: a full-width band so a
            // wide window shows more history, while the reading content stays a
            // comfortable column.
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: bandPadding,
                vertical: tokens.spacing.sectionGap,
              ),
              sliver: const SliverToBoxAdapter(child: HabitHeatmapCard()),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                readingPadding,
                0,
                readingPadding,
                tokens.spacing.step6,
              ),
              sliver: const SliverToBoxAdapter(child: HabitsChartCard()),
            ),
          ],
        ),
      ),
    );
  }
}
