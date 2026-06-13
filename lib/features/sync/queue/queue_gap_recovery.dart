part of 'queue_pipeline_coordinator.dart';

/// Bootstrap and gap-recovery routing of [QueuePipelineCoordinator]:
/// history collection, forward/backward bootstrap, barren-bridge flag
/// upkeep, and the gap-recovery trigger. The class keeps thin delegators
/// for the public methods so mocks keep intercepting them.
extension QueueGapRecovery on QueuePipelineCoordinator {
  /// Walks the current room's entire visible history into the queue
  /// through a [QueueBootstrapSink], awaiting drain back-pressure
  /// between pages. Invoked by the "Fetch all history" action in the
  /// Sync Settings page. The caller receives a
  /// [BootstrapPageInfo] via [onProgress] after every page and can
  /// pre-empt pagination by completing [cancelSignal].
  ///
  /// Throws [StateError] if no sync room is currently joined.
  Future<BootstrapResult> collectHistoryImpl({
    void Function(BootstrapPageInfo info)? onProgress,
    Future<void>? cancelSignal,
    Duration? overallTimeout,
  }) async {
    final room = await _resolveRoom();
    if (room == null) {
      throw StateError('collectHistory: no current room');
    }
    final sink = ProgressForwardingSink(
      inner: QueueBootstrapSink(
        queue: _queue,
        logging: _logging,
        cancelSignal: cancelSignal,
      ),
      onProgress: onProgress,
    );
    return CatchUpStrategy.collectHistoryForBootstrap(
      room: room,
      sink: sink,
      logging: _logging,
      overallTimeout: overallTimeout,
    );
  }

  /// Streams the room's catch-up events through [QueueBootstrapSink]
  /// (page-by-page with back-pressure) into the queue. Invoked by
  /// [BridgeCoordinator] for every catch-up; dispatches by [marker]:
  ///
  /// - `marker.lastAppliedEventId != null`: reconnect — forward-walks
  ///   from the anchor event via `collectForwardForBootstrap`. This
  ///   hits `/rooms/{roomId}/context/{eventId}` then
  ///   `/messages?dir=f`, so the walk sees server state rather than
  ///   whatever the SDK cached from prior sessions — the only way to
  ///   close a gap in the `[lastAppliedTs, now]` window when the
  ///   cached timeline's oldest event predates the gap.
  /// - Fallbacks:
  ///   - Anchor walk returns `error` (server compacted the anchor,
  ///     context fetch threw) → fall through to the backward walk so
  ///     something still runs.
  ///   - `marker.lastAppliedEventId == null`: fresh client or
  ///     anchor-unavailable — walk backward from the room tip via
  ///     `collectHistoryForBootstrap`. Stops when the server
  ///     exhausts history.
  ///
  /// Returns `true` when the walk completed (server exhausted OR
  /// boundary reached) and `false` on sink cancellation / pagination
  /// error so the bridge can schedule a bounded retry.
  Future<bool> _runBootstrap({
    required Room room,
    required BridgeMarker marker,
  }) async {
    if (marker.lastAppliedEventId != null) {
      final forward = await _runForwardBootstrap(
        room: room,
        anchorEventId: marker.lastAppliedEventId!,
      );
      // Anchor-based forward walk is the preferred path. On a hard
      // error (context fetch failed, anchor no longer resolvable) we
      // fall back to the backward walk so reconnect always tries
      // *something* — the backward walk is still useful for the
      // case where the gap happens to live at the cache's oldest
      // end (small, contiguous reconnect windows).
      if (forward != BootstrapOutcome.errorNoProgress) {
        _updateBarrenBridgeFlagForward(forward);
        return forward == BootstrapOutcome.completed;
      }
      _logging.log(
        LogDomain.sync,
        'queue.bootstrap.forward.fallbackToBackward '
        'reason=anchorUnavailable anchor=${marker.lastAppliedEventId}',
        subDomain: '$_logSub.forward',
      );
    }

    return _runBackwardBootstrap(
      room: room,
      untilTimestamp: marker.lastAppliedTs,
    );
  }

  Future<BootstrapOutcome> _runForwardBootstrap({
    required Room room,
    required String anchorEventId,
  }) async {
    final innerSink = _attachmentIngestor == null
        ? QueueBootstrapSink(queue: _queue, logging: _logging)
        : AttachmentAwareBootstrapSink(
                inner: QueueBootstrapSink(queue: _queue, logging: _logging),
                processAttachment: _processAttachment,
              )
              as BootstrapSink;
    final countingSink = TotalAcceptedCountingSink(innerSink);
    final result = await CatchUpStrategy.collectForwardForBootstrap(
      room: room,
      sink: countingSink,
      logging: _logging,
      anchorEventId: anchorEventId,
    );
    _logging.log(
      LogDomain.sync,
      'queue.bootstrap.forward.done '
      'anchor=$anchorEventId pages=${result.totalPages} '
      'events=${result.totalEvents} accepted=${countingSink.totalAccepted} '
      'stopReason=${result.stopReason.name}',
      subDomain: '$_logSub.forward',
    );
    return switch (result.stopReason) {
      BootstrapStopReason.serverExhausted ||
      BootstrapStopReason.boundaryReached => BootstrapOutcome.completed,
      BootstrapStopReason.sinkCancelled => BootstrapOutcome.incomplete,
      // No pages + error means "anchor unresolvable": the context
      // fetch returned an empty chunk or threw. Signal the caller so
      // it can fall back to the backward walk.
      BootstrapStopReason.error when result.totalPages == 0 =>
        BootstrapOutcome.errorNoProgress,
      BootstrapStopReason.error => BootstrapOutcome.incomplete,
    };
  }

  Future<bool> _runBackwardBootstrap({
    required Room room,
    required int? untilTimestamp,
  }) async {
    // Wrap the queue sink so attachment descriptor events in each
    // paginated page get fed to `AttachmentIngestor.process()` before
    // the queue's own enqueue drops them as non-payload. Without
    // this, catch-up on a room with historical attachments would
    // enqueue the sync-payload events while their descriptor
    // JSONs never land on disk, producing the pendingAttachment
    // skip cascade we just fixed.
    final innerSink = _attachmentIngestor == null
        ? QueueBootstrapSink(queue: _queue, logging: _logging)
        : AttachmentAwareBootstrapSink(
                inner: QueueBootstrapSink(queue: _queue, logging: _logging),
                processAttachment: _processAttachment,
              )
              as BootstrapSink;
    // Count accepted events across every page so we can detect the
    // "boundaryReached with totalAccepted==0" case that marks the
    // bridge barren — the gap-recovery trigger reads this flag.
    final countingSink = TotalAcceptedCountingSink(innerSink);
    final result = await CatchUpStrategy.collectHistoryForBootstrap(
      room: room,
      sink: countingSink,
      logging: _logging,
      untilTimestamp: untilTimestamp,
    );
    _updateBarrenBridgeFlag(
      untilTimestamp: untilTimestamp,
      result: result,
      totalAccepted: countingSink.totalAccepted,
    );
    return switch (result.stopReason) {
      BootstrapStopReason.serverExhausted ||
      BootstrapStopReason.boundaryReached => true,
      BootstrapStopReason.sinkCancelled || BootstrapStopReason.error => false,
    };
  }

  void _updateBarrenBridgeFlag({
    required num? untilTimestamp,
    required BootstrapResult result,
    required int totalAccepted,
  }) {
    // Only reconnect-mode walks (bounded by `untilTimestamp`) can be
    // barren. A fresh-client walk (`untilTimestamp == null`) that
    // accepts nothing just means the server has nothing for us — a
    // later gap cannot be recovered by re-running the same walk.
    if (untilTimestamp == null) {
      _lastBarrenBridgeAt = null;
      return;
    }
    final isBarren =
        result.stopReason == BootstrapStopReason.boundaryReached &&
        totalAccepted == 0;
    if (isBarren) {
      _lastBarrenBridgeAt = clock.now();
      _logging.log(
        LogDomain.sync,
        'queue.coordinator.bridgeBarren '
        'untilTimestamp=$untilTimestamp totalPages=${result.totalPages} '
        'totalEvents=${result.totalEvents}',
        subDomain: _logSub,
      );
    } else {
      // Any productive bridge clears the flag so a later gap is not
      // attributed to a long-since-healed cache wedge.
      _lastBarrenBridgeAt = null;
    }
  }

  void _updateBarrenBridgeFlagForward(BootstrapOutcome outcome) {
    // Forward-walk semantics: anchor resolved and we walked to the
    // tip (or cap). Whether anything was accepted or not, the cache-
    // wedge scenario that drove the barren-bridge recovery does not
    // apply to this path — the forward walk fetches server state
    // directly. Clearing the flag prevents a later gap-detected
    // signal from triggering a redundant unbounded backward walk.
    if (outcome == BootstrapOutcome.completed) {
      _lastBarrenBridgeAt = null;
    }
  }

  /// Triggered from the sequence-log gap-detected callback. When the
  /// most recent bridge finished barren (boundary reached, zero
  /// accepted) and a live event's vector clock now reveals a missing
  /// counter, close the hole aggressively by running an unbounded
  /// history walk instead of waiting for the normal backfill cadence.
  ///
  /// Fire-and-forget from the caller's perspective — the sequence
  /// log's `onMissingEntriesDetected` is `void`. A concurrent trigger
  /// coalesces onto the in-flight recovery so a burst of gap signals
  /// does not spawn parallel /messages walks.
  void maybeStartGapRecoveryImpl() {
    if (!_started) return;
    if (_gapRecoveryInFlight != null) return;
    final at = _lastBarrenBridgeAt;
    if (at == null) return;
    if (clock.now().difference(at) > QueuePipelineCoordinator.barrenBridgeTtl) {
      _lastBarrenBridgeAt = null;
      return;
    }
    // Consume the signal up-front. If the recovery walk itself finds
    // nothing and leaves the cache still wedged, the next live event
    // will not re-trigger until a new barren bridge arrives — which
    // is the right behaviour: we already tried the unbounded walk
    // once and burning a second one immediately wastes the peer's
    // /messages quota without new information.
    _lastBarrenBridgeAt = null;
    final completer = Completer<void>();
    _gapRecoveryInFlight = completer.future;
    unawaited(
      _runGapRecovery().whenComplete(() {
        _gapRecoveryInFlight = null;
        completer.complete();
      }),
    );
  }

  Future<void> _runGapRecovery() async {
    try {
      final room = await _resolveRoom();
      if (room == null) {
        _logging.log(
          LogDomain.sync,
          'queue.coordinator.gapRecovery.skip reason=noRoom',
          subDomain: _logSub,
        );
        return;
      }
      _logging.log(
        LogDomain.sync,
        'queue.coordinator.gapRecovery.start',
        subDomain: _logSub,
      );
      // Gap-recovery is specifically the "cache-wedged backward walk
      // couldn't surface what we need" fallback. It runs an
      // unbounded backward walk (no anchor, no untilTimestamp), so
      // we call the backward primitive directly rather than going
      // through `_runBootstrap` — we do NOT want it to forward-walk
      // here because the forward walk already ran as the main
      // bridge pass.
      final completed = await _runBackwardBootstrap(
        room: room,
        untilTimestamp: null,
      );
      _logging.log(
        LogDomain.sync,
        'queue.coordinator.gapRecovery.done completed=$completed',
        subDomain: _logSub,
      );
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.gapRecovery',
      );
    }
  }

  @visibleForTesting
  bool get hasBarrenBridgeSignal => _lastBarrenBridgeAt != null;

  @visibleForTesting
  bool get gapRecoveryInFlight => _gapRecoveryInFlight != null;

  @visibleForTesting
  Future<void>? get gapRecoveryFuture => _gapRecoveryInFlight;

  /// Test-only entry point for `_runBootstrap`. Lets tests exercise
  /// the barren-tracking + gap-recovery + forward-walk dispatch
  /// without wiring a real [BridgeCoordinator] — the `triggerBridge`
  /// path funnels through the live `onSync` listener and computes
  /// the marker itself, which makes it awkward to pin down a test
  /// scenario.
  @visibleForTesting
  Future<bool> runBootstrapForTest({
    required Room room,
    int? untilTimestamp,
    String? anchorEventId,
  }) => _runBootstrap(
    room: room,
    marker: BridgeMarker(
      lastAppliedTs: untilTimestamp,
      lastAppliedEventId: anchorEventId,
    ),
  );

  Future<BridgeMarker> _readMarker() async {
    final roomId = _roomManager.currentRoomId;
    if (roomId == null) {
      return const BridgeMarker(
        lastAppliedTs: null,
        lastAppliedEventId: null,
      );
    }
    final marker = await (_syncDb.select(
      _syncDb.queueMarkers,
    )..where((t) => t.roomId.equals(roomId))).getSingleOrNull();
    if (marker == null) {
      final legacy = await getLastReadMatrixEventTs(_settingsDb);
      return BridgeMarker(
        lastAppliedTs: legacy,
        lastAppliedEventId: null,
      );
    }
    final ts = marker.lastAppliedTs > 0
        ? marker.lastAppliedTs
        : await getLastReadMatrixEventTs(_settingsDb);
    return BridgeMarker(
      lastAppliedTs: ts,
      // Only use the event id when it's a server-assigned `$`-
      // prefixed id — placeholder ids that the outbox minted before
      // the server echoed back would make `getEventContext` fail.
      lastAppliedEventId:
          marker.lastAppliedEventId != null &&
              marker.lastAppliedEventId!.startsWith(r'$')
          ? marker.lastAppliedEventId
          : null,
    );
  }
}
