import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Update-notification channel fired whenever the persisted saved-task-filter
/// list changes — locally or via an applied sync message.
const savedTaskFiltersNotification = 'SAVED_TASK_FILTERS_CHANGED';

final savedTaskFiltersRepositoryProvider = Provider<SavedTaskFiltersRepository>(
  (ref) => getIt<SavedTaskFiltersRepository>(),
  name: 'savedTaskFiltersRepositoryProvider',
);

/// Per-item persistence + cross-device sync for [SavedTaskFilter] definitions.
///
/// Mirrors `AiConfigRepository`: every mutation writes locally and, unless it
/// originated from an inbound sync message (`fromSync: true`), enqueues a
/// matching [SyncMessage] so the change propagates to peers. The `fromSync`
/// flag is what breaks the echo loop — an applied remote change never
/// re-enqueues itself.
///
/// The underlying store is still the single [SettingsDb] JSON blob (via
/// [SavedTaskFiltersPersistence]), but every mutation is a per-item
/// read-modify-write serialized by an in-class async lock, so concurrent
/// local edits and inbound sync applies never clobber each other's slices of
/// the list. Derived task counts are computed per-device and are never synced.
class SavedTaskFiltersRepository {
  SavedTaskFiltersRepository(this._persistence, this._updateNotifications);

  final SavedTaskFiltersPersistence _persistence;
  final UpdateNotifications _updateNotifications;

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
    if (previous != null) {
      await previous;
    }
    try {
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
  /// When [fromSync] is false the change is enqueued for peers. When true the
  /// change came from an inbound sync message: it is applied locally under a
  /// last-write-wins guard (a stale incoming revision — strictly older
  /// `updatedAt` than the local copy — is ignored) and never re-enqueued.
  Future<void> upsert(
    SavedTaskFilter filter, {
    bool fromSync = false,
  }) {
    return _runLocked(() async {
      final current = await _persistence.load();
      final idx = current.indexWhere((f) => f.id == filter.id);
      final existing = idx >= 0 ? current[idx] : null;

      // Last-write-wins: drop a remote revision that is strictly older than
      // what we already hold. Only applies when both sides carry timestamps
      // and the change arrived via sync; local edits always win for their own
      // action.
      if (fromSync && existing != null && _isStale(filter, existing)) {
        return;
      }

      // Idempotent no-op: an identical re-delivery (common on catch-up) needs
      // no write, enqueue, or notification.
      if (existing == filter) {
        return;
      }

      final next = [...current];
      if (idx >= 0) {
        next[idx] = filter;
      } else {
        next.add(filter);
      }
      await _persistence.save(next);

      if (!fromSync) {
        await getIt<OutboxService>().enqueueMessage(
          SyncMessage.savedTaskFilter(
            filter: filter,
            status: SyncEntryStatus.update,
          ),
        );
      }
      _updateNotifications.notify(
        {filter.id, savedTaskFiltersNotification},
        fromSync: fromSync,
      );
    });
  }

  /// Removes the saved filter with [id] from the persisted list.
  ///
  /// A no-op when [id] is absent (no write, enqueue, or notification). When
  /// present and [fromSync] is false the removal is enqueued for peers.
  Future<void> delete(
    String id, {
    bool fromSync = false,
  }) {
    return _runLocked(() async {
      final current = await _persistence.load();
      if (!current.any((f) => f.id == id)) {
        return;
      }

      final next = current.where((f) => f.id != id).toList(growable: false);
      await _persistence.save(next);

      if (!fromSync) {
        await getIt<OutboxService>().enqueueMessage(
          SyncMessage.savedTaskFilterDelete(id: id),
        );
      }
      _updateNotifications.notify(
        {id, savedTaskFiltersNotification},
        fromSync: fromSync,
      );
    });
  }

  /// Persists a reordered [filters] list without enqueuing a sync message.
  ///
  /// Order is per-device (the cross-device contract syncs each definition, not
  /// the list order), so reorders stay local — they only re-persist the blob
  /// and notify local listeners.
  Future<void> saveOrder(List<SavedTaskFilter> filters) {
    return _runLocked(() async {
      await _persistence.save(filters);
      _updateNotifications.notify({savedTaskFiltersNotification});
    });
  }

  /// True when [incoming] is a strictly older revision of [existing] — both
  /// carry an `updatedAt` and the incoming one predates the local one.
  bool _isStale(SavedTaskFilter incoming, SavedTaskFilter existing) {
    final incomingAt = incoming.updatedAt;
    final existingAt = existing.updatedAt;
    if (incomingAt == null || existingAt == null) return false;
    return incomingAt.isBefore(existingAt);
  }
}
