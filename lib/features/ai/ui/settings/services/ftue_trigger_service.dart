import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ftue_trigger_service.g.dart';

/// Result of the FTUE trigger check.
enum FtueTriggerResult {
  /// FTUE should be shown for this provider type.
  shouldShowFtue,

  /// FTUE should be skipped because this is not the first provider of this type.
  skipNotFirstProvider,

  /// FTUE should be skipped because this provider type is not supported.
  skipUnsupportedProvider,
}

/// Provider types that support FTUE (First Time User Experience) setup.
const Set<InferenceProviderType> ftueSupportedProviderTypes = {
  InferenceProviderType.gemini,
  InferenceProviderType.openAi,
  InferenceProviderType.mistral,
};

/// Extension providing FTUE-related properties for provider types.
extension FtueProviderTypeExtension on InferenceProviderType {
  /// Returns the display name for FTUE dialogs, or null if not supported.
  String? get ftueDisplayName => switch (this) {
        InferenceProviderType.gemini => 'Gemini',
        InferenceProviderType.openAi => 'OpenAI',
        InferenceProviderType.mistral => 'Mistral',
        _ => null,
      };
}

/// Service that determines whether FTUE setup should be triggered for a provider.
///
/// This service encapsulates the logic for deciding when to show the FTUE setup
/// dialog, making it independently testable from the UI layer.
@riverpod
class FtueTriggerService extends _$FtueTriggerService {
  @override
  FutureOr<void> build() {}

  /// Checks if the given provider type is supported for FTUE setup.
  bool isFtueSupported(InferenceProviderType providerType) {
    return ftueSupportedProviderTypes.contains(providerType);
  }

  /// Determines whether FTUE should be triggered for the given provider.
  ///
  /// Returns [FtueTriggerResult.shouldShowFtue] if:
  /// - The provider type is supported (Gemini, OpenAI, or Mistral) AND
  /// - This is the first provider of this type (count == 1 after creation)
  ///
  /// Returns [FtueTriggerResult.skipNotFirstProvider] if there's already
  /// more than one provider of this type (count > 1).
  ///
  /// Returns [FtueTriggerResult.skipUnsupportedProvider] if the provider
  /// type doesn't support FTUE.
  Future<FtueTriggerResult> shouldTriggerFtue(
    AiConfigInferenceProvider provider,
  ) async {
    // Check if provider type is supported
    if (!isFtueSupported(provider.inferenceProviderType)) {
      return FtueTriggerResult.skipUnsupportedProvider;
    }

    // Check the provider count for this type
    // Note: This is called after the provider is saved, so count includes the new provider
    final providerCount = await getProviderCountByType(
      provider.inferenceProviderType,
    );

    // If there's more than 1 provider of this type, skip FTUE
    // (models and prompts likely already exist from the first provider)
    if (providerCount > 1) {
      return FtueTriggerResult.skipNotFirstProvider;
    }

    return FtueTriggerResult.shouldShowFtue;
  }

  /// Gets the count of providers for a specific type.
  Future<int> getProviderCountByType(InferenceProviderType providerType) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    final providers = await repository.getConfigsByType(
      AiConfigType.inferenceProvider,
    );

    return providers
        .whereType<AiConfigInferenceProvider>()
        .where((p) => p.inferenceProviderType == providerType)
        .length;
  }

  /// Checks if this would be the first provider of a specific type.
  ///
  /// Unlike [shouldTriggerFtue], this checks BEFORE a provider is created.
  Future<bool> isFirstProviderOfType(InferenceProviderType providerType) async {
    final count = await getProviderCountByType(providerType);
    return count == 0;
  }
}
