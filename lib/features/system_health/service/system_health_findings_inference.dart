import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/one_shot_text_generation.dart';

/// Signature the analyzer uses to obtain findings from a model.
///
/// Kept as a plain function type so the analyzer can be tested with a stub,
/// and so a future scheduler can wire a different writer without touching
/// the analysis.
typedef SystemHealthFindingsWriter =
    Future<String> Function({
      required String systemMessage,
      required String prompt,
      required AiConfigModel model,
    });

/// Runs one text-generation call against the model the user picked.
///
/// Resolves the model's provider, streams the completion through the AI
/// consumption capture when it is registered (so the run shows up in usage
/// attribution as a manual text generation), and returns the accumulated
/// text. Throws [StateError] when the provider is missing or has no key.
class SystemHealthFindingsInference {
  const SystemHealthFindingsInference({
    required this.inferenceRepository,
    required this.aiConfigRepository,
  });

  final CloudInferenceRepository inferenceRepository;
  final AiConfigRepository aiConfigRepository;

  static const double _temperature = 0.2;
  static const int _maxCompletionTokens = 2048;

  Future<String> write({
    required String systemMessage,
    required String prompt,
    required AiConfigModel model,
  }) async {
    final config = await aiConfigRepository.getConfigById(
      model.inferenceProviderId,
    );
    final provider = config is AiConfigInferenceProvider ? config : null;
    if (provider == null || !provider.isUsable) {
      throw StateError(
        'inference provider for ${model.name} is missing or has no API key',
      );
    }

    return inferenceRepository.generateText(
      prompt: prompt,
      systemMessage: systemMessage,
      model: model.providerModelId,
      provider: provider,
      temperature: _temperature,
      maxCompletionTokens: _maxCompletionTokens,
      geminiThinkingMode: model.geminiThinkingMode,
      attribution: const OneShotGenerationAttribution(
        workType: AiWorkType.textGeneration,
      ),
    );
  }
}
