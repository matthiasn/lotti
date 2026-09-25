part of 'inbound_event_queue_test.dart';

// Model conformance: the real queue, marker advancer and resume floor,
// driven through generated interleavings of the catch-up protocol that
// `specs/tla/InboundQueue.tla` model-checks. TLC proves the design; this
// trace checks the Dart primitives behave like the model's actions:
// `advanceIfNewer`'s clamp, the floor's revision compare-and-set on
// completion and checkpoint, and the claim one above the marker.
//
// The room timeline is events 1..5 with origin timestamps 1..5, so a
// timestamp is a position. Event 3 arrives encrypted until its key does.
// The live stream, the walks and the worker are driven here the way
// QueuePipelineCoordinator, BridgeCoordinator and InboundWorker drive the
// queue; a crash is a fresh InboundQueue over the same database, which
// loses the process-local floor revisions and retained floors.

const _conformanceRoom = '!conformance:example.org';
const _timelineLength = 5;
const _encryptedEvent = 3;

/// Each op does the next useful thing, so few generated steps are no-ops:
/// a delivery with nothing left to deliver first lets an event arrive,
/// and a walk step with no walk running starts one.
enum _QueueOp {
  arrive,
  liveDeliver,
  liveGap,
  keyArrives,
  walkStep,
  walkFail,
  workerCommit,
  workerRetry,
  retryDue,
  workerSkip,
  workerPeekThenCrash,
  crash,
}

/// How often each op is drawn. Walk steps and worker commits dominate,
/// since the interleavings that matter are a walk in flight while live
/// events apply past it.
const _opWeights = <_QueueOp, int>{
  _QueueOp.arrive: 1,
  _QueueOp.liveDeliver: 2,
  _QueueOp.liveGap: 2,
  _QueueOp.keyArrives: 1,
  _QueueOp.walkStep: 4,
  _QueueOp.walkFail: 1,
  _QueueOp.workerCommit: 3,
  _QueueOp.workerRetry: 1,
  _QueueOp.retryDue: 1,
  _QueueOp.workerSkip: 1,
  _QueueOp.workerPeekThenCrash: 1,
  _QueueOp.crash: 1,
};

final List<_QueueOp> _weightedOps = [
  for (final entry in _opWeights.entries)
    for (var i = 0; i < entry.value; i++) entry.key,
];

extension _AnyQueueTrace on glados.Any {
  /// Glados grows its integers with the run's size, so early runs draw
  /// small codes. Hashing each code with its position spreads the ops
  /// over [_weightedOps] from the first run on.
  glados.Generator<List<_QueueOp>> get queueTrace => glados.ListAnys(this)
      .listWithLengthInRange(4, 32, glados.IntAnys(this).intInRange(0, 1000))
      .map(
        (codes) => [
          for (var i = 0; i < codes.length; i++)
            _weightedOps[((codes[i] + 1) * 2654435761 + i * 40503) %
                _weightedOps.length],
        ],
      );
}

String _conformanceEventId(int index) => '\$e$index';

int? _conformanceIndex(String? eventId) =>
    eventId == null ? null : int.tryParse(eventId.substring(2));

/// One room's queue, and everything that feeds and drains it.
class _QueueBench {
  _QueueBench(this.db, this.logging) : queue = _open(db, logging);

  static InboundQueue _open(SyncDatabase db, DomainLogger logging) =>
      InboundQueue(db: db, logging: logging, leaseDuration: Duration.zero);

  final SyncDatabase db;
  final DomainLogger logging;
  InboundQueue queue;

  int tip = 1;
  int liveNext = 2;
  bool encrypted = true;
  bool bridgePending = true;
  final List<String> log = [];

  // The walk in flight.
  String walk = 'idle';
  int cursor = 0;
  int bound = 0;
  int revision = 0;
  int? unresolved;

  /// The clock the queue's retries and leases read.
  DateTime now = DateTime(2026, 9, 25, 12);

  // What the invariants compare against.
  int lastMarkerTs = 0;
  final Set<int> applied = {};

  Event event(int index) {
    final isCipher = index == _encryptedEvent && encrypted;
    return buildSyncEvent(
      eventId: _conformanceEventId(index),
      roomId: _conformanceRoom,
      originTsMs: index,
      type: isCipher ? EventTypes.Encrypted : EventTypes.Message,
    );
  }

  bool isCipher(int index) => index == _encryptedEvent && encrypted;

  Future<QueueMarkerItem?> durableMarker() => (db.select(
    db.queueMarkers,
  )..where((t) => t.roomId.equals(_conformanceRoom))).getSingleOrNull();

  /// The marker as the coordinator reads it: the floor goes through the
  /// accessor that first persists a retained value.
  Future<BridgeMarker> readMarker() async {
    final floor = await queue.resumeFloorTs(_conformanceRoom);
    final row = await durableMarker();
    return BridgeMarker(
      lastAppliedTs: row != null && row.lastAppliedTs > 0
          ? row.lastAppliedTs
          : null,
      lastAppliedEventId: row?.lastAppliedEventId,
      resumeFloorTs: floor ?? row?.resumeFloorTs,
    );
  }

  Future<void> claim({required bool walkLocal}) async {
    final marker = await readMarker();
    if (walkLocal) {
      await queue.lowerResumeFloorFromWalk(
        roomId: _conformanceRoom,
        originTs: marker.claimFloorTs,
      );
    } else {
      await queue.lowerResumeFloor(
        roomId: _conformanceRoom,
        originTs: marker.claimFloorTs,
      );
    }
  }

  Future<void> emit(int index) async {
    if (isCipher(index)) {
      await queue.lowerResumeFloorFromWalk(
        roomId: _conformanceRoom,
        originTs: index,
      );
      final oldest = unresolved;
      unresolved = oldest == null || index < oldest ? index : oldest;
      return;
    }
    await queue.appendBootstrapPage([event(index)]);
  }

  Future<void> restart() async {
    await queue.dispose();
    queue = _open(db, logging);
    walk = 'idle';
    // startImpl: claim, then the live stream (from the tip) and the
    // startup bridge.
    await claim(walkLocal: false);
    liveNext = tip + 1;
    bridgePending = true;
  }

  Future<void> startWalk() async {
    bridgePending = false;
    await claim(walkLocal: true);
    final marker = await readMarker();
    revision = queue.resumeFloorRevision(_conformanceRoom);
    unresolved = null;
    final anchor = _conformanceIndex(marker.lastAppliedEventId);
    if (anchor != null && marker.anchorIsSafe) {
      walk = 'fwd';
      cursor = anchor;
    } else {
      walk = 'bwd';
      cursor = tip + 1;
      bound = marker.backwardWalkBound ?? 0;
    }
  }

  Future<void> run(_QueueOp op) async {
    log.add(op.name);
    switch (op) {
      case _QueueOp.arrive:
        if (tip < _timelineLength) tip++;
      case _QueueOp.liveDeliver:
        if (liveNext > tip && tip < _timelineLength) tip++;
        if (liveNext > tip) return;
        final index = liveNext++;
        if (isCipher(index)) {
          await queue.lowerResumeFloor(
            roomId: _conformanceRoom,
            originTs: index,
          );
        } else {
          await queue.enqueueLive(event(index));
        }
      case _QueueOp.liveGap:
        // A limited sync drops the next event and delivers the one after.
        while (liveNext + 1 > tip && tip < _timelineLength) {
          tip++;
        }
        if (liveNext + 1 > tip) return;
        liveNext++;
        await claim(walkLocal: false);
        bridgePending = true;
        final index = liveNext++;
        if (isCipher(index)) {
          await queue.lowerResumeFloor(
            roomId: _conformanceRoom,
            originTs: index,
          );
        } else {
          await queue.enqueueLive(event(index));
        }
      case _QueueOp.keyArrives:
        encrypted = false;
        if (await queue.resumeFloorTs(_conformanceRoom) != null) {
          bridgePending = true;
        }
      case _QueueOp.walkStep:
        if (walk == 'idle') {
          // A pending pass, or "Catch up now".
          await startWalk();
        } else if (walk == 'fwd' && cursor < tip) {
          cursor++;
          await emit(cursor);
          await queue.checkpointResumeWalk(
            roomId: _conformanceRoom,
            coveredThroughTs: cursor,
            unresolvedFloorTs: unresolved,
          );
        } else if (walk == 'bwd' && cursor - 1 >= math.max(bound, 1)) {
          cursor--;
          await emit(cursor);
        } else {
          walk = 'idle';
          await queue.completeResumeWalk(
            roomId: _conformanceRoom,
            walkStartedAtFloorRevision: revision,
            unresolvedFloorTs: unresolved,
          );
        }
      case _QueueOp.walkFail:
        if (walk == 'idle') return;
        walk = 'idle';
        bridgePending = true;
      case _QueueOp.workerCommit:
        final batch = await queue.peekBatchReady(maxBatch: 1);
        if (batch.isEmpty) return;
        await queue.commitApplied(batch.single);
        applied.add(_conformanceIndex(batch.single.eventId)!);
      case _QueueOp.workerRetry:
        // missingBase, pendingAttachment and the like: the row stays
        // active but is not ready, so newer rows apply around it.
        final batch = await queue.peekBatchReady(maxBatch: 1);
        if (batch.isEmpty) return;
        await queue.scheduleRetry(
          batch.single,
          const Duration(hours: 1),
          reason: RetryReason.missingBase,
        );
      case _QueueOp.retryDue:
        now = now.add(const Duration(hours: 2));
      case _QueueOp.workerSkip:
        final batch = await queue.peekBatchReady(maxBatch: 1);
        if (batch.isEmpty) return;
        await queue.markSkipped(batch.single, reason: 'permanentSkip');
      case _QueueOp.workerPeekThenCrash:
        await queue.peekBatchReady(maxBatch: 1);
        await restart();
      case _QueueOp.crash:
        await restart();
    }
  }

  /// `NoSilentLoss`, `MarkerMonotone` and `AppliedIsFinal`.
  Future<void> check() async {
    final rows = await db.select(db.inboundEventQueue).get();
    final captured = {
      for (final row in rows) _conformanceIndex(row.eventId)!: row.status,
    };
    final row = await durableMarker();
    final marker = BridgeMarker(
      lastAppliedTs: row != null && row.lastAppliedTs > 0
          ? row.lastAppliedTs
          : null,
      lastAppliedEventId: row?.lastAppliedEventId,
      resumeFloorTs: row?.resumeFloorTs,
    );
    final anchor = _conformanceIndex(marker.lastAppliedEventId);
    final forward = anchor != null && marker.anchorIsSafe;
    final bound = marker.backwardWalkBound ?? 0;
    for (var index = 1; index <= tip; index++) {
      final recoverable = forward ? index > anchor : index >= bound;
      expect(
        captured.containsKey(index) || recoverable,
        isTrue,
        reason:
            'NoSilentLoss: event $index is neither queued nor fetched by '
            'the next catch-up (marker ts=${marker.lastAppliedTs} '
            'anchor=${marker.lastAppliedEventId} '
            'floor=${marker.resumeFloorTs}) after $log',
      );
    }
    final markerTs = row?.lastAppliedTs ?? 0;
    expect(
      markerTs,
      greaterThanOrEqualTo(lastMarkerTs),
      reason: 'MarkerMonotone after $log',
    );
    lastMarkerTs = markerTs;
    for (final index in applied) {
      expect(
        captured[index],
        InboundQueueStatuses.applied,
        reason: 'AppliedIsFinal: event $index after $log',
      );
    }
  }
}

void _registerModelConformance() {
  glados.Glados(
    glados.any.queueTrace,
    glados.ExploreConfig(numRuns: 1000),
  ).test(
    'generated live, gap, walk, worker and crash interleavings keep '
    'NoSilentLoss, MarkerMonotone and AppliedIsFinal on the real queue',
    (trace) async {
      final db = SyncDatabase(inMemoryDatabase: true);
      final bench = _QueueBench(db, MockDomainLogger());
      try {
        await withClock(Clock(() => bench.now), () async {
          // The first start: event 1 is already on the homeserver.
          await bench.claim(walkLocal: false);
          await bench.check();
          for (final op in trace) {
            await bench.run(op);
            await bench.check();
          }
        });
      } finally {
        await bench.queue.dispose();
        await db.close();
      }
    },
    tags: 'glados',
  );
}
