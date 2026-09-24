part of 'change_set_confirmation_service_test.dart';

// Model conformance: the real confirmation service, driven through generated
// interleavings, must keep the invariants `specs/tla/ChangeSetConfirm.tla`
// model-checks. TLC proves the design; these traces check that the Dart code
// behaves like it. Confirms run concurrently over one stored change set, with
// transactions serialized as Drift serializes them, and a crash is a fresh
// service over the same store.

enum _ConfirmOp {
  start,
  reject,
  dispatchOk,
  dispatchOkHookThrows,
  dispatchFails,
  crash,
}

class _ConfirmStep {
  const _ConfirmStep(this.op, this.arg);

  factory _ConfirmStep.decode(int code) => _ConfirmStep(
    _ConfirmOp.values[code % _ConfirmOp.values.length],
    code ~/ _ConfirmOp.values.length,
  );

  final _ConfirmOp op;

  /// Picks among the dispatches in flight, modulo how many there are.
  final int arg;

  @override
  String toString() => '${op.name}($arg)';
}

extension _AnyConfirmTrace on glados.Any {
  glados.Generator<List<_ConfirmStep>> get confirmTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        14,
        glados.IntAnys(this).intInRange(0, _ConfirmOp.values.length * 3),
      )
      .map((codes) => [for (final code in codes) _ConfirmStep.decode(code)]);
}

/// One stored single-item change set, and every process that confirms it.
class _ConfirmBench {
  _ConfirmBench() {
    when(() => repository.getEntity(any())).thenAnswer((_) async => stored);
    when(() => syncService.repository).thenReturn(repository);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first;
      if (entity is ChangeSetEntity) stored = entity;
    });
    syncService.transactionDelegate = driftLikeTransactions(
      save: () => stored,
      restore: (snapshot) => stored = snapshot,
    );
    when(
      () => logger.log(any(), any(), subDomain: any(named: 'subDomain')),
    ).thenReturn(null);
    when(
      () => logger.error(
        any(),
        any(),
        message: any(named: 'message'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);
    boot();
  }

  final syncService = MockAgentSyncService();
  final repository = MockAgentRepository();
  final logger = MockDomainLogger();

  ChangeSetEntity stored = makeTestChangeSet(
    items: const [
      ChangeItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 30},
        humanSummary: 'Set estimate to 30 minutes',
      ),
    ],
  );

  late ChangeSetConfirmationService service;

  /// Dispatches waiting for the trace to decide their outcome.
  final inFlight = <Completer<ToolExecutionResult>>[];

  /// Confirms of the current process that have not returned yet.
  int running = 0;

  /// Ghost: how many times the change took effect.
  int applied = 0;
  bool crashed = false;
  bool hookThrows = false;

  void boot() {
    inFlight.clear();
    running = 0;
    service = ChangeSetConfirmationService(
      syncService: syncService,
      toolDispatcher: (_, _, _) {
        final dispatch = Completer<ToolExecutionResult>();
        inFlight.add(dispatch);
        return dispatch.future;
      },
      labelsRepository: MockLabelsRepository(),
      domainLogger: logger,
      onConfirmedDecision:
          ({required changeSet, required item, required decision}) async {
            if (hookThrows) throw StateError('hook failed');
          },
    );
  }

  Future<void> run(_ConfirmStep step) async {
    if (step.op == _ConfirmOp.start) {
      // A tap on "confirm" with whatever the UI last showed. Not pumped:
      // consecutive taps overlap, like a double tap or a "confirm all"
      // racing a single confirm.
      final process = service;
      running++;
      unawaited(
        process.confirmItem(stored, 0).whenComplete(() {
          if (identical(process, service)) running--;
        }),
      );
      return;
    }
    if (step.op == _ConfirmOp.reject) {
      // A swipe-reject racing the confirms, unpumped like them.
      final process = service;
      running++;
      unawaited(
        process.rejectItem(stored, 0).whenComplete(() {
          if (identical(process, service)) running--;
        }),
      );
      return;
    }
    // Let every confirm started so far reach its dispatch, or give up.
    await pumpEventQueue();
    switch (step.op) {
      case _ConfirmOp.dispatchOk:
      case _ConfirmOp.dispatchOkHookThrows:
        if (inFlight.isEmpty) return;
        applied++;
        hookThrows = step.op == _ConfirmOp.dispatchOkHookThrows;
        inFlight
            .removeAt(step.arg % inFlight.length)
            .complete(const ToolExecutionResult(success: true, output: 'ok'));
      case _ConfirmOp.dispatchFails:
        if (inFlight.isEmpty) return;
        inFlight
            .removeAt(step.arg % inFlight.length)
            .complete(
              const ToolExecutionResult(success: false, output: 'failed'),
            );
      case _ConfirmOp.crash:
        // Dispatches in flight never return; the store survives.
        crashed = true;
        boot();
      case _ConfirmOp.start:
      case _ConfirmOp.reject:
        break;
    }
    await pumpEventQueue();
    hookThrows = false;
  }

  void checkInvariants(List<_ConfirmStep> trace) {
    final status = stored.items.single.status;
    expect(applied, lessThanOrEqualTo(1), reason: 'AtMostOnceApply: $trace');
    // A pending item has never taken effect: a failure reverts only a
    // dispatch that had none.
    if (status == ChangeItemStatus.pending) {
      expect(applied, 0, reason: 'pending but applied: $trace');
    }
    if (status == ChangeItemStatus.rejected) {
      expect(applied, 0, reason: 'RejectedMeansNotApplied: $trace');
    }
    // ConfirmedMeansApplied, once no confirm is mid-way. A crash between the
    // claim and the dispatch is the documented residual.
    if (!crashed && running == 0 && status == ChangeItemStatus.confirmed) {
      expect(applied, 1, reason: 'ConfirmedMeansApplied: $trace');
    }
  }
}

void _registerModelConformance() {
  group('model conformance with specs/tla/ChangeSetConfirm.tla', () {
    glados.Glados(
      glados.any.confirmTrace,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'generated interleavings keep AtMostOnceApply, RejectedMeansNotApplied '
      'and ConfirmedMeansApplied',
      (trace) async {
        final bench = _ConfirmBench();
        await withClock(Clock.fixed(DateTime(2024, 6, 15, 12)), () async {
          try {
            for (final step in trace) {
              await bench.run(step);
              bench.checkInvariants(trace);
            }
          } finally {
            // Settle whatever is still racing — also after a failure, so no
            // confirm of this input leaks into the next one.
            for (var i = 0; i < 8 && bench.running > 0; i++) {
              await bench.run(const _ConfirmStep(_ConfirmOp.dispatchFails, 0));
            }
          }
          expect(bench.running, 0, reason: 'a confirm never returned: $trace');
          bench.checkInvariants(trace);
        });
      },
      tags: 'glados',
    );
  });
}
