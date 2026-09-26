import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// Update-notification channel fired whenever the persisted saved-task-filter
/// list changes — locally or via an applied sync message.
const savedTaskFiltersNotification = 'SAVED_TASK_FILTERS_CHANGED';

final savedTaskFiltersRepositoryProvider = Provider<SavedTaskFiltersRepository>(
  (ref) => getIt<SavedTaskFiltersRepository>(),
  name: 'savedTaskFiltersRepositoryProvider',
);

/// Per-item persistence + cross-device sync for [SavedTaskFilter] definitions.
///
/// Every local mutation writes locally and owes the peers a [SyncMessage];
/// one that originated from an inbound sync message (`fromSync: true`) owes
/// nothing, which is what breaks the echo loop.
///
/// What is owed is durable. The id goes into the [SavedTaskFilterSyncLedger]
/// before the write and leaves it only once the outbox accepted the row, and
/// [flushPending] sends whatever the ledger still owes: after every write, on
/// a retry timer after a failure, and at startup. A device whose ledger does
/// not exist yet — one that saved filters before they synced — owes every
/// filter it holds. The protocol, and the model TLC checks it against, is
/// `specs/tla/SavedTaskFilterSync.tla`.
///
/// Revisions are ordered totally, so every device settles on the same one
/// whatever order they arrive in: by `updatedAt` (a missing stamp is oldest),
/// then by content. A delete is kept as a tombstone with its stamp and beats
/// any revision at or before it. A local write is stamped past the revision
/// it replaces, so a device whose clock runs behind cannot write a change its
/// peers would discard as stale.
///
/// The underlying store is the `SettingsDb` JSON blob (via
/// [SavedTaskFiltersPersistence]); every mutation is a read-modify-write
/// serialized by an in-class async lock, so concurrent local edits and inbound
/// sync applies never clobber each other's slices of the list. Derived task
/// counts are computed per-device and are never synced.
class SavedTaskFiltersRepository {
  SavedTaskFiltersRepository(
    this._persistence,
    this._updateNotifications, {
    this.retryDelay = const Duration(minutes: 1),
  });

  final SavedTaskFiltersPersistence _persistence;
  final UpdateNotifications _updateNotifications;

  /// How long after a failed enqueue the owed rows are tried again.
  final Duration retryDelay;

  Timer? _retryTimer;
  bool _disposed = false;

  // Serializes the read-modify-write so two writers never interleave their
  // load/save. Each call awaits the previous holder's completer before running;
  // the uncontended path (the common case) runs the action immediately with no
  // intermediate Future indirection, which keeps it well-behaved under
  // flutter_test's fake-async microtask flushing.
  Completer<void>? _lockTail;

  Future<T> _runLocked<T>(Future<T> Function() action) async {
    final previous = _lockTail?.future;
    final mine = Completer<void>();
    _lockTail = mine;
    // `await previous` sits *inside* the try so a throwing predecessor still
    // runs the finally and completes `mine` — otherwise every later caller
    // would await a completer that never fires and deadlock permanently.
    try {
      if (previous != null) {
        await previous;
      }
      return await action();
    } finally {
      if (identical(_lockTail, mine)) _lockTail = null;
      mine.complete();
    }
  }

  /// Loads the persisted list (ordered). Reads are not locked: a single
  /// `SettingsDb` key read is atomic, and callers tolerate a snapshot taken
  /// just before an in-flight write commits.
  Future<List<SavedTaskFilter>> load() => _persistence.load();

  /// Inserts or replaces [filter] (matched by id) in the persisted list.
  ///
  /// When [fromSync] is false the change is owed to the peers and flushed.
  /// Its `updatedAt` is raised past the stored revision's when the caller's
  /// clock is behind it.
  ///
  /// When [fromSync] is true the change came from an inbound sync message and
  /// is applied only if it is newer than what is stored, and than any
  /// tombstone of its id. It is never re-sent.
  Future<void> upsert(
    SavedTaskFilter filter, {
    bool fromSync = false,
  }) {
    return _runLocked(() async {
      final current = await _persistence.load();
      final idx = current.indexWhere((f) => f.id == filter.id);
      final existing = idx >= 0 ? current[idx] : null;

      // Idempotent no-op: an identical re-delivery (common on catch-up) needs
      // no write, enqueue, or notification.
      if (existing == filter) {
        return;
      }

      final ledger = await _loadLedger(current);
      final SavedTaskFilter next;
      if (fromSync) {
        final tombstone = ledger.tombstones[filter.id];
        if (tombstone != null && !_stampOf(filter).isAfter(tombstone)) {
          return;
        }
        if (existing != null && compareRevisions(filter, existing) <= 0) {
          return;
        }
        next = filter;
      } else {
        next = _stampedPast(filter, existing);
        await _persistence.saveLedger(
          ledger.copyWith(pending: {...ledger.pending, next.id}),
        );
      }

      final list = [...current];
      if (idx >= 0) {
        list[idx] = next;
      } else {
        list.add(next);
      }
      await _persistence.save(list);
      _updateNotifications.notify(
        {next.id, savedTaskFiltersNotification},
        fromSync: fromSync,
      );
      if (!fromSync) {
        await _flush();
      }
    });
  }

  /// Removes the saved filter with [id] from the persisted list.
  ///
  /// A local delete of an absent [id] is a no-op (no write, enqueue, or
  /// notification). A present one is tombstoned, stamped no earlier than the
  /// revision it removes, and owed to the peers.
  ///
  /// A delete from sync ([fromSync]) carrying [deletedAt] is ignored when the
  /// stored revision is newer — an edit made after the delete — and otherwise
  /// removes the filter and keeps the tombstone, even for an id this device
  /// has not received yet. One without [deletedAt], from a build that
  /// predates tombstones, removes the filter unconditionally.
  Future<void> delete(
    String id, {
    bool fromSync = false,
    DateTime? deletedAt,
  }) {
    return _runLocked(() async {
      final current = await _persistence.load();
      final existing = current.where((f) => f.id == id).firstOrNull;
      if (!fromSync && existing == null) {
        return;
      }

      final ledger = await _loadLedger(current);
      final DateTime? stamp;
      if (fromSync) {
        stamp = deletedAt;
        if (stamp != null &&
            existing != null &&
            _stampOf(existing).isAfter(stamp)) {
          return;
        }
      } else {
        final now = clock.now();
        final revision = _stampOf(existing!);
        stamp = revision.isAfter(now) ? revision : now;
      }

      if (stamp != null) {
        final kept = ledger.tombstones[id];
        final tombstone = kept != null && kept.isAfter(stamp) ? kept : stamp;
        await _persistence.saveLedger(
          ledger.copyWith(
            pending: fromSync ? ledger.pending : {...ledger.pending, id},
            tombstones: {...ledger.tombstones, id: tombstone},
          ),
        );
      }

      if (existing != null) {
        await _persistence.save(
          current.where((f) => f.id != id).toList(growable: false),
        );
        _updateNotifications.notify(
          {id, savedTaskFiltersNotification},
          fromSync: fromSync,
        );
      }
      if (!fromSync) {
        await _flush();
      }
    });
  }

  /// Persists the stored filters in the order of [orderedIds], without
  /// enqueuing a sync message.
  ///
  /// Order is per-device (the cross-device contract syncs each definition, not
  /// the list order), so reorders stay local. The order is applied to what is
  /// stored now, not to the caller's copy of it: a filter that arrived by
  /// sync after the caller last loaded keeps its place at the end, and an id
  /// no longer stored is ignored.
  Future<void> saveOrder(List<String> orderedIds) {
    return _runLocked(() async {
      final current = await _persistence.load();
      final byId = {for (final f in current) f.id: f};
      final ordered = [for (final id in orderedIds) ?byId.remove(id)];
      await _persistence.save([
        ...ordered,
        ...current.where((f) => byId.containsKey(f.id)),
      ]);
      _updateNotifications.notify({savedTaskFiltersNotification});
    });
  }

  /// Sends every row the ledger still owes: the stored revision of each owed
  /// id, or its tombstone. Called at startup, and by the retry timer.
  Future<void> flushPending() => _runLocked(_flush);

  /// Stops the retry timer.
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Sends the owed rows, one at a time, clearing each id from the ledger as
  /// the outbox accepts its row. On the first failure the rest stay owed and
  /// a retry is scheduled; the failure is logged, never thrown, because the
  /// write it follows has committed and what it owes is already durable.
  /// Runs under the lock.
  Future<void> _flush() async {
    try {
      final current = await _persistence.load();
      var ledger = await _loadLedger(current);
      for (final id in ledger.pending.toList()..sort()) {
        final message = _owedMessage(id, current, ledger);
        if (message != null) {
          await getIt<OutboxService>().enqueueMessageOrThrow(message);
        }
        ledger = ledger.copyWith(pending: {...ledger.pending}..remove(id));
        await _persistence.saveLedger(ledger);
      }
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'savedTaskFilters.flush',
      );
      _scheduleRetry();
    }
  }

  /// The row that carries [id]'s current state, or null for an id that is
  /// neither stored nor tombstoned.
  SyncMessage? _owedMessage(
    String id,
    List<SavedTaskFilter> current,
    SavedTaskFilterSyncLedger ledger,
  ) {
    final filter = current.where((f) => f.id == id).firstOrNull;
    if (filter != null) {
      return SyncMessage.savedTaskFilter(
        filter: filter,
        status: SyncEntryStatus.update,
      );
    }
    final tombstone = ledger.tombstones[id];
    if (tombstone != null) {
      return SyncMessage.savedTaskFilterDelete(id: id, deletedAt: tombstone);
    }
    return null;
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retryTimer ??= Timer(retryDelay, () {
      _retryTimer = null;
      unawaited(flushPending());
    });
  }

  /// The ledger. A device that has never written one gets — and persists — a
  /// ledger that owes every filter in [current]: they were saved before saved
  /// filters synced, so no peer has been sent them. Runs under the lock.
  Future<SavedTaskFilterSyncLedger> _loadLedger(
    List<SavedTaskFilter> current,
  ) async {
    final stored = await _persistence.loadLedger();
    if (stored != null) return stored;
    final migrated = SavedTaskFilterSyncLedger(
      pending: {for (final f in current) f.id},
    );
    await _persistence.saveLedger(migrated);
    return migrated;
  }

  /// [filter], with its stamp raised past [existing]'s when it is not later.
  SavedTaskFilter _stampedPast(
    SavedTaskFilter filter,
    SavedTaskFilter? existing,
  ) {
    final previous = existing?.updatedAt;
    final stamp = filter.updatedAt;
    if (previous == null || (stamp != null && stamp.isAfter(previous))) {
      return filter;
    }
    return filter.copyWith(
      updatedAt: previous.add(const Duration(milliseconds: 1)),
    );
  }
}

// A filter saved before revisions were stamped ranks below every stamp.
final _unstamped = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

DateTime _stampOf(SavedTaskFilter filter) => filter.updatedAt ?? _unstamped;

/// Orders two revisions of one saved filter: negative when [a] is older than
/// [b], zero when they are equal, positive when [a] is newer.
///
/// By `updatedAt` first, a missing stamp ranking lowest; equal stamps are
/// ordered by the filters' canonical JSON, so two devices comparing the same
/// pair agree whichever of them holds which.
int compareRevisions(SavedTaskFilter a, SavedTaskFilter b) {
  if (a == b) return 0;
  final byStamp = _stampOf(a).compareTo(_stampOf(b));
  if (byStamp != 0) return byStamp;
  return _canonicalJson(a.toJson()).compareTo(_canonicalJson(b.toJson()));
}

/// JSON with map keys sorted and list elements sorted. Every list in a saved
/// filter encodes a set, whose iteration order is not part of its value.
String _canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) => switch (value) {
  final Map<String, dynamic> map => {
    for (final key in map.keys.toList()..sort()) key: _canonical(map[key]),
  },
  final List<dynamic> list =>
    list.map(_canonical).toList()
      ..sort((x, y) => jsonEncode(x).compareTo(jsonEncode(y))),
  _ => value,
};
