import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/state/category_details_controller.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkbox_visibility_provider.g.dart';

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
/// - Whether a Task is linked (not just any entity)
/// - User's speech recognition preference
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.
@riverpod
AutomaticPromptVisibility checkboxVisibility(
  Ref ref, {
  required String? categoryId,
  required String? linkedId,
  required bool? userSpeechPreference,
}) {
  // No category means no automatic prompts configured
  if (categoryId == null) {
    return const AutomaticPromptVisibility(
      speech: false,
      checklist: false,
      summary: false,
    );
  }

  // Get the category to check automatic prompts configuration
  final categoryDetailsState = ref.watch(
    categoryDetailsControllerProvider(categoryId),
  );
  final category = categoryDetailsState.category;

  // Check if the linked entry is actually a Task
  // Optimistically show checkboxes while loading if linkedId exists
  final linkedEntryAsync = linkedId != null
      ? ref.watch(entryControllerProvider(id: linkedId))
      : null;

  final isLinkedToTask = linkedEntryAsync?.maybeWhen(
        data: (entryState) {
          // Only return true if entry exists AND is a Task
          final entry = entryState?.entry;
          return entry != null && entry is Task;
        },
        loading: () => true, // Optimistic: assume Task while loading
        orElse: () => false, // Hide on error or if not found
      ) ??
      false;

  // Compute visibility based on configuration and context
  return deriveAutomaticPromptVisibility(
    automaticPrompts: category?.automaticPrompts,
    hasLinkedTask: isLinkedToTask,
    userSpeechPreference: userSpeechPreference,
  );
}
