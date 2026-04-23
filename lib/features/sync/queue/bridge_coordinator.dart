import 'dart:async';

import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Snapshot of the per-room queue marker the bridge reads at the
/// start of each pass. Bundles both fields together so future
/// additions (e.g. a persisted `prev_batch` token) need one new
/// field here, not a second getter on the coordinator.
class BridgeMarker {
  const BridgeMarker({
    required this.lastAppliedTs,
    required this.lastAppliedEventId,
  });

  /// Highest `originServerTs` the worker has applied. Null on a
  /// fresh client. When non-null, receivers that don't have an
  /// anchor event id can still use this as a timestamp floor.
  final int? lastAppliedTs;

  /// Matrix event id (`$...`) of the last applied event. Null on a
  /// fresh client or when the last applied event was a placeholder
  /// id that never reached the server (defensive; should not
  /// happen in practice). When present, the bootstrap runner uses
  /// it to anchor a forward-walk via
  /// `CatchUpStrategy.collectForwardForBootstrap` — the
  /// Matrix-canonical way to close a post-offline gap that doesn't
  /// depend on whether the SDK's cached backward timeline happens
  /// to span the gap window.
  final String? lastAppliedEventId;
}

/// Callback owned by `QueuePipelineCoordinator` that streams the room's
/// catch-up events through a `BootstrapSink` with back-pressure.
///
/// The bridge calls this for every catch-up trigger. The coordinator
/// decides, based on [marker], whether to run a backward walk from
/// the room tip (fresh client: no anchor) or a forward walk anchored
/// at `marker.lastAppliedEventId` (reconnect: anchor known).
///
/// Returns `true` when the walk completed (server exhausted OR
/// boundary reached). Returns `false` when it stopped early (error,
/// back-pressure timeout, user cancelled) — the bridge treats that
/// as incomplete and schedules a bounded retry.
typedef BootstrapRunner =
    Future<bool> Function({
      required Room room,
      required BridgeMarker marker,
    });

const _logDomain = 'sync';
const _logSub = 'queue.bridge';

/// Owns the "limited=true" bridge call for the queue-based pipeline.
/// Subscribes to [Client.onSync], filters to the current room, and
/// (when the sync response arrives with `timeline.limited == true`)
/// invokes the [BootstrapRunner] to stream catch-up events into the
/// queue via a page-by-page bootstrap sink.
///
/// Single-flight: a second limited-sync that fires while a bridge
/// call is still in-flight is coalesced. The coordinator remembers
/// that another trigger arrived and, once the current bridge
/// completes, re-runs exactly once. This mirrors the legacy
/// pipeline's `_catchUpInFlight` semantics without using a mutable
/// flag stored across three collaborators.
class BridgeCoordinator {
  BridgeCoordinator({
    required Client client,
    required String? Function() currentRoomId,
    required Future<Room?> Function() resolveRoom,
    required Future<BridgeMarker> Function() readMarker,
    required BootstrapRunner bootstrapRunner,
    required LoggingService logging,
    Duration incompleteRetryDelay = const Duration(seconds: 10),
    int maxIncompleteRetries = 3,
  }) : _client = client,
       _currentRoomId = currentRoomId,
       _resolveRoom = resolveRoom,
       _readMarker = readMarker,
       _bootstrapRunner = bootstrapRunner,
       _logging = logging,
       _incompleteRetryDelay = incompleteRetryDelay,
       _maxIncompleteRetries = maxIncompleteRetries;

  final Client _client;
  final String? Function() _currentRoomId;
  final Future<Room?> Function() _resolveRoom;
  final Future<BridgeMarker> Function() _readMarker;
  final BootstrapRunner _bootstrapRunner;
  final LoggingService _logging;
  final Duration _incompleteRetryDelay;
  final int _maxIncompleteRetries;

  StreamSubscription<SyncUpdate>? _sub;
  Future<void>? _inFlightBridge;
  bool _pendingRerun = false;
  String? _pendingRerunRoomId;
  bool _stopped = false;
  int _consecutiveIncomplete = 0;
  Timer? _incompleteRetryTimer;

  bool get isRunning => _sub != null;

  void start() {
    _stopped = false;
    _sub ??= _client.onSync.stream.listen(
      _handle,
      onError: (Object error, StackTrace stackTrace) {
        _logging.captureException(
          error,
          domain: _logDomain,
          subDomain: '$_logSub.subscription',
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<void> stop() async {
    _stopped = true;
    _pendingRerun = false;
    _incompleteRetryTimer?.cancel();
    _incompleteRetryTimer = null;
    _consecutiveIncomplete = 0;
    await _sub?.cancel();
    _sub = null;
    // Await the in-flight bridge so enqueue/capture calls cannot land
    // on a disposed queue after the owner considers shutdown complete.
    final current = _inFlightBridge;
    if (current != null) {
      try {
        await current;
      } catch (_) {
        // Already logged inside `_bridge()`.
      }
    }
  }

  /// Runs a bridge pass explicitly, bypassing the onSync listener.
  /// Used by `MatrixService.forceRescan(includeCatchUp: true)` and by
  /// tests.
  Future<void> bridgeNow() => _bridge(_currentRoomId());

  void _handle(SyncUpdate sync) {
    if (_stopped) return;
    final roomId = _currentRoomId();
    if (roomId == null) return;
    final joined = sync.rooms?.join?[roomId];
    if (joined?.timeline?.limited != true) return;
    // Carry the room id that triggered this limited-sync through the
    // async bridge pass: if the user switches sync rooms (or a
    // settings flip changes `_currentRoomId`) between the trigger and
    // `_runBridgeOnce` resolving a Room, we must not end up running a
    // catch-up against the wrong room.
    unawaited(_bridge(roomId));
  }

  Future<void> _bridge(String? expectedRoomId) async {
    if (_stopped) return;
    if (_inFlightBridge != null) {
      _pendingRerun = true;
      // Remember the room id of the most recent trigger so the rerun
      // after the in-flight pass completes targets the latest room,
      // not a stale one captured on an earlier iteration.
      _pendingRerunRoomId = expectedRoomId;
      return;
    }
    final completer = Completer<void>();
    _inFlightBridge = completer.future;
    try {
      await _runBridgeOnce(expectedRoomId);
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.run',
        stackTrace: stackTrace,
      );
    } finally {
      _inFlightBridge = null;
      completer.complete();
      if (_pendingRerun && !_stopped) {
        _pendingRerun = false;
        final rerunRoomId = _pendingRerunRoomId;
        _pendingRerunRoomId = null;
        unawaited(_bridge(rerunRoomId));
      } else {
        _pendingRerun = false;
        _pendingRerunRoomId = null;
      }
    }
  }

  Future<void> _runBridgeOnce(String? expectedRoomId) async {
    final room = await _resolveRoom();
    if (room == null) {
      _logging.captureEvent(
        'queue.bridge.skip reason=noRoom',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return;
    }
    if (expectedRoomId != null && room.id != expectedRoomId) {
      // The selected sync room changed between the trigger and now;
      // abandon this pass rather than running catch-up against a
      // different room than the one whose `limited=true` sync
      // scheduled the work.
      _logging.captureEvent(
        'queue.bridge.skip reason=roomChanged '
        'expectedRoomId=$expectedRoomId actualRoomId=${room.id}',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return;
    }
    final marker = await _readMarker();
    // Reconnect catch-up anchors a forward-walk on the last-applied
    // event id whenever one is known; the coordinator falls back to
    // a timestamp-bounded backward walk only for fresh clients (no
    // anchor). See `BridgeMarker` and
    // `CatchUpStrategy.collectForwardForBootstrap` for the
    // rationale — a backward walk against the SDK's cached timeline
    // cannot close gaps in the recent `[lastAppliedTs, now]` window
    // once the cache's oldest event predates the window.
    final mode = marker.lastAppliedEventId != null
        ? 'reconnect.forward'
        : marker.lastAppliedTs != null
        ? 'reconnect.backward'
        : 'fresh';

    _logging.captureEvent(
      'queue.bridge.start '
      'mode=$mode '
      'lastAppliedTs=${marker.lastAppliedTs} '
      'lastAppliedEventId=${marker.lastAppliedEventId}',
      domain: _logDomain,
      subDomain: _logSub,
    );

    bool completed;
    try {
      completed = await _bootstrapRunner(
        room: room,
        marker: marker,
      );
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.bootstrap',
        stackTrace: stackTrace,
      );
      completed = false;
    }

    _logging.captureEvent(
      'queue.bridge.done completed=$completed',
      domain: _logDomain,
      subDomain: _logSub,
    );

    _handleIncompleteFollowUp(
      incomplete: !completed,
      expectedRoomId: expectedRoomId,
    );
  }

  /// Schedules a bounded retry when the bootstrap runner reports an
  /// incomplete walk (error, timeout, back-pressure cancellation).
  /// Without this, recovery would depend on another limited-sync
  /// happening to arrive, which can leave gaps indefinitely on a
  /// quiet room.
  ///
  /// The retry targets the room that triggered the original bridge so
  /// a sync-room change during the retry delay cannot redirect the
  /// catch-up to a different room.
  void _handleIncompleteFollowUp({
    required bool incomplete,
    required String? expectedRoomId,
  }) {
    if (_stopped) return;
    if (!incomplete) {
      _consecutiveIncomplete = 0;
      _incompleteRetryTimer?.cancel();
      _incompleteRetryTimer = null;
      return;
    }
    _consecutiveIncomplete++;
    if (_consecutiveIncomplete > _maxIncompleteRetries) {
      _logging.captureEvent(
        'queue.bridge.incomplete.giveUp '
        'retries=$_consecutiveIncomplete',
        domain: _logDomain,
        subDomain: _logSub,
      );
      _consecutiveIncomplete = 0;
      return;
    }
    _incompleteRetryTimer?.cancel();
    _incompleteRetryTimer = Timer(_incompleteRetryDelay, () {
      _incompleteRetryTimer = null;
      if (_stopped) return;
      _logging.captureEvent(
        'queue.bridge.incomplete.retry '
        'attempt=$_consecutiveIncomplete',
        domain: _logDomain,
        subDomain: _logSub,
      );
      unawaited(_bridge(expectedRoomId));
    });
  }
}
