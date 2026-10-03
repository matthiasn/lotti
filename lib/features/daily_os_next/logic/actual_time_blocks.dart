import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/recorded_time.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';

const _fallbackActualCategory = DayAgentCategory(
  id: 'uncategorized',
  name: '',
  colorHex: '8E8E8E',
);

/// Projects the day's entries onto the Actual lane.
///
/// A [JournalEvent] becomes a [TimeBlockType.cal] block so the timeline can
/// route a tap to the event page, in the state its status implies; everything
/// else is a [TimeBlockType.manual] recording, finished by definition.
/// [eventsEnabled] is the Events feature flag, forwarded to the shared core.
List<TimeBlock> actualTimeBlocksForEntries({
  required List<JournalEntity> entries,
  required List<EntryLink> links,
  required Map<String, JournalEntity> linkedFromById,
  required CategoryDefinition? Function(String id) categoryById,
  required bool eventsEnabled,
}) {
  // The shared core decides what counts as recorded time (tombstones,
  // zero-length entries, linked-from resolution, events); this projection
  // only shapes the resolved pairs into UI TimeBlocks.
  final resolved = resolveTimeEntries(
    entries: entries,
    links: links,
    linkedFromById: linkedFromById,
    eventsEnabled: eventsEnabled,
  );

  final out = <TimeBlock>[];
  for (final pair in resolved) {
    final entry = pair.entry;
    final category = projectDayAgentCategory(pair.categoryId, categoryById);
    final title = _actualBlockTitle(
      entry: entry,
      linkedFrom: pair.linkedFrom,
      category: category,
    );

    out.add(
      TimeBlock(
        id: '$actualTimeBlockIdPrefix${entry.meta.id}',
        title: title,
        start: entry.meta.dateFrom,
        end: entry.meta.dateTo,
        type: entry is JournalEvent ? TimeBlockType.cal : TimeBlockType.manual,
        state: entry is JournalEvent
            ? eventBlockState(entry)
            : TimeBlockState.completed,
        category: category,
        taskId: pair.taskId,
      ),
    );
  }

  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// The lane state an [event] projects to: a recording is finished by
/// definition, an event is only as far along as its status says.
///
/// `completed` earns the tracked lane's check mark (and a place in "N done"
/// on the time-spent card), `ongoing` the in-progress treatment, and an event
/// still ahead of the user — tentative, planned, rescheduled — is `committed`:
/// on the lane, filled, unchecked. Cancelled, missed and postponed never reach
/// the projection ([resolveTimeEntries] drops them), so they map to
/// [TimeBlockState.dropped] only to keep the mapping total.
TimeBlockState eventBlockState(JournalEvent event) =>
    switch (event.data.status) {
      EventStatus.completed => TimeBlockState.completed,
      EventStatus.ongoing => TimeBlockState.inProgress,
      EventStatus.tentative ||
      EventStatus.planned ||
      EventStatus.rescheduled => TimeBlockState.committed,
      EventStatus.cancelled ||
      EventStatus.missed ||
      EventStatus.postponed => TimeBlockState.dropped,
    };

/// Projects [categoryId] onto the chip the Daily OS surfaces draw: the
/// category's name and six-digit colour, or a neutral fallback when the id is
/// missing or unknown.
DayAgentCategory projectDayAgentCategory(
  String? categoryId,
  CategoryDefinition? Function(String id) categoryById,
) {
  if (categoryId == null || categoryId.isEmpty) return _fallbackActualCategory;
  final category = categoryById(categoryId);
  final rawColor = (category?.color ?? _fallbackActualCategory.colorHex)
      .replaceFirst('#', '');
  final normalizedColor = rawColor.length >= 6
      ? rawColor.substring(0, 6)
      : _fallbackActualCategory.colorHex;
  return DayAgentCategory(
    id: categoryId,
    name: category?.name ?? categoryId,
    colorHex: normalizedColor,
  );
}

String _actualBlockTitle({
  required JournalEntity entry,
  required JournalEntity? linkedFrom,
  required DayAgentCategory category,
}) {
  // An event is titled on its own page; that title is the block's. An
  // untitled event falls through the same chain as any other recording.
  if (entry is JournalEvent) {
    final eventTitle = entry.data.title.trim();
    if (eventTitle.isNotEmpty) return eventTitle;
  }

  if (linkedFrom is Task) {
    final taskTitle = linkedFrom.data.title.trim();
    if (taskTitle.isNotEmpty) return taskTitle;
  }

  // A check-in is time spent with someone: the block names the person, not
  // the first line of what was said.
  if (entry is CheckInEntry && linkedFrom is RelationshipEntry) {
    final name = linkedFrom.data.title.trim();
    if (name.isNotEmpty) return name;
  }

  final entryText = entry.entryText?.plainText.trim();
  if (entryText != null && entryText.isNotEmpty) {
    return entryText.split('\n').first.trim();
  }

  // An imported workout carries no text and no category; its activity is the
  // title ("Walking"), not the entry id the last fallback would print.
  if (entry is WorkoutEntry) {
    final activity = humanWorkoutType(entry.data.workoutType);
    if (activity.isNotEmpty) return activity;
  }

  if (category.name.isNotEmpty) return category.name;
  return entry.meta.id;
}
