import 'dart:async';

import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/repository/day_plan_repository.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_daily_os_data_controller.g.dart';

/// Combined data for Daily OS view - single source of truth.
///
/// This consolidates day plan, timeline data, and budget progress into
/// a single atomic state that updates together when any underlying data changes.
class DailyOsData {
  const DailyOsData({
    required this.date,
    required this.dayPlan,
    required this.timelineData,
    required this.budgetProgress,
  });

  final DateTime date;
  final DayPlanEntry dayPlan;
  final DailyTimelineData timelineData;
  final List<TimeBudgetProgress> budgetProgress;
}

/// Unified data controller for the Daily OS view.
///
/// This controller solves the auto-update problem by:
/// 1. Using `ref.keepAlive()` to prevent disposal when navigating away
/// 2. Owning a manual `StreamSubscription` to `UpdateNotifications.updateStream`
///    which is NOT affected by Riverpod 3's automatic pausing
/// 3. Fetching ALL data directly (day plan, calendar entries, links) rather
///    than watching sub-controllers
/// 4. Updating state atomically when any relevant notification arrives
///
/// This ensures that when a time entry is created or synced, all UI components
/// (timeline, budget progress bars, summary) update together.
@riverpod
class UnifiedDailyOsDataController extends _$UnifiedDailyOsDataController {
  late DateTime _date;
  late DayPlanRepository _dayPlanRepository;
  StreamSubscription<Set<String>>? _updateSubscription;
  bool _isDisposed = false;

  @override
  Future<DailyOsData> build({required DateTime date}) async {
    _date = date;
    _isDisposed = false;
    _dayPlanRepository = ref.read(dayPlanRepositoryProvider);

    // CRITICAL: Keep alive to prevent disposal when navigating away.
    // This ensures data is fresh when the user returns to the page.
    ref
      ..keepAlive()
      ..onDispose(() {
        _isDisposed = true;
        _updateSubscription?.cancel();
      });

    // Start listening BEFORE fetch to avoid missing updates during initial load.
    _listen();
    return _fetchAllData();
  }

  void _listen() {
    final notifications = getIt<UpdateNotifications>();
    _updateSubscription = notifications.updateStream.listen((_) async {
      if (_isDisposed) return;

      try {
        final data = await _fetchAllData();
        if (!_isDisposed) {
          state = AsyncData(data);
        }
      } catch (e, stackTrace) {
        if (_isDisposed) return;
        getIt<LoggingService>().captureException(
          e,
          domain: 'unified_daily_os_data_controller',
          subDomain: '_listen',
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<DailyOsData> _fetchAllData() async {
    if (_isDisposed) {
      return DailyOsData(
        date: _date,
        dayPlan: _createEmptyDayPlan(),
        timelineData: _createEmptyTimelineData(),
        budgetProgress: [],
      );
    }

    final db = getIt<JournalDb>();
    final dayStart = _date.dayAtMidnight;
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Fetch day plan and calendar entries in parallel
    final results = await Future.wait([
      _dayPlanRepository.getOrCreateDayPlan(_date),
      db.sortedCalendarEntries(rangeStart: dayStart, rangeEnd: dayEnd),
    ]);

    final dayPlan = results[0] as DayPlanEntry;
    final entries = results[1] as List<JournalEntity>;

    // Fetch linked entries (parent tasks/journals) for each entry
    final entryIds = entries.map((e) => e.meta.id).toSet();
    final links = await db.linksForEntryIds(entryIds);

    // Build lookup maps for linked entries
    final entryIdToLinkedFromIds = <String, Set<String>>{};
    final linkedFromIds = <String>{};

    for (final link in links) {
      entryIdToLinkedFromIds[link.toId] = {
        link.fromId,
        ...?entryIdToLinkedFromIds[link.toId],
      };
      linkedFromIds.add(link.fromId);
    }

    final linkedFromEntries = await db.getJournalEntitiesForIds(linkedFromIds);
    final linkedFromMap = <String, JournalEntity>{
      for (final entry in linkedFromEntries) entry.meta.id: entry,
    };

    // Build timeline data
    final timelineData = _buildTimelineData(
      dayPlan: dayPlan,
      entries: entries,
      entryIdToLinkedFromIds: entryIdToLinkedFromIds,
      linkedFromMap: linkedFromMap,
      dayStart: dayStart,
    );

    // Build budget progress
    final budgetProgress = _buildBudgetProgress(
      dayPlan: dayPlan,
      entries: entries,
      entryIdToLinkedFromIds: entryIdToLinkedFromIds,
      linkedFromMap: linkedFromMap,
    );

    return DailyOsData(
      date: _date,
      dayPlan: dayPlan,
      timelineData: timelineData,
      budgetProgress: budgetProgress,
    );
  }

  DailyTimelineData _buildTimelineData({
    required DayPlanEntry dayPlan,
    required List<JournalEntity> entries,
    required Map<String, Set<String>> entryIdToLinkedFromIds,
    required Map<String, JournalEntity> linkedFromMap,
    required DateTime dayStart,
  }) {
    // Convert planned blocks to time slots
    final plannedSlots = <PlannedTimeSlot>[];
    for (final block in dayPlan.data.plannedBlocks) {
      plannedSlots.add(
        PlannedTimeSlot(
          startTime: block.startTime,
          endTime: block.endTime,
          block: block,
          categoryId: block.categoryId,
        ),
      );
    }

    // Convert actual entries to time slots
    final actualSlots = <ActualTimeSlot>[];
    for (final entry in entries) {
      final linkedFromId = entryIdToLinkedFromIds[entry.meta.id]?.firstOrNull;
      final linkedFrom =
          linkedFromId != null ? linkedFromMap[linkedFromId] : null;
      final categoryId = linkedFrom?.meta.categoryId ?? entry.meta.categoryId;

      actualSlots.add(
        ActualTimeSlot(
          startTime: entry.meta.dateFrom,
          endTime: entry.meta.dateTo,
          entry: entry,
          categoryId: categoryId,
          linkedFrom: linkedFrom,
        ),
      );
    }

    // Sort by start time
    plannedSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
    actualSlots.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Calculate day bounds
    final dayStartHour = _calculateDayStartHour(plannedSlots, actualSlots);
    final dayEndHour = _calculateDayEndHour(
      plannedSlots,
      actualSlots,
      dayStart,
    );

    return DailyTimelineData(
      date: _date,
      plannedSlots: plannedSlots,
      actualSlots: actualSlots,
      dayStartHour: dayStartHour,
      dayEndHour: dayEndHour,
    );
  }

  List<TimeBudgetProgress> _buildBudgetProgress({
    required DayPlanEntry dayPlan,
    required List<JournalEntity> entries,
    required Map<String, Set<String>> entryIdToLinkedFromIds,
    required Map<String, JournalEntity> linkedFromMap,
  }) {
    final derivedBudgets = dayPlan.data.derivedBudgets;
    if (derivedBudgets.isEmpty) {
      return [];
    }

    // Group entries by category, using linked parent's category if available
    final entriesByCategory = <String, List<JournalEntity>>{};
    for (final entry in entries) {
      final linkedFromId = entryIdToLinkedFromIds[entry.meta.id]?.firstOrNull;
      final linkedFrom =
          linkedFromId != null ? linkedFromMap[linkedFromId] : null;
      final categoryId = linkedFrom?.meta.categoryId ?? entry.meta.categoryId;

      if (categoryId != null) {
        entriesByCategory.putIfAbsent(categoryId, () => []).add(entry);
      }
    }

    final cacheService = getIt<EntitiesCacheService>();
    final results = <TimeBudgetProgress>[];

    for (final budget in derivedBudgets) {
      final categoryEntries = entriesByCategory[budget.categoryId] ?? [];
      final recordedDuration = _sumDurations(categoryEntries);
      final plannedDuration = budget.plannedDuration;

      results.add(
        TimeBudgetProgress(
          categoryId: budget.categoryId,
          category: cacheService.getCategoryById(budget.categoryId),
          plannedDuration: plannedDuration,
          recordedDuration: recordedDuration,
          status: _calculateStatus(plannedDuration, recordedDuration),
          contributingEntries: categoryEntries,
          // Pinned tasks are loaded separately when needed
          pinnedTasks: const [],
          blocks: budget.blocks,
        ),
      );
    }

    return results;
  }

  Duration _sumDurations(List<JournalEntity> entries) {
    return entries.fold(
      Duration.zero,
      (total, entry) => total + entryDuration(entry),
    );
  }

  BudgetProgressStatus _calculateStatus(
    Duration planned,
    Duration recorded,
  ) {
    final remaining = planned - recorded;

    if (remaining.isNegative) {
      return BudgetProgressStatus.overBudget;
    } else if (remaining == Duration.zero) {
      return BudgetProgressStatus.exhausted;
    } else if (remaining.inMinutes <= 15) {
      return BudgetProgressStatus.nearLimit;
    } else {
      return BudgetProgressStatus.underBudget;
    }
  }

  int _calculateDayStartHour(
    List<PlannedTimeSlot> planned,
    List<ActualTimeSlot> actual,
  ) {
    if (planned.isEmpty && actual.isEmpty) return 8;

    var earliest = 24;

    if (planned.isNotEmpty) {
      final plannedStart = planned.first.startTime.hour;
      if (plannedStart < earliest) earliest = plannedStart;
    }

    if (actual.isNotEmpty) {
      final actualStart = actual.first.startTime.hour;
      if (actualStart < earliest) earliest = actualStart;
    }

    // Add 1 hour buffer before, but not before midnight
    return (earliest - 1).clamp(0, 23);
  }

  int _calculateDayEndHour(
    List<PlannedTimeSlot> planned,
    List<ActualTimeSlot> actual,
    DateTime dayStart,
  ) {
    if (planned.isEmpty && actual.isEmpty) return 18;

    final nextDay = dayStart.add(const Duration(days: 1));
    var latest = 0;

    // Find max end time across all planned slots
    for (final slot in planned) {
      // If entry ends on the next day (crosses midnight), treat as hour 24
      final endHour =
          !slot.endTime.isBefore(nextDay) ? 24 : slot.endTime.hour + 1;
      if (endHour > latest) latest = endHour;
    }

    // Find max end time across all actual slots
    for (final slot in actual) {
      // If entry ends on the next day (crosses midnight), treat as hour 24
      final endHour =
          !slot.endTime.isBefore(nextDay) ? 24 : slot.endTime.hour + 1;
      if (endHour > latest) latest = endHour;
    }

    // Add 1 hour buffer after, but not past midnight
    return (latest + 1).clamp(1, 24);
  }

  DayPlanEntry _createEmptyDayPlan() {
    return DayPlanEntry(
      meta: Metadata(
        id: '',
        createdAt: _date,
        updatedAt: _date,
        dateFrom: _date,
        dateTo: _date.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: _date,
        status: const DayPlanStatus.draft(),
      ),
    );
  }

  DailyTimelineData _createEmptyTimelineData() {
    return DailyTimelineData(
      date: _date,
      plannedSlots: [],
      actualSlots: [],
      dayStartHour: 8,
      dayEndHour: 18,
    );
  }
}
