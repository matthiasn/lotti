import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_review_fence.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_transcript_writer.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_processor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repair.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_runtime.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
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
  return DayProcessingOutboxProcessor(
    repository: ref.watch(dayProcessingOutboxRepositoryProvider),
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
    drain: processor.drain,
    repair: () async {
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
