import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_realtime_transcription_repository.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:meta/meta.dart';

const _kDefaultAudioModel = 'gemini-2.5-flash';
const _kTranscriptionPrompt = 'Transcribe the audio to natural text.';

/// Service that transcribes a local audio file to text using the
/// configured cloud inference provider and selected audio-capable model.
class AudioTranscriptionService {
  /// Creates an [AudioTranscriptionService] backed by Riverpod [Ref].
  AudioTranscriptionService(this.ref);

  final Ref ref;

  /// Transcribes audio from a local file at [filePath] to natural text.
  ///
  /// Returns the full transcription as a single concatenated string by
  /// consuming [transcribeStream]. Tests rely on this convenience entry
  /// point; UI code uses the streaming variant directly.
  Future<String> transcribe(
    String filePath, {
    List<String> speechDictionaryTerms = const [],
  }) => transcribeStream(
    filePath,
    speechDictionaryTerms: speechDictionaryTerms,
  ).join();

  /// Transcribes audio from a local file at [filePath] with streaming output.
  ///
  /// Yields each transcribed chunk as it's received from the inference provider,
  /// allowing the UI to display progressive transcription results.
  ///
  /// For providers that support chunk-by-chunk streaming (like Voxtral),
  /// each yield represents a portion of the audio (e.g., 60-second segments).
  /// For other providers, the entire transcription may come as a single chunk.
  Stream<String> transcribeStream(
    String filePath, {
    List<String> speechDictionaryTerms = const [],
  }) async* {
    final aiRepo = ref.read(aiConfigRepositoryProvider);
    // Fetch models and providers in parallel to reduce I/O latency
    final modelsFuture = aiRepo.getConfigsByType(AiConfigType.model);
    final providersFuture = aiRepo.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    final models = await modelsFuture;
    final providers = await providersFuture;

    // Find all audio-capable models, excluding realtime-only models that
    // require WebSocket streaming (handled by RealtimeTranscriptionService).
    final allProviders = providers.whereType<AiConfigInferenceProvider>();
    final audioModels = models
        .whereType<AiConfigModel>()
        .where(
          (m) => m.inputModalities.contains(Modality.audio),
        )
        .where((m) {
          final provider = allProviders
              .where((p) => p.id == m.inferenceProviderId)
              .firstOrNull;
          if (provider == null) return true; // keep orphan models, fail later
          return !(provider.inferenceProviderType ==
                  InferenceProviderType.mistral &&
              MistralRealtimeTranscriptionRepository.isRealtimeModel(
                m.providerModelId,
              ));
        })
        .toList();

    if (audioModels.isEmpty) {
      throw Exception('No audio-capable models configured');
    }

    final model = _selectBatchAudioModel(
      audioModels,
      allProviders,
    );

    // Get the provider for the selected model
    final provider = providers
        .whereType<AiConfigInferenceProvider>()
        .firstWhere(
          (p) => p.id == model.inferenceProviderId,
          orElse: () => throw Exception('Provider not found for audio model'),
        );

    if (provider.inferenceProviderType == InferenceProviderType.mlxAudio) {
      final result = await ref
          .read(mlxAudioChannelProvider)
          .transcribeFile(
            filePath: filePath,
            modelId: model.providerModelId,
            speechDictionaryTerms: speechDictionaryTerms,
          );
      if (result.text.isNotEmpty) {
        yield result.text;
      }
      return;
    }

    final bytes = await File(filePath).readAsBytes();
    final audioBase64 = base64Encode(bytes);

    final cloud = ref.read(cloudInferenceRepositoryProvider);
    final useGeminiThinkingMode =
        provider.inferenceProviderType == InferenceProviderType.gemini &&
        GeminiThinkingConfig.isGemini3(model.providerModelId);
    final stream = cloud.generateWithAudio(
      _kTranscriptionPrompt,
      model: model.providerModelId,
      audioBase64: audioBase64,
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      provider: provider,
      maxCompletionTokens: model.maxCompletionTokens,
      speechDictionaryTerms: speechDictionaryTerms,
      geminiThinkingMode: useGeminiThinkingMode
          ? model.geminiThinkingMode
          : null,
    );

    await for (final chunk in stream) {
      final content = chunk.choices?.firstOrNull?.delta?.content ?? '';
      if (content.isNotEmpty) {
        yield content;
      }
    }
  }
}

/// Test-only access to the batch audio-model selection priority, so its
/// ordering algebra (Mistral-offline > Mistral-batch > Melious-STT >
/// MLX-Qwen > flash-preferred > first) can be property-tested without driving
/// the streaming pipeline.
@visibleForTesting
AiConfigModel debugSelectBatchAudioModel(
  List<AiConfigModel> audioModels,
  Iterable<AiConfigInferenceProvider> providers,
) => _selectBatchAudioModel(audioModels, providers);

AiConfigModel _selectBatchAudioModel(
  List<AiConfigModel> audioModels,
  Iterable<AiConfigInferenceProvider> providers,
) {
  final providersById = {
    for (final provider in providers) provider.id: provider,
  };

  bool hasProviderType(AiConfigModel model, InferenceProviderType type) {
    return providersById[model.inferenceProviderId]?.inferenceProviderType ==
        type;
  }

  final mistralOffline = audioModels.firstWhereOrNull(
    (model) =>
        hasProviderType(model, InferenceProviderType.mistral) &&
        MistralTranscriptionRepository.isMistralTranscriptionModel(
          model.providerModelId,
        ),
  );
  if (mistralOffline != null) {
    return mistralOffline;
  }

  final mistralBatch = audioModels.firstWhereOrNull(
    (model) => hasProviderType(model, InferenceProviderType.mistral),
  );
  if (mistralBatch != null) {
    return mistralBatch;
  }

  final meliousTranscription = audioModels.firstWhereOrNull(
    (model) =>
        hasProviderType(model, InferenceProviderType.melious) &&
        MeliousInferenceRepository.isMeliousTranscriptionModel(
          model.providerModelId,
        ),
  );
  if (meliousTranscription != null) {
    return meliousTranscription;
  }

  final mlxQwen = audioModels.firstWhereOrNull(
    (model) =>
        isMlxAudioQwenAsrModelId(model.providerModelId) &&
        hasProviderType(model, InferenceProviderType.mlxAudio),
  );
  if (mlxQwen != null) {
    return mlxQwen;
  }

  return audioModels.firstWhere(
    (model) => model.providerModelId.contains(_kDefaultAudioModel),
    orElse: () => audioModels.first,
  );
}

final Provider<AudioTranscriptionService> audioTranscriptionServiceProvider =
    Provider<AudioTranscriptionService>((ref) {
      return AudioTranscriptionService(ref);
    });
