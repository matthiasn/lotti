import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/recorded_time.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/signals/health_signal_refresh_service.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/date_utils_extension.dart';

const _fallbackActualCategory = DayAgentCategory(
  id: 'uncategorized',
  name: '',
  colorHex: '8E8E8E',
);

/// Emits whenever recorded ("actual") time entries change, so the actual-time
/// blocks for the day can be recomputed. Bridges the global update-notification
/// stream into Riverpod, dropping empty batches via [actualTimelineUpdateBatches].
// ignore: specify_nonobvious_property_types
final dailyOsActualTimeUpdateProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) {
    final notifications = ref.watch(maybeUpdateNotificationsProvider);
    if (notifications == null) return const Stream<Set<String>>.empty();
    return actualTimelineUpdateBatches(notifications.updateStream);
  },
);

@visibleForTesting
Stream<Set<String>> actualTimelineUpdateBatches(Stream<Set<String>> updates) {
  return updates.where((affectedIds) => affectedIds.isNotEmpty);
}

/// The recorded ("actual") [TimeBlock]s for a given local day, projected from
/// journal entries that overlap that day. Re-runs whenever
/// [dailyOsActualTimeUpdateProvider] signals a change; the heavy lifting
/// (tombstone/zero-length filtering, linked-from resolution) lives in
/// [actualTimeBlocksForEntries] via the shared `resolveTimeEntries` core.
///
/// An event whose span sits inside the day is recorded time too — the user
/// set its start and end on the event page — and lands on the lane as a
/// calendar block whose state follows the event's status
/// ([eventBlockState]). Because events are hidden everywhere while the
/// Events feature is off, the projection watches that flag and re-runs when
/// it flips.
///
/// Workouts are recorded time too, but they reach the journal only through the
/// health import, and nothing on this surface used to ask for one — a walk
/// appeared on the timeline only after some dashboard with a workout chart had
/// been opened. Each recompute therefore nudges the workout delta, fire and
/// forget: the importer throttles it, and the journal write it produces comes
/// back through [dailyOsActualTimeUpdateProvider] to repaint the lane.
// ignore: specify_nonobvious_property_types
final dailyOsActualTimeBlocksProvider = FutureProvider.autoDispose
    .family<List<TimeBlock>, DateTime>((ref, date) async {
      ref.watch(dailyOsActualTimeUpdateProvider);
      final eventsEnabled = ref.watch(
        configFlagProvider(enableEventsFlag).future,
      );
      unawaited(
        ref.read(healthSignalRefreshServiceProvider)?.refreshWorkouts(),
      );
      final db = ref.watch(journalDbProvider);
      final dayStart = date.dayAtMidnight;
      final dayEnd = dayStart.add(const Duration(days: 1));
      final entries = await db.sortedCalendarEntries(
        rangeStart: dayStart,
        rangeEnd: dayEnd,
      );
      final links = await db.basicLinksForEntryIds(
        entries.map((entry) => entry.meta.id).toSet(),
      );
      return actualTimeBlocksForEntries(
        entries: entries,
        links: links,
        linkedFromById: await _linkedFromById(db, links),
        categoryById: _categoryById,
        eventsEnabled: await eventsEnabled,
      );
    });

Future<Map<String, JournalEntity>> _linkedFromById(
  JournalDb db,
  List<EntryLink> links,
) async {
  final linkedFromIds = links.map((link) => link.fromId).toSet();
  if (linkedFromIds.isEmpty) return const {};
  final linked = await db.getJournalEntitiesForIdsUnordered(linkedFromIds);
  return {for (final entity in linked) entity.meta.id: entity};
}

CategoryDefinition? _categoryById(String id) {
  if (!getIt.isRegistered<EntitiesCacheService>()) return null;
  return getIt<EntitiesCacheService>().getCategoryById(id);
}

/// Projects the day's entries onto the Actual lane.
///
/// A [JournalEvent] becomes a [TimeBlockType.cal] block so the timeline can
/// route a tap to the event page, in the state its status implies; everything
/// else is a [TimeBlockType.manual] recording, finished by definition.
/// [eventsEnabled] is the Events feature flag, forwarded to the shared core.
@visibleForTesting
List<TimeBlock> actualTimeBlocksForEntries({
  required List<JournalEntity> entries,
  required List<EntryLink> links,
  required Map<String, JournalEntity> linkedFromById,
  required CategoryDefinition? Function(String id) categoryById,
  required bool eventsEnabled,
}) {
  // The shared core decides what counts as recorded time (tombstones,
  // zero-length entries, linked-from resolution, events); this provider only
  // projects the resolved pairs into UI TimeBlocks.
  final resolved = resolveTimeEntries(
    entries: entries,
    links: links,
    linkedFromById: linkedFromById,
    eventsEnabled: eventsEnabled,
  );

  final out = <TimeBlock>[];
  for (final pair in resolved) {
    final entry = pair.entry;
    final category = _projectCategory(pair.categoryId, categoryById);
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
@visibleForTesting
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

DayAgentCategory _projectCategory(
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
