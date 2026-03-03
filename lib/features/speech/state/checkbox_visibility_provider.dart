import 'package:lotti/features/categories/state/category_details_controller.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkbox_visibility_provider.g.dart';

/// Provider that computes which automatic prompt checkboxes should be visible
/// in the audio recording modal based on:
/// - Category configuration (automatic prompts)
///
/// This extracts the business logic from the widget, making it testable
/// independently without widget build cycles or timing issues.
@riverpod
AutomaticPromptVisibility checkboxVisibility(
  Ref ref, {
  required String? categoryId,
}) {
  // No category means no automatic prompts configured
  if (categoryId == null) {
    return const AutomaticPromptVisibility(
      speech: false,
    );
  }

  // Get the category to check automatic prompts configuration
  final categoryDetailsState = ref.watch(
    categoryDetailsControllerProvider(categoryId),
  );
  final category = categoryDetailsState.category;

  // Compute visibility based on configuration
  return deriveAutomaticPromptVisibility(
    automaticPrompts: category?.automaticPrompts,
  );
}
