import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';

/// Shared recorded-time resolution for Daily OS consumers.
///
/// Both the per-day actual-time timeline lane and the planner's week-context
/// lookback need the same answer to "which journal entries count as recorded
/// time, and what work do they belong to?": skip tombstones, skip zero-length
/// entries, and resolve each survivor's linked-from entity (a linked Task wins,
/// ratings never count, otherwise the first surviving non-rating link).
/// An event with a span counts too — it is the user's own statement of where
/// the time went — as long as the Events feature is on and the event
/// actually took place ([eventTookPlace]); an event is always its own thing
/// and is never attributed to the task it may hang off.
/// This module owns that resolution once; each consumer projects the resolved
/// pairs into its own shape (UI `TimeBlock`s, prompt span buckets).

/// A journal entry that counts as recorded time, paired with the entity it was
/// recorded against (if any).
class ResolvedTimeEntry {
  /// Creates a resolved pair. Instances come from [resolveTimeEntries].
  const ResolvedTimeEntry({
    required this.entry,
    required this.linkedFrom,
    required this.duration,
  });

  /// The time-recording journal entry — or the [JournalEvent] — itself
  /// (carries id, dateFrom/dateTo, entry text — everything a UI projection
  /// needs that a bare span loses).
  final JournalEntity entry;

  /// The entity the time was recorded against: a linked [Task] when one
  /// exists, else the first surviving non-rating linked entity, else null.
  /// Always null for a [JournalEvent]: the event is the thing the time went
  /// to, so its own title and category stand.
  final JournalEntity? linkedFrom;

  /// The entry's recorded duration (strictly positive by construction).
  final Duration duration;

  /// The category the recorded time belongs to: the linked-from entity's
  /// category when present, falling back to the entry's own.
  String? get categoryId =>
      linkedFrom?.meta.categoryId ?? entry.meta.categoryId;

  /// The backing task id when the time was recorded against a [Task].
  String? get taskId {
    final linked = linkedFrom;
    return linked is Task ? linked.meta.id : null;
  }

  /// When the recorded time started.
  DateTime get start => entry.meta.dateFrom;
}

/// Whether an [event] took place at the time it carries.
///
/// A cancelled or missed event never happened, and a postponed one has left
/// its slot without yet naming a new one — none of them fills the Actual lane
/// or the planner's recorded-time lookback. Every other status — tentative,
/// planned, ongoing, completed, rescheduled — describes an event that stands
/// at its stored slot: the date line on the event page is the single source
/// of the event's when, so the status is not second-guessed against it.
bool eventTookPlace(JournalEvent event) => switch (event.data.status) {
  EventStatus.cancelled || EventStatus.missed || EventStatus.postponed => false,
  EventStatus.tentative ||
  EventStatus.planned ||
  EventStatus.ongoing ||
  EventStatus.completed ||
  EventStatus.rescheduled => true,
};

/// Resolves the entries that count as recorded time into
/// entry/linked-from pairs.
///
/// Skips deleted entries and entries without a positive [entryDuration];
/// resolves each survivor's linked-from entity via [resolveLinkedFrom] using
/// the non-deleted [links]. Output preserves the order of [entries].
///
/// A [JournalEvent] survives only while [eventsEnabled] (the Events feature
/// flag — with it off, events are hidden everywhere, this resolution
/// included) and while it [eventTookPlace]; it resolves with no linked-from
/// entity, so its own category and title are what the consumers see.
///
/// The [links] are ordered by `(createdAt, fromId)` before the candidate
/// sets are built: the backing query carries no ORDER BY, so its row order
/// is not stable across runs or devices — without this, every
/// order-dependent pick in [resolveLinkedFrom] (the first surviving Task
/// among several, and the first-survivor non-rating fallback) could differ
/// per device. Earliest-created link first matches the insertion order the
/// query typically (but not contractually) returns.
List<ResolvedTimeEntry> resolveTimeEntries({
  required List<JournalEntity> entries,
  required List<EntryLink> links,
  required Map<String, JournalEntity> linkedFromById,
  required bool eventsEnabled,
}) {
  final orderedLinks = links.toList()
    ..sort((a, b) {
      final byCreated = a.createdAt.compareTo(b.createdAt);
      if (byCreated != 0) return byCreated;
      return a.fromId.compareTo(b.fromId);
    });
  final entryIdToLinkedFromIds = <String, Set<String>>{};
  for (final link in orderedLinks) {
    if (link.deletedAt != null) continue;
    entryIdToLinkedFromIds
        .putIfAbsent(link.toId, () => <String>{})
        .add(link.fromId);
  }

  final out = <ResolvedTimeEntry>[];
  for (final entry in entries) {
    if (entry.meta.deletedAt != null) continue;
    final isEvent = entry is JournalEvent;
    if (isEvent && (!eventsEnabled || !eventTookPlace(entry))) continue;
    final duration = entryDuration(entry);
    if (duration <= Duration.zero) continue;

    out.add(
      ResolvedTimeEntry(
        entry: entry,
        linkedFrom: isEvent
            ? null
            : resolveLinkedFrom(
                linkedFromIds: entryIdToLinkedFromIds[entry.meta.id],
                linkedFromById: linkedFromById,
              ),
        duration: duration,
      ),
    );
  }
  return out;
}

/// Picks the entity a time entry was recorded against from its linked-from
/// candidates: the first surviving [Task] wins outright; [RatingEntry]s and
/// tombstones never surface; otherwise the first surviving non-rating entity
/// is the fallback. Returns null when [linkedFromIds] is null or nothing
/// survives.
JournalEntity? resolveLinkedFrom({
  required Set<String>? linkedFromIds,
  required Map<String, JournalEntity> linkedFromById,
}) {
  if (linkedFromIds == null) return null;

  JournalEntity? fallbackNonRating;
  for (final linkedFromId in linkedFromIds) {
    final linkedFrom = linkedFromById[linkedFromId];
    if (linkedFrom == null || linkedFrom.meta.deletedAt != null) continue;
    if (linkedFrom is Task) return linkedFrom;
    if (linkedFrom is RatingEntry) continue;
    fallbackNonRating ??= linkedFrom;
  }
  return fallbackNonRating;
}
