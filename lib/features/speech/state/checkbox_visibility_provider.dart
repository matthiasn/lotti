import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkbox_visibility_provider.g.dart';

/// Checks whether a task has profile-driven transcription available.
///
/// Re-evaluates when profiles change (via [inferenceProfileControllerProvider])
/// so that edits to automation toggles are immediately reflected in the UI.
/// Uses the pure capability check rather than the execution path to avoid
/// side effects during render-time reads.
@riverpod
Future<bool> hasProfileTranscription(Ref ref, String taskId) async {
  // Watch the profiles stream so this provider invalidates when any
  // profile is edited. Without this, the result would be stale after
  // a profile automation toggle change.
  ref.watch(inferenceProfileControllerProvider);

  final service = ref.watch(profileAutomationServiceProvider);
  return service.hasAutomatedSkillType(
    taskId: taskId,
    skillType: SkillType.transcription,
  );
}

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on profile-driven transcription
/// availability (when linked to a task).
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.
@riverpod
AutomaticPromptVisibility checkboxVisibility(
  Ref ref, {
  required String? categoryId,
  String? linkedId,
}) {
  // No linked task means no profile-driven transcription.
  if (linkedId == null) {
    return const AutomaticPromptVisibility(
      speech: false,
    );
  }

  // Profile-aware path: check if the linked task has profile-driven
  // transcription available.
  final asyncValue = ref.watch(
    hasProfileTranscriptionProvider(linkedId),
  );
  final hasProfileTranscriptionValue = asyncValue.when(
    data: (value) => value,
    loading: () => false,
    error: (_, _) => false,
  );

  // Compute visibility based on configuration.
  return deriveAutomaticPromptVisibility(
    hasProfileTranscription: hasProfileTranscriptionValue,
  );
}
