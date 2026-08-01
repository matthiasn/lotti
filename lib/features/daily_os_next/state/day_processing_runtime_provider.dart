import 'dart:async';
import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
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
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/vector_clock_service.dart';

final Provider<DayProcessingOutboxRepository>
dayProcessingOutboxRepositoryProvider = Provider((ref) {
  return getIt<DayProcessingOutboxRepository>();
});

final Provider<DayProcessingOutboxProcessor>
dayProcessingOutboxProcessorProvider = Provider((ref) {
  final transcriber = ref.watch(audioTranscriptionServiceProvider);
  final writer = ref.watch(dayAudioTranscriptWriterProvider);
  final executor = buildDayAgentJobExecutor(
    dayAgentService: ref.watch(dayAgentServiceProvider),
    planService: ref.watch(dayAgentPlanServiceProvider),
    captureService: ref.watch(dayAgentCaptureServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    outbox: ref.watch(dayProcessingOutboxRepositoryProvider),
  );
  final planReadyNotifier = DayPlanReadyNotifier();
  return DayProcessingOutboxProcessor(
    repository: ref.watch(dayProcessingOutboxRepositoryProvider),
    // ADR 0032 §5: event-driven completion surface for jobs that finish
    // while the app is backgrounded — "your plan is ready" as an OS banner.
    onJobOutcome: (job) => unawaited(planReadyNotifier.onJobOutcome(job)),
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
      return transcriber.transcribe(audioPath, target: transcriptionTarget);
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
        persistenceLogic: getIt<PersistenceLogic>(),
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

final Provider<DayProcessingRuntime> dayProcessingRuntimeProvider = Provider((
  ref,
) {
  final processor = ref.watch(dayProcessingOutboxProcessorProvider);
  final outbox = ref.watch(dayProcessingOutboxRepositoryProvider);
  ref.watch(dayAudioReviewFenceProvider);
  final runtime = DayProcessingRuntime(
    repository: outbox,
    // Two independent lanes: a slow agent wake (drafting/refining can take
    // tens of seconds) must never block the transcription lane, and vice
    // versa. Each lane drains serially within itself.
    drain: () async {
      final counts = await Future.wait([
        processor.drain(kinds: const {DayProcessingJobKind.transcribeAudio}),
        processor.drain(kinds: dayAgentJobKinds),
      ]);
      return counts[0] + counts[1];
    },
    repair: () async {
      // Retention (ADR 0044 decision 5) rides the once-per-start repair pass
      // rather than owning a scheduler: terminal ledger rows past the window
      // go, pending work never does regardless of age. A partial prune is
      // harmless — the remainder is collected on the next start.
      await outbox.pruneTerminalBefore(
        DateTime.now().subtract(dayProcessingLedgerRetention),
      );
      final currentHostId = await getIt<VectorClockService>().getHost();
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
