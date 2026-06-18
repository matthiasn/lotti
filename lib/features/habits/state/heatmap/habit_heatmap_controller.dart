import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'habit_heatmap_controller.g.dart';

/// Owns the deep-history series for the habits consistency heatmap.
///
/// Deliberately separate from [HabitsController]: that controller refetches
/// only a short 7/14-day window on every completion to drive the tab's hot
/// path, whereas the heatmap wants a multi-year range — coupling them would put
/// years of data on the completion hot path. This controller fetches its own
/// wide range once, recomputes purely on category-filter changes (no refetch),
/// and refetches only when a habit completion actually changes.
///
/// State is a plain [HabitHeatmapData] (not an `AsyncValue`) seeded with
/// [HabitHeatmapData.empty]; after the first recompute it never republishes a
/// loading state, so a background refresh never blanks the grid.
@Riverpod(keepAlive: true)
class HabitHeatmapController extends _$HabitHeatmapController {
  StreamSubscription<List<HabitDefinition>>? _definitionsSubscription;
  StreamSubscription<Set<String>>? _updateSubscription;

  /// Debounces the completion-triggered recompute so a burst of completions
  /// coalesces and the heavy refetch lands off the tap's animation frames.
  Timer? _refreshDebounce;

  late HabitsRepository _repository;
  List<HabitDefinition> _habitDefinitions = [];
  List<JournalEntity> _habitCompletions = [];
  Set<String> _selectedCategoryIds = const {};

  /// Monotonic guard so overlapping refreshes can't let an older fetch finish
  /// last and overwrite fresher completions with stale data.
  int _refreshEpoch = 0;

  /// Never show more than this far back, regardless of how old the earliest
  /// habit is — a guard against a single ancient `activeFrom` producing a
  /// decade-wide grid.
  static const _maxHistoryYears = 5;

  /// The grid always covers at least this many days, so a brand-new user still
  /// sees a full year canvas (older cells render neutral).
  static const _minHistoryDays = 365;

  @override
  HabitHeatmapData build() {
    _repository = ref.read(habitsRepositoryProvider);
    ref.onDispose(_cleanup);

    // Track the tab's category filter; recompute (no refetch) when it changes —
    // completions for every habit are already in memory, so filtering is pure.
    // The habits controller emits on every completion, so guard on the filter
    // actually changing to avoid needless recomputes.
    _selectedCategoryIds = ref
        .read(habitsControllerProvider)
        .selectedCategoryIds;
    ref.listen(habitsControllerProvider, (previous, next) {
      if (previous?.selectedCategoryIds == next.selectedCategoryIds) return;
      _selectedCategoryIds = next.selectedCategoryIds;
      _recompute();
    });

    // The range depends on the earliest habit, so (re)fetch whenever the
    // definitions change, then recompute.
    _definitionsSubscription = _repository.watchHabitDefinitions().listen((
      definitions,
    ) async {
      _habitDefinitions = definitions.where((h) => h.active).toList();
      await _refreshAndRecompute();
    });

    Future.microtask(_startWatching);
    return HabitHeatmapData.empty();
  }

  void _cleanup() {
    _refreshDebounce?.cancel();
    _definitionsSubscription?.cancel();
    _updateSubscription?.cancel();
  }

  Future<void> _startWatching() async {
    if (!ref.mounted) return;
    _updateSubscription = _repository.updateStream.listen((affectedIds) {
      if (affectedIds.contains(habitCompletionNotification)) {
        // Debounce the recompute. The heatmap is a background "seeing" surface,
        // and refetching a year+ of completions and rebuilding it on every
        // completion blocks the completion frame — which janked the tap's
        // celebration on mobile. Coalesce rapid completions and let the heavy
        // work land after the tap, off the animation's critical frames.
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(
          const Duration(milliseconds: 350),
          _refreshAndRecompute,
        );
      }
    });
  }

  /// Fetches the wide completion range and recomputes, but only applies the
  /// result if no newer refresh started in the meantime — so concurrent
  /// definition/completion events can't regress the grid to stale data.
  Future<void> _refreshAndRecompute() async {
    final epoch = ++_refreshEpoch;
    final completions = await _repository.getHabitCompletionsInRange(
      rangeStart: _rangeStart(clock.now()),
    );
    if (!ref.mounted || epoch != _refreshEpoch) return;
    _habitCompletions = completions;
    _recompute();
  }

  /// Earliest day the grid covers: the earlier of the oldest habit's
  /// `activeFrom` and a one-year floor, clamped so it is never older than
  /// [_maxHistoryYears].
  DateTime _rangeStart(DateTime now) {
    final today = now.dayAtMidnight;
    // Calendar-day arithmetic (not a fixed 24h Duration) so a DST transition
    // can't shift the floor onto the previous day. Matches the streak walk.
    final oneYearFloor = DateTime(
      today.year,
      today.month,
      today.day - _minHistoryDays,
    );
    final maxCap = DateTime(
      today.year - _maxHistoryYears,
      today.month,
      today.day,
    );

    DateTime? earliest;
    for (final habit in _habitDefinitions) {
      final from = habit.activeFrom?.dayAtMidnight;
      if (from == null) continue;
      if (earliest == null || from.isBefore(earliest)) {
        earliest = from;
      }
    }

    var start = earliest != null && earliest.isBefore(oneYearFloor)
        ? earliest
        : oneYearFloor;
    if (start.isBefore(maxCap)) {
      start = maxCap;
    }
    return start;
  }

  void _recompute() {
    if (!ref.mounted) return;
    final now = clock.now();
    state = HabitHeatmapData(
      days: buildHeatmapDays(
        completions: _habitCompletions,
        habitDefinitions: _habitDefinitions,
        rangeStartYmd: _rangeStart(now).ymd,
        rangeEndYmd: now.ymd,
        selectedCategoryIds: _selectedCategoryIds,
        todayYmd: now.ymd,
      ),
      // Streaks are per habit and ignore the category filter — a habit's own
      // chain shouldn't vanish because a different category is selected.
      streaksByHabit: currentStreaksByHabit(
        completions: _habitCompletions,
        habitDefinitions: _habitDefinitions,
        todayYmd: now.ymd,
      ),
      hasHabits: _habitDefinitions.isNotEmpty,
      isLoading: false,
    );
  }
}
