import 'dart:async';

import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/services/audio_transcription_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_wake_progress.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/services/day_agent_job_executor.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_review_fence.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_transcript_writer.dart';
import 'package:lotti/features/daily_os_next/services/day_plan_ready_notifier.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_processor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repair.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_runtime.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_job_wiring.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';

final Provider<DayProcessingOutboxRepository>
dayProcessingOutboxRepositoryProvider = Provider((ref) {
  return getIt<DayProcessingOutboxRepository>();
});

/// Outlives processor rebuilds so old and new claim holders share one attempt.
final dayAgentJobExecutionsProvider = Provider<DayAgentJobExecutions>(
  (_) => DayAgentJobExecutions(),
);

final Provider<DayProcessingOutboxProcessor>
dayProcessingOutboxProcessorProvider = Provider((ref) {
  final transcriber = ref.watch(audioTranscriptionServiceProvider);
  final writer = ref.watch(dayAudioTranscriptWriterProvider);
  final executor = buildDayAgentJobExecutor(
    executions: ref.watch(dayAgentJobExecutionsProvider),
    dayAgentService: ref.watch(dayAgentServiceProvider),
    planService: ref.watch(dayAgentPlanServiceProvider),
    captureService: ref.watch(dayAgentCaptureServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    outbox: ref.watch(dayProcessingOutboxRepositoryProvider),
  );
  final planReadyNotifier = DayPlanReadyNotifier();
  final progressBus = ref.watch(dayAgentWakeProgressBusProvider);
  return DayProcessingOutboxProcessor(
    repository: ref.watch(dayProcessingOutboxRepositoryProvider),
    // ADR 0032 §5: event-driven completion surface for jobs that finish
    // while the app is backgrounded — "your plan is ready" as an OS banner.
    // Draft outcomes also reach the drafting screen, which otherwise cannot
    // tell a re-queued attempt from a slow one.
    onJobOutcome: (job) {
      unawaited(planReadyNotifier.onJobOutcome(job));
      final attempt = dayAgentJobAttemptOf(job);
      if (attempt != null) progressBus.publishAttempt(attempt);
    },
    // Claim the day the user is actually looking at first. `ref.read`, not
    // `watch`: navigating between days must not tear down and rebuild the
    // long-lived runtime, and the resolver runs per claim so the current
    // selection is picked up on the next job either way.
    priority: () {
      final selected = ref.read(dailyOsNextSelectedDateProvider);
      final today = clock.now();
      return DayProcessingClaimPriority(
        dayIds: [
          dayAgentIdForDate(selected),
          dayAgentIdForDate(today),
          dayAgentIdForDate(today.add(const Duration(days: 1))),
        ],
        agingCutoff: today.subtract(dayProcessingPriorityAging),
      );
    },
    // Resolve the planner profile's transcription slot per attempt so a
    // configuration change between retries takes effect immediately;
    // discovery remains the fallback when no profile slot exists.
    transcribe: (audioPath) async {
      DailyOsTranscriptionTarget? transcriptionTarget;
      try {
        transcriptionTarget = await ref.read(
          dailyOsTranscriptionTargetProvider.future,
        );
      } catch (_) {
        // Profile resolution is best-effort; discovery still applies.
      }
      return correctHeardTranscript(
        transcriber: transcriber,
        transcript: await transcriber.transcribe(
          audioPath,
          target: transcriptionTarget,
        ),
        heardBy: transcriptionTarget,
        correctionTarget: () =>
            ref.read(dailyOsTranscriptCorrectionTargetProvider.future),
      );
    },
    attachTranscript: (job, transcript) =>
        writer.attach(job: job, transcript: transcript),
    agentJobExecutor: executor.execute,
    isOnline: () async {
      final results = await Connectivity().checkConnectivity();
      return results.any(
        (result) =>
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.ethernet ||
            result == ConnectivityResult.vpn,
      );
    },
  );
});

final Provider<DayAudioTranscriptWriter> dayAudioTranscriptWriterProvider =
    Provider((ref) {
      return DayAudioTranscriptWriter(
        journalDb: getIt(),
        persistenceLogic: ref.read(persistenceLogicProvider),
      );
    });

/// Long-lived fence that terminalizes pending transcription jobs once their
/// recording carries user-reviewed text saved through the inline editor.
final Provider<DayAudioReviewFence> dayAudioReviewFenceProvider = Provider((
  ref,
) {
  final fence = DayAudioReviewFence(
    updates: getIt<UpdateNotifications>().updateStream,
    outbox: ref.watch(dayProcessingOutboxRepositoryProvider),
    journalDb: getIt(),
  )..start();
  ref.onDispose(fence.dispose);
  return fence;
});

/// Drains the outbox as two independent lanes: a slow agent wake (drafting
/// or refining can take tens of seconds) must never block the transcription
/// lane, and vice versa. Each lane drains serially within itself. Returns the
/// number of jobs processed across both lanes.
/// The drafting screen's view of a draft job's outcome, or null for every
/// other job kind and for a `local` deferral — the executor coming back while
/// its wake is still running, which is no attempt at all.
DayAgentJobAttempt? dayAgentJobAttemptOf(DayProcessingJob job) {
  if (job.kind != DayProcessingJobKind.draftPlan ||
      job.lastFailureClass == DayProcessingFailureClass.local) {
    return null;
  }
  return DayAgentJobAttempt(
    dayId: job.dayId,
    attempts: job.attempts,
    maxAttempts: DayAgentJobExecutor.defaultMaxAttempts,
    updatedAt: job.updatedAt,
    willRetry:
        job.status == DayProcessingJobStatus.queued ||
        job.status == DayProcessingJobStatus.waitingForNetwork,
    nextAttemptAt: job.nextAttemptAt,
    lastError: job.lastError,
  );
}

/// One drain pass over the transcription lane and the agent-job lane, run
/// side by side; returns how many jobs both processed.
///
/// The pass ends only when both lanes are idle, and the runtime looks for new
/// work only after it ends. So a lane that runs dry keeps listening to the
/// outbox while its sibling still works, and drains again when work arrives:
/// otherwise a draft requested during a minutes-long transcription retry sat
/// queued behind it, with nothing running in its own lane.
Future<int> drainDayProcessingLanes(
  DayProcessingOutboxProcessor processor,
) async {
  const lanes = [
    {DayProcessingJobKind.transcribeAudio},
    dayAgentJobKinds,
  ];
  var busy = lanes.length;
  var processed = 0;
  final laneIdle = StreamController<void>.broadcast(sync: true);

  Future<void> runLane(Set<DayProcessingJobKind> kinds) async {
    while (true) {
      // Awaited into a local first: `processed += await …` reads the total
      // before the await and would drop the sibling lane's concurrent count.
      final drained = await processor.drain(kinds: kinds);
      processed += drained;
      busy -= 1;
      laneIdle.add(null);
      if (busy == 0) return;
      final woken = await _outboxChangeOrAllIdle(
        processor.repository.changes,
        laneIdle.stream,
        allIdle: () => busy == 0,
      );
      if (!woken) return;
      busy += 1;
    }
  }

  await Future.wait([for (final kinds in lanes) runLane(kinds)]);
  await laneIdle.close();
  return processed;
}

/// Completes `true` on the next outbox change, or `false` once [laneIdle]
/// reports that every lane is idle — whichever comes first.
///
/// Both subscriptions are made before the first `await`, i.e. synchronously
/// with the caller's own idle report, so the sibling's final report cannot
/// slip between the two.
Future<bool> _outboxChangeOrAllIdle(
  Stream<void> changes,
  Stream<void> laneIdle, {
  required bool Function() allIdle,
}) async {
  final completer = Completer<bool>();
  final changeSubscription = changes.listen((_) {
    if (!completer.isCompleted) completer.complete(true);
  });
  final idleSubscription = laneIdle.listen((_) {
    if (allIdle() && !completer.isCompleted) completer.complete(false);
  });
  try {
    return await completer.future;
  } finally {
    await changeSubscription.cancel();
    await idleSubscription.cancel();
  }
}

final Provider<DayProcessingRuntime> dayProcessingRuntimeProvider = Provider((
  ref,
) {
  final processor = ref.watch(dayProcessingOutboxProcessorProvider);
  final outbox = ref.watch(dayProcessingOutboxRepositoryProvider);
  ref.watch(dayAudioReviewFenceProvider);
  final vectorClockService = ref.read(vectorClockServiceProvider);
  final runtime = DayProcessingRuntime(
    repository: outbox,
    drain: () => drainDayProcessingLanes(processor),
    repair: () async {
      // Retention (ADR 0044 decision 5) rides the once-per-start repair pass
      // rather than owning a scheduler: terminal ledger rows past the window
      // go, pending work never does regardless of age. A partial prune is
      // harmless — the remainder is collected on the next start.
      await outbox.pruneTerminalBefore(
        DateTime.now().subtract(dayProcessingLedgerRetention),
      );
      final currentHostId = await vectorClockService.getHost();
      return DayProcessingOutboxRepair(
        repository: outbox,
        journalDb: getIt(),
        assetRoot: getIt(),
        currentHostId: currentHostId,
      ).repair();
    },
  )..start();
  ref.onDispose(runtime.dispose);
  return runtime;
});
