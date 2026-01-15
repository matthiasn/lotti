import 'dart:async';

import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
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
  });

  final JournalEntity entry;
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
  @override
  Future<DailyTimelineData> build({required DateTime date}) async {
    final dayPlanAsync = await ref.watch(
      dayPlanControllerProvider(date: date).future,
    );

    final dayStart = date.dayAtMidnight;
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Fetch actual entries for the day
    final db = getIt<JournalDb>();
    final entries = await db.sortedCalendarEntries(
      rangeStart: dayStart,
      rangeEnd: dayEnd,
    );

    // Convert planned blocks to time slots
    final plannedSlots = <PlannedTimeSlot>[];
    if (dayPlanAsync is DayPlanEntry) {
      for (final block in dayPlanAsync.data.plannedBlocks) {
        plannedSlots.add(
          PlannedTimeSlot(
            startTime: block.startTime,
            endTime: block.endTime,
            block: block,
            categoryId: block.categoryId,
          ),
        );
      }
    }

    // Convert actual entries to time slots
    final actualSlots = <ActualTimeSlot>[];
    for (final entry in entries) {
      actualSlots.add(
        ActualTimeSlot(
          startTime: entry.meta.dateFrom,
          endTime: entry.meta.dateTo,
          entry: entry,
          categoryId: entry.meta.categoryId,
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
      date: date,
      plannedSlots: plannedSlots,
      actualSlots: actualSlots,
      dayStartHour: dayStartHour,
      dayEndHour: dayEndHour,
    );
  }

  int _calculateDayStartHour(
    List<PlannedTimeSlot> planned,
    List<ActualTimeSlot> actual,
  ) {
    var earliest = 8; // Default start

    if (planned.isNotEmpty) {
      final plannedStart = planned.first.startTime.hour;
      if (plannedStart < earliest) earliest = plannedStart;
    }

    if (actual.isNotEmpty) {
      final actualStart = actual.first.startTime.hour;
      if (actualStart < earliest) earliest = actualStart;
    }

    return earliest;
  }

  int _calculateDayEndHour(
    List<PlannedTimeSlot> planned,
    List<ActualTimeSlot> actual,
  ) {
    var latest = 18; // Default end

    if (planned.isNotEmpty) {
      final plannedEnd = planned.last.endTime.hour + 1;
      if (plannedEnd > latest) latest = plannedEnd;
    }

    if (actual.isNotEmpty) {
      final actualEnd = actual.last.endTime.hour + 1;
      if (actualEnd > latest) latest = actualEnd;
    }

    return latest.clamp(0, 24);
  }
}
