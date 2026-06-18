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

  /// The whole dashboard (header, summary, list, heatmap, chart) is capped at
  /// this width and centred, so on a wide window it reads as one comfortable
  /// column rather than rows stretched edge-to-edge — and every block shares the
  /// same width, so nothing juts out wider than the rest.
  static const _maxContentWidth = 1100.0;

  /// How long a just-completed habit's row is kept pinned in the open section so
  /// its in-place completion celebration can finish before the row leaves. On
  /// the default "due" filter the row would otherwise be removed the instant the
  /// habit is logged, cutting the celebration off before it is seen.
  static const _lingerDuration = Duration(milliseconds: 1750);

  /// The open section's row order, including habits that are lingering after
  /// completion. Maintained across rebuilds so a completed row holds its place
  /// instead of jumping, and new open habits append.
  List<String> _openOrder = [];

  /// Habits kept visible past completion until their linger timer fires.
  final Set<String> _lingering = {};
  final Map<String, Timer> _lingerTimers = {};

  /// Habits whose linger has ended and are now collapsing out of the list; kept
  /// in the order until their exit animation reports back via [_finishRemoval].
  final Set<String> _leaving = {};

  /// Pins any habit that just flipped to done in the open section and schedules
  /// its collapse-out. Called from a `ref.listen` (not `build`) so the side
  /// effect fires once per real transition rather than on every rebuild.
  void _scheduleLingerForNewlyDone(HabitsState? previous, HabitsState next) {
    final newlyDone = next.successfulToday.difference(
      previous?.successfulToday ?? const <String>{},
    );
    for (final id in newlyDone) {
      if (_openOrder.contains(id) && !_lingering.contains(id)) {
        _lingering.add(id);
        _lingerTimers[id]?.cancel();
        // When the linger ends, mark the row leaving so it collapses out
        // gracefully (see [_CollapsibleRow]) rather than popping; the row is
        // dropped from the order once that exit animation completes.
        _lingerTimers[id] = Timer(_lingerDuration, () {
          if (!mounted) return;
          setState(() => _leaving.add(id));
        });
      }
    }
  }

  /// Drops a row from the open section once its collapse-out animation finishes.
  void _finishRemoval(String id) {
    if (!mounted) return;
    setState(() {
      _lingering.remove(id);
      _leaving.remove(id);
      _openOrder.remove(id);
      _lingerTimers.remove(id);
    });
  }

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

  /// Returns the open-section habits in stable order, keeping any lingering
  /// (just-completed) rows pinned in place. A pure projection of the current
  /// state + linger bookkeeping — the transition detection and removal timers
  /// live in [_scheduleLingerForNewlyDone], driven by a `ref.listen`.
  List<HabitDefinition> _openWithLinger(HabitsState state) {
    final byId = <String, HabitDefinition>{
      for (final h in [
        ...state.openNow,
        ...state.completed,
        ...state.pendingLater,
      ])
        h.id: h,
    };

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

    // Detect the just-completed transition and schedule the linger here, in a
    // listener, so the timer side effect fires once per real change rather than
    // on every (possibly framework-driven) rebuild.
    ref.listen(habitsControllerProvider, _scheduleLingerForNewlyDone);

    // One content width for every block (header, summary, list, heatmap, chart):
    // capped + centred on a wide window, full-bleed minus a gutter when narrow.
    // The heatmap no longer breaks out wider than everything else (the "cross").
    final width = MediaQuery.sizeOf(context).width;
    final pagePadding = width > _maxContentWidth + tokens.spacing.step6 * 2
        ? (width - _maxContentWidth) / 2
        : tokens.spacing.step6;

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

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Open rows collapse out gracefully when their post-completion linger ends,
    // instead of the list snapping shut under them.
    Widget buildOpenRow(HabitDefinition habitDefinition) {
      return _CollapsibleRow(
        key: ValueKey('open-collapse-${habitDefinition.id}'),
        collapsing: _leaving.contains(habitDefinition.id),
        reduceMotion: reduceMotion,
        onCollapsed: () => _finishRemoval(habitDefinition.id),
        child: buildRow(habitDefinition),
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
                pagePadding,
                tokens.spacing.step5,
                pagePadding,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const HabitsHeader(),
                  SizedBox(height: tokens.spacing.sectionGap),
                  const HabitsSummaryCard(),
                  if (showOpenNow) ...[
                    if (showAll)
                      HabitsSectionHeader(
                        label: messages.habitsOpenHeader,
                        count: openNow.length,
                      )
                    else
                      SizedBox(height: tokens.spacing.step5),
                    ...openNow.map(buildOpenRow),
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
                horizontal: pagePadding,
                vertical: tokens.spacing.sectionGap,
              ),
              sliver: const SliverToBoxAdapter(child: HabitHeatmapCard()),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                pagePadding,
                0,
                pagePadding,
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

/// Wraps an open habit row so that, when [collapsing] flips true, it fades and
/// collapses its height to zero over a short beat, then reports back via
/// [onCollapsed] — a just-completed row leaves the list gracefully instead of
/// the list snapping shut under it. Under [reduceMotion] it removes itself at
/// once (no animation).
class _CollapsibleRow extends StatefulWidget {
  const _CollapsibleRow({
    required this.collapsing,
    required this.reduceMotion,
    required this.onCollapsed,
    required this.child,
    super.key,
  });

  final bool collapsing;
  final bool reduceMotion;
  final VoidCallback onCollapsed;
  final Widget child;

  @override
  State<_CollapsibleRow> createState() => _CollapsibleRowState();
}

class _CollapsibleRowState extends State<_CollapsibleRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1, // full height + opaque at rest
  );

  @override
  void initState() {
    super.initState();
    if (widget.collapsing) _collapse();
  }

  @override
  void didUpdateWidget(_CollapsibleRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsing && !oldWidget.collapsing) _collapse();
  }

  void _collapse() {
    // Defer the callback past the current frame: it removes this row from the
    // parent's list (a setState), which must not run during build.
    if (widget.reduceMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCollapsed();
      });
      return;
    }
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onCollapsed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // At rest the row is rendered unclipped, so the completion spark burst
        // can paint beyond the row's bounds and off the card edges. Only once
        // the row is actually collapsing out (controller < 1) do we clip and
        // shrink it — by then the burst has finished.
        if (_controller.value >= 1.0) return child!;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: Curves.easeInOut.transform(_controller.value),
            child: Opacity(opacity: _controller.value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
