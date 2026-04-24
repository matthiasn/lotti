import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:meta/meta.dart';

/// A reservation for the next vector clock counter.
///
/// Every counter advance flows through a reservation. The in-memory watermark
/// is bumped synchronously at [VectorClockService.reserveNextVectorClock] time
/// so concurrent reservations do not collide, but the persistent watermark
/// only moves on [commit]. [release] leaves the persistent state untouched.
///
/// A reservation must be finalized exactly once. [VectorClockService.withVcScope]
/// handles this for nested callers automatically; callers of
/// [VectorClockService.reserveNextVectorClock] outside a scope must finalize
/// the returned reservation themselves.
class VcReservation {
  VcReservation._(this.vc, this._counter, this._service);

  /// The reserved vector clock.
  final VectorClock vc;
  final int _counter;
  final VectorClockService _service;
  bool _finalized = false;

  /// Whether the reservation is still pending (neither committed nor released).
  bool get isPending => !_finalized;

  /// Persist the counter advance. Idempotent: subsequent calls are no-ops.
  ///
  /// Call this only after the entire write+enqueue pipeline that is supposed
  /// to carry the counter has completed successfully. A burnt commit means a
  /// counter is consumed on disk but no Matrix event was emitted carrying it,
  /// producing a gap on receivers.
  Future<void> commit() async {
    if (_finalized) return;
    _finalized = true;
    await _service._commitReservation(_counter);
  }

  /// Roll back the reservation without persisting. Idempotent.
  ///
  /// The in-memory watermark will rewind only when this was the most-recent
  /// reservation AND no other reservations are outstanding. Otherwise the
  /// counter is abandoned in-memory (no persisted burn), which means the
  /// next reservation may skip past it — a receiver that observes a later
  /// Matrix event from this host will detect the gap, and the originator
  /// will answer any backfill request for the abandoned counter with
  /// `unresolvable` via the sequence log's "own counter not found" path.
  void release() {
    if (_finalized) return;
    _finalized = true;
    _service._releaseReservation(_counter);
  }
}

class _VcScope {
  _VcScope(this.parent);

  final _VcScope? parent;
  final List<VcReservation> reservations = [];
}

class VectorClockService {
  VectorClockService() {
    _initialized = init();
  }

  static const Symbol _zoneKey = #_vcScope;

  /// The maximum counter that has been persisted to [SettingsDb].
  /// Always `<= _nextAvailableCounter`.
  late int _persistedCounter;

  /// The next counter to hand out. Advanced synchronously by
  /// [reserveNextVectorClock] before any persistence so concurrent reservations
  /// see distinct counters; rewound by [_releaseReservation] only when this
  /// was the most-recent reservation with no siblings outstanding.
  late int _nextAvailableCounter;

  late String _host;

  /// Set of counters reserved but not yet committed or released. Used by
  /// release to decide whether a rewind is safe.
  final Set<int> _outstanding = <int>{};

  late final Future<void> _initialized;

  /// Future that completes when initialization is done.
  /// Await this before using the service to ensure it's ready.
  Future<void> get initialized => _initialized;

  Future<void> init() async {
    final storedValues = await getIt<SettingsDb>().itemsByKeys({
      hostKey,
      nextAvailableCounterKey,
    });
    final storedHost = storedValues[hostKey];
    if (storedHost == null) {
      await setNewHost();
      return;
    }

    _host = storedHost;
    final storedCounter = storedValues[nextAvailableCounterKey];
    if (storedCounter != null) {
      _persistedCounter = int.parse(storedCounter);
    } else {
      _persistedCounter = 0;
      await _persistCounter(0);
    }
    _nextAvailableCounter = _persistedCounter;
  }

  Future<String> setNewHost() async {
    final host = uuid.v4();

    await getIt<SettingsDb>().saveSettingsItem(hostKey, host);
    _host = host;
    _persistedCounter = 0;
    _nextAvailableCounter = 0;
    _outstanding.clear();
    await _persistCounter(0);
    return host;
  }

  Future<String?> getHost() async {
    return _host;
  }

  Future<String?> getHostHash() async {
    final host = await getHost();

    if (host == null) {
      return null;
    }

    final bytes = utf8.encode(host);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  /// Reserve the next vector clock counter.
  ///
  /// The reservation bumps the in-memory watermark but does not persist. The
  /// caller is responsible for finalizing the reservation via
  /// [VcReservation.commit] (advance the persisted watermark) or
  /// [VcReservation.release] (roll back).
  ///
  /// When called inside [withVcScope], the reservation is automatically
  /// attached to the scope and the scope handles the finalization based on
  /// the action's outcome.
  Future<VcReservation> reserveNextVectorClock({VectorClock? previous}) async {
    await _initialized;
    // Synchronous block — no await between read and write of
    // _nextAvailableCounter, so Dart's single-threaded execution model makes
    // the arithmetic atomic.
    final previousHostCounter = previous?.vclock[_host];
    final int effectiveCounter;
    if (previousHostCounter != null &&
        previousHostCounter >= _nextAvailableCounter) {
      // Previous clock has a counter >= ours for our host - catch up.
      effectiveCounter = previousHostCounter + 1;
    } else {
      effectiveCounter = _nextAvailableCounter;
    }
    _nextAvailableCounter = effectiveCounter + 1;
    _outstanding.add(effectiveCounter);

    final reservation = VcReservation._(
      VectorClock({...?previous?.vclock, _host: effectiveCounter}),
      effectiveCounter,
      this,
    );

    final scope = Zone.current[_zoneKey] as _VcScope?;
    if (scope != null) {
      scope.reservations.add(reservation);
    }

    return reservation;
  }

  /// Obtain the next vector clock with scope-aware auto-commit semantics.
  ///
  /// - Outside a [withVcScope]: the reservation is committed immediately
  ///   (legacy behavior — a burnt counter if the caller's write fails).
  /// - Inside a [withVcScope]: the reservation is attached to the scope and
  ///   finalized according to the action's outcome (commit on success, release
  ///   on failure or `commitWhen == false`).
  ///
  /// Prefer wrapping a failable write path in [withVcScope] so the counter
  /// rolls back when the write rejects (e.g., `applied=false`).
  Future<VectorClock> getNextVectorClock({VectorClock? previous}) async {
    final reservation = await reserveNextVectorClock(previous: previous);
    final scope = Zone.current[_zoneKey] as _VcScope?;
    if (scope == null) {
      await reservation.commit();
    }
    // Inside a scope, the scope finalizes the reservation.
    return reservation.vc;
  }

  /// Run [action] inside a vector-clock scope.
  ///
  /// Every call to [reserveNextVectorClock] / [getNextVectorClock] made
  /// inside [action] (or transitively, including through other services such
  /// as `MetadataService`) attaches its reservation to this scope instead of
  /// committing immediately.
  ///
  /// On completion:
  /// - [action] returns normally AND ([commitWhen] is null OR
  ///   `commitWhen(result)` is true) → all reservations in this scope commit.
  /// - [action] throws → all reservations release. The exception rethrows.
  /// - `commitWhen(result)` is false → all reservations release; [action]'s
  ///   result is still returned.
  ///
  /// Nested scopes are supported: an inner [withVcScope] call delegates to
  /// the existing outer scope (no new scope is created), so a single
  /// commit/release decision covers the whole nested chain.
  Future<T> withVcScope<T>(
    Future<T> Function() action, {
    bool Function(T result)? commitWhen,
  }) async {
    await _initialized;
    final parent = Zone.current[_zoneKey] as _VcScope?;
    if (parent != null) {
      // Nested: the outer scope owns finalization. Just run the action.
      return action();
    }

    final scope = _VcScope(null);
    try {
      final result = await runZoned(action, zoneValues: {_zoneKey: scope});
      final shouldCommit = commitWhen?.call(result) ?? true;
      if (shouldCommit) {
        for (final reservation in scope.reservations) {
          await reservation.commit();
        }
      } else {
        // Release in reverse order so the rewind heuristic in
        // [_releaseReservation] can collapse a contiguous tail back to the
        // pre-reservation watermark.
        for (final reservation in scope.reservations.reversed) {
          reservation.release();
        }
      }
      return result;
    } catch (_) {
      for (final reservation in scope.reservations.reversed) {
        reservation.release();
      }
      rethrow;
    }
  }

  Future<void> _commitReservation(int counter) async {
    _outstanding.remove(counter);
    final target = counter + 1;
    if (_persistedCounter < target) {
      _persistedCounter = target;
      await _persistCounter(target);
    }
  }

  void _releaseReservation(int counter) {
    _outstanding.remove(counter);
    // Rewind the in-memory watermark only when this release targets the
    // most-recent reservation (`counter + 1 == _nextAvailableCounter`).
    // Callers that release in reverse chronological order (including the
    // [withVcScope] finalizer) collapse a contiguous tail back to the
    // pre-scope watermark. A middle-release leaves a gap that sibling
    // reservations already committed past — that counter is abandoned.
    if (_nextAvailableCounter == counter + 1) {
      _nextAvailableCounter = counter;
    }
  }

  Future<void> _persistCounter(int counter) async {
    await getIt<SettingsDb>().saveSettingsItem(
      nextAvailableCounterKey,
      counter.toString(),
    );
  }

  // ---------------------------------------------------------------------------
  // Test-only helpers retained so existing unit tests can still poke at the
  // persisted counter directly. Production code must go through
  // [reserveNextVectorClock] / [withVcScope] / [getNextVectorClock].
  // ---------------------------------------------------------------------------

  @visibleForTesting
  Future<int> getNextAvailableCounter() async => _nextAvailableCounter;

  @visibleForTesting
  Future<void> setNextAvailableCounter(int counter) async {
    _nextAvailableCounter = counter;
    _persistedCounter = counter;
    _outstanding.clear();
    await _persistCounter(counter);
  }

  @visibleForTesting
  Future<void> increment() async {
    final reservation = await reserveNextVectorClock();
    await reservation.commit();
  }
}
