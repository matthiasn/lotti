part of 'outbox_enqueue_writer_test.dart';

// Model conformance: the real enqueue writer, SyncDatabase outbox,
// DatabaseOutboxRepository and OutboxProcessor, driven through generated
// traces, must keep the invariants `specs/tla/Outbox.tla` model-checks. TLC
// proves the design; these traces check that the Dart code behaves like it.
//
// One agent entity is written again and again. Its enqueues run
// concurrently with each other and with drains, a write can be enqueued
// late (after a newer one), a drain can fail or lose its marks (the rows it
// sent stay `sending`, as after a crash between the send and markSent), time
// can pass beyond the claim lease, and a crash is a fresh writer, repository
// and processor over the same database. A drain releases orphaned claims
// first, as `MatrixOutboxService.sendNext` does.

enum _OutboxOp {
  enqueueNext,
  holdBack,
  enqueueHeld,
  settle,
  drainOk,
  drainFail,
  drainMarksThrow,
  drainMarkSentThrows,
  tick,
  crash,
  prune,
}

class _OutboxStep {
  const _OutboxStep(this.op);

  factory _OutboxStep.decode(int code) =>
      _OutboxStep(_OutboxOp.values[code % _OutboxOp.values.length]);

  final _OutboxOp op;

  @override
  String toString() => op.name;
}

extension _AnyOutboxTrace on glados.Any {
  glados.Generator<List<_OutboxStep>> get outboxTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        16,
        glados.IntAnys(this).intInRange(0, _OutboxOp.values.length),
      )
      .map((codes) => [for (final code in codes) _OutboxStep.decode(code)]);
}

/// A payload as it left the device: the counter it announces and the
/// counters it covers.
typedef _Sent = ({int payload, Set<int> covered});

_Sent _sentOf(SyncMessage message) {
  final agent = message as SyncAgentEntity;
  return (
    payload: agent.agentEntity!.vectorClock!.vclock['host-A']!,
    covered: {
      for (final vc in agent.coveredVectorClocks ?? <VectorClock>[])
        vc.vclock['host-A']!,
    },
  );
}

/// A mark that failed, as a database write can.
class _MarkFailed implements Exception {
  const _MarkFailed();
}

/// Delegates to the real repository; its marks can be made to throw.
class _FaultyRepository implements OutboxRepository {
  _FaultyRepository(this._inner);

  final DatabaseOutboxRepository _inner;
  bool markSentThrows = false;
  bool markRetryThrows = false;

  @override
  Future<List<OutboxItem>> fetchPending({int limit = 10}) =>
      _inner.fetchPending(limit: limit);

  @override
  Future<OutboxItem?> claim({Duration? leaseDuration}) =>
      _inner.claim(leaseDuration: leaseDuration);

  @override
  Future<List<OutboxItem>> claimNextBatch({
    required int maxSize,
    Duration? leaseDuration,
  }) => _inner.claimNextBatch(maxSize: maxSize, leaseDuration: leaseDuration);

  @override
  Future<int> releaseOrphanedClaims() => _inner.releaseOrphanedClaims();

  @override
  Future<bool> hasMorePending() => _inner.hasMorePending();

  @override
  Future<void> markSent(OutboxItem item) async {
    if (markSentThrows) throw const _MarkFailed();
    await _inner.markSent(item);
  }

  @override
  Future<void> markSentBatch(List<OutboxItem> items) async {
    if (markSentThrows) throw const _MarkFailed();
    await _inner.markSentBatch(items);
  }

  @override
  Future<void> markRetry(OutboxItem item) async {
    if (markRetryThrows) throw const _MarkFailed();
    await _inner.markRetry(item);
  }

  @override
  Future<void> markRetryBatch(List<OutboxItem> items) async {
    if (markRetryThrows) throw const _MarkFailed();
    await _inner.markRetryBatch(items);
  }

  @override
  Future<int> pruneSentOutboxItems({
    required Duration retention,
    DateTime? now,
  }) => _inner.pruneSentOutboxItems(retention: retention, now: now);

  @override
  Future<int> pruneSentOutboxItemsChunked({
    required Duration retention,
    int chunkSize = 5000,
    bool vacuumWhenDone = false,
    void Function(int deletedSoFar)? onProgress,
  }) => _inner.pruneSentOutboxItemsChunked(
    retention: retention,
    chunkSize: chunkSize,
    vacuumWhenDone: vacuumWhenDone,
    onProgress: onProgress,
  );
}

class _OutboxBench {
  _OutboxBench() {
    when(
      () => sequenceLog.recordSentEntry(
        entryId: any(named: 'entryId'),
        vectorClock: any(named: 'vectorClock'),
        payloadType: any(named: 'payloadType'),
      ),
    ).thenAnswer((invocation) async {
      final vc = invocation.namedArguments[#vectorClock] as VectorClock;
      final counter = vc.vclock['host-A']!;
      if (counter > lastRecorded) lastRecorded = counter;
    });
    when(
      () => sequenceLog.getLastSentVectorClockForEntry(any()),
    ).thenAnswer(
      (_) async =>
          lastRecorded == 0 ? null : VectorClock({'host-A': lastRecorded}),
    );
    when(() => sender.send(any())).thenAnswer((invocation) async {
      if (sendFails) return false;
      final message = invocation.positionalArguments.single as SyncMessage;
      wire.addAll(
        message is SyncOutboxBundle
            ? message.children.map(_sentOf)
            : [_sentOf(message)],
      );
      return true;
    });
    boot();
  }

  final db = SyncDatabase(inMemoryDatabase: true);
  final sequenceLog = MockSyncSequenceLogService();
  final sender = MockOutboxMessageSender();
  final wire = <_Sent>[];
  DateTime now = DateTime(2026, 9, 25, 12);
  int lastRecorded = 0;
  bool sendFails = false;

  late OutboxEnqueueWriter writer;
  late _FaultyRepository repository;
  late OutboxProcessor processor;

  int written = 0;
  final heldBack = <int>[];
  final inFlight = <Future<void>>[];
  final done = <int>{};
  final enqueued = <int>{};

  /// Whether every enqueue so far started in version order.
  bool inOrder = true;

  /// Payload counter of each pending row after the previous step.
  Map<int, int> pendingPayloads = {};

  /// A process start: fresh writer, repository and processor.
  void boot() {
    writer = OutboxEnqueueWriter(
      journalDb: MockJournalDb(),
      loggingService: MockDomainLogger(),
      syncDatabase: db,
      documentsDirectory: Directory(p.join(p.separator, 'outbox-model-docs')),
      saveJson: (_, _) async {},
      safePayloadFullPath: (_) => null,
      enqueueNextSendRequest:
          ({Duration delay = const Duration(milliseconds: 1)}) async {},
      sequenceLogService: sequenceLog,
    );
    repository = _FaultyRepository(DatabaseOutboxRepository(db, maxRetries: 3));
    processor = OutboxProcessor(
      repository: repository,
      messageSender: sender,
      loggingService: MockDomainLogger(),
      bundleMaxSizeOverride: 2,
      maxRetriesOverride: 3,
    );
  }

  void launch(int version) {
    if (enqueued.any((v) => v > version)) inOrder = false;
    enqueued.add(version);
    final msg = writer.prepareAgentEntity(
      SyncMessage.agentEntity(
            agentEntity: _agentEntity(
              vectorClock: VectorClock({'host-A': version}),
            ),
            status: SyncEntryStatus.update,
          )
          as SyncAgentEntity,
      'host-A',
    );
    inFlight.add(
      writer
          .enqueueAgentEntity(msg: msg, commonFields: _commonFields(msg))
          .then((_) => done.add(version)),
    );
  }

  Future<void> settle() async {
    await Future.wait(inFlight);
    inFlight.clear();
  }

  /// `sendNext`: release orphaned claims, then drain until the queue is empty
  /// or a pass backs off.
  Future<void> drain() async {
    await repository.releaseOrphanedClaims();
    for (var pass = 0; pass < 12; pass++) {
      try {
        final result = await processor.processQueue();
        if (!result.shouldSchedule || result.nextDelay != Duration.zero) {
          return;
        }
      } on _MarkFailed {
        return; // processQueue threw: sendNext backs off
      }
    }
  }

  Future<void> run(_OutboxStep step) async {
    switch (step.op) {
      case _OutboxOp.enqueueNext:
        launch(++written);
      case _OutboxOp.holdBack:
        heldBack.add(++written);
      case _OutboxOp.enqueueHeld:
        if (heldBack.isNotEmpty) launch(heldBack.removeAt(0));
      case _OutboxOp.settle:
        await settle();
      case _OutboxOp.drainOk:
        await drain();
      case _OutboxOp.drainFail:
        sendFails = true;
        await drain();
        sendFails = false;
      case _OutboxOp.drainMarksThrow:
        repository
          ..markSentThrows = true
          ..markRetryThrows = true;
        await drain();
        repository
          ..markSentThrows = false
          ..markRetryThrows = false;
      case _OutboxOp.drainMarkSentThrows:
        repository.markSentThrows = true;
        await drain();
        repository.markSentThrows = false;
      case _OutboxOp.tick:
        now = now.add(const Duration(minutes: 2));
      case _OutboxOp.crash:
        await settle();
        boot();
      case _OutboxOp.prune:
        final before = await db.getOutboxItems();
        await db.pruneSentOutboxItems(
          retention: Duration.zero,
          now: now.add(const Duration(days: 1)),
        );
        final after = {for (final item in await db.getOutboxItems()) item.id};
        for (final item in before.where((item) => !after.contains(item.id))) {
          expect(
            item.status,
            OutboxStatus.sent.index,
            reason: 'PruneOnlySent: row ${item.id}',
          );
        }
    }
  }

  Future<void> checkInvariants(List<_OutboxStep> trace) async {
    final items = await db.getOutboxItems();
    final live = items.where(
      (item) =>
          item.status == OutboxStatus.pending.index ||
          item.status == OutboxStatus.sending.index ||
          item.status == OutboxStatus.error.index,
    );
    final liveRows = {
      for (final item in live) item.id: _sentOf(_decode(item.message)),
    };

    for (final version in done) {
      final carried =
          wire.any(
            (m) => m.payload == version || m.covered.contains(version),
          ) ||
          liveRows.values.any(
            (m) => m.payload == version || m.covered.contains(version),
          );
      expect(carried, isTrue, reason: 'NoLostCounter $version: $trace');
    }

    for (final row in liveRows.values) {
      expect(
        row.covered.every((c) => c <= row.payload),
        isTrue,
        reason: 'CoversOnlyOlder $row: $trace',
      );
    }

    final pendingNow = {
      for (final item in items.where(
        (item) => item.status == OutboxStatus.pending.index,
      ))
        item.id: _sentOf(_decode(item.message)).payload,
    };
    for (final entry in pendingNow.entries) {
      final before = pendingPayloads[entry.key];
      if (before != null) {
        expect(
          entry.value,
          greaterThanOrEqualTo(before),
          reason: 'MergeNeverRegresses row ${entry.key}: $trace',
        );
      }
    }
    pendingPayloads = pendingNow;

    for (final item in items.where(
      (item) => item.status == OutboxStatus.sent.index,
    )) {
      final sent = _sentOf(_decode(item.message));
      expect(
        wire.any((m) => m.payload == sent.payload),
        isTrue,
        reason: 'SentWasDelivered row ${item.id}: $trace',
      );
    }

    if (inOrder && wire.isNotEmpty) {
      final newest = wire.map((m) => m.payload).reduce(math.max);
      expect(
        wire.last.payload,
        newest,
        reason: 'NewestLandsLast ${wire.map((m) => m.payload)}: $trace',
      );
    }
  }
}

void _registerOutboxModelConformance() {
  group('model conformance with specs/tla/Outbox.tla', () {
    glados.Glados(
      glados.any.outboxTrace,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated traces keep NoLostCounter, CoversOnlyOlder, '
      'MergeNeverRegresses, SentWasDelivered, PruneOnlySent and '
      'NewestLandsLast, and deliver every enqueued version',
      (trace) async {
        final bench = _OutboxBench();
        try {
          await withClock(Clock(() => bench.now), () => _playOut(bench, trace));
        } finally {
          await bench.db.close();
        }
      },
      tags: 'glados',
    );
  });
}

Future<void> _playOut(_OutboxBench bench, List<_OutboxStep> trace) async {
  try {
    for (final step in trace) {
      await bench.run(step);
      await bench.checkInvariants(trace);
    }
  } finally {
    await bench.settle();
  }
  // Every held-back write is enqueued, and the queue drains cleanly.
  List.of(bench.heldBack).forEach(bench.launch);
  bench.heldBack.clear();
  await bench.settle();
  for (var i = 0; i < 6; i++) {
    await bench.drain();
  }
  await bench.checkInvariants(trace);

  // EnqueuedIsDelivered: on the wire, or in a row that failed for good.
  final errorRows = (await bench.db.getOutboxItems(
    statuses: const [OutboxStatus.error],
  )).map((item) => _sentOf(_decode(item.message)));
  for (final version in bench.done) {
    bool carries(_Sent m) =>
        m.payload == version || m.covered.contains(version);
    expect(
      bench.wire.any(carries) || errorRows.any(carries),
      isTrue,
      reason: 'EnqueuedIsDelivered $version: $trace',
    );
  }
  expect(
    await bench.db.getOutboxItems(
      statuses: const [OutboxStatus.pending, OutboxStatus.sending],
    ),
    isEmpty,
    reason: 'EveryRowSettles: $trace',
  );
}
