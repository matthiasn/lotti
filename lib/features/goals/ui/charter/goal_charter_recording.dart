import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';

/// Records one recording and returns the id of the audio entry it became, or
/// null when the user cancelled — the shared recording sheet in production,
/// a fake in tests. It must save the recording with no parent and stay put.
typedef GoalCharterAudioRecorder =
    Future<String?> Function(BuildContext context, {String? categoryId});

Future<String?> _recordWithSheet(BuildContext context, {String? categoryId}) =>
    AudioRecordingModal.show(
      context,
      categoryId: categoryId,
      transcriptionHandledByCaller: true,
      openCreatedEntry: false,
    );

/// Records a spoken charter entry for the goal coached by [agentId]
/// (ADR 0140): the recording kept and playable, its transcript what the
/// agent reads.
///
/// Three steps, in an order that keeps the recording from ever being a
/// check-in:
///
/// 1. The shared recording sheet saves it with **no parent**. The recorder
///    links a recording FROM its parent, and a recording linked from the
///    goal is by definition a check-in. With no parent the sheet must not
///    open the new entry either (`openCreatedEntry: false`): the user stays
///    on the goal.
/// 2. `GoalRepository.attachCharterRecording` links it INTO the goal.
/// 3. Its transcription is started here (`transcriptionHandledByCaller`):
///    the recorder's own automation keys on a parent this recording does not
///    have. Recording for the charter is the consent — the goal's automatic
///    updates switch governs check-ins, not this.
///
/// A recording that cannot be linked is gone again and the reason shown; a
/// transcription that fails records its failure on the recording, where the
/// card offers Retry.
Future<void> recordGoalCharterEntry(
  BuildContext context, {
  required String agentId,
  GoalCharterAudioRecorder recordAudio = _recordWithSheet,
}) async {
  // The app-wide container, read before the first await: the card that
  // asked may be rebuilt or gone by the time the recording is saved.
  final container = ProviderScope.containerOf(context);
  final messages = context.messages;
  final repository = container.read(goalRepositoryProvider);
  if (repository == null) return;
  final goal = await repository.getGoalForAgent(agentId);
  if (!context.mounted) return;
  final audioId = await recordAudio(
    context,
    categoryId: goal?.meta.categoryId,
  );
  if (audioId == null) return;

  final logger = container.read(domainLoggerProvider);
  bool attached;
  try {
    attached = await repository.attachCharterRecording(
      agentId: agentId,
      audioId: audioId,
    );
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.general,
      error,
      stackTrace: stackTrace,
      subDomain: 'GoalCharterRecording',
      message: 'Failed to link a recording into a goal charter',
    );
    attached = false;
  }
  if (!attached) {
    if (context.mounted) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: messages.goalCharterSaveFailed,
      );
    }
    return;
  }

  try {
    await container.read(
      triggerSkillProvider((
        entityId: audioId,
        skillId: skillTranscribeContextId,
        linkedTaskId: null,
        referenceImages: null,
        overrideModelId: null,
        geminiThinkingMode: null,
      )).future,
    );
  } catch (error, stackTrace) {
    // The skill records its own failed state on the recording, which the
    // card reads; this line is for the support export.
    logger.error(
      LogDomain.general,
      error,
      stackTrace: stackTrace,
      subDomain: 'GoalCharterRecording',
      message: 'Failed to start transcribing a goal charter recording',
    );
  }
}
