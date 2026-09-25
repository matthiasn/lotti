part of 'backfill_response_handler_test.dart';

// Model conformance: the real reservation, sequence-log and settlement code,
// driven through generated operation traces, must keep the invariants that
// `specs/tla/SyncSequence.tla` model-checks. TLC proves the design; these
// traces check that the Dart code behaves like the design, over in-memory
// databases, with a crash being a fresh service stack over the same stores.

/// One step of a generated trace. `arg` picks among live reservations or
/// counters; it is interpreted modulo whatever is available at that step.
enum _TraceOp {
  reserveA,
  reserveB,
  commit,
  outboxBind,
  release,
  crash,
  request,
  outboxDown,
  outboxUp,
}

class _TraceStep {
  const _TraceStep(this.op, this.arg);

  factory _TraceStep.decode(int code) => _TraceStep(
    _TraceOp.values[code % _TraceOp.values.length],
    code ~/ _TraceOp.values.length,
  );

  final _TraceOp op;
  final int arg;

  @override
  String toString() => '${op.name}($arg)';
}

extension _AnySyncTrace on glados.Any {
  glados.Generator<List<_TraceStep>> get syncTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        18,
        glados.IntAnys(this).intInRange(0, _TraceOp.values.length * 6),
      )
      .map((codes) => [for (final code in codes) _TraceStep.decode(code)]);
}

/// A live reservation in the current process.
class _LiveWrite {
  _LiveWrite(this.reservation, this.entity, this.counter);

  final VcReservation reservation;
  final String entity;
  final int counter;
  bool committed = false;
  bool finished = false;
}

/// The "process": services that a crash replaces, over stores that survive.
class _ConformanceBench {
  _ConformanceBench._(this.settings, this.syncDb);

  final SettingsDb settings;
  final SyncDatabase syncDb;

  /// The journal: each entity's committed own-host counter (0 = absent).
  final payloads = <String, int>{'entity-a': 0, 'entity-b': 0};

  /// Ghost state, as in the spec.
  final committed = <int>{};

  /// Which entity each committed counter wrote.
  final committedEntity = <int, String>{};

  /// The highest payload counter per entity that actually reached the
  /// outbox — what peers will receive.
  final delivered = <String, int>{};
  final burnedEver = <int>{};
  final unresolvableSent = <int>{};

  final journalDb = MockJournalDb();
  final outbox = MockOutboxService();
  final logger = MockDomainLogger();
  bool outboxDown = false;

  late VectorClockService vc;
  late SyncSequenceLogService log;
  late BackfillResponseHandler handler;
  late String host;
  final live = <_LiveWrite>[];

  static Future<_ConformanceBench> create() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});
    final bench = _ConformanceBench._(
      SettingsDb(inMemoryDatabase: true),
      SyncDatabase(inMemoryDatabase: true),
    );
    getIt
      ..registerSingleton<SettingsDb>(bench.settings)
      ..registerSingleton<SyncDatabase>(bench.syncDb)
      ..registerSingleton<DomainLogger>(bench.logger);
    when(
      () => bench.journalDb.journalEntityByIdIncludingDeleted(any()),
    ).thenAnswer((call) {
      final id = call.positionalArguments.first as String;
      final counter = bench.payloads[id] ?? 0;
      return Future.value(
        counter == 0
            ? null
            : _createJournalEntry(
                id,
                vectorClock: VectorClock({bench.host: counter}),
              ),
      );
    });
    Future<void> send(Invocation call, {required bool orThrow}) async {
      if (bench.outboxDown) {
        // A durable enqueue reports the outage; a best-effort one swallows
        // it and the message is simply gone.
        if (orThrow) throw StateError('outbox down');
        return;
      }
      final message = call.positionalArguments.first;
      if (message is SyncJournalEntity) {
        bench._deliver(message.id, message.vectorClock?.vclock[bench.host]);
      }
      if (message is SyncBackfillResponse && message.unresolvable == true) {
        bench.unresolvableSent.add(message.counter);
      }
    }

    when(
      () => bench.outbox.enqueueMessage(any()),
    ).thenAnswer((call) => send(call, orThrow: false));
    when(
      () => bench.outbox.enqueueMessageOrThrow(any()),
    ).thenAnswer((call) => send(call, orThrow: true));
    await bench._startProcess();
    return bench;
  }

  void _deliver(String entity, int? counter) {
    if (counter == null) return;
    if (counter > (delivered[entity] ?? -1)) delivered[entity] = counter;
  }

  /// Boot: fresh in-memory services over the surviving stores, then the
  /// startup reconciliation `get_it_sync.dart` runs.
  Future<void> _startProcess() async {
    live.clear();
    vc = VectorClockService();
    await vc.initialized;
    host = (await vc.getHost())!;
    log = SyncSequenceLogService(
      syncDatabase: syncDb,
      vectorClockService: vc,
      loggingService: logger,
    );
    handler = BackfillResponseHandler(
      journalDb: journalDb,
      sequenceLogService: log,
      outboxService: outbox,
      loggingService: logger,
      vectorClockService: vc,
      responseCooldown: Duration.zero,
    );
    vc.setBurnHandler(
      (hostId, counter) =>
          handler.settleOwnCounter(hostId: hostId, counter: counter),
    );
    await vc.migrateUnrecordedReservations();
    await handler.settleOrphanedOwnCounters();
  }

  Future<void> run(_TraceStep step) async {
    final open = live.where((w) => !w.finished).toList();
    _LiveWrite? pick(List<_LiveWrite> from) =>
        from.isEmpty ? null : from[step.arg % from.length];
    switch (step.op) {
      case _TraceOp.reserveA:
      case _TraceOp.reserveB:
        final entity = step.op == _TraceOp.reserveA ? 'entity-a' : 'entity-b';
        final reservation = await vc.reserveNextVectorClock(
          payload: (id: entity, type: SyncSequencePayloadType.journalEntity),
        );
        live.add(
          _LiveWrite(reservation, entity, reservation.vc.vclock[host]!),
        );
      case _TraceOp.commit:
        // The journal write lands only if its clock dominates the stored one.
        final write = pick(open.where((w) => !w.committed).toList());
        if (write != null && payloads[write.entity]! < write.counter) {
          payloads[write.entity] = write.counter;
          write.committed = true;
          committed.add(write.counter);
          committedEntity[write.counter] = write.entity;
        }
      case _TraceOp.outboxBind:
        // The enqueue writer binds the counter after its outbox insert.
        final write = pick(open.where((w) => w.committed).toList());
        if (write != null && !outboxDown) {
          _deliver(write.entity, payloads[write.entity]);
          await log.recordSentEntry(
            entryId: write.entity,
            vectorClock: VectorClock({host: write.counter}),
          );
          write.finished = true;
        }
      case _TraceOp.release:
        // A rejected write, or a post-commit throw an outer scope reads as
        // failure: the reservation is released either way.
        final write = pick(open);
        if (write != null) {
          await write.reservation.release();
          write.finished = true;
        }
      case _TraceOp.crash:
        await _startProcess();
      case _TraceOp.request:
        final watermark = int.parse(
          (await settings.itemByKey(nextAvailableCounterKey)) ?? '0',
        );
        if (watermark > 0) {
          await handler.handleBackfillRequest(
            SyncBackfillRequest(
              entries: [
                BackfillRequestEntry(
                  hostId: host,
                  counter: step.arg % watermark,
                ),
              ],
              requesterId: 'peer-device',
            ),
          );
        }
      case _TraceOp.outboxDown:
        outboxDown = true;
      case _TraceOp.outboxUp:
        outboxDown = false;
    }
  }

  /// The spec's safety properties, over every counter handed out so far.
  Future<void> checkInvariants(List<_TraceStep> trace) async {
    final watermark = int.parse(
      (await settings.itemByKey(nextAvailableCounterKey)) ?? '0',
    );
    for (var counter = 0; counter < watermark; counter++) {
      final row = await syncDb.getEntryByHostAndCounter(host, counter);
      final status = row == null ? null : SyncSequenceStatus.values[row.status];
      final reason = 'counter $counter after $trace';
      if (committed.contains(counter)) {
        // NoFalseBurn: a committed payload is never declared lost.
        expect(status, isNot(SyncSequenceStatus.burned), reason: reason);
        expect(unresolvableSent, isNot(contains(counter)), reason: reason);
      }
      if (status == SyncSequenceStatus.received) {
        // BoundRowsHavePayload: a bound row's payload covers its counter.
        expect(
          payloads[row!.entryId] ?? 0,
          greaterThanOrEqualTo(counter),
          reason: reason,
        );
      }
      // BurnedIsTerminal.
      if (burnedEver.contains(counter)) {
        expect(status, SyncSequenceStatus.burned, reason: reason);
      }
      if (status == SyncSequenceStatus.burned) burnedEver.add(counter);
    }
  }

  Future<void> close() async {
    await syncDb.close();
    await settings.close();
    await getIt.reset();
  }
}

void _registerModelConformance() {
  group('model conformance with specs/tla/SyncSequence.tla', () {
    glados.Glados(
      glados.any.syncTrace,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'generated traces keep NoFalseBurn, BoundRowsHavePayload and '
      'BurnedIsTerminal, and a final restart binds every committed write',
      (trace) async {
        final bench = await _ConformanceBench.create();
        try {
          for (final step in trace) {
            await bench.run(step);
            await bench.checkInvariants(trace);
          }
          // EventuallyDelivered, on the originator: after a restart with a
          // working outbox, every committed write is bound and its payload —
          // or a newer version of it — actually reached the outbox.
          bench.outboxDown = false;
          await bench.run(const _TraceStep(_TraceOp.crash, 0));
          await bench.checkInvariants(trace);
          for (final counter in bench.committed) {
            final row = await bench.syncDb.getEntryByHostAndCounter(
              bench.host,
              counter,
            );
            expect(
              row?.status,
              SyncSequenceStatus.received.index,
              reason: 'committed counter $counter unbound after $trace',
            );
            expect(
              bench.delivered[bench.committedEntity[counter]] ?? -1,
              greaterThanOrEqualTo(counter),
              reason: 'committed counter $counter never sent after $trace',
            );
          }
        } finally {
          await bench.close();
        }
      },
      tags: 'glados',
    );
  });
}
