import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_setup_prompt_service.g.dart';

/// Key for storing whether the AI setup prompt was permanently dismissed
const _dismissedKey = 'ai_setup_prompt_dismissed';

/// Enum representing the available AI providers for FTUE setup
enum AiProviderOption {
  gemini,
  openAi,
  mistral,
}

/// Extension to get display properties for AI provider options
extension AiProviderOptionExtension on AiProviderOption {
  String get displayName => switch (this) {
        AiProviderOption.gemini => 'Google Gemini',
        AiProviderOption.openAi => 'OpenAI',
        AiProviderOption.mistral => 'Mistral AI',
      };

  String get description => switch (this) {
        AiProviderOption.gemini =>
          'Free tier available. Best for multimodal tasks including audio transcription.',
        AiProviderOption.openAi =>
          'Powerful reasoning models. Requires API key with credits.',
        AiProviderOption.mistral =>
          'European AI with strong reasoning (Magistral) and audio (Voxtral) models.',
      };

  InferenceProviderType get inferenceProviderType => switch (this) {
        AiProviderOption.gemini => InferenceProviderType.gemini,
        AiProviderOption.openAi => InferenceProviderType.openAi,
        AiProviderOption.mistral => InferenceProviderType.mistral,
      };
}

/// Service that manages the automatic AI setup prompt for new users.
///
/// This service:
/// 1. Checks if any supported AI providers (Gemini or OpenAI) exist
/// 2. Tracks whether the user has dismissed the prompt permanently
/// 3. Waits for What's New modal to be dismissed first
/// 4. Determines whether to show the setup prompt
@riverpod
class AiSetupPromptService extends _$AiSetupPromptService {
  @override
  Future<bool> build() async {
    return _shouldShowPrompt();
  }

  /// Checks whether the setup prompt should be shown.
  ///
  /// Returns true if:
  /// - No Gemini OR OpenAI providers exist AND
  /// - The user hasn't permanently dismissed the prompt AND
  /// - What's New modal is not showing (no unseen releases)
  Future<bool> _shouldShowPrompt() async {
    // Check if What's New has unseen content - wait for it to be dismissed first
    final hasUnseenWhatsNew = await _hasUnseenWhatsNew();
    if (hasUnseenWhatsNew) {
      return false;
    }

    // Check if any supported AI providers exist
    final hasAiProvider = await _hasAnyAiProvider();
    if (hasAiProvider) {
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
      // If we can't determine What's New state, don't block AI prompt
      return false;
    }
  }

  /// Checks if any Gemini, OpenAI, or Mistral inference providers exist.
  Future<bool> _hasAnyAiProvider() async {
    final repository = ref.read(aiConfigRepositoryProvider);
    final providers = await repository.getConfigsByType(
      AiConfigType.inferenceProvider,
    );

    return providers.whereType<AiConfigInferenceProvider>().any(
          (p) =>
              p.inferenceProviderType == InferenceProviderType.gemini ||
              p.inferenceProviderType == InferenceProviderType.openAi ||
              p.inferenceProviderType == InferenceProviderType.mistral,
        );
  }

  /// Checks if the prompt was previously dismissed.
  Future<bool> _wasPromptDismissed() async {
    final settingsDb = getIt<SettingsDb>();
    final value = await settingsDb.itemByKey(_dismissedKey);
    return value == 'true';
  }

  /// Marks the prompt as dismissed so it won't show again.
  Future<void> dismissPrompt() async {
    final settingsDb = getIt<SettingsDb>();
    await settingsDb.saveSettingsItem(_dismissedKey, 'true');
    state = const AsyncValue.data(false);
  }

  /// Resets the dismissal state (useful for testing or user preference reset).
  Future<void> resetDismissal() async {
    final settingsDb = getIt<SettingsDb>();
    await settingsDb.removeSettingsItem(_dismissedKey);
    ref.invalidateSelf();
  }
}
