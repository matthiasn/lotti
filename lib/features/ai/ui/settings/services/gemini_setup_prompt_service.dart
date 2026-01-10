import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'gemini_setup_prompt_service.g.dart';

/// Key for storing whether the Gemini setup prompt was permanently dismissed
const _dismissedKey = 'gemini_setup_prompt_dismissed';

/// Service that manages the automatic Gemini setup prompt for new users.
///
/// This service:
/// 1. Checks if any Gemini providers exist
/// 2. Tracks whether the user has dismissed the prompt permanently
/// 3. Waits for What's New modal to be dismissed first
/// 4. Determines whether to show the setup prompt
@riverpod
class GeminiSetupPromptService extends _$GeminiSetupPromptService {
  @override
  Future<bool> build() async {
    return _shouldShowPrompt();
  }

  /// Checks whether the setup prompt should be shown.
  ///
  /// Returns true if:
  /// - No Gemini providers exist AND
  /// - The user hasn't permanently dismissed the prompt AND
  /// - What's New modal is not showing (no unseen releases)
  Future<bool> _shouldShowPrompt() async {
    // Check if What's New has unseen content - wait for it to be dismissed first
    final hasUnseenWhatsNew = await _hasUnseenWhatsNew();
    if (hasUnseenWhatsNew) {
      return false;
    }

    // Check if any Gemini providers exist
    final hasGeminiProvider = await _hasGeminiProvider();
    if (hasGeminiProvider) {
      return false;
    }

    // Check if prompt was permanently dismissed
    final wasDismissed = await _wasPromptDismissed();
    return !wasDismissed;
  }

  /// Checks if the What's New controller has unseen releases.
  Future<bool> _hasUnseenWhatsNew() async {
    try {
      final whatsNewState = await ref.read(whatsNewControllerProvider.future);
      return whatsNewState.hasUnseenRelease;
    } catch (_) {
      // If we can't determine What's New state, don't block Gemini prompt
      return false;
    }
  }

  /// Checks if any Gemini inference providers exist.
  Future<bool> _hasGeminiProvider() async {
    final repository = ref.read(aiConfigRepositoryProvider);
    final providers = await repository.getConfigsByType(
      AiConfigType.inferenceProvider,
    );

    return providers
        .whereType<AiConfigInferenceProvider>()
        .any((p) => p.inferenceProviderType == InferenceProviderType.gemini);
  }

  /// Checks if the prompt was previously dismissed.
  Future<bool> _wasPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  /// Marks the prompt as dismissed so it won't show again.
  Future<void> dismissPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    state = const AsyncValue.data(false);
  }

  /// Resets the dismissal state (useful for testing or user preference reset).
  Future<void> resetDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
    ref.invalidateSelf();
  }
}
