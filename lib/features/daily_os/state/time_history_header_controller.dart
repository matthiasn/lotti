import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'time_history_header_controller.freezed.dart';
part 'time_history_header_controller.g.dart';

/// Summary of time spent per category for a single day.
/// Uses noon representation to avoid DST artifacts.
@freezed
abstract class DayTimeSummary with _$DayTimeSummary {
  const factory DayTimeSummary({
    /// Date at local noon to avoid DST artifacts.
    required DateTime day,

    /// Category ID to duration. Null key represents uncategorized entries.
    required Map<String?, Duration> durationByCategoryId,

    /// Precomputed total duration for this day.
    required Duration total,
  }) = _DayTimeSummary;
}

/// Precomputed stacked heights for efficient painting.
/// Maps category ID to its cumulative height (sum of lower categories).
typedef StackedHeights = Map<DateTime, Map<String?, double>>;

/// Aggregated data for the time history header visualization.
@freezed
abstract class TimeHistoryData with _$TimeHistoryData {
  const factory TimeHistoryData({
    /// Days ordered newest to oldest.
    required List<DayTimeSummary> days,

    /// Earliest day in the loaded range.
    required DateTime earliestDay,

    /// Latest day in the loaded range.
    required DateTime latestDay,

    /// Maximum daily total across loaded range, for Y-axis normalization.
    required Duration maxDailyTotal,

    /// Consistent category order for stacking.
    required List<String> categoryOrder,

    /// Whether more days are currently being loaded.
    required bool isLoadingMore,

    /// Whether there are more days available to load.
    required bool canLoadMore,

    /// Precomputed stacked heights per day per category.
    /// Maps day (at noon) -> categoryId -> cumulative height from lower cats.
    required StackedHeights stackedHeights,
  }) = _TimeHistoryData;
}

/// Extension methods for TimeHistoryData.
extension TimeHistoryDataX on TimeHistoryData {
  /// Lookup a day summary by date (at noon).
  DayTimeSummary? dayAt(DateTime day) {
    final noon = day.dayAtNoon;
    return days.firstWhereOrNull((d) => d.day == noon);
  }
}

/// Controller for the time history header data layer.
///
/// Fetches and aggregates time-by-category data for multiple days,
/// supporting incremental loading for infinite scroll.
@riverpod
class TimeHistoryHeaderController extends _$TimeHistoryHeaderController {
  static const int _initialDays = 30;
  static const int _loadMoreDays = 14;
  static const int _maxLoadedDays = 180;
  static const int _batchSize = 500;

  StreamSubscription<Set<String>>? _updateSubscription;

  @override
  Future<TimeHistoryData> build() async {
    ref.onDispose(() => _updateSubscription?.cancel());
    _listenToUpdates();
    return _fetchInitialData();
  }

  void _listenToUpdates() {
    // Include taskNotification since categories come from linked tasks
    const subscribedIds = {
      textEntryNotification,
      audioNotification,
      taskNotification,
    };

    _updateSubscription = getIt<UpdateNotifications>()
        .updateStream
        .throttleTime(
          const Duration(seconds: 5),
          leading: false,
          trailing: true,
        )
        .listen((affectedIds) async {
      if (affectedIds.intersection(subscribedIds).isNotEmpty) {
        await _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    final current = state.value;
    if (current == null) return;

    // Skip refresh while a load is in progress to avoid state conflicts
    if (current.isLoadingMore) return;

    try {
      // Use midnight boundaries for refresh query
      final refreshed = await _fetchDataForRange(
        current.earliestDay.dayAtMidnight,
        current.latestDay.dayAtMidnight,
      );

      if (ref.mounted) {
        // Preserve isLoadingMore and canLoadMore state from before refresh
        state = AsyncData(
          refreshed.copyWith(
            isLoadingMore: current.isLoadingMore,
            canLoadMore: current.canLoadMore,
          ),
        );
      }
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'TimeHistoryHeaderController._refresh',
        stackTrace: stackTrace,
      );
      // Keep current state on error - don't disrupt the UI
    }
  }

  Future<TimeHistoryData> _fetchInitialData() async {
    // Using clock.now() for testability - can be mocked with withClock()
    final today = clock.now().dayAtMidnight;
    // Use calendar arithmetic (day - n) instead of Duration subtraction
    // to avoid DST artifacts when crossing daylight saving transitions.
    final startDate =
        DateTime(today.year, today.month, today.day - (_initialDays - 1));
    return _fetchDataForRange(startDate, today);
  }

  /// Load more days of history (backward scrolling).
  ///
  /// Uses a sliding window: when cap is hit, drops newest days to make room
  /// for older history, preserving backward scroll position.
  Future<void> loadMoreDays() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.canLoadMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      // Compute range for new data: from (earliest - loadMoreDays) to (earliest - 1 day)
      // Use calendar arithmetic (day - n) instead of Duration subtraction
      // to avoid DST artifacts when crossing daylight saving transitions.
      final e = current.earliestDay;
      final newRangeEnd = DateTime(e.year, e.month, e.day - 1);
      final newRangeStart = DateTime(e.year, e.month, e.day - _loadMoreDays);

      final additionalData = await _fetchDataForRange(
        newRangeStart,
        newRangeEnd,
      );

      if (!ref.mounted) return;

      // Merge: append older days to end of list (list is newest-to-oldest)
      final mergedDays = [...current.days, ...additionalData.days];

      // Sliding window: drop NEWEST days (front of list) when over cap
      // This preserves backward scroll position
      final prunedDays = mergedDays.length > _maxLoadedDays
          ? mergedDays.sublist(mergedDays.length - _maxLoadedDays)
          : mergedDays;

      final newEarliestDay =
          prunedDays.isNotEmpty ? prunedDays.last.day : current.earliestDay;

      // Recompute maxDailyTotal from pruned days to handle:
      // 1. Dropped days that had the previous max
      // 2. Additional data computed with different max scale
      final newMax = _computeMaxFromDays(prunedDays);

      // Always recompute stacked heights for scale consistency.
      // This is necessary because:
      // - additionalData.stackedHeights was computed with additionalData.maxDailyTotal
      // - After pruning, the max may have changed
      // - Merging heights from different scales would cause rendering bugs
      final categoryOrder = current.categoryOrder;
      final stackedHeights =
          _computeStackedHeights(prunedDays, categoryOrder, newMax);

      state = AsyncData(
        current.copyWith(
          days: prunedDays,
          earliestDay: newEarliestDay,
          latestDay:
              prunedDays.isNotEmpty ? prunedDays.first.day : current.latestDay,
          maxDailyTotal: newMax,
          isLoadingMore: false,
          // Always allow more loading - the sliding window handles memory,
          // and stopping on gaps would break infinite scroll
          canLoadMore: true,
          stackedHeights: stackedHeights,
        ),
      );
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'TimeHistoryHeaderController.loadMoreDays',
        stackTrace: stackTrace,
      );
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// Reset to today's view, reloading the initial date range.
  ///
  /// Use this when the user wants to return to the current day after
  /// scrolling far into history (which may have dropped today from the window).
  Future<void> resetToToday() async {
    final previousState = state;
    state = const AsyncLoading();

    try {
      final data = await _fetchInitialData();
      if (ref.mounted) {
        state = AsyncData(data);
      }
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'TimeHistoryHeaderController.resetToToday',
        stackTrace: stackTrace,
      );
      if (ref.mounted) {
        // Restore previous state on error to avoid stuck loading
        state =
            previousState.hasValue ? previousState : AsyncError(e, stackTrace);
      }
    }
  }

  Future<TimeHistoryData> _fetchDataForRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = getIt<JournalDb>();

    // Normalize to calendar day boundaries for DB query
    final rangeStartMidnight = start.dayAtMidnight;
    final rangeEndMidnight = end.dayAtMidnight.add(const Duration(days: 1));

    // Query calendar entries for the range
    final entries = await db.sortedCalendarEntries(
      rangeStart: rangeStartMidnight,
      rangeEnd: rangeEndMidnight,
    );

    // Resolve category links using batched queries
    final entryIds = entries.map((e) => e.meta.id).toSet();
    final links = await _batchedLinksForEntryIds(db, entryIds);

    // Build entry ID -> linked entry IDs map.
    // Links are directional: tasks link TO entries (task.fromId -> entry.toId).
    // linksForEntryIds queries WHERE to_id IN ids, returning tasks that link
    // to our entries. We map entry (toId) -> task IDs (fromId) to resolve
    // each entry's category from its parent task.
    final entryIdFromLinkedIds = <String, Set<String>>{};
    final linkedIds = <String>{};

    for (final link in links) {
      entryIdFromLinkedIds
          .putIfAbsent(link.toId, () => <String>{})
          .add(link.fromId);
    }

    entryIdFromLinkedIds.values.forEach(linkedIds.addAll);

    // Batch fetch linked entities
    final linkedEntries = await _batchedGetEntitiesForIds(db, linkedIds);
    final linkedEntriesMap = <String, JournalEntity>{
      for (final entry in linkedEntries) entry.meta.id: entry,
    };

    // Aggregate by day and category
    return _aggregateEntries(
      entries,
      entryIdFromLinkedIds,
      linkedEntriesMap,
      start,
      end,
    );
  }

  /// Generic utility to run a batched query over a set of IDs.
  Future<List<T>> _runBatchedQuery<T>(
    Set<String> ids,
    Future<List<T>> Function(Set<String> batchIds) query,
  ) async {
    if (ids.isEmpty) return [];

    final idList = ids.toList();
    final results = <T>[];

    for (var i = 0; i < idList.length; i += _batchSize) {
      final batch = idList.sublist(
        i,
        (i + _batchSize).clamp(0, idList.length),
      );
      final batchResults = await query(batch.toSet());
      results.addAll(batchResults);
    }

    return results;
  }

  /// Batch query links to avoid SQLite variable limits.
  Future<List<EntryLink>> _batchedLinksForEntryIds(
    JournalDb db,
    Set<String> ids,
  ) =>
      _runBatchedQuery(ids, db.linksForEntryIds);

  /// Batch fetch entities to avoid SQLite variable limits.
  Future<List<JournalEntity>> _batchedGetEntitiesForIds(
    JournalDb db,
    Set<String> ids,
  ) =>
      _runBatchedQuery(ids, db.getJournalEntitiesForIds);

  TimeHistoryData _aggregateEntries(
    List<JournalEntity> entries,
    Map<String, Set<String>> entryIdFromLinkedIds,
    Map<String, JournalEntity> linkedEntriesMap,
    DateTime start,
    DateTime end,
  ) {
    // Calculate day count using UTC dates to avoid DST artifacts.
    // Local DateTime.difference().inDays is unreliable across DST boundaries
    // because days can be 23 or 25 hours. UTC dates have consistent 24-hour days.
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final endUtc = DateTime.utc(end.year, end.month, end.day);
    final dayCount = endUtc.difference(startUtc).inDays + 1;
    final data = <DateTime, Map<String?, Duration>>{};

    // Use calendar arithmetic (day - i) at noon to avoid DST artifacts.
    // This is the proven pattern from time_by_category_controller.dart:getDaysAtNoon()
    final endNoon = end.dayAtNoon;
    for (var i = 0; i < dayCount; i++) {
      final dayNoon =
          DateTime(endNoon.year, endNoon.month, endNoon.day - i, 12);
      data[dayNoon] = <String?, Duration>{};
    }

    // Aggregate entries
    // Note: JournalAudio is excluded to avoid double-counting when audio
    // is recorded during an active timer. Proper overlap detection for
    // standalone audio entries is a future enhancement.
    for (final journalEntity in entries) {
      if (journalEntity is! JournalEntry) {
        continue;
      }

      final duration = entryDuration(journalEntity);
      if (duration <= Duration.zero) continue;

      // Find category through linked entries
      final linkedTo =
          (entryIdFromLinkedIds[journalEntity.meta.id] ?? <String>{})
              .map((id) => linkedEntriesMap[id])
              .nonNulls;

      final categoryId =
          linkedTo.map((item) => item.meta.categoryId).nonNulls.firstOrNull;

      final noon = journalEntity.meta.dateFrom.dayAtNoon;
      final dataByDay = data[noon];
      if (dataByDay == null) continue;

      final timeByCategory = dataByDay[categoryId] ?? Duration.zero;
      dataByDay[categoryId] = timeByCategory + duration;
    }

    // Build day summaries and find max
    final days = <DayTimeSummary>[];
    var maxTotal = Duration.zero;

    // Get category order from cache
    final sortedCategories = getIt<EntitiesCacheService>().sortedCategories;
    final categoryOrder = sortedCategories.map((c) => c.id).toList();

    for (final entry in data.entries) {
      final total = entry.value.values.fold<Duration>(
        Duration.zero,
        (sum, d) => sum + d,
      );

      days.add(
        DayTimeSummary(
          day: entry.key,
          durationByCategoryId: entry.value,
          total: total,
        ),
      );

      if (total > maxTotal) {
        maxTotal = total;
      }
    }

    // Sort days newest to oldest
    days.sort((a, b) => b.day.compareTo(a.day));

    // Compute stacked heights
    final stackedHeights =
        _computeStackedHeights(days, categoryOrder, maxTotal);

    return TimeHistoryData(
      days: days,
      earliestDay: days.isNotEmpty ? days.last.day : start.dayAtNoon,
      latestDay: days.isNotEmpty ? days.first.day : end.dayAtNoon,
      maxDailyTotal: maxTotal,
      categoryOrder: categoryOrder,
      isLoadingMore: false,
      canLoadMore: true,
      stackedHeights: stackedHeights,
    );
  }

  /// Precompute stacked heights for efficient painting.
  ///
  /// For each day and category, computes the cumulative height of all
  /// categories below it in the stack order.
  ///
  /// Uses microseconds for precision - inMinutes truncates durations < 60s to 0,
  /// which would cause divide-by-zero or incorrect scaling.
  StackedHeights _computeStackedHeights(
    List<DayTimeSummary> days,
    List<String> categoryOrder,
    Duration maxTotal,
  ) {
    if (maxTotal <= Duration.zero) {
      return {};
    }

    final maxMicroseconds = maxTotal.inMicroseconds.toDouble();

    // Guard against zero after conversion (shouldn't happen if maxTotal > zero,
    // but defensive against edge cases)
    if (maxMicroseconds == 0) {
      return {};
    }

    final result = <DateTime, Map<String?, double>>{};

    for (final day in days) {
      final heights = <String?, double>{};
      var cumulative = 0.0;

      // Stack in category order
      for (final categoryId in categoryOrder) {
        heights[categoryId] = cumulative;
        final microseconds =
            (day.durationByCategoryId[categoryId]?.inMicroseconds ?? 0)
                .toDouble();
        cumulative += microseconds / maxMicroseconds;
      }

      // Handle uncategorized (null key) at the top
      heights[null] = cumulative;

      result[day.day] = heights;
    }

    return result;
  }

  /// Compute max daily total from a list of day summaries.
  ///
  /// Returns [Duration.zero] for empty lists, which is handled downstream
  /// by `_computeStackedHeights` returning an empty map.
  Duration _computeMaxFromDays(List<DayTimeSummary> days) {
    var max = Duration.zero;
    for (final day in days) {
      if (day.total > max) {
        max = day.total;
      }
    }
    return max;
  }
}
