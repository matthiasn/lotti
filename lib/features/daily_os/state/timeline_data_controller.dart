import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// One positioned segment on the daily timeline, either planned or actual.
///
/// Sealed so the two concrete cases ([PlannedTimeSlot], [ActualTimeSlot]) can
/// be exhaustively switched on. Carries a start/end time and an optional
/// resolved [categoryId] (for actual slots this is the category resolved
/// through the linked parent, not necessarily the raw entry's own category).
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

  /// Resolves [categoryId] to its [CategoryDefinition] via the in-memory
  /// [EntitiesCacheService]; null when uncategorised or the id is unknown.
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

/// The fully-resolved input the timeline widget paints for one day: the
/// planned blocks ([plannedSlots]) drawn in the plan lane and the recorded
/// entries ([actualSlots]) drawn in the actual lane, both pre-sorted by start
/// time, plus the [dayStartHour]/[dayEndHour] bounds computed by
/// `calculateDayStartHour`/`calculateDayEndHour` that frame the visible axis.
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
