import 'dart:convert';

import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Dequeue-time coalescing of an entity's outbox rows (ADR 0086).
///
/// Enqueue appends one immutable row per version and never merges. When the
/// processor sends a row of an entity, it collapses that entity's pending and
/// failed rows into one send: the newest version's payload, carrying every
/// collapsed row's counter as a covered clock, and the attachment if any
/// collapsed row owed one. Every collapsed row is then marked sent with it.
///
/// Only entity payloads collapse: journal entities, entry links, agent
/// entities and links, and config flags. Their rows share an outbox entry id
/// per entity. Everything else — notifications, consumption events, backfill
/// traffic, onboarding — is sent row by row.

/// The row [row] as the send pipeline sees it: its decoded message and the
/// clock that orders it among the rows of the same entity.
class CollapseCandidate {
  CollapseCandidate(this.row, this.message);

  factory CollapseCandidate.decode(OutboxItem row) => CollapseCandidate(
    row,
    SyncMessage.fromJson(json.decode(row.message) as Map<String, dynamic>),
  );

  final OutboxItem row;
  final SyncMessage message;

  /// The version this row carries, or null for a payload without a clock (a
  /// config flag) — ordered by enqueue order instead.
  VectorClock? get clock => switch (message) {
    final SyncJournalEntity m => m.vectorClock,
    final SyncEntryLink m => m.entryLink.vectorClock,
    final SyncAgentEntity m => m.agentEntity?.vectorClock,
    final SyncAgentLink m => m.agentLink?.vectorClock,
    _ => null,
  };

  /// The counters this row already covers.
  List<VectorClock> get covered => switch (message) {
    final SyncJournalEntity m => m.coveredVectorClocks ?? const [],
    final SyncEntryLink m => m.coveredVectorClocks ?? const [],
    final SyncAgentEntity m => m.coveredVectorClocks ?? const [],
    final SyncAgentLink m => m.coveredVectorClocks ?? const [],
    _ => const [],
  };

  /// Whether this row still owes the peers the entry's attachment.
  bool get needsMedia => row.filePath != null;
}

/// The collapse key of [candidate]: its payload family and its row's outbox
/// entry id, when its message is an entity payload whose rows collapse, else
/// null.
///
/// The family is part of the key because the entry id alone is not unique
/// across families: an agent entity and an agent link, say, can share an id,
/// and folding one into the other would mark a row sent whose object never
/// went out.
String? collapseKeyOf(CollapseCandidate candidate) {
  final entryId = candidate.row.outboxEntryId;
  if (entryId == null) return null;
  final family = switch (candidate.message) {
    SyncJournalEntity() => 'journalEntity',
    SyncEntryLink() => 'entryLink',
    SyncAgentEntity() => 'agentEntity',
    SyncAgentLink() => 'agentLink',
    SyncConfigFlag() => 'configFlag',
    _ => null,
  };
  return family == null ? null : '$family:$entryId';
}

/// Whether [a] is a newer version than [b]: by clock when both carry one and
/// one dominates, otherwise by enqueue order. A clockless payload (a config
/// flag, applied in arrival order) is therefore newest-by-enqueue.
bool _isNewer(CollapseCandidate a, CollapseCandidate b) {
  final ca = a.clock;
  final cb = b.clock;
  if (ca != null && cb != null) {
    final order = _compare(ca, cb);
    if (order == VclockStatus.a_gt_b) return true;
    if (order == VclockStatus.b_gt_a) return false;
  }
  return a.row.id > b.row.id;
}

VclockStatus _compare(VectorClock a, VectorClock b) {
  try {
    return VectorClock.compare(a, b);
  } on VclockException {
    return VclockStatus.concurrent;
  }
}

/// The newest of [candidates], which must not be empty.
CollapseCandidate newestOf(List<CollapseCandidate> candidates) =>
    candidates.reduce((best, c) => _isNewer(c, best) ? c : best);

/// Whether [older] can be folded into a send of [newest]: its version is
/// the newest one or one the newest supersedes. A row whose clock is
/// concurrent with the newest is not: covering it would tell peers they hold
/// a version they do not.
bool supersededBy(CollapseCandidate older, CollapseCandidate newest) {
  if (identical(older, newest)) return true;
  final co = older.clock;
  final cn = newest.clock;
  if (co != null && cn != null) {
    final order = _compare(cn, co);
    return order == VclockStatus.a_gt_b || order == VclockStatus.equal;
  }
  return older.row.id < newest.row.id;
}

/// The message a collapsed send carries: [newest]'s payload, covering every
/// other member's counters, and asking for the attachment when any member
/// owed it.
SyncMessage collapsedMessage(
  CollapseCandidate newest,
  List<CollapseCandidate> members,
) {
  if (members.length == 1) return newest.message;
  final covered = VectorClock.mergeUniqueClocks([
    ...newest.covered,
    for (final m in members)
      if (!identical(m, newest)) ...[m.clock, ...m.covered],
  ]);
  final needsMedia = members.any((m) => m.needsMedia);
  return switch (newest.message) {
    final SyncJournalEntity m => m.copyWith(
      coveredVectorClocks: covered,
      includeAttachments: needsMedia ? true : m.includeAttachments,
    ),
    final SyncEntryLink m => m.copyWith(coveredVectorClocks: covered),
    final SyncAgentEntity m => m.copyWith(coveredVectorClocks: covered),
    final SyncAgentLink m => m.copyWith(coveredVectorClocks: covered),
    final other => other,
  };
}
