import 'dart:convert';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/classes/vector_clock.dart';

/// Conflict-free merge rules for synced notification rows.
///
/// Notifications replicate across devices via Matrix sync, so two hosts can
/// edit the same row before they exchange events. These pure static helpers
/// resolve those conflicts deterministically so every device converges on the
/// same content, lifecycle and clock regardless of event-arrival order.
/// The last state sender's `originatingHostId` is arrival-dependent metadata:
/// - **Content** (title/body/kind) is the maximum of one total order: the
///   content rank (from `meta.contentVectorClock`, which grows along every
///   causal step), then `meta.updatedAt`, then canonical JSON. A version whose
///   content follows the other therefore wins, and every host settles on the
///   same content whatever order three or more versions arrive in. The row
///   clock is not used, since lifecycle patches advance it without touching
///   the words. A row without a content clock ranks below any with one.
/// - **Lifecycle state** (`seenAt`/`actedOnAt`/`deletedAt`) converges via
///   [earliestNonNull]: these transitions are monotonic and irreversible, so
///   the first device to observe each transition wins permanently.
/// - **Vector clocks** are unioned via `VectorClock.merge`.
///
/// All methods are side-effect free; persistence and transaction scoping live
/// in `NotificationsDb` (see its `upsertNotification` / `mergeState`).
abstract final class NotificationMerge {
  /// Merges a fully-formed [incoming] row against the local [existing] one.
  ///
  /// Used by `NotificationsDb.upsertNotification` when a synced create/update
  /// lands on a row that already exists locally. Content fields come from the
  /// content winner (see the class doc), together with its content clock,
  /// while the three lifecycle timestamps and the row clock are merged
  /// independently of who won the content race — so a remote title edit
  /// cannot resurrect a row this device already marked seen/acted-on/deleted.
  /// Keeping the winner's own content clock, not a union, is what keeps the
  /// content choice independent of arrival order.
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
  /// and its content clock untouched.
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
    // Content goes to the higher content rank whatever the wall clocks say:
    // a peer whose clock runs fast, or a late copy of the template, must not
    // outrank a reword made after it. The rank grows along every causal step,
    // and the full key below is one total order, so the merge picks the same
    // content in any order of arrival.
    final rankComparison = _contentRank(
      existing,
    ).compareTo(_contentRank(incoming));
    if (rankComparison > 0) return existing;
    if (rankComparison < 0) return incoming;

    final updatedComparison = existing.meta.updatedAt.compareTo(
      incoming.meta.updatedAt,
    );
    if (updatedComparison < 0) return incoming;
    if (updatedComparison > 0) return existing;

    final existingJson = jsonEncode(_canonicalTieBreakJson(existing));
    final incomingJson = jsonEncode(_canonicalTieBreakJson(incoming));
    final contentComparison = incomingJson.compareTo(existingJson);
    if (contentComparison != 0) {
      return contentComparison > 0 ? incoming : existing;
    }

    // Equal content still needs a stable metadata winner for full snapshots.
    // A state patch can change the owner, so it must never rank *different*
    // content ahead of the canonical content key.
    return incoming.meta.originatingHostId.compareTo(
              existing.meta.originatingHostId,
            ) >
            0
        ? incoming
        : existing;
  }

  /// The content clock's counters, each plus one, summed. Content that
  /// causally follows other content holds every counter of it and one more,
  /// so its rank is strictly higher; the `+ 1` keeps a host whose first
  /// counter is 0 from adding nothing (ADR 0080). The row clock is not used:
  /// it also counts lifecycle patches that carried no words. A row without a
  /// content clock, or with a malformed one, ranks 0.
  static int _contentRank(NotificationEntity entity) {
    final clock = entity.meta.contentVectorClock;
    if (clock == null || !clock.isValid()) return 0;
    return clock.vclock.values.fold(0, (sum, counter) => sum + counter + 1);
  }

  // Builds a canonical map for deterministic tie-breaking when two devices
  // produce edits with identical updatedAt. Sorting keys recursively makes
  // the comparison stable across app versions that may differ in JSON key
  // insertion order. Meta state fields that converge via earliest-non-null
  // merging, and the owner overwritten by state patches, are stripped so
  // they never participate in the content tie-break.
  static Map<String, dynamic> _canonicalTieBreakJson(NotificationEntity e) {
    final json = Map<String, dynamic>.from(e.toJson());
    final meta = Map<String, dynamic>.from(e.meta.toJson())
      ..remove('seenAt')
      ..remove('actedOnAt')
      ..remove('deletedAt')
      ..remove('originatingHostId')
      ..remove('vectorClock')
      ..remove('contentVectorClock');
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
