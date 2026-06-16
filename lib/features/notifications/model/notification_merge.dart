import 'dart:convert';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Conflict-free merge rules for synced notification rows.
///
/// Notifications replicate across devices via Matrix sync, so two hosts can
/// edit the same row before they exchange events. These pure static helpers
/// resolve those conflicts deterministically so every device converges on the
/// same row regardless of event-arrival order:
/// - **Content** (title/body/kind) follows last-writer-wins on
///   `meta.updatedAt`, broken by a canonical-JSON comparison so identical
///   timestamps still pick a stable winner on every host.
/// - **Lifecycle state** (`seenAt`/`actedOnAt`/`deletedAt`) converges via
///   [earliestNonNull]: these transitions are monotonic and irreversible, so
///   the first device to observe each transition wins permanently.
/// - **Vector clocks** are unioned via `VectorClock.merge`.
///
/// All methods are side-effect free; persistence and transaction scoping live
/// in `NotificationsDb` (see its `upsertNotification` / `mergeState`).
class NotificationMerge {
  const NotificationMerge._();

  /// Merges a fully-formed [incoming] row against the local [existing] one.
  ///
  /// Used by `NotificationsDb.upsertNotification` when a synced create/update
  /// lands on a row that already exists locally. Content fields come from the
  /// last-writer-wins winner (see the class doc), while the three lifecycle
  /// timestamps and the vector clock are merged independently of who won the
  /// content race — so a remote title edit cannot resurrect a row this device
  /// already marked seen/acted-on/deleted.
  static NotificationEntity mergeFull(
    NotificationEntity existing,
    NotificationEntity incoming,
  ) {
    final contentWinner = _chooseContentWinner(existing, incoming);
    final existingMeta = existing.meta;
    final incomingMeta = incoming.meta;
    final winnerMeta = contentWinner.meta;

    return contentWinner.copyWithMeta(
      winnerMeta.copyWith(
        seenAt: earliestNonNull(existingMeta.seenAt, incomingMeta.seenAt),
        actedOnAt: earliestNonNull(
          existingMeta.actedOnAt,
          incomingMeta.actedOnAt,
        ),
        deletedAt: earliestNonNull(
          existingMeta.deletedAt,
          incomingMeta.deletedAt,
        ),
        vectorClock: VectorClock.merge(
          existingMeta.vectorClock,
          incomingMeta.vectorClock,
        ),
      ),
    );
  }

  /// Applies a lifecycle-only state change to [existing], leaving its content
  /// untouched.
  ///
  /// Used for local actions (mark-seen/acted-on/retract) and for sync state
  /// events that carry no content. Each supplied timestamp is folded in with
  /// [earliestNonNull] so re-applying or racing the same transition is
  /// idempotent and never moves a timestamp later. A non-empty
  /// [originatingHostId] overwrites the stored value (the last host to touch
  /// state owns it); empty/null preserves the existing one. A non-null
  /// [vectorClock] is unioned with the stored clock; null leaves it as-is.
  static NotificationEntity mergeState(
    NotificationEntity existing, {
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
    VectorClock? vectorClock,
    String? originatingHostId,
  }) {
    final meta = existing.meta;
    final mergedMeta = meta.copyWith(
      seenAt: earliestNonNull(meta.seenAt, seenAt),
      actedOnAt: earliestNonNull(meta.actedOnAt, actedOnAt),
      deletedAt: earliestNonNull(meta.deletedAt, deletedAt),
      vectorClock: vectorClock == null
          ? meta.vectorClock
          : VectorClock.merge(meta.vectorClock, vectorClock),
      originatingHostId: originatingHostId?.isNotEmpty ?? false
          ? originatingHostId!
          : meta.originatingHostId,
    );
    return existing.copyWithMeta(mergedMeta);
  }

  /// Returns the earlier of two optional timestamps, treating null as "not yet
  /// observed".
  ///
  /// This is the convergence rule for the monotonic lifecycle fields: once any
  /// device records a transition, that time sticks and the earliest wins
  /// across all hosts.
  static DateTime? earliestNonNull(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  /// Whether a merge produced no change, i.e. the merged row equals what was
  /// already stored.
  ///
  /// `NotificationsDb` calls this after merging so an idempotent sync apply
  /// can skip the write and the change notification — a no-op merge should not
  /// fan out an `UpdateNotifications` event or re-emit to the outbox.
  static bool same(NotificationEntity left, NotificationEntity right) {
    return left == right;
  }

  static NotificationEntity _chooseContentWinner(
    NotificationEntity existing,
    NotificationEntity incoming,
  ) {
    final updatedComparison = existing.meta.updatedAt.compareTo(
      incoming.meta.updatedAt,
    );
    if (updatedComparison < 0) return incoming;
    if (updatedComparison > 0) return existing;

    final existingJson = jsonEncode(_canonicalTieBreakJson(existing));
    final incomingJson = jsonEncode(_canonicalTieBreakJson(incoming));
    return incomingJson.compareTo(existingJson) > 0 ? incoming : existing;
  }

  // Builds a canonical map for deterministic tie-breaking when two devices
  // produce edits with identical updatedAt. Sorting keys recursively makes
  // the comparison stable across app versions that may differ in JSON key
  // insertion order. Meta state fields that converge via earliest-non-null
  // merging are stripped so they never participate in the tie-break.
  static Map<String, dynamic> _canonicalTieBreakJson(NotificationEntity e) {
    final json = Map<String, dynamic>.from(e.toJson());
    final meta = Map<String, dynamic>.from(e.meta.toJson())
      ..remove('seenAt')
      ..remove('actedOnAt')
      ..remove('deletedAt')
      ..remove('vectorClock');
    json['meta'] = meta;
    return _canonicalize(json)! as Map<String, dynamic>;
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return {
        for (final entry in entries)
          entry.key.toString(): _canonicalize(entry.value),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}
