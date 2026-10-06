import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/backfill/inference_backfill.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_detector.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

const _subDomain = 'inferenceBackfill';

/// The detector over the app's journal and automation service.
final inferenceBackfillDetectorProvider = Provider<InferenceBackfillDetector>(
  (ref) => InferenceBackfillDetector(
    db: ref.watch(journalDbProvider),
    automation: ref.watch(profileAutomationServiceProvider),
  ),
  name: 'inferenceBackfillDetectorProvider',
);

/// Runs accepted backfill suggestions one at a time, in the order accepted.
///
/// The state is the set of candidate keys ([InferenceBackfillCandidate.key])
/// waiting or running, so a suggestion leaves the list the moment it is
/// accepted and cannot be accepted twice while its run is pending.
///
/// Sequential on purpose: "Confirm all" on a task with fifteen unprocessed
/// photos must not fire fifteen concurrent vision calls at one provider.
/// Each job decides at the moment it runs, not when it was accepted:
///
/// - an entry whose inference is running (an automatic trigger, the AI popup)
///   is skipped rather than run a second time;
/// - an entry whose inference has landed meanwhile is skipped;
/// - the model comes from resolving the task's profile now, so a profile
///   switched after the suggestion appeared is the one that runs, and a
///   category whose automatic inference was switched off runs nothing.
class InferenceBackfillQueue extends Notifier<Set<String>> {
  Future<void> _tail = Future<void>.value();

  @override
  Set<String> build() => const {};

  /// Completes once every job accepted so far has finished.
  Future<void> get idle => _tail;

  /// Queues [candidate] of [taskId]. Returns false when it is already queued.
  bool enqueue({
    required String taskId,
    required InferenceBackfillCandidate candidate,
  }) {
    if (state.contains(candidate.key)) return false;
    state = {...state, candidate.key};
    _tail = _tail.then((_) => _run(taskId, candidate));
    return true;
  }

  Future<void> _run(String taskId, InferenceBackfillCandidate candidate) async {
    final logger = ref.read(domainLoggerProvider);
    final entryId = DomainLogger.sanitizeId(candidate.entryId);
    void skip(String reason) => logger.log(
      LogDomain.ai,
      'Skipping ${candidate.kind.name} backfill for $entryId: $reason',
      subDomain: _subDomain,
    );

    try {
      if (_isRunning(candidate)) {
        skip('inference is already running');
        return;
      }
      final detector = ref.read(inferenceBackfillDetectorProvider);
      if (!await detector.isStillMissing(candidate)) {
        skip('it is no longer missing');
        return;
      }

      final automation = ref.read(profileAutomationServiceProvider);
      final result = await switch (candidate.kind) {
        InferenceBackfillKind.imageAnalysis => automation.tryAnalyzeImage(
          subjectId: taskId,
        ),
        InferenceBackfillKind.transcription => automation.tryTranscribe(
          subjectId: taskId,
        ),
        InferenceBackfillKind.audioSummary => automation.trySummarizeAudio(
          subjectId: taskId,
        ),
      };
      if (!result.handled) {
        skip('automation no longer handles it for this task');
        return;
      }

      await _dispatch(taskId, candidate, result);
    } catch (exception, stackTrace) {
      logger.error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: _subDomain,
      );
    } finally {
      state = {...state}..remove(candidate.key);
    }
  }

  bool _isRunning(InferenceBackfillCandidate candidate) =>
      candidate.kind.busyResponseTypes.any(
        (type) =>
            ref.read(
              inferenceStatusControllerProvider((
                id: candidate.entryId,
                aiResponseType: type,
              )),
            ) ==
            InferenceStatus.running,
      );

  Future<void> _dispatch(
    String taskId,
    InferenceBackfillCandidate candidate,
    AutomationResult result,
  ) {
    final runner = ref.read(skillInferenceRunnerProvider);
    return switch (candidate.kind) {
      InferenceBackfillKind.imageAnalysis => runner.runImageAnalysis(
        imageEntryId: candidate.entryId,
        automationResult: result,
        linkedTaskId: taskId,
      ),
      InferenceBackfillKind.transcription => runner.runTranscription(
        audioEntryId: candidate.entryId,
        automationResult: result,
        linkedTaskId: taskId,
      ),
      InferenceBackfillKind.audioSummary => runner.runAudioSummary(
        audioEntryId: candidate.entryId,
        automationResult: result,
        linkedTaskId: taskId,
      ),
    };
  }
}

final inferenceBackfillQueueProvider =
    NotifierProvider<InferenceBackfillQueue, Set<String>>(
      InferenceBackfillQueue.new,
      name: 'inferenceBackfillQueueProvider',
    );
