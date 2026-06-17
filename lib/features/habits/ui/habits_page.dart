import 'dart:async';

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

  /// How long a just-completed habit's row is kept pinned in the open section so
  /// its in-place completion celebration can finish before the row leaves. On
  /// the default "due" filter the row would otherwise be removed the instant the
  /// habit is logged, cutting the celebration off before it is seen.
  static const _lingerDuration = Duration(milliseconds: 1200);

  /// The open section's row order, including habits that are lingering after
  /// completion. Maintained across rebuilds so a completed row holds its place
  /// instead of jumping, and new open habits append.
  List<String> _openOrder = [];

  /// Habits kept visible past completion until their linger timer fires.
  final Set<String> _lingering = {};
  final Map<String, Timer> _lingerTimers = {};

  /// Last seen `successfulToday`, to detect the completion transition in build.
  Set<String> _prevSuccessful = {};

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
    super.initState();
  }

  @override
  void dispose() {
    for (final timer in _lingerTimers.values) {
      timer.cancel();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// Returns the open-section habits in stable order, pinning any that just
  /// flipped to done for [_lingerDuration] so their celebration can play in
  /// place. Mutates the linger bookkeeping and schedules removal timers.
  List<HabitDefinition> _openWithLinger(HabitsState state) {
    final byId = <String, HabitDefinition>{
      for (final h in [
        ...state.openNow,
        ...state.completed,
        ...state.pendingLater,
      ])
        h.id: h,
    };

    // Pin habits that just flipped to done while shown in the open section.
    final newlyDone = state.successfulToday.difference(_prevSuccessful);
    _prevSuccessful = state.successfulToday.toSet();
    for (final id in newlyDone) {
      if (_openOrder.contains(id) && !_lingering.contains(id)) {
        _lingering.add(id);
        _lingerTimers[id]?.cancel();
        _lingerTimers[id] = Timer(_lingerDuration, () {
          if (!mounted) return;
          setState(() {
            _lingering.remove(id);
            _openOrder.remove(id);
            _lingerTimers.remove(id);
          });
        });
      }
    }

    // Keep order: drop rows that are neither open nor lingering, append new
    // open habits at the end.
    final openIds = state.openNow.map((h) => h.id).toSet();
    final newOpen = state.openNow
        .map((h) => h.id)
        .where((id) => !_openOrder.contains(id))
        .toList();
    _openOrder = [
      ..._openOrder.where(
        (id) => openIds.contains(id) || _lingering.contains(id),
      ),
      ...newOpen,
    ];

    return _openOrder
        .map((id) => byId[id])
        .whereType<HabitDefinition>()
        .toList();
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

    // Pin just-completed rows in the open section briefly so their celebration
    // plays before they leave (and exclude them from the completed bucket so
    // they don't appear twice during the linger).
    final openWithLinger = _openWithLinger(state);
    final completedRaw = state.completed
        .where((h) => !_lingering.contains(h.id))
        .toList();

    final openNow = state.showSearch
        ? filterMatching(openWithLinger)
        : openWithLinger;
    final completed = state.showSearch
        ? filterMatching(completedRaw)
        : completedRaw;
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
