import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:meta/meta.dart';

/// A reservation for the next vector clock counter.
///
/// **Persistence is eager (collision-safe, burn-accepting).** The persisted
/// watermark in [SettingsDb] is advanced synchronously at
/// [VectorClockService.reserveNextVectorClock] time, BEFORE any entity write
/// can commit with the returned counter.
///
/// The VC counter lives in `SettingsDb` while entity writes hit other Drift
/// databases (`JournalDb`, `AgentDatabase`) and outbox writes hit a third
/// (`SyncDatabase`) — no transaction spans any two of those files. If we
/// persisted the counter AFTER the entity write, a crash between the entity
/// commit and the counter persist would let the next reservation re-hand an
/// already-used counter: **cross-entity VC collision on disk — permanent,
/// unrecoverable, breaks vector-clock semantics.** Persist-first makes the
/// opposite tradeoff: a crash (or a rejected/failed write) can burn a
/// counter — no entity carries it — which IS recoverable.
///
/// Recovery of burnt counters:
/// - [release] logs the burn and emits a proactive `unresolvable` broadcast
///   (when a handler is registered — see
///   [VectorClockService.setBurnHandler]) so receivers mark the counter as
///   `unresolvable` on arrival instead of waiting for a backfill round-trip.
/// - If the broadcast is missed (offline, crash before enqueue), the
///   fallback is the existing backfill path: the originator answers
///   `unresolvable` when a peer eventually requests the missing counter via
///   `backfill_response_handler.dart`'s "own counter not found" branch.
///
/// A reservation must be finalized exactly once. [VectorClockService.withVcScope]
/// handles this for nested callers automatically; direct callers of
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

  /// Acknowledge the reservation on a successful write. No-op — the counter
  /// was already persisted at [VectorClockService.reserveNextVectorClock]
  /// time. Retained for API stability so [VectorClockService.withVcScope] can
  /// drive a single finalization path. Idempotent.
  Future<void> commit() async {
    if (_finalized) return;
    _finalized = true;
  }

  /// Acknowledge that the reservation will not carry an entity/Matrix event.
  /// The counter is already persisted on disk; this call logs the burn and
  /// asks the registered burn handler (if any) to broadcast an
  /// `unresolvable` hint to peers so they can resolve the gap immediately
  /// instead of waiting for the next backfill round-trip. Idempotent.
  void release() {
    if (_finalized) return;
    _finalized = true;
    _service._onReleaseBurn(_counter);
  }
}

class _VcScope {
  _VcScope(this.parent);

  final _VcScope? parent;
  final List<VcReservation> reservations = [];
}

/// Handler invoked synchronously when a reserved counter is released without
/// a matching write (a "burn"). Implementations typically enqueue a proactive
/// `SyncBackfillResponse(unresolvable=true)` for the given counter so peers
/// close the gap without waiting for the reactive backfill-request path.
///
/// The handler MUST NOT throw. Errors are the handler's responsibility to log
/// and swallow — the VC counter is already persisted and cannot be rewound,
/// so a handler exception would be uselessly destructive.
typedef VcBurnHandler = void Function(int counter);

class VectorClockService {
  VectorClockService() {
    _initialized = init();
  }

  static const Symbol _zoneKey = #_vcScope;

  /// The maximum counter that has been persisted to [SettingsDb].
  /// Under persist-on-reserve semantics [_persistedCounter] and
  /// [_nextAvailableCounter] are always equal outside of the tiny window
  /// inside [reserveNextVectorClock] where the in-memory bump and the
  /// [_persistCounter] write are not yet complete.
  late int _persistedCounter;

  /// The next counter to hand out. Advanced synchronously inside
  /// [reserveNextVectorClock]; see [_persistedCounter] for the persistence
  /// invariant.
  late int _nextAvailableCounter;

  late String _host;

  late final Future<void> _initialized;

  /// Serializes [reserveNextVectorClock] so the in-memory bump, the
  /// [SettingsDb] write, and the return of the reservation happen atomically
  /// from the caller's perspective. Concurrent reservations then see
  /// monotonically increasing counters without ever racing past each other.
  Future<void>? _reserveLock;

  /// Proactive "this counter is unresolvable" broadcast hook. Set by the
  /// composition root via [setBurnHandler]; not wired by default so unit tests
  /// and bootstrap paths (pre-outbox) do not blow up on a null handler. When
  /// absent, burns still log and the backfill responder's reactive path
  /// covers the gap on peer request.
  VcBurnHandler? _burnHandler;

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

  /// Register the proactive burn-broadcast handler. Call this from the
  /// composition root after `OutboxService` is ready. Passing `null` clears
  /// the handler (useful in tests).
  // ignore: use_setters_to_change_properties
  void setBurnHandler(VcBurnHandler? handler) {
    _burnHandler = handler;
  }

  /// Reserve the next vector clock counter.
  ///
  /// Persists the advance to [SettingsDb] BEFORE returning — see the
  /// [VcReservation] class doc for why. The returned reservation must still
  /// be finalized via [VcReservation.commit] on success or
  /// [VcReservation.release] on failure (commit is a no-op; release logs +
  /// broadcasts the burn). When called inside [withVcScope] the finalization
  /// is automatic.
  Future<VcReservation> reserveNextVectorClock({VectorClock? previous}) async {
    await _initialized;

    // Serialize so concurrent reservers never observe the same
    // _nextAvailableCounter between the in-memory bump and the [_persistCounter]
    // flush. Dart's single-threaded execution guards synchronous code, but
    // [_persistCounter] awaits a Drift write, and without this lock another
    // reserver could overtake us between the await points.
    while (_reserveLock != null) {
      await _reserveLock;
    }
    final completer = Completer<void>();
    _reserveLock = completer.future;
    try {
      final previousHostCounter = previous?.vclock[_host];
      final int effectiveCounter;
      if (previousHostCounter != null &&
          previousHostCounter >= _nextAvailableCounter) {
        // Previous clock has a counter >= ours for our host — catch up.
        effectiveCounter = previousHostCounter + 1;
      } else {
        effectiveCounter = _nextAvailableCounter;
      }
      final newWatermark = effectiveCounter + 1;
      _nextAvailableCounter = newWatermark;
      if (_persistedCounter < newWatermark) {
        _persistedCounter = newWatermark;
        await _persistCounter(newWatermark);
      }

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
    } finally {
      _reserveLock = null;
      completer.complete();
    }
  }

  /// Obtain the next vector clock, attaching to an ambient [withVcScope] when
  /// one is present (so a burn-broadcast fires on action failure) and
  /// otherwise committing immediately (counter already persisted on reserve,
  /// so a non-scoped caller that never runs a matching write will burn a
  /// counter — prefer [withVcScope] for failable writes).
  Future<VectorClock> getNextVectorClock({VectorClock? previous}) async {
    final reservation = await reserveNextVectorClock(previous: previous);
    final scope = Zone.current[_zoneKey] as _VcScope?;
    if (scope == null) {
      await reservation.commit();
    }
    return reservation.vc;
  }

  /// Run [action] inside a vector-clock scope.
  ///
  /// Every call to [reserveNextVectorClock] / [getNextVectorClock] made
  /// inside [action] (or transitively, including through other services such
  /// as `MetadataService`) attaches its reservation to this scope.
  ///
  /// On completion:
  /// - [action] returns normally AND ([commitWhen] is null OR
  ///   `commitWhen(result)` is true) → all reservations commit (no-op;
  ///   counters already persisted).
  /// - [action] throws → all reservations release → each burn is logged and
  ///   broadcast via the burn handler. The exception rethrows.
  /// - `commitWhen(result)` is false → all reservations release; [action]'s
  ///   result is still returned.
  ///
  /// Nested scopes delegate to the outermost scope so a single commit/release
  /// decision covers the whole nested chain.
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

  /// Called by [VcReservation.release]. Logs the burn and invokes the
  /// registered broadcast handler (if any). Swallows handler exceptions —
  /// the counter is already on disk, so a throw here would be destructive
  /// for no benefit.
  void _onReleaseBurn(int counter) {
    // DomainLogger may not be registered in some test harnesses / bootstrap
    // paths; use the `isRegistered` guard so a release on a minimally-wired
    // service (e.g. unit test seeding the SettingsDb counter) does not crash.
    if (getIt.isRegistered<DomainLogger>()) {
      getIt<DomainLogger>().error(
        LogDomains.sync,
        'VC counter burnt (reservation released; counter already persisted)',
        subDomain: 'vc.burn',
      );
    }
    final handler = _burnHandler;
    if (handler == null) return;
    try {
      handler(counter);
    } catch (error, stackTrace) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomains.sync,
          'VC burn broadcast handler threw — counter $counter will fall back '
          'to reactive backfill resolution',
          error: error,
          stackTrace: stackTrace,
          subDomain: 'vc.burn.handler',
        );
      }
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
    await _persistCounter(counter);
  }

  @visibleForTesting
  Future<void> increment() async {
    final reservation = await reserveNextVectorClock();
    await reservation.commit();
  }
}
