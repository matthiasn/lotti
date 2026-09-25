import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
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
/// - reservation writes an own-host `reserved` sequence row before returning
///   the counter, recording the payload it is for when the caller names it
///   ([VcPayloadRef]). If that insert fails the reservation is recorded in
///   [SettingsDb] instead, and startup moves it into the sequence log
///   ([VectorClockService.migrateUnrecordedReservations]); if both fail,
///   reserving throws and no write uses the counter. The outbox binds the
///   row to `received` once the payload is durably enqueued.
/// - A reservation the process has neither bound nor released is *pending*
///   ([VectorClockService.isPending]); only a pending counter may still land,
///   so only pending counters are deferred when a peer asks for them.
/// - A row still `reserved` after its process died is settled by
///   `BackfillResponseHandler.settleOwnCounter`: if the named payload's clock
///   covers the counter the write landed and the counter is bound and
///   resent, otherwise it is burned. An unnamed reservation cannot be proven
///   either way and stays deferred.
/// - [VcReservation.release] upgrades the reservation to `burnPending`,
///   recording its payload, and hands the counter to the burn handler (see
///   [VectorClockService.setBurnHandler]), which settles it the same way: a
///   release never burns a counter whose payload is on disk.
///
/// The protocol is model-checked in `specs/tla/SyncSequence.tla`.
///
/// A reservation must be finalized exactly once. [VectorClockService.withVcScope]
/// handles this for nested callers automatically; direct callers of
/// [VectorClockService.reserveNextVectorClock] outside a scope must finalize
/// the returned reservation themselves.
class VcReservation {
  VcReservation._(
    this.vc,
    this._counter,
    this._hostId,
    this._payload,
    this._service,
  );

  /// The reserved vector clock.
  final VectorClock vc;
  final int _counter;

  /// The payload this counter is for, when the caller named it.
  final VcPayloadRef? _payload;

  /// The host ID at the time of reservation. Captured so that a later burn
  /// broadcast attributes the counter to the correct host even if
  /// [VectorClockService.setNewHost] swaps the service's host between
  /// reservation and release.
  final String _hostId;
  final VectorClockService _service;
  bool _finalized = false;

  /// Acknowledge the reservation on a successful write. No-op — the counter
  /// was already persisted at [VectorClockService.reserveNextVectorClock]
  /// time. Retained for API stability so [VectorClockService.withVcScope] can
  /// drive a single finalization path. Idempotent.
  Future<void> commit() async {
    if (_finalized) return;
    _finalized = true;
  }

  /// Acknowledge that the write this reservation was for has ended without
  /// the caller binding it. The counter is already persisted on disk; the
  /// row becomes `burnPending` and the registered burn handler (if any)
  /// settles it — burning it only if its payload never landed. Idempotent.
  Future<void> release() async {
    if (_finalized) return;
    _finalized = true;
    await _service._release(_hostId, _counter, _payload);
  }
}

/// The payload a vector-clock reservation is for: its id and the sequence-log
/// type it is recorded under. Naming it lets the originator later prove
/// whether the reserved counter's write landed, from the payload's own clock.
typedef VcPayloadRef = ({String id, SyncSequencePayloadType type});

typedef _OwnCounter = ({String hostId, int counter});

/// A reservation recorded in the settings database because the sequence-log
/// insert failed.
typedef _UnrecordedReservation = ({
  String hostId,
  int counter,
  VcPayloadRef? payload,
});

extension _UnrecordedReservationJson on _UnrecordedReservation {
  static _UnrecordedReservation fromJson(Map<String, dynamic> json) {
    final id = json['payloadId'] as String?;
    final type = json['payloadType'] as String?;
    return (
      hostId: json['hostId'] as String,
      counter: json['counter'] as int,
      payload: id == null || type == null
          ? null
          : (id: id, type: SyncSequencePayloadType.values.byName(type)),
    );
  }

  Map<String, dynamic> toJson() => {
    'hostId': hostId,
    'counter': counter,
    if (payload != null) 'payloadId': payload!.id,
    if (payload != null) 'payloadType': payload!.type.name,
  };
}

class _VcScope {
  final List<VcReservation> reservations = [];
}

/// Async handler invoked when a reserved counter is released without the
/// caller binding it. By then the row is `burnPending` and records the
/// reservation's payload, if named. The implementation settles the counter:
/// it binds and resends a counter whose payload landed anyway, and otherwise
/// enqueues a proactive `SyncBackfillResponse(unresolvable=true)` so peers
/// close the gap without waiting for the reactive backfill-request path.
///
/// [hostId] is the host captured at reservation time, NOT the service's
/// current host at broadcast time. These can differ if
/// [VectorClockService.setNewHost] runs between reservation and release —
/// the broadcast must attribute the burnt counter to the host that actually
/// reserved it.
///
/// The handler is awaited so durable outbox persistence can complete before
/// [VcReservation.release] returns. Handler errors are caught and logged by
/// [VectorClockService] — the VC counter is already persisted and cannot be
/// rewound, so a handler exception must not escape the finalizer.
typedef VcBurnHandler = Future<void> Function(String hostId, int counter);

/// The first counter a host hands out (ADR 0080).
///
/// Counter 0 is never issued: in the sequence log a watermark of 0 means
/// "nothing seen yet", and gap detection and the contiguous-prefix watermark
/// count from 1. A build that reads an absent host as counter 0 in
/// [VectorClock.compare] also sees a new host's first write, `host: 1`,
/// dominate the version it extends. Hosts that older builds created started
/// at 0 and simply continue from where they are.
const int firstVectorClockCounter = 1;

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

  /// Reservations this process has neither bound nor released, with the
  /// payload each is for. Process-local on purpose: only a live process can
  /// still land one of these counters, so a crash must forget them.
  final Map<_OwnCounter, VcPayloadRef?> _pending = {};

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
    final stored = storedCounter == null ? null : int.parse(storedCounter);
    if (stored != null && stored >= firstVectorClockCounter) {
      _persistedCounter = stored;
    } else {
      // Nothing was handed out yet (the watermark is persisted before a
      // counter is returned), so skipping counter 0 leaves no hole.
      _persistedCounter = firstVectorClockCounter;
      await _persistCounter(firstVectorClockCounter);
    }
    _nextAvailableCounter = _persistedCounter;
  }

  /// Gives this device a new host id, whose first counter is
  /// [firstVectorClockCounter].
  Future<String> setNewHost() async {
    final host = uuid.v4();

    await getIt<SettingsDb>().saveSettingsItem(hostKey, host);
    _host = host;
    _persistedCounter = firstVectorClockCounter;
    _nextAvailableCounter = firstVectorClockCounter;
    await _persistCounter(firstVectorClockCounter);
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
  ///
  /// Pass [payload] whenever the caller knows which payload the counter is
  /// for. It is recorded on the reserved row, which is what lets a later
  /// process settle the counter if this one dies before the outbox binds it.
  Future<VcReservation> reserveNextVectorClock({
    VectorClock? previous,
    VcPayloadRef? payload,
  }) async {
    await _initialized;

    // Serialize so concurrent reservers never observe the same
    // _nextAvailableCounter between the in-memory bump and the [_persistCounter]
    // flush. Dart's single-threaded execution guards synchronous code, but
    // [_persistCounter] awaits a Drift write, and without this lock another
    // reserver could overtake us between the await points.
    return _underReserveLock(() async {
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
        _host,
        payload,
        this,
      );
      final key = (hostId: _host, counter: effectiveCounter);
      _pending[key] = payload;
      try {
        await _recordReservedCounter(_host, effectiveCounter, payload);
      } catch (_) {
        // Neither store took the reservation, so no write may use the
        // counter: it stays persisted with no row, which truthfully says no
        // payload carries it.
        _pending.remove(key);
        rethrow;
      }

      final scope = Zone.current[_zoneKey] as _VcScope?;
      if (scope != null) {
        scope.reservations.add(reservation);
      }

      return reservation;
    });
  }

  /// Runs [action] holding the reservation lock.
  Future<T> _underReserveLock<T>(Future<T> Function() action) async {
    while (_reserveLock != null) {
      await _reserveLock;
    }
    final completer = Completer<void>();
    _reserveLock = completer.future;
    try {
      return await action();
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
  ///
  /// Pass [payload] whenever the caller knows it; see
  /// [reserveNextVectorClock].
  Future<VectorClock> getNextVectorClock({
    VectorClock? previous,
    VcPayloadRef? payload,
  }) async {
    final reservation = await reserveNextVectorClock(
      previous: previous,
      payload: payload,
    );
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

    final scope = _VcScope();
    try {
      final result = await runZoned(action, zoneValues: {_zoneKey: scope});
      final shouldCommit = commitWhen?.call(result) ?? true;
      if (shouldCommit) {
        for (final reservation in scope.reservations) {
          await reservation.commit();
        }
      } else {
        for (final reservation in scope.reservations.reversed) {
          await reservation.release();
        }
      }
      return result;
    } catch (_) {
      for (final reservation in scope.reservations.reversed) {
        await reservation.release();
      }
      rethrow;
    }
  }

  /// Whether this process reserved `(hostId, counter)` and has neither bound
  /// nor released it — the only counters whose write may still land.
  bool isPending({required String hostId, required int counter}) =>
      _pending.containsKey((hostId: hostId, counter: counter));

  /// The payload a pending reservation was made for, if the caller named it.
  VcPayloadRef? pendingPayload({
    required String hostId,
    required int counter,
  }) => _pending[(hostId: hostId, counter: counter)];

  /// Forget a pending reservation once its counter is bound to a payload.
  /// Called by the sequence log when it binds an own-host counter.
  void settle({required String hostId, required int counter}) {
    _pending.remove((hostId: hostId, counter: counter));
  }

  /// Ends a reservation whose write will not bind it. The row becomes
  /// `burnPending` and records [payload] *before* the reservation stops being
  /// pending, so that a backfill request answered in between still knows which
  /// payload to look for. The burn handler then settles the counter.
  Future<void> _release(
    String hostId,
    int counter,
    VcPayloadRef? payload,
  ) async {
    await _markBurnPending(hostId, counter, payload);
    settle(hostId: hostId, counter: counter);
    await _onRelease(hostId, counter);
  }

  /// Logs the release and invokes the registered burn handler (if any).
  /// Swallows handler exceptions — the counter is already on disk and the row
  /// is `burnPending`, which startup reconciliation retries.
  ///
  /// [hostId] is the host captured at reservation time; may differ from the
  /// service's current [_host] if [setNewHost] ran between reserve and
  /// release. The broadcast must attribute the burnt counter to the host
  /// that actually reserved it.
  Future<void> _onRelease(String hostId, int counter) async {
    // DomainLogger may not be registered in some test harnesses / bootstrap
    // paths; use the `isRegistered` guard so a release on a minimally-wired
    // service (e.g. unit test seeding the SettingsDb counter) does not crash.
    if (getIt.isRegistered<DomainLogger>()) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        'VC reservation released host=$hostId counter=$counter '
        '(counter already persisted; settling)',
        subDomain: 'vc.burn',
      );
    }
    final handler = _burnHandler;
    if (handler == null) return;
    try {
      await handler(hostId, counter);
    } catch (error, stackTrace) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.sync,
          error,
          message:
              'VC burn broadcast handler threw — counter $counter will fall back '
              'to reactive backfill resolution',
          stackTrace: stackTrace,
          subDomain: 'vc.burn.handler',
        );
      }
    }
  }

  /// Explicitly burns a vector clock that was reserved outside a
  /// [withVcScope] but whose write was later rejected as a no-op.
  ///
  /// This is the recovery path for deterministic-create flows: metadata is
  /// built before the DB insert can discover that the row already exists. The
  /// counter has already been persisted and cannot be reused, so the safest
  /// terminal state is the same `burnPending` -> proactive unresolvable flow
  /// used by scoped reservation releases.
  ///
  /// The host is taken from the [vectorClock] itself rather than the service's
  /// current `_host`. Otherwise a [setNewHost] call between reservation and
  /// the rejected write would leave the old counter stranded as plain
  /// `reserved`, outside the startup recovery path.
  Future<void> burnUnboundVectorClock(
    VectorClock? vectorClock, {
    required String reason,
  }) async {
    await _initialized;
    if (vectorClock == null) return;
    if (vectorClock.vclock.isEmpty) return;
    // [reserveNextVectorClock] builds clocks as `{...previous, localHost: c}`,
    // so the reservation host is always the last inserted entry. Picking
    // [entries.first] would burn a peer's counter when the incoming clock
    // carries spread-previous entries.
    final entry = vectorClock.vclock.entries.last;
    final hostId = entry.key;
    final counter = entry.value;

    if (getIt.isRegistered<DomainLogger>()) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        'VC counter burnt host=$hostId counter=$counter '
        '(unbound vector clock; $reason)',
        subDomain: 'vc.burn.unbound',
      );
    }
    await _release(
      hostId,
      counter,
      pendingPayload(hostId: hostId, counter: counter),
    );
  }

  /// Records the reservation durably before its counter is handed out: in
  /// the sequence log, or — when that write fails — in [SettingsDb], the
  /// store that already holds the watermark. Without either record a crash
  /// before the outbox binds the counter would leave nothing naming its
  /// payload, and a later backfill request would be answered as a burn even
  /// if the write landed. Throws only when both stores refuse the write; the
  /// watermark write has then usually failed as well.
  Future<void> _recordReservedCounter(
    String hostId,
    int counter,
    VcPayloadRef? payload,
  ) async {
    if (!getIt.isRegistered<SyncDatabase>()) return;

    try {
      await getIt<SyncDatabase>().recordReservedSequenceCounter(
        hostId: hostId,
        counter: counter,
        entryId: payload?.id,
        payloadType: payload?.type,
      );
    } catch (error, stackTrace) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.sync,
          error,
          message:
              'VC reservation ledger write failed host=$hostId counter=$counter; '
              'recording it in the settings database until startup migrates it',
          stackTrace: stackTrace,
          subDomain: 'vc.reserve.ledger',
        );
      }
      final records = await _unrecordedReservations();
      await _saveUnrecordedReservations([
        ...records.where(
          (record) => record.hostId != hostId || record.counter != counter,
        ),
        (hostId: hostId, counter: counter, payload: payload),
      ]);
    }
  }

  /// The reservation of `(hostId, counter)` that could only be recorded in
  /// the settings database, if any. Its payload is null for a reservation
  /// that did not name one.
  Future<({VcPayloadRef? payload})?> unrecordedReservation({
    required String hostId,
    required int counter,
  }) async {
    for (final record in await _unrecordedReservations()) {
      if (record.hostId == hostId && record.counter == counter) {
        return (payload: record.payload);
      }
    }
    return null;
  }

  /// Startup: move reservations that could only be recorded in the settings
  /// database into the sequence log, where settlement finds them. Records the
  /// sequence log still refuses are kept for the next attempt. Returns how
  /// many moved.
  Future<int> migrateUnrecordedReservations() async {
    await _initialized;
    if (!getIt.isRegistered<SyncDatabase>()) return 0;
    return _underReserveLock(() async {
      final records = await _unrecordedReservations();
      if (records.isEmpty) return 0;
      final kept = <_UnrecordedReservation>[];
      for (final record in records) {
        try {
          // INSERT OR IGNORE: a row written since — a binding, a release —
          // already knows more than the fallback record.
          await getIt<SyncDatabase>().recordReservedSequenceCounter(
            hostId: record.hostId,
            counter: record.counter,
            entryId: record.payload?.id,
            payloadType: record.payload?.type,
          );
        } catch (error, stackTrace) {
          kept.add(record);
          if (getIt.isRegistered<DomainLogger>()) {
            getIt<DomainLogger>().error(
              LogDomain.sync,
              error,
              message:
                  'VC reservation migration failed host=${record.hostId} '
                  'counter=${record.counter}; retried on the next startup',
              stackTrace: stackTrace,
              subDomain: 'vc.reserve.migrate',
            );
          }
        }
      }
      await _saveUnrecordedReservations(kept);
      return records.length - kept.length;
    });
  }

  Future<List<_UnrecordedReservation>> _unrecordedReservations() async {
    final raw = await getIt<SettingsDb>().itemByKey(
      unrecordedReservationsKey,
    );
    if (raw == null || raw.isEmpty) return const [];
    // One unreadable record — corrupt JSON, or a payload type from a newer
    // build after a downgrade — must not block every settlement and every
    // new fallback. It is skipped and logged; its counter then falls back to
    // being burned when a peer asks for it.
    final List<dynamic> items;
    try {
      items = jsonDecode(raw) as List<dynamic>;
    } catch (error, stackTrace) {
      _logUnreadableFallback(error, stackTrace);
      return const [];
    }
    final records = <_UnrecordedReservation>[];
    for (final item in items) {
      try {
        records.add(
          _UnrecordedReservationJson.fromJson(item as Map<String, dynamic>),
        );
      } catch (error, stackTrace) {
        _logUnreadableFallback(error, stackTrace);
      }
    }
    return records;
  }

  void _logUnreadableFallback(Object error, StackTrace stackTrace) {
    if (!getIt.isRegistered<DomainLogger>()) return;
    getIt<DomainLogger>().error(
      LogDomain.sync,
      error,
      message: 'unreadable unrecorded-reservation record skipped',
      stackTrace: stackTrace,
      subDomain: 'vc.reserve.fallback',
    );
  }

  Future<void> _saveUnrecordedReservations(
    List<_UnrecordedReservation> records,
  ) async {
    final settings = getIt<SettingsDb>();
    if (records.isEmpty) {
      await settings.removeSettingsItem(unrecordedReservationsKey);
      return;
    }
    await settings.saveSettingsItem(
      unrecordedReservationsKey,
      jsonEncode([for (final record in records) record.toJson()]),
    );
  }

  Future<void> _markBurnPending(
    String hostId,
    int counter,
    VcPayloadRef? payload,
  ) async {
    if (!getIt.isRegistered<SyncDatabase>()) return;

    try {
      await getIt<SyncDatabase>().markReservedSequenceCounterBurnPending(
        hostId: hostId,
        counter: counter,
        entryId: payload?.id,
        payloadType: payload?.type,
      );
    } catch (error, stackTrace) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.sync,
          error,
          message:
              'VC burn-pending ledger write failed host=$hostId counter=$counter; '
              'counter already persisted and will fall back to reactive backfill',
          stackTrace: stackTrace,
          subDomain: 'vc.burn.ledger',
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
  // Called by vector-clock tests outside DCM's `lib`-only usage graph.
  // ignore: unused-code
  Future<int> getNextAvailableCounter() async => _nextAvailableCounter;

  @visibleForTesting
  // Called by vector-clock tests outside DCM's `lib`-only usage graph.
  // ignore: unused-code
  Future<void> setNextAvailableCounter(int counter) async {
    _nextAvailableCounter = counter;
    _persistedCounter = counter;
    await _persistCounter(counter);
  }

  @visibleForTesting
  // Called by vector-clock tests outside DCM's `lib`-only usage graph.
  // ignore: unused-code
  Future<void> increment() async {
    final reservation = await reserveNextVectorClock();
    await reservation.commit();
  }
}
