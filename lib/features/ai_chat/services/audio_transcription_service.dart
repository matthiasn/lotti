import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_realtime_transcription_repository.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/get_it.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';

const _kDefaultAudioModel = 'gemini-2.5-flash';
const _kTranscriptionPrompt = 'Transcribe the audio to natural text.';

/// Whether a failed attributed transcription definitely published its single
/// provider interaction or has an uncertain publication outcome.
enum TranscriptionEvidenceState { recorded, uncertain }

/// Failure from an attributed provider call with explicit evidence state.
class AttributedTranscriptionException implements Exception {
  const AttributedTranscriptionException({
    required this.cause,
    required this.evidenceState,
  });

  final Object cause;
  final TranscriptionEvidenceState evidenceState;

  @override
  String toString() => cause.toString();
}

class _ProviderTranscriptionFailure implements Exception {
  const _ProviderTranscriptionFailure(this.cause);

  final Object cause;
}

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
    AiAttributionSession? attributionSession,
    bool terminalizeAttributionFailure = true,
  }) => transcribeStream(
    filePath,
    speechDictionaryTerms: speechDictionaryTerms,
    attributionSession: attributionSession,
    terminalizeAttributionFailure: terminalizeAttributionFailure,
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
    AiAttributionSession? attributionSession,
    bool terminalizeAttributionFailure = true,
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
      Future<MlxAudioTranscriptionResult> invoke() async {
        final result = await ref
            .read(mlxAudioChannelProvider)
            .transcribeFile(
              filePath: filePath,
              modelId: model.providerModelId,
              speechDictionaryTerms: speechDictionaryTerms,
            );
        if (result.text.trim().isEmpty) {
          throw TranscriptionException(
            '${provider.name} returned no transcript for '
            '${model.providerModelId}. The request completed without any text.',
            provider: provider.name,
          );
        }
        return result;
      }

      final capture = getIt.isRegistered<AiInteractionCapture>()
          ? getIt<AiInteractionCapture>()
          : null;
      late MlxAudioTranscriptionResult result;
      if (capture == null) {
        result = await invoke();
      } else {
        try {
          result = await capture.captureUnary(
            workType: AiWorkType.audioTranscription,
            interactionKind: AiInteractionKind.audioTranscription,
            responseType: AiConsumptionResponseType.audioTranscription,
            providerType: provider.inferenceProviderType,
            modelId: model.providerModelId,
            requestText: _kTranscriptionPrompt,
            invoke: () async {
              try {
                return await invoke();
              } catch (error) {
                throw _ProviderTranscriptionFailure(error);
              }
            },
            responseText: (value) => value.text,
            existingSession: attributionSession,
            terminalizeSuccess: attributionSession == null,
            terminalizeFailure: terminalizeAttributionFailure,
          );
        } on _ProviderTranscriptionFailure catch (failure) {
          throw AttributedTranscriptionException(
            cause: failure.cause,
            evidenceState: TranscriptionEvidenceState.recorded,
          );
        } catch (error) {
          throw AttributedTranscriptionException(
            cause: error,
            evidenceState: TranscriptionEvidenceState.uncertain,
          );
        }
      }
      yield result.text;
      return;
    }

    final bytes = await File(filePath).readAsBytes();
    final audioBase64 = base64Encode(bytes);

    final cloud = ref.read(cloudInferenceRepositoryProvider);
    final impactCollector =
        provider.inferenceProviderType == InferenceProviderType.melious
        ? InferenceImpactCollector()
        : null;
    final useGeminiThinkingMode =
        provider.inferenceProviderType == InferenceProviderType.gemini &&
        GeminiThinkingConfig.isGemini3(model.providerModelId);
    Stream<CreateChatCompletionStreamResponse> invoke() async* {
      var receivedTranscript = false;
      try {
        await for (final chunk in cloud.generateWithAudio(
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
          impactCollector: impactCollector,
        )) {
          final content = chunk.choices?.firstOrNull?.delta?.content ?? '';
          if (content.trim().isNotEmpty) {
            receivedTranscript = true;
          }
          yield chunk;
        }
        if (!receivedTranscript) {
          throw TranscriptionException(
            '${provider.name} returned no transcript for '
            '${model.providerModelId}. The request completed without any text.',
            provider: provider.name,
          );
        }
      } catch (error) {
        throw _ProviderTranscriptionFailure(error);
      }
    }

    final capture = getIt.isRegistered<AiInteractionCapture>()
        ? getIt<AiInteractionCapture>()
        : null;
    final stream = capture == null
        ? invoke()
        : capture.captureStream(
            workType: AiWorkType.audioTranscription,
            interactionKind: AiInteractionKind.audioTranscription,
            responseType: AiConsumptionResponseType.audioTranscription,
            providerType: provider.inferenceProviderType,
            modelId: model.providerModelId,
            requestText: '$_kTranscriptionPrompt|audioBytes:${bytes.length}',
            invoke: invoke,
            responseText: (chunk) =>
                chunk.choices?.firstOrNull?.delta?.content ?? '',
            usageForChunk: (chunk) {
              final usage = chunk.usage;
              if (usage == null) return null;
              return AiCapturedUsage(
                inputTokens: usage.promptTokens,
                outputTokens: usage.completionTokens,
                cachedInputTokens: usage.promptTokensDetails?.cachedTokens,
                thoughtsTokens: usage.completionTokensDetails?.reasoningTokens,
                totalTokens: usage.totalTokens,
              );
            },
            impact: () => impactCollector?.impact,
            existingSession: attributionSession,
            terminalizeSuccess: attributionSession == null,
            terminalizeFailure: terminalizeAttributionFailure,
          );

    try {
      await for (final chunk in stream) {
        final content = chunk.choices?.firstOrNull?.delta?.content ?? '';
        if (content.isNotEmpty) {
          yield content;
        }
      }
    } on _ProviderTranscriptionFailure catch (failure) {
      if (capture == null) {
        final cause = failure.cause;
        if (cause is StateError) throw cause;
        if (cause is Exception) throw cause;
        throw Exception(cause.toString());
      }
      throw AttributedTranscriptionException(
        cause: failure.cause,
        evidenceState: TranscriptionEvidenceState.recorded,
      );
    } catch (error) {
      throw AttributedTranscriptionException(
        cause: error,
        evidenceState: TranscriptionEvidenceState.uncertain,
      );
    }
  }
}

/// Test-only access to the batch audio-model selection priority, so its
/// ordering algebra (Mistral-chat-audio > Mistral-transcription >
/// Mistral-batch > Melious-chat-audio > Melious-STT > MLX-Qwen >
/// flash-preferred > first) can be property-tested without driving the
/// streaming pipeline.
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

  final mistralChatAudio = audioModels.firstWhereOrNull(
    (model) =>
        hasProviderType(model, InferenceProviderType.mistral) &&
        MistralInferenceRepository.isMistralChatAudioModel(
          model.providerModelId,
        ),
  );
  if (mistralChatAudio != null) {
    return mistralChatAudio;
  }

  final mistralTranscription = audioModels.firstWhereOrNull(
    (model) =>
        hasProviderType(model, InferenceProviderType.mistral) &&
        MistralTranscriptionRepository.isMistralTranscriptionModel(
          model.providerModelId,
        ),
  );
  if (mistralTranscription != null) {
    return mistralTranscription;
  }

  final mistralBatch = audioModels.firstWhereOrNull(
    (model) => hasProviderType(model, InferenceProviderType.mistral),
  );
  if (mistralBatch != null) {
    return mistralBatch;
  }

  final meliousChatAudio = audioModels.firstWhereOrNull(
    (model) =>
        hasProviderType(model, InferenceProviderType.melious) &&
        MeliousInferenceRepository.isMeliousChatAudioModel(
          model.providerModelId,
        ),
  );
  if (meliousChatAudio != null) {
    return meliousChatAudio;
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
