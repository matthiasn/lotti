import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/categories/state/category_details_controller.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkbox_visibility_provider.g.dart';

/// Checks whether a task has profile-driven transcription available.
///
/// Uses `keepAlive` to cache the result across modal open/close cycles,
/// avoiding repeated full profile-chain resolution for the same task.
/// Uses the pure capability check rather than the execution path to avoid
/// side effects during render-time reads.
@Riverpod(keepAlive: true)
Future<bool> hasProfileTranscription(Ref ref, String taskId) async {
  final service = ref.watch(profileAutomationServiceProvider);
  return service.hasAutomatedSkillType(
    taskId: taskId,
    skillType: SkillType.transcription,
  );
}

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Profile-driven transcription availability (when linked to a task)
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.
@riverpod
AutomaticPromptVisibility checkboxVisibility(
  Ref ref, {
  required String? categoryId,
  String? linkedId,
}) {
  // No category means no automatic prompts configured (but profile may still
  // provide transcription).
  if (categoryId == null && linkedId == null) {
    return const AutomaticPromptVisibility(
      speech: false,
    );
  }

  // Get the category to check automatic prompts configuration.
  final category = categoryId != null
      ? ref.watch(categoryDetailsControllerProvider(categoryId)).category
      : null;

  // Profile-aware path: check if the linked task has profile-driven
  // transcription available.
  var hasProfileTranscriptionValue = false;
  if (linkedId != null) {
    final asyncValue = ref.watch(
      hasProfileTranscriptionProvider(linkedId),
    );
    hasProfileTranscriptionValue = asyncValue.value ?? false;
  }

  // Compute visibility based on configuration.
  return deriveAutomaticPromptVisibility(
    automaticPrompts: category?.automaticPrompts,
    hasProfileTranscription: hasProfileTranscriptionValue,
  );
}
