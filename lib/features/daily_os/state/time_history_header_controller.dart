import 'dart:async';

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
    const subscribedIds = {textEntryNotification, audioNotification};

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
    final today = DateTime.now().dayAtMidnight;
    final startDate = today.subtract(const Duration(days: _initialDays - 1));
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
      // Use dayAtMidnight for DB query boundaries
      final currentEarliestMidnight = current.earliestDay.dayAtMidnight;
      final newRangeEnd =
          currentEarliestMidnight.subtract(const Duration(days: 1));
      final newRangeStart =
          currentEarliestMidnight.subtract(const Duration(days: _loadMoreDays));

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

      final newMax = _maxDuration(
        current.maxDailyTotal,
        additionalData.maxDailyTotal,
      );

      // Recompute ALL stacked heights if max changed (scale consistency)
      final categoryOrder = current.categoryOrder;
      final stackedHeights = newMax != current.maxDailyTotal
          ? _computeStackedHeights(prunedDays, categoryOrder, newMax)
          : _mergeStackedHeights(
              current.stackedHeights,
              additionalData.stackedHeights,
              prunedDays,
            );

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
        state = previousState.hasValue
            ? previousState
            : AsyncError(e, stackTrace);
      }
    }
  }

  /// Merge stacked heights, pruning any days not in the final list.
  StackedHeights _mergeStackedHeights(
    StackedHeights existing,
    StackedHeights additional,
    List<DayTimeSummary> prunedDays,
  ) {
    final prunedDaySet = prunedDays.map((d) => d.day).toSet();
    final merged = <DateTime, Map<String?, double>>{};

    for (final entry in existing.entries) {
      if (prunedDaySet.contains(entry.key)) {
        merged[entry.key] = entry.value;
      }
    }
    for (final entry in additional.entries) {
      if (prunedDaySet.contains(entry.key)) {
        merged[entry.key] = entry.value;
      }
    }

    return merged;
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

    // Build entry ID -> linked entry IDs map
    final entryIdFromLinkedIds = <String, Set<String>>{};
    final linkedIds = <String>{};

    for (final link in links) {
      final fromId = link.fromId;
      final toId = link.toId;
      final prev = entryIdFromLinkedIds[toId] ?? <String>{}
        ..add(fromId);
      entryIdFromLinkedIds[toId] = prev;
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

  /// Batch query links to avoid SQLite variable limits.
  Future<List<EntryLink>> _batchedLinksForEntryIds(
    JournalDb db,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return [];

    final idList = ids.toList();
    final results = <EntryLink>[];

    for (var i = 0; i < idList.length; i += _batchSize) {
      final batch = idList.sublist(
        i,
        (i + _batchSize).clamp(0, idList.length),
      );
      final batchLinks = await db.linksForEntryIds(batch.toSet());
      results.addAll(batchLinks);
    }

    return results;
  }

  /// Batch fetch entities to avoid SQLite variable limits.
  Future<List<JournalEntity>> _batchedGetEntitiesForIds(
    JournalDb db,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return [];

    final idList = ids.toList();
    final results = <JournalEntity>[];

    for (var i = 0; i < idList.length; i += _batchSize) {
      final batch = idList.sublist(
        i,
        (i + _batchSize).clamp(0, idList.length),
      );
      final batchEntities = await db.getJournalEntitiesForIds(batch.toSet());
      results.addAll(batchEntities);
    }

    return results;
  }

  TimeHistoryData _aggregateEntries(
    List<JournalEntity> entries,
    Map<String, Set<String>> entryIdFromLinkedIds,
    Map<String, JournalEntity> linkedEntriesMap,
    DateTime start,
    DateTime end,
  ) {
    // Normalize to midnight for consistent day counting
    final startMidnight = start.dayAtMidnight;
    final endMidnight = end.dayAtMidnight;

    // Initialize day buckets using noon representation
    final dayCount = endMidnight.difference(startMidnight).inDays + 1;
    final data = <DateTime, Map<String?, Duration>>{};

    for (var i = 0; i < dayCount; i++) {
      // Generate each day at noon, going backwards from end date
      final dayMidnight = endMidnight.subtract(Duration(days: i));
      final dayNoon = dayMidnight.dayAtNoon;
      data[dayNoon] = <String?, Duration>{};
    }

    // Aggregate entries
    for (final journalEntity in entries) {
      if (journalEntity is! JournalEntry && journalEntity is! JournalAudio) {
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
  StackedHeights _computeStackedHeights(
    List<DayTimeSummary> days,
    List<String> categoryOrder,
    Duration maxTotal,
  ) {
    if (maxTotal <= Duration.zero) {
      return {};
    }

    final maxMinutes = maxTotal.inMinutes.toDouble();
    final result = <DateTime, Map<String?, double>>{};

    for (final day in days) {
      final heights = <String?, double>{};
      var cumulative = 0.0;

      // Stack in category order
      for (final categoryId in categoryOrder) {
        heights[categoryId] = cumulative;
        final minutes =
            (day.durationByCategoryId[categoryId]?.inMinutes ?? 0).toDouble();
        cumulative += minutes / maxMinutes;
      }

      // Handle uncategorized (null key) at the top
      heights[null] = cumulative;

      result[day.day] = heights;
    }

    return result;
  }

  Duration _maxDuration(Duration a, Duration b) {
    return a > b ? a : b;
  }
}
