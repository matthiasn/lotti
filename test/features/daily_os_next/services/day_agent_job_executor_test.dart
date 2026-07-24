import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/daily_os_next/services/day_agent_job_executor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';

void main() {
  final requestedAt = DateTime.utc(2026, 7, 22, 8);
  const dayId = 'dayplan-2026-07-22';
  const agentId = 'day_agent:dayplan-2026-07-22';

  DayProcessingJob draftJob({DateTime? requested}) => DayProcessingJob(
    id: 'draft_$dayId',
    status: DayProcessingJobStatus.queued,
    dayId: dayId,
    payload: const DraftPlanPayload(),
    createdAt: requested ?? requestedAt,
    updatedAt: requested ?? requestedAt,
    requestedAt: requested ?? requestedAt,
    nextAttemptAt: requested ?? requestedAt,
    attempts: 0,
    generation: 0,
  );

  DayProcessingJob parseJob() => DayProcessingJob(
    id: 'parse_cap-1',
    status: DayProcessingJobStatus.queued,
    dayId: dayId,
    payload: const ParseCapturePayload(captureId: 'cap-1'),
    createdAt: requestedAt,
    updatedAt: requestedAt,
    requestedAt: requestedAt,
    nextAttemptAt: requestedAt,
    attempts: 0,
    generation: 0,
  );

  DayProcessingJob transcribeJob() => DayProcessingJob(
    id: 'transcribe_rec-1',
    status: DayProcessingJobStatus.queued,
    dayId: dayId,
    payload: const TranscribeAudioPayload(
      activityEntryId: 'entry-1',
      recordingSessionId: 'rec-1',
      audioId: 'audio-1',
      audioPath: '/tmp/rec-1.m4a',
    ),
    createdAt: requestedAt,
    updatedAt: requestedAt,
    requestedAt: requestedAt,
    nextAttemptAt: requestedAt,
    attempts: 0,
    generation: 0,
  );

  DayProcessingJob refineJob() => DayProcessingJob(
    id: 'refine_${dayId}_abc',
    status: DayProcessingJobStatus.queued,
    dayId: dayId,
    payload: const RefinePlanPayload(transcriptCaptureId: 'cap-refine'),
    createdAt: requestedAt,
    updatedAt: requestedAt,
    requestedAt: requestedAt,
    nextAttemptAt: requestedAt,
    attempts: 0,
    generation: 0,
  );

  DayAgentJobExecutor buildExecutor({
    Future<String> Function(String dayId)? resolveAgentId,
    String Function(DayAgentJobWakeRequest request)? enqueueWake,
    Stream<WakeRunCompletion>? runCompletions,
    Future<DateTime?> Function(String agentId, String dayId)?
    draftPlanUpdatedAt,
    Future<String?> Function(String agentId, String dayId, DateTime since)?
    pendingDiffCreatedSince,
    Future<String?> Function(String agentId, String dayId, Set<String> runKeys)?
    pendingDiffForRuns,
    Future<void> Function(String jobId, String runKey)? recordRunKey,
    Future<bool> Function(String captureId)? hasParsedItems,
    Future<bool> Function(String dayId)? hasPendingDraftWork,
    Duration wakeTimeout = const Duration(seconds: 1),
    int maxAttempts = 5,
  }) => DayAgentJobExecutor(
    resolveAgentId: resolveAgentId ?? (_) async => agentId,
    enqueueWake: enqueueWake ?? (request) => 'run-key-1',
    runCompletions: runCompletions ?? const Stream.empty(),
    draftPlanUpdatedAt: draftPlanUpdatedAt ?? (_, _) async => null,
    pendingDiffCreatedSince: pendingDiffCreatedSince ?? (_, _, _) async => null,
    pendingDiffForRuns: pendingDiffForRuns ?? (_, _, _) async => null,
    recordRunKey: recordRunKey ?? (_, _) async {},
    hasParsedItems: hasParsedItems ?? (_) async => false,
    hasPendingDraftWork: hasPendingDraftWork ?? (_) async => false,
    wakeTimeout: wakeTimeout,
    maxAttempts: maxAttempts,
  );

  group('artifact pre-check (idempotency)', () {
    test(
      'parseCapture short-circuits when parsed items already exist',
      () async {
        var wakeEnqueued = false;
        final executor = buildExecutor(
          hasParsedItems: (captureId) async => captureId == 'cap-1',
          enqueueWake: (request) {
            wakeEnqueued = true;
            return 'run-key';
          },
        );

        final outcome = await executor.execute(parseJob());

        expect(outcome, isA<DayAgentJobSucceeded>());
        expect(wakeEnqueued, isFalse);
      },
    );

    test(
      'draftPlan short-circuits when the plan was already updated at/after '
      'requestedAt',
      () async {
        var wakeEnqueued = false;
        final executor = buildExecutor(
          draftPlanUpdatedAt: (agentId, dayId) async =>
              requestedAt.add(const Duration(seconds: 1)),
          enqueueWake: (request) {
            wakeEnqueued = true;
            return 'run-key';
          },
        );

        final outcome = await executor.execute(draftJob());

        expect(outcome, isA<DayAgentJobSucceeded>());
        expect(wakeEnqueued, isFalse);
      },
    );

    test(
      'draftPlan does NOT short-circuit on a stale plan (updated before '
      'requestedAt)',
      () async {
        var wakeEnqueued = false;
        final completions = StreamController<WakeRunCompletion>.broadcast();
        addTearDown(completions.close);
        final executor = buildExecutor(
          draftPlanUpdatedAt: (agentId, dayId) async =>
              requestedAt.subtract(const Duration(minutes: 1)),
          enqueueWake: (request) {
            wakeEnqueued = true;
            return 'run-key';
          },
          runCompletions: completions.stream,
        );

        unawaited(
          Future<void>.delayed(Duration.zero, () {
            completions.add(
              const WakeRunCompletion(
                runKey: 'run-key',
                agentId: agentId,
                status: WakeRunStatus.completed,
              ),
            );
          }),
        );
        await executor.execute(draftJob());

        expect(wakeEnqueued, isTrue);
      },
    );

    test(
      'refinePlan short-circuits when a pending diff matches one of the '
      "job's recorded wake run keys",
      () async {
        Set<String>? consultedRunKeys;
        final executor = buildExecutor(
          draftPlanUpdatedAt: (agentId, dayId) async => requestedAt,
          pendingDiffForRuns: (agentId, dayId, runKeys) async {
            consultedRunKeys = runKeys;
            return runKeys.contains('recorded-key') ? 'diff-1' : null;
          },
        );
        final job = refineJob().copyWith(runKeys: const ['recorded-key']);

        final outcome = await executor.execute(job);

        expect(outcome, isA<DayAgentJobSucceeded>());
        expect((outcome as DayAgentJobSucceeded).resultEntityId, 'diff-1');
        expect(consultedRunKeys, {'recorded-key'});
      },
    );

    test(
      "a never-attempted refine job ignores a sibling refine's diff in its "
      'time window and runs its own wake (provenance regression)',
      () async {
        var wakeEnqueued = false;
        var timeWindowConsulted = false;
        final completions = StreamController<WakeRunCompletion>.broadcast();
        addTearDown(completions.close);
        final executor = buildExecutor(
          draftPlanUpdatedAt: (agentId, dayId) async => requestedAt,
          // A sibling refine's diff sits in the window — the old time-based
          // check would have returned it and dropped this job's transcript.
          pendingDiffCreatedSince: (agentId, dayId, since) async {
            timeWindowConsulted = true;
            return 'diff-of-sibling';
          },
          pendingDiffForRuns: (agentId, dayId, runKeys) async => null,
          enqueueWake: (request) {
            wakeEnqueued = true;
            return 'run-key';
          },
          runCompletions: completions.stream,
          wakeTimeout: const Duration(milliseconds: 10),
        );

        final outcome = await executor.execute(refineJob());

        expect(timeWindowConsulted, isFalse);
        expect(wakeEnqueued, isTrue);
        // No completion arrives in this test; the point is the wake ran
        // instead of the sibling's diff satisfying the job.
        expect(outcome, isA<DayAgentJobFailed>());
      },
    );

    test(
      'a legacy attempted refine job (no recorded run keys) still falls '
      'back to the time-window check',
      () async {
        final executor = buildExecutor(
          draftPlanUpdatedAt: (agentId, dayId) async => requestedAt,
          pendingDiffCreatedSince: (agentId, dayId, since) async => 'diff-1',
        );
        final job = refineJob().copyWith(attempts: 1);

        final outcome = await executor.execute(job);

        expect(outcome, isA<DayAgentJobSucceeded>());
        expect((outcome as DayAgentJobSucceeded).resultEntityId, 'diff-1');
      },
    );

    test(
      'refinePlan records the enqueued wake run key and matches the diff '
      'it produced on completion',
      () async {
        final recorded = <(String, String)>[];
        final completions = StreamController<WakeRunCompletion>.broadcast();
        addTearDown(completions.close);
        final executor = buildExecutor(
          draftPlanUpdatedAt: (agentId, dayId) async => requestedAt,
          recordRunKey: (jobId, runKey) async => recorded.add((jobId, runKey)),
          pendingDiffForRuns: (agentId, dayId, runKeys) async =>
              runKeys.contains('run-key-1') ? 'diff-from-this-wake' : null,
          runCompletions: completions.stream,
        );
        unawaited(
          Future<void>.delayed(Duration.zero, () {
            completions.add(
              const WakeRunCompletion(
                runKey: 'run-key-1',
                agentId: agentId,
                status: WakeRunStatus.completed,
              ),
            );
          }),
        );

        final outcome = await executor.execute(refineJob());

        expect(recorded, [('refine_${dayId}_abc', 'run-key-1')]);
        expect(outcome, isA<DayAgentJobSucceeded>());
        expect(
          (outcome as DayAgentJobSucceeded).resultEntityId,
          'diff-from-this-wake',
        );
      },
    );
  });

  test(
    'refinePlan defers while a pending draft job can still produce a plan',
    () async {
      final executor = buildExecutor(
        draftPlanUpdatedAt: (agentId, dayId) async => null,
        hasPendingDraftWork: (jobDayId) async => jobDayId == dayId,
      );

      final outcome = await executor.execute(refineJob());

      expect(outcome, isA<DayAgentJobFailed>());
      final failed = outcome as DayAgentJobFailed;
      expect(failed.failureClass, DayProcessingFailureClass.local);
      expect(failed.retryAfter, isNotNull);
    },
  );

  test('refinePlan fails deterministically when no plan exists and no draft '
      'job is pending — a local defer would loop forever', () async {
    final executor = buildExecutor(
      draftPlanUpdatedAt: (agentId, dayId) async => null,
    );

    final outcome = await executor.execute(refineJob());

    expect(outcome, isA<DayAgentJobFailed>());
    final failed = outcome as DayAgentJobFailed;
    expect(failed.failureClass, DayProcessingFailureClass.deterministic);
    expect(failed.retryAfter, isNull);
  });

  test('resolveAgentId throwing maps to setupRequired', () async {
    final executor = buildExecutor(
      resolveAgentId: (_) async => throw StateError('no template'),
    );

    final outcome = await executor.execute(parseJob());

    expect(outcome, isA<DayAgentJobFailed>());
    expect(
      (outcome as DayAgentJobFailed).failureClass,
      DayProcessingFailureClass.setupRequired,
    );
  });

  test(
    'resolveAgentId throwing a transient (non-setup) error is routed '
    'through the same classifier as a wake failure, not a blanket '
    'setupRequired',
    () async {
      final executor = buildExecutor(
        resolveAgentId: (_) async =>
            throw StateError('day agent lookup timed out'),
      );

      final outcome = await executor.execute(parseJob());

      expect(outcome, isA<DayAgentJobFailed>());
      expect(
        (outcome as DayAgentJobFailed).failureClass,
        isNot(DayProcessingFailureClass.setupRequired),
      );
    },
  );

  test(
    'enqueueWake receives the resolved agent id and the job',
    () async {
      DayAgentJobWakeRequest? captured;
      final completions = StreamController<WakeRunCompletion>.broadcast();
      addTearDown(completions.close);
      final executor = buildExecutor(
        resolveAgentId: (dayId) async => 'resolved-$dayId',
        enqueueWake: (request) {
          captured = request;
          return 'run-key';
        },
        runCompletions: completions.stream,
        hasParsedItems: (_) async => false,
      );
      unawaited(
        Future<void>.delayed(Duration.zero, () {
          completions.add(
            const WakeRunCompletion(
              runKey: 'run-key',
              agentId: 'resolved-$dayId',
              status: WakeRunStatus.completed,
            ),
          );
        }),
      );

      await executor.execute(parseJob());

      expect(captured!.agentId, 'resolved-$dayId');
      expect(captured!.dayId, dayId);
      expect(captured!.job.id, 'parse_cap-1');
    },
  );

  test(
    'a wake that times out is classified as a timeout failure',
    () async {
      // A never-closed, never-emitting stream — unlike Stream.empty(), this
      // exercises the timeout path rather than firstWhere's immediate
      // "no element" completion.
      final neverCompletes = StreamController<WakeRunCompletion>.broadcast();
      addTearDown(neverCompletes.close);
      final executor = buildExecutor(
        runCompletions: neverCompletes.stream,
        wakeTimeout: const Duration(milliseconds: 10),
      );

      final outcome = await executor.execute(parseJob());

      expect(outcome, isA<DayAgentJobFailed>());
      expect(
        (outcome as DayAgentJobFailed).failureClass,
        DayProcessingFailureClass.timeout,
      );
    },
  );

  test(
    'a completed wake without the expected artifact counts the spent '
    'inference as an attempt (providerBusy, not local)',
    () async {
      final completions = StreamController<WakeRunCompletion>.broadcast();
      addTearDown(completions.close);
      final executor = buildExecutor(
        runCompletions: completions.stream,
        hasParsedItems: (_) async => false,
      );
      unawaited(
        Future<void>.delayed(Duration.zero, () {
          completions.add(
            const WakeRunCompletion(
              runKey: 'run-key-1',
              agentId: agentId,
              status: WakeRunStatus.completed,
            ),
          );
        }),
      );

      final outcome = await executor.execute(parseJob());

      expect(outcome, isA<DayAgentJobFailed>());
      expect(
        (outcome as DayAgentJobFailed).failureClass,
        DayProcessingFailureClass.providerBusy,
      );
    },
  );

  test(
    'a completed wake without the expected artifact is downgraded to '
    'deterministic at maxAttempts instead of re-inferring forever',
    () async {
      final completions = StreamController<WakeRunCompletion>.broadcast();
      addTearDown(completions.close);
      final executor = buildExecutor(
        runCompletions: completions.stream,
        hasParsedItems: (_) async => false,
        maxAttempts: 3,
      );
      unawaited(
        Future<void>.delayed(Duration.zero, () {
          completions.add(
            const WakeRunCompletion(
              runKey: 'run-key-1',
              agentId: agentId,
              status: WakeRunStatus.completed,
            ),
          );
        }),
      );
      final job = parseJob().copyWith(attempts: 2);

      final outcome = await executor.execute(job);

      expect(outcome, isA<DayAgentJobFailed>());
      final failed = outcome as DayAgentJobFailed;
      expect(failed.failureClass, DayProcessingFailureClass.deterministic);
      expect(failed.error, contains('Gave up after 3 attempts'));
    },
  );

  test(
    'a transcribeAudio-shaped job (never actually claimed by this executor '
    'in production) never short-circuits the artifact pre-check',
    () async {
      final completions = StreamController<WakeRunCompletion>.broadcast();
      addTearDown(completions.close);
      final executor = buildExecutor(runCompletions: completions.stream);
      unawaited(
        Future<void>.delayed(Duration.zero, () {
          completions.add(
            const WakeRunCompletion(
              runKey: 'run-key-1',
              agentId: agentId,
              status: WakeRunStatus.completed,
            ),
          );
        }),
      );

      final outcome = await executor.execute(transcribeJob());

      expect(outcome, isA<DayAgentJobFailed>());
      expect(
        (outcome as DayAgentJobFailed).failureClass,
        DayProcessingFailureClass.providerBusy,
      );
    },
  );

  group('failure classification', () {
    test(
      'MissingDraftDayPlanException-shaped errors classify as providerBusy',
      () async {
        final completions = StreamController<WakeRunCompletion>.broadcast();
        addTearDown(completions.close);
        final executor = buildExecutor(runCompletions: completions.stream);
        unawaited(
          Future<void>.delayed(Duration.zero, () {
            completions.add(
              WakeRunCompletion(
                runKey: 'run-key-1',
                agentId: agentId,
                status: WakeRunStatus.failed,
                error: MissingDraftDayPlanException(),
              ),
            );
          }),
        );

        final outcome = await executor.execute(draftJob());

        expect(outcome, isA<DayAgentJobFailed>());
        expect(
          (outcome as DayAgentJobFailed).failureClass,
          DayProcessingFailureClass.providerBusy,
        );
      },
    );

    test(
      'a retryable failure that hits maxAttempts is downgraded to '
      'deterministic instead of retrying forever',
      () async {
        final completions = StreamController<WakeRunCompletion>.broadcast();
        addTearDown(completions.close);
        final executor = buildExecutor(
          runCompletions: completions.stream,
          maxAttempts: 3,
        );
        unawaited(
          Future<void>.delayed(Duration.zero, () {
            completions.add(
              WakeRunCompletion(
                runKey: 'run-key-1',
                agentId: agentId,
                status: WakeRunStatus.failed,
                error: TimeoutException('slow'),
              ),
            );
          }),
        );
        final job = draftJob().copyWith(attempts: 2);

        final outcome = await executor.execute(job);

        expect(outcome, isA<DayAgentJobFailed>());
        expect(
          (outcome as DayAgentJobFailed).failureClass,
          DayProcessingFailureClass.deterministic,
        );
      },
    );
  });

  group('classifyDayAgentJobFailure', () {
    test('classifies representative error shapes', () {
      expect(
        classifyDayAgentJobFailure(const SocketException('offline')),
        DayProcessingFailureClass.network,
      );
      expect(
        classifyDayAgentJobFailure(TimeoutException('slow')),
        DayProcessingFailureClass.timeout,
      );
      expect(
        classifyDayAgentJobFailure(StateError('ambiguous day')),
        DayProcessingFailureClass.deterministic,
      );
      expect(
        classifyDayAgentJobFailure(StateError('template not configured')),
        DayProcessingFailureClass.setupRequired,
      );
      expect(
        classifyDayAgentJobFailure(null),
        DayProcessingFailureClass.local,
      );
    });
  });
}

class MissingDraftDayPlanException implements Exception {
  @override
  String toString() => 'MissingDraftDayPlanException: no tool call';
}
