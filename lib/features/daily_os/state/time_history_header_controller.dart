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

    final refreshed = await _fetchDataForRange(
      current.earliestDay,
      current.latestDay,
    );

    if (ref.mounted) {
      state = AsyncData(refreshed);
    }
  }

  Future<TimeHistoryData> _fetchInitialData() async {
    final today = DateTime.now().dayAtMidnight;
    final startDate = today.subtract(const Duration(days: _initialDays - 1));
    return _fetchDataForRange(startDate, today);
  }

  /// Load more days of history.
  Future<void> loadMoreDays() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.canLoadMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final newEarliest = current.earliestDay.subtract(
        const Duration(days: _loadMoreDays),
      );
      final additionalData = await _fetchDataForRange(
        newEarliest,
        current.earliestDay.subtract(const Duration(days: 1)),
      );

      if (!ref.mounted) return;

      // Merge with existing data
      final mergedDays = [...current.days, ...additionalData.days];
      final prunedDays = mergedDays.length > _maxLoadedDays
          ? mergedDays.sublist(0, _maxLoadedDays)
          : mergedDays;

      // Merge stacked heights
      final mergedHeights = {
        ...current.stackedHeights,
        ...additionalData.stackedHeights,
      };

      // Prune stacked heights if days were pruned
      if (prunedDays.length < mergedDays.length) {
        final prunedDaySet = prunedDays.map((d) => d.day).toSet();
        mergedHeights.removeWhere((day, _) => !prunedDaySet.contains(day));
      }

      final newMax = _maxDuration(
        current.maxDailyTotal,
        additionalData.maxDailyTotal,
      );

      state = AsyncData(
        current.copyWith(
          days: prunedDays,
          earliestDay:
              prunedDays.isNotEmpty ? prunedDays.last.day : current.earliestDay,
          maxDailyTotal: newMax,
          isLoadingMore: false,
          canLoadMore: additionalData.days.isNotEmpty,
          stackedHeights: mergedHeights,
        ),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<TimeHistoryData> _fetchDataForRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = getIt<JournalDb>();

    // Query calendar entries for the range
    final entries = await db.sortedCalendarEntries(
      rangeStart: start,
      rangeEnd: end.add(const Duration(days: 1)).dayAtMidnight,
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
    // Initialize day buckets
    final dayCount = end.difference(start).inDays + 1;
    final data = <DateTime, Map<String?, Duration>>{};

    for (var i = 0; i < dayCount; i++) {
      final day = DateTime(end.year, end.month, end.day - i, 12);
      data[day] = <String?, Duration>{};
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
