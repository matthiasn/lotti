part of 'change_set_confirmation_service_test.dart';

// Model conformance with `specs/tla/ChangeSetLifecycle.tla`: the real
// confirmation and retraction services, driven through generated
// interleavings over one stored set of three items — a follow-up task, the
// checklist migration into it, and a plain change. Every read of the set
// made outside a transaction returns the state as it was when it was made,
// but only when the trace delivers it: that is the await between a writer's
// read and its write, where another writer can slip in. Transactions are serialized as Drift
// serializes them. After every step the invariants the model checks must
// hold for the real code.

enum _LifecycleOp {
  confirm,
  reject,
  retract,
  deliverRead,
  dispatchOk,
  dispatchFails,
  dispatchNonRetryable,
}

class _LifecycleStep {
  const _LifecycleStep(this.op, this.arg);

  factory _LifecycleStep.decode(int code) => _LifecycleStep(
    _LifecycleOp.values[code % _LifecycleOp.values.length],
    code ~/ _LifecycleOp.values.length,
  );

  final _LifecycleOp op;

  /// The item, or which pending read or dispatch, modulo how many there are.
  final int arg;

  @override
  String toString() => '${op.name}($arg)';
}

extension _AnyLifecycleTrace on glados.Any {
  glados.Generator<List<_LifecycleStep>> get lifecycleTrace =>
      glados.ListAnys(this)
          .listWithLengthInRange(
            1,
            22,
            glados.IntAnys(
              this,
            ).intInRange(0, _LifecycleOp.values.length * 3),
          )
          .map((codes) => [for (final c in codes) _LifecycleStep.decode(c)]);
}

const _placeholder = 'placeholder-task';
const _createdTask = 'created-task';

class _PendingRead {
  _PendingRead(this.snapshot);

  final ChangeSetEntity snapshot;
  final Completer<ChangeSetEntity> completer = Completer<ChangeSetEntity>();
}

class _Dispatch {
  _Dispatch(this.toolName, this.args);

  final String toolName;
  final Map<String, dynamic> args;
  final Completer<ToolExecutionResult> completer =
      Completer<ToolExecutionResult>();
}

class _LifecycleBench {
  _LifecycleBench() {
    when(() => repository.getEntity(any())).thenAnswer((_) {
      // Inside a transaction nothing else can write, so the read is
      // immediate; outside one, the trace decides when it returns.
      if (Zone.current[_inTransaction] == true) return Future.value(stored);
      final read = _PendingRead(stored);
      reads.add(read);
      return read.completer.future;
    });
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
    service = ChangeSetConfirmationService(
      syncService: syncService,
      toolDispatcher: (name, args, _) {
        final dispatch = _Dispatch(name, args);
        inFlight.add(dispatch);
        return dispatch.completer.future;
      },
      labelsRepository: MockLabelsRepository(),
      domainLogger: logger,
    );
    retractions = SuggestionRetractionService(
      syncService: syncService,
      domainLogger: logger,
    );
  }

  final syncService = MockAgentSyncService();
  final repository = MockAgentRepository();
  final logger = MockDomainLogger();
  late final ChangeSetConfirmationService service;
  late final SuggestionRetractionService retractions;

  ChangeSetEntity stored = makeTestChangeSet(
    items: const [
      ChangeItem(
        toolName: TaskAgentToolNames.createFollowUpTask,
        args: {'title': 'Follow-up', '_placeholderTaskId': _placeholder},
        humanSummary: 'Create follow-up task',
      ),
      ChangeItem(
        toolName: TaskAgentToolNames.migrateChecklistItem,
        args: {'id': 'checklist-item', 'targetTaskId': _placeholder},
        humanSummary: 'Move checklist item',
      ),
      ChangeItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 30},
        humanSummary: 'Set estimate to 30 minutes',
      ),
    ],
  );

  final reads = <_PendingRead>[];
  final inFlight = <_Dispatch>[];

  /// Operations started and not returned yet.
  int running = 0;

  /// Ghost: how many times each item's change took effect.
  final applied = [0, 0, 0];

  /// Ghost: a migration dispatched before its target task existed.
  bool migratedEarly = false;

  static const Map<String, int> _toolIndex = {
    TaskAgentToolNames.createFollowUpTask: 0,
    TaskAgentToolNames.migrateChecklistItem: 1,
    'update_task_estimate': 2,
  };

  void _track(Future<Object?> operation) {
    running++;
    unawaited(operation.whenComplete(() => running--));
  }

  Future<void> run(_LifecycleStep step) async {
    final item = step.arg % stored.items.length;
    switch (step.op) {
      case _LifecycleOp.confirm:
        _track(service.confirmItem(stored, item));
      case _LifecycleOp.reject:
        _track(service.rejectItem(stored, item));
      case _LifecycleOp.retract:
        _track(
          retractions.applyStaged([
            StagedRetraction(
              changeSet: stored,
              itemIndex: item,
              item: stored.items[item],
              reason: 'stale',
            ),
          ]),
        );
      case _LifecycleOp.deliverRead:
        if (reads.isNotEmpty) {
          final read = reads.removeAt(step.arg % reads.length);
          read.completer.complete(read.snapshot);
        }
      case _LifecycleOp.dispatchOk:
        if (inFlight.isNotEmpty) {
          final dispatch = inFlight.removeAt(step.arg % inFlight.length);
          final index = _toolIndex[dispatch.toolName]!;
          applied[index]++;
          if (index == 1 &&
              (applied[0] == 0 ||
                  dispatch.args['targetTaskId'] != _createdTask)) {
            migratedEarly = true;
          }
          dispatch.completer.complete(
            ToolExecutionResult(
              success: true,
              output: 'ok',
              mutatedEntityId: index == 0 ? _createdTask : null,
            ),
          );
        }
      case _LifecycleOp.dispatchFails:
      case _LifecycleOp.dispatchNonRetryable:
        if (inFlight.isNotEmpty) {
          inFlight
              .removeAt(step.arg % inFlight.length)
              .completer
              .complete(
                ToolExecutionResult(
                  success: false,
                  output: 'failed',
                  nonRetryable: step.op == _LifecycleOp.dispatchNonRetryable,
                ),
              );
        }
    }
    await pumpEventQueue();
  }

  /// Delivers every read and fails every dispatch until nothing runs.
  Future<void> settle() async {
    for (var i = 0; i < 64 && running > 0; i++) {
      await run(const _LifecycleStep(_LifecycleOp.deliverRead, 0));
      await run(const _LifecycleStep(_LifecycleOp.dispatchFails, 0));
    }
  }

  void checkInvariants(List<_LifecycleStep> trace) {
    for (var i = 0; i < applied.length; i++) {
      final status = stored.items[i].status;
      expect(applied[i], lessThanOrEqualTo(1), reason: 'AtMostOnceApply $i');
      if (applied[i] > 0) {
        expect(
          status,
          isNot(ChangeItemStatus.pending),
          reason: 'AppliedStaysDecided $i: $trace',
        );
      }
      if (status == ChangeItemStatus.rejected ||
          status == ChangeItemStatus.retracted) {
        expect(applied[i], 0, reason: 'shown undone but applied $i: $trace');
      }
      if (running == 0 && status == ChangeItemStatus.confirmed) {
        expect(applied[i], 1, reason: 'ConfirmedMeansApplied $i: $trace');
      }
    }
    expect(migratedEarly, isFalse, reason: 'MigrationAfterTarget: $trace');
  }
}

void _registerLifecycleConformance() {
  group('model conformance with specs/tla/ChangeSetLifecycle.tla', () {
    glados.Glados(
      glados.any.lifecycleTrace,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'generated interleavings of every writer keep the set consistent',
      (trace) async {
        final bench = _LifecycleBench();
        await withClock(Clock.fixed(DateTime(2024, 6, 15, 12)), () async {
          try {
            for (final step in trace) {
              await bench.run(step);
              bench.checkInvariants(trace);
            }
          } finally {
            await bench.settle();
          }
          expect(bench.running, 0, reason: 'an operation never returned');
          bench.checkInvariants(trace);
        });
      },
      tags: 'glados',
    );
  });
}
