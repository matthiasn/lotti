import 'dart:async';

import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/repository/day_plan_repository.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'timeline_data_controller.g.dart';

/// Represents a time slot in the daily timeline.
sealed class TimelineSlot {
  const TimelineSlot({
    required this.startTime,
    required this.endTime,
    this.categoryId,
  });

  final DateTime startTime;
  final DateTime endTime;
  final String? categoryId;

  Duration get duration => endTime.difference(startTime);

  CategoryDefinition? get category {
    final id = categoryId;
    if (id == null) return null;
    return getIt<EntitiesCacheService>().getCategoryById(id);
  }
}

/// A planned time block from the day plan.
class PlannedTimeSlot extends TimelineSlot {
  const PlannedTimeSlot({
    required super.startTime,
    required super.endTime,
    required this.block,
    super.categoryId,
  });

  final PlannedBlock block;
}

/// An actual recorded time entry.
class ActualTimeSlot extends TimelineSlot {
  const ActualTimeSlot({
    required super.startTime,
    required super.endTime,
    required this.entry,
    super.categoryId,
    this.linkedFrom,
  });

  final JournalEntity entry;

  /// The parent entity this entry is linked to (e.g., a Task).
  final JournalEntity? linkedFrom;
}

/// Combined timeline data for plan vs actual view.
class DailyTimelineData {
  const DailyTimelineData({
    required this.date,
    required this.plannedSlots,
    required this.actualSlots,
    required this.dayStartHour,
    required this.dayEndHour,
  });

  final DateTime date;
  final List<PlannedTimeSlot> plannedSlots;
  final List<ActualTimeSlot> actualSlots;
  final int dayStartHour;
  final int dayEndHour;

  /// All entries for the timeline, sorted by start time.
  List<JournalEntity> get allEntries =>
      actualSlots.map((s) => s.entry).toList();

  /// Total planned duration for the day.
  Duration get totalPlannedDuration => plannedSlots.fold(
        Duration.zero,
        (total, slot) => total + slot.duration,
      );

  /// Total recorded duration for the day.
  Duration get totalActualDuration => actualSlots.fold(
        Duration.zero,
        (total, slot) => total + slot.duration,
      );
}

/// Provides timeline data for plan vs actual comparison.
@riverpod
class TimelineDataController extends _$TimelineDataController {
  late DateTime _date;
  late DayPlanRepository _dayPlanRepository;
  StreamSubscription<Set<String>>? _updateSubscription;
  bool _isDisposed = false;

  DailyTimelineData get _emptyData => DailyTimelineData(
        date: _date,
        plannedSlots: [],
        actualSlots: [],
        dayStartHour: 8,
        dayEndHour: 18,
      );

  void _listen() {
    final notifications = getIt<UpdateNotifications>();
    _updateSubscription = notifications.updateStream.listen((_) async {
      // Don't update if provider has been disposed
      if (_isDisposed) return;

      try {
        // Refresh timeline data when any journal entries change
        final data = await _fetchData();
        if (!_isDisposed) {
          state = AsyncData(data);
        }
      } catch (e, stackTrace) {
        // Ignore errors from disposed refs - silently return
        if (_isDisposed) return;
        getIt<LoggingService>().captureException(
          e,
          domain: 'timeline_data_controller',
          subDomain: '_listen',
          stackTrace: stackTrace,
        );
        // Don't rethrow - this would terminate the subscription and prevent future updates
      }
    });
  }

  Future<DailyTimelineData> _fetchData() async {
    // Check if disposed
    if (_isDisposed) return _emptyData;

    // Get day plan directly from repository (doesn't use ref)
    final dayPlan = await _dayPlanRepository.getOrCreateDayPlan(_date);

    final dayStart = _date.dayAtMidnight;
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Fetch actual entries for the day
    final db = getIt<JournalDb>();
    final entries = await db.sortedCalendarEntries(
      rangeStart: dayStart,
      rangeEnd: dayEnd,
    );

    // Fetch linked entries (parent tasks/journals) for each entry
    final entryIds = entries.map((e) => e.meta.id).toSet();
    final links = await db.linksForEntryIds(entryIds);
    final entryIdToLinkedFromIds = <String, Set<String>>{};
    final linkedFromIds = <String>{};

    for (final link in links) {
      final fromId = link.fromId;
      final toId = link.toId;
      entryIdToLinkedFromIds[toId] = {
        fromId,
        ...?entryIdToLinkedFromIds[toId],
      };
    }

    entryIdToLinkedFromIds.forEach((toId, fromIds) {
      linkedFromIds.addAll(fromIds);
    });

    final linkedFromEntries = await db.getJournalEntitiesForIds(linkedFromIds);
    final linkedFromMap = <String, JournalEntity>{
      for (final entry in linkedFromEntries) entry.meta.id: entry,
    };

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
      // Get the linked parent entry (e.g., a Task).
      // Note: If an entry has multiple linked parents, we use the first one.
      // In practice, time entries are typically linked to a single task/journal,
      // so this covers the common case. If multi-parent attribution becomes
      // needed, this logic would need to be extended (e.g., prioritize by type).
      final linkedFromId = entryIdToLinkedFromIds[entry.meta.id]?.firstOrNull;
      final linkedFrom =
          linkedFromId != null ? linkedFromMap[linkedFromId] : null;

      // Use category from linked parent if available
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

    // Sort both by start time
    plannedSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
    actualSlots.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Calculate day bounds
    final dayStartHour = _calculateDayStartHour(plannedSlots, actualSlots);
    final dayEndHour = _calculateDayEndHour(plannedSlots, actualSlots);

    return DailyTimelineData(
      date: _date,
      plannedSlots: plannedSlots,
      actualSlots: actualSlots,
      dayStartHour: dayStartHour,
      dayEndHour: dayEndHour,
    );
  }

  @override
  Future<DailyTimelineData> build({required DateTime date}) async {
    _date = date;
    _isDisposed = false;
    _dayPlanRepository = ref.read(dayPlanRepositoryProvider);

    ref
      ..onDispose(() {
        _isDisposed = true;
        _updateSubscription?.cancel();
      })
      // Also watch day plan for planned block changes
      ..watch(dayPlanControllerProvider(date: date));

    final result = await _fetchData();
    _listen();
    return result;
  }

  int _calculateDayStartHour(
    List<PlannedTimeSlot> planned,
    List<ActualTimeSlot> actual,
  ) {
    // If no content, use default range
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
  ) {
    // If no content, use default range
    if (planned.isEmpty && actual.isEmpty) return 18;

    var latest = 0;

    // Find max end time across all planned slots (not just the last by start)
    for (final slot in planned) {
      final endHour = slot.endTime.hour + 1;
      if (endHour > latest) latest = endHour;
    }

    // Find max end time across all actual slots
    for (final slot in actual) {
      final endHour = slot.endTime.hour + 1;
      if (endHour > latest) latest = endHour;
    }

    // Add 1 hour buffer after, but not past midnight
    return (latest + 1).clamp(1, 24);
  }
}
