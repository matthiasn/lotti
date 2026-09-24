part of 'day_agent_job_executor_test.dart';

// Model conformance: the real outbox repository, processor and executor,
// driven through generated interleavings, must keep the invariants
// `specs/tla/DayProcessingJob.tla` model-checks. One refine request; two
// agent lanes claim it (a runtime and the one a provider rebuild left
// behind); a fake wake runtime keeps single flight, emits completions and
// commits artifacts; time passing expires the lease and the wait together,
// as three minutes does for both. A crash is a fresh process over the same
// database whose predecessor can no longer write.

enum _JobOp {
  claimA,
  claimB,
  threeMinutes,
  thirtySeconds,
  wakeStart,
  wakeCommit,
  wakeFail,
  wakeAbort,
  abortedSettles,
  retryNow,
  crash,
}

class _JobStep {
  const _JobStep(this.op, this.arg);

  factory _JobStep.decode(int code) => _JobStep(
    // Crashes are rarer than the rest.
    code % 23 == 22 ? _JobOp.crash : _JobOp.values[code % 10],
    code ~/ 23,
  );

  final _JobOp op;
  final int arg;

  @override
  String toString() => '${op.name}($arg)';
}

extension _AnyJobTrace on glados.Any {
  glados.Generator<List<_JobStep>> get jobTrace => glados.ListAnys(this)
      .listWithLengthInRange(1, 24, glados.IntAnys(this).intInRange(0, 46))
      .map((codes) => [for (final code in codes) _JobStep.decode(code)]);
}

enum _WakeState { queued, running, aborted, done, dead }

class _FakeWake {
  _FakeWake(this.runKey, this.token);

  final String runKey;
  final String token;
  _WakeState state = _WakeState.queued;

  bool get live =>
      state == _WakeState.queued ||
      state == _WakeState.running ||
      state == _WakeState.aborted;
}

class _ProcessDied implements Exception {}

/// One process lifetime: its repository, executor, two agent lanes and the
/// completion stream its wakes report on.
class _JobProcess {
  _JobProcess(_JobBench bench, DayProcessingDb db) {
    repository = DayProcessingOutboxRepository(
      db: db,
      now: () => alive ? bench.now : throw _ProcessDied(),
    );
    final executor = DayAgentJobExecutor(
      // A real read, as the day-agent lookup is: it gives the other lane's
      // attempt room to interleave with this one.
      resolveAgentId: (_) async {
        await repository.getById(bench.jobId);
        return 'day_agent:dayplan-2026-07-22';
      },
      enqueueWake: (request) {
        if (!alive) throw _ProcessDied();
        return bench.enqueue(request.job);
      },
      runCompletions: completions.stream,
      draftPlanUpdatedAt: (_, _) async =>
          (updatedAt: bench.requestedAt, runKey: null),
      pendingDiffCreatedSince: (_, _, _) async => bench.anyArtifact,
      pendingDiffForRuns: (_, _, runKeys) async => bench.artifactOf(runKeys),
      recordRunKey: (jobId, runKey) =>
          repository.recordRunKey(jobId: jobId, runKey: runKey),
      hasCompletedCaptureParse: (_) async => false,
      hasPendingDraftWork: (_) async => false,
      liveWakeRunKey: (job) => alive ? bench.liveRunKey(job) : null,
    );
    processor = DayProcessingOutboxProcessor(
      repository: repository,
      transcribe: (_) async => throw UnimplementedError(),
      attachTranscript: (_, _) async => false,
      agentJobExecutor: executor.execute,
    );
  }

  late final DayProcessingOutboxRepository repository;
  late final DayProcessingOutboxProcessor processor;
  final completions = StreamController<WakeRunCompletion>.broadcast();
  final lanes = <bool>[false, false];
  bool alive = true;

  void claim(int lane) {
    if (lanes[lane]) return;
    lanes[lane] = true;
    unawaited(
      processor
          .processNext(kinds: dayAgentJobKinds)
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() => lanes[lane] = false),
    );
  }
}

class _JobBench {
  _JobBench(this.db);

  final DayProcessingDb db;
  final start = DateTime.utc(2026, 7, 22, 8);
  late DateTime requestedAt;
  late String jobId;
  late FakeAsync async;
  late _JobProcess process;
  final wakes = <_FakeWake>[];
  final artifacts = <String>[];
  int wasted = 0;

  DateTime get now => start.add(async.elapsed);

  String? get anyArtifact => artifacts.isEmpty ? null : 'diff-${artifacts[0]}';

  String? artifactOf(Set<String> runKeys) {
    for (final runKey in artifacts) {
      if (runKeys.contains(runKey)) return 'diff-$runKey';
    }
    return null;
  }

  String tokenOf(DayProcessingJob job) =>
      dayAgentProcessingJobToken(job.id, requestedAt: job.requestedAt);

  String enqueue(DayProcessingJob job) {
    final wake = _FakeWake('run-${wakes.length + 1}', tokenOf(job));
    wakes.add(wake);
    return wake.runKey;
  }

  String? liveRunKey(DayProcessingJob job) {
    final token = tokenOf(job);
    for (final wake in wakes) {
      if (wake.token == token && wake.live) return wake.runKey;
    }
    return null;
  }

  void settle() {
    for (var i = 0; i < 12; i++) {
      async
        ..flushMicrotasks()
        ..elapse(Duration.zero);
    }
  }

  void boot() => process = _JobProcess(this, db);

  _FakeWake? _first(_WakeState state) {
    for (final wake in wakes) {
      if (wake.state == state) return wake;
    }
    return null;
  }

  void _emit(_FakeWake wake, WakeRunStatus status, [Object? error]) =>
      process.completions.add(
        WakeRunCompletion(runKey: wake.runKey, status: status, error: error),
      );

  void run(_JobStep step) {
    switch (step.op) {
      case _JobOp.claimA:
        process.claim(0);
      case _JobOp.claimB:
        process.claim(1);
      case _JobOp.threeMinutes:
        async.elapse(const Duration(minutes: 3, seconds: 1));
      case _JobOp.thirtySeconds:
        async.elapse(const Duration(seconds: 30));
      case _JobOp.wakeStart:
        final blocked = wakes.any(
          (wake) =>
              wake.state == _WakeState.running ||
              wake.state == _WakeState.aborted,
        );
        final wake = _first(_WakeState.queued);
        if (!blocked && wake != null) {
          wake.state = _WakeState.running;
          if (artifacts.isNotEmpty) wasted++;
        }
      case _JobOp.wakeCommit:
        final wake = _first(_WakeState.running);
        if (wake != null) {
          wake.state = _WakeState.done;
          artifacts.add(wake.runKey);
          _emit(wake, WakeRunStatus.completed);
        }
      case _JobOp.wakeFail:
        final wake = _first(_WakeState.running);
        if (wake != null) {
          wake.state = _WakeState.done;
          _emit(wake, WakeRunStatus.failed, StateError('provider failed'));
        }
      case _JobOp.wakeAbort:
        final wake = _first(_WakeState.running);
        if (wake != null) {
          wake.state = _WakeState.aborted;
          _emit(wake, WakeRunStatus.aborted, TimeoutException('timeout'));
        }
      case _JobOp.abortedSettles:
        final wake = _first(_WakeState.aborted);
        if (wake != null) {
          wake.state = _WakeState.done;
          if (step.arg.isEven) artifacts.add(wake.runKey);
        }
      case _JobOp.retryNow:
        // Odd args race the tap between two lanes' claims, unsettled, so the
        // attempts' pre-enqueue reads interleave.
        unawaited(process.repository.retryNow(jobId));
        if (step.arg.isOdd) {
          process.claim(0);
          unawaited(process.repository.retryNow(jobId));
          process.claim(1);
        }
      case _JobOp.crash:
        process.alive = false;
        for (final wake in wakes) {
          if (wake.live) wake.state = _WakeState.dead;
        }
        boot();
    }
    settle();
  }

  void checkInvariants(List<_JobStep> trace) {
    expect(
      wakes.where((wake) => wake.live).length,
      lessThanOrEqualTo(1),
      reason: 'AtMostOneLiveWake: $trace',
    );
    expect(wasted, 0, reason: 'NoInferenceAfterArtifact: $trace');
    expect(
      artifacts.length,
      lessThanOrEqualTo(1),
      reason: 'AtMostOneArtifact: $trace',
    );
  }
}

void _registerModelConformance() {
  group('model conformance with specs/tla/DayProcessingJob.tla', () {
    glados.Glados(
      glados.any.jobTrace,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated interleavings keep AtMostOneLiveWake, '
      'NoInferenceAfterArtifact and AtMostOneArtifact',
      (trace) {
        final bench = _JobBench(createTestDayProcessingDb());
        fakeAsync((async) {
          bench
            ..async = async
            ..boot();
          unawaited(
            bench.process.repository
                .enqueueRefinePlan(dayId: 'dayplan-2026-07-22')
                .then((job) {
                  bench
                    ..jobId = job.id
                    ..requestedAt = job.requestedAt;
                }),
          );
          bench.settle();
          for (final step in trace) {
            bench
              ..run(step)
              ..checkInvariants(trace);
          }
        });
      },
      tags: 'glados',
    );
  });
}
