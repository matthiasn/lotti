part of 'outbox_enqueue_writer_test.dart';

// Model conformance: the real enqueue writer, SyncDatabase outbox,
// DatabaseOutboxRepository and OutboxProcessor, driven through generated
// traces, must keep the invariants `specs/tla/Outbox.tla` model-checks. TLC
// proves the design; these traces check that the Dart code behaves like it.
//
// Two entities are written again and again: an agent entity, enqueued by the
// real writer (append-only, ADR 0086), sometimes concurrently and sometimes
// late (after a newer version), and a journal entry whose first row owes its
// audio and whose later rows are JSON-only edits — rows shaped exactly as the
// journal writer appends them. Drains collapse each entity's rows when they
// send; they can fail, lose their marks (the rows stay `sending`, as after a
// crash between send and markSent), time can pass beyond the claim lease, a
// crash is a fresh writer, repository and processor over the same database,
// sent rows are pruned, and the monitor retries a failed row. A drain releases
// orphaned claims first, as `MatrixOutboxService.sendNext` does.
//
// A third entity is an AI configuration: its rows never collapse, each version
// carries the stamp the sender's real `AiConfigDb` gave it, and a real
// receiving `AiConfigDb` applies what lands in arrival order. A drain can time
// out while its send still lands later (a ghost), so the room's order is not
// the newest-last order; the receiver must still end on the newest version
// (`PeerHoldsNewest`, ADR 0094). `NewestLandsLast` is only checked while no
// ghost has landed, as `OutboxGhost` does not claim it.

enum _OutboxOp {
  enqueueNext,
  enqueueLatePair,
  holdBack,
  enqueueHeld,
  journalEdit,
  settle,
  drainOk,
  drainFail,
  drainMarksThrow,
  drainMarkSentThrows,
  aiEdit,
  drainGhost,
  ghostLand,
  tick,
  crash,
  prune,
  userRetry,
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
        20,
        glados.IntAnys(this).intInRange(0, _OutboxOp.values.length),
      )
      .map((codes) => [for (final code in codes) _OutboxStep.decode(code)]);
}

const _agentId = 'agent-1';
const _journalId = 'journal-1';
const _aiConfigId = 'ai-config-1';

/// Version [version] of the AI configuration; its name carries the version.
AiConfig _aiConfig(int version) => AiConfig.inferenceProfile(
  id: _aiConfigId,
  name: 'v$version',
  createdAt: DateTime(2026, 9, 25),
  thinkingModelId: 'model-1',
);

/// A payload as it left the device: its entity, the counter it announces, the
/// counters it covers, and whether it carries the attachment.
typedef _Sent = ({String entity, int payload, Set<int> covered, bool media});

_Sent _sentOf(SyncMessage message) => switch (message) {
  final SyncAgentEntity m => (
    entity: _agentId,
    payload: m.agentEntity!.vectorClock!.vclock['host-A']!,
    covered: {
      for (final vc in m.coveredVectorClocks ?? <VectorClock>[])
        vc.vclock['host-A']!,
    },
    media: false,
  ),
  final SyncJournalEntity m => (
    entity: _journalId,
    payload: m.vectorClock!.vclock['host-A']!,
    covered: {
      for (final vc in m.coveredVectorClocks ?? <VectorClock>[])
        vc.vclock['host-A']!,
    },
    media:
        m.status == SyncEntryStatus.initial || (m.includeAttachments ?? false),
  ),
  final SyncAiConfig m => (
    entity: _aiConfigId,
    payload: int.parse(m.aiConfig.name.substring(1)),
    covered: const <int>{},
    media: false,
  ),
  final other => throw StateError('unexpected $other'),
};

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
  Future<List<OutboxItem>> collapsibleRows(
    String entryId, {
    Set<int> excludeIds = const {},
  }) => _inner.collapsibleRows(entryId, excludeIds: excludeIds);

  @override
  Future<List<OutboxItem>> claimRows(List<OutboxItem> rows) =>
      _inner.claimRows(rows);

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
  Future<void> markFailed(List<OutboxItem> items) async {
    if (markRetryThrows) throw const _MarkFailed();
    await _inner.markFailed(items);
  }

  @override
  Future<void> releaseClaims(List<OutboxItem> items) async {
    if (markRetryThrows) throw const _MarkFailed();
    await _inner.releaseClaims(items);
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
    when(() => sender.send(any())).thenAnswer((invocation) async {
      if (sendFails) return false;
      final message = invocation.positionalArguments.single as SyncMessage;
      final children = message is SyncOutboxBundle
          ? message.children
          : [message];
      if (sendTimesOut) {
        // The processor gives up on the send; the SDK lands it later.
        ghosts.add(children);
        return false;
      }
      land(children);
      return true;
    });
    boot();
  }

  final db = SyncDatabase(inMemoryDatabase: true);
  final sender = MockOutboxMessageSender();
  final wire = <_Sent>[];
  DateTime now = DateTime(2026, 9, 25, 12);
  bool sendFails = false;
  bool sendTimesOut = false;

  /// Sends that timed out but have not landed yet, oldest first.
  final ghosts = <List<SyncMessage>>[];
  bool ghostLanded = false;

  /// The sender's and the receiver's AI config stores.
  final senderAiDb = AiConfigDb(
    inMemoryDatabase: true,
    apiKeyStorage: AiApiKeyStorage.inMemory(),
  );
  final receiverAiDb = AiConfigDb(
    inMemoryDatabase: true,
    apiKeyStorage: AiApiKeyStorage.inMemory(),
  );

  /// AI config payloads in the order they landed; the receiver applies them
  /// in that order.
  final aiLanded = <SyncAiConfig>[];
  int aiApplied = 0;
  int aiVersion = 0;

  late OutboxEnqueueWriter writer;
  late _FaultyRepository repository;
  late OutboxProcessor processor;

  int written = 0;
  final heldBack = <int>[];
  final inFlight = <Future<void>>[];

  /// Versions whose enqueue finished, per entity.
  final done = <String, Set<int>>{
    _agentId: {},
    _journalId: {},
    _aiConfigId: {},
  };
  final launched = <int>{};
  int journalVersion = 0;

  /// Whether every agent enqueue so far started in version order.
  bool inOrder = true;

  /// Each row's message as it was inserted: rows are immutable.
  final inserted = <int, String>{};

  /// A process start: fresh writer, repository and processor.
  void boot() {
    writer = OutboxEnqueueWriter(
      journalDb: MockJournalDb(),
      loggingService: MockDomainLogger(),
      syncDatabase: db,
      documentsDirectory: Directory(p.join(p.separator, 'outbox-model-docs')),
      saveJson: (_, _) async {},
      safePayloadFullPath: (_) => null,
      sequenceLogService: null,
    );
    repository = _FaultyRepository(DatabaseOutboxRepository(db, maxRetries: 2));
    processor = OutboxProcessor(
      repository: repository,
      messageSender: sender,
      loggingService: MockDomainLogger(),
      bundleMaxSizeOverride: 2,
      maxRetriesOverride: 2,
    );
  }

  void launch(int version) {
    if (launched.any((v) => v > version)) inOrder = false;
    launched.add(version);
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
          .then((_) => done[_agentId]!.add(version)),
    );
  }

  /// The journal writer's row for the next version of the entry: the first
  /// one owes the audio (status initial, `filePath` set), later ones are
  /// JSON-only edits.
  Future<void> journalEdit() async {
    final version = ++journalVersion;
    final initial = version == 1;
    final msg = SyncMessage.journalEntity(
      id: _journalId,
      vectorClock: VectorClock({'host-A': version}),
      jsonPath: '/text_entries/$_journalId.json',
      status: initial ? SyncEntryStatus.initial : SyncEntryStatus.update,
      coveredVectorClocks: [
        VectorClock({'host-A': version}),
      ],
    );
    await db.addOutboxItem(
      _commonFields(msg, priority: OutboxPriority.high.index).copyWith(
        subject: Value('hash:$version'),
        outboxEntryId: const Value(_journalId),
        filePath: Value(initial ? '/audio/$_journalId.m4a' : null),
      ),
    );
    done[_journalId]!.add(version);
  }

  /// Payloads reaching the room, in order.
  void land(List<SyncMessage> messages) {
    wire.addAll(messages.map(_sentOf));
    aiLanded.addAll(messages.whereType<SyncAiConfig>());
  }

  /// A local edit of the AI configuration: the sender's store stamps the
  /// version, and the row carries that stamp, as `AiConfigRepository` does.
  Future<void> aiEdit() async {
    final version = ++aiVersion;
    final stamp = await senderAiDb.saveConfig(_aiConfig(version));
    final msg =
        SyncMessage.aiConfig(
              aiConfig: _aiConfig(version),
              status: SyncEntryStatus.update,
              versionStamp: stamp,
            )
            as SyncAiConfig;
    await writer.enqueueAiConfig(msg: msg, commonFields: _commonFields(msg));
    done[_aiConfigId]!.add(version);
  }

  /// The receiver applies what landed since it last looked, in arrival
  /// order.
  Future<void> receive() async {
    for (; aiApplied < aiLanded.length; aiApplied++) {
      final msg = aiLanded[aiApplied];
      await receiverAiDb.applyConfigVersion(
        msg.aiConfig,
        stamp: msg.versionStamp!,
      );
    }
  }

  Future<void> close() async {
    await db.close();
    await senderAiDb.close();
    await receiverAiDb.close();
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
      case _OutboxOp.enqueueLatePair:
        // Two writes whose enqueues arrive out of order: the newer first.
        written += 2;
        launch(written);
        launch(written - 1);
      case _OutboxOp.holdBack:
        heldBack.add(++written);
      case _OutboxOp.enqueueHeld:
        if (heldBack.isNotEmpty) launch(heldBack.removeAt(0));
      case _OutboxOp.journalEdit:
        await journalEdit();
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
      case _OutboxOp.aiEdit:
        await aiEdit();
      case _OutboxOp.drainGhost:
        sendTimesOut = true;
        await drain();
        sendTimesOut = false;
      case _OutboxOp.ghostLand:
        if (ghosts.isNotEmpty) {
          land(ghosts.removeAt(0));
          ghostLanded = true;
        }
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
      case _OutboxOp.userRetry:
        final failed = await db.getOutboxItems(
          statuses: const [OutboxStatus.error],
        );
        if (failed.isNotEmpty) {
          await db.updateOutboxItem(
            OutboxCompanion(
              id: Value(failed.last.id),
              status: Value(OutboxStatus.pending.index),
              retries: Value(failed.last.retries + 1),
            ),
          );
        }
    }
  }

  bool carries(_Sent m, String entity, int version) =>
      m.entity == entity &&
      (m.payload == version || m.covered.contains(version));

  Future<void> checkInvariants(List<_OutboxStep> trace) async {
    final items = await db.getOutboxItems();
    for (final item in items) {
      final first = inserted.putIfAbsent(item.id, () => item.message);
      expect(item.message, first, reason: 'RowsImmutable ${item.id}: $trace');
    }
    final live = [
      for (final item in items)
        if (item.status == OutboxStatus.pending.index ||
            item.status == OutboxStatus.sending.index ||
            item.status == OutboxStatus.error.index)
          _sentOf(_decode(item.message)),
    ];

    for (final entity in done.keys) {
      for (final version in done[entity]!) {
        expect(
          wire.any((m) => carries(m, entity, version)) ||
              live.any((m) => carries(m, entity, version)),
          isTrue,
          reason: 'NoLostCounter $entity@$version: $trace',
        );
      }
    }

    for (final m in wire) {
      expect(
        m.covered.every((c) => c <= m.payload),
        isTrue,
        reason: 'CoversOnlyOlder $m: $trace',
      );
    }

    for (final item in items.where(
      (item) => item.status == OutboxStatus.sent.index,
    )) {
      final sent = _sentOf(_decode(item.message));
      expect(
        wire.any((m) => carries(m, sent.entity, sent.payload)),
        isTrue,
        reason: 'SentWasDelivered row ${item.id}: $trace',
      );
      if (item.filePath != null) {
        expect(
          wire.any((m) => m.entity == sent.entity && m.media),
          isTrue,
          reason: 'MediaNotDropped row ${item.id}: $trace',
        );
      }
    }

    // An AI configuration's rows never collapse, so a Retry of an older
    // failed row can land after a newer one; the model does not claim this
    // for them either.
    for (final entity in [_agentId, _journalId]) {
      if (ghostLanded) break;
      if (entity == _agentId && !inOrder) continue;
      final sent = wire.where((m) => m.entity == entity).toList();
      if (sent.isEmpty) continue;
      final newest = sent.map((m) => m.payload).reduce(math.max);
      expect(
        sent.last.payload,
        newest,
        reason: 'NewestLandsLast $entity ${sent.map((m) => m.payload)}: $trace',
      );
    }

    await receive();
    final aiSent = wire.where((m) => m.entity == _aiConfigId);
    if (aiSent.isNotEmpty) {
      final newest = aiSent.map((m) => m.payload).reduce(math.max);
      expect(
        (await receiverAiDb.getConfigById(_aiConfigId))?.name,
        'v$newest',
        reason: 'PeerHoldsNewest ${aiSent.map((m) => m.payload)}: $trace',
      );
    }
  }
}

void _registerOutboxModelConformance() {
  group('model conformance with specs/tla/Outbox.tla', () {
    glados.Glados(
      glados.any.outboxTrace,
      glados.ExploreConfig(numRuns: 250),
    ).test(
      'generated traces keep NoLostCounter, CoversOnlyOlder, RowsImmutable, '
      'SentWasDelivered, MediaNotDropped, PruneOnlySent, NewestLandsLast and '
      'PeerHoldsNewest, and deliver every enqueued version',
      (trace) async {
        final bench = _OutboxBench();
        try {
          await withClock(Clock(() => bench.now), () => _playOut(bench, trace));
        } finally {
          await bench.close();
        }
      },
      tags: 'glados',
    );

    // OutboxGhostRows' ten-step counterexample with StampedReceiver off: v1 is
    // claimed, v2 is written, v1's send times out and is retried, v1 and v2
    // go out, and the abandoned v1 lands last. The receiver keeps v2.
    test('a timed-out AI config send that lands last does not overwrite the '
        'newer version on the peer', () async {
      final bench = _OutboxBench();
      const trace = [
        _OutboxStep(_OutboxOp.aiEdit),
        _OutboxStep(_OutboxOp.drainGhost),
        _OutboxStep(_OutboxOp.aiEdit),
        _OutboxStep(_OutboxOp.drainOk),
        _OutboxStep(_OutboxOp.ghostLand),
      ];
      try {
        await withClock(Clock(() => bench.now), () => _playOut(bench, trace));
        expect(
          bench.wire
              .where((m) => m.entity == _aiConfigId)
              .map((m) => m.payload),
          [1, 2, 1],
        );
        expect(
          (await bench.receiverAiDb.getConfigById(_aiConfigId))!.name,
          'v2',
        );
      } finally {
        await bench.close();
      }
    });
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
  // Every held-back write is enqueued, late sends land, and the queue drains
  // cleanly.
  List.of(bench.heldBack).forEach(bench.launch);
  bench.heldBack.clear();
  await bench.settle();
  for (var i = 0; i < 6; i++) {
    await bench.drain();
  }
  while (bench.ghosts.isNotEmpty) {
    bench
      ..land(bench.ghosts.removeAt(0))
      ..ghostLanded = true;
  }
  await bench.checkInvariants(trace);

  // EnqueuedIsDelivered: on the wire, or in a row that failed for good.
  final errorRows = (await bench.db.getOutboxItems(
    statuses: const [OutboxStatus.error],
  )).map((item) => _sentOf(_decode(item.message)));
  for (final entity in bench.done.keys) {
    for (final version in bench.done[entity]!) {
      expect(
        bench.wire.any((m) => bench.carries(m, entity, version)) ||
            errorRows.any((m) => bench.carries(m, entity, version)),
        isTrue,
        reason: 'EnqueuedIsDelivered $entity@$version: $trace',
      );
    }
  }
  expect(
    await bench.db.getOutboxItems(
      statuses: const [OutboxStatus.pending, OutboxStatus.sending],
    ),
    isEmpty,
    reason: 'EveryRowSettles: $trace',
  );
}
