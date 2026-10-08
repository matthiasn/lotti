import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai/ai_call_impact.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/ai_consumption/ai_consumption_enums.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/tool_call_accumulator.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/skills/recording_summary_tool.dart';
import 'package:lotti/features/ai/skills/transcript_correction_tool.dart';
import 'package:lotti/features/ai/skills/transcript_name_correction_tool.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/repository/speech_dictionary_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/utils/transcript_term_corrector.dart';
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
/// configured inference provider and selected audio-capable model.
///
/// It serves the callers that take the words back rather than leaving them
/// on a recording — Daily OS capture, onboarding, chat voice input — so the
/// speech dictionary reaches them here: its terms are sent to the engine as
/// a vocabulary hint and the words are corrected against them by sound and
/// spelling, and [correctTranscript] adds a model's correction for a caller
/// that can wait for one.
class AudioTranscriptionService {
  /// Creates an [AudioTranscriptionService] backed by Riverpod [Ref].
  AudioTranscriptionService(this.ref);

  final Ref ref;

  /// Records each provider call this service makes, when the ledger runs.
  AiInteractionCapture? get _capture =>
      getIt.isRegistered<AiInteractionCapture>()
      ? getIt<AiInteractionCapture>()
      : null;

  /// The speech dictionary entries that reach [categoryId] — with none, the
  /// entries that apply to every category. Empty when the dictionary cannot
  /// be read: it improves the words, and must never cost them.
  Future<List<SpeechDictionaryEntry>> _dictionaryEntries(
    String? categoryId,
  ) async {
    try {
      return entriesForCategory(
        await ref.read(journalDbProvider).getAllSpeechDictionaryEntries(),
        categoryId,
      );
    } catch (_) {
      return const [];
    }
  }

  /// Transcribes audio from a local file at [filePath] to natural text.
  ///
  /// Returns the full transcription as a single concatenated string by
  /// consuming [transcribeStream]. Tests rely on this convenience entry
  /// point; UI code uses the streaming variant directly.
  Future<String> transcribe(
    String filePath, {
    List<String> knownTerms = const [],
    String? dictionaryCategoryId,
    AiAttributionSession? attributionSession,
    bool terminalizeAttributionFailure = true,
    ({AiConfigInferenceProvider provider, AiConfigModel model})? target,
  }) => transcribeStream(
    filePath,
    knownTerms: knownTerms,
    dictionaryCategoryId: dictionaryCategoryId,
    attributionSession: attributionSession,
    terminalizeAttributionFailure: terminalizeAttributionFailure,
    target: target,
  ).join();

  /// Transcribes audio from a local file at [filePath] with streaming output.
  ///
  /// Yields each transcribed chunk as it's received from the inference provider,
  /// allowing the UI to display progressive transcription results.
  ///
  /// For providers that support chunk-by-chunk streaming (like Voxtral),
  /// each yield represents a portion of the audio (e.g., 60-second segments).
  /// For other providers, the entire transcription may come as a single chunk.
  ///
  /// [knownTerms] — words the caller expects — lead the speech dictionary
  /// entries that reach [dictionaryCategoryId] (with none, those that apply
  /// to every category). Together they are the engine's vocabulary hint, and
  /// each chunk is corrected against them by sound and spelling
  /// ([correctTranscriptTerms]) before it is yielded.
  Stream<String> transcribeStream(
    String filePath, {
    List<String> knownTerms = const [],
    String? dictionaryCategoryId,
    AiAttributionSession? attributionSession,
    bool terminalizeAttributionFailure = true,
    ({AiConfigInferenceProvider provider, AiConfigModel model})? target,
  }) async* {
    final AiConfigModel model;
    final AiConfigInferenceProvider provider;
    if (target != null) {
      // An explicit target (e.g. the caller's inference-profile
      // transcription slot) skips discovery entirely.
      model = target.model;
      provider = target.provider;
    } else {
      final aiRepo = ref.read(aiConfigRepositoryProvider);
      // Fetch models and providers in parallel to reduce I/O latency
      final modelsFuture = aiRepo.getConfigsByType(AiConfigType.model);
      final providersFuture = aiRepo.getConfigsByType(
        AiConfigType.inferenceProvider,
      );
      final models = await modelsFuture;
      final providers = await providersFuture;

      // Find all audio-capable models, excluding realtime-only models —
      // they require WebSocket streaming, which this app does not use.
      final allProviders = providers.whereType<AiConfigInferenceProvider>();
      final audioModels = models
          .whereType<AiConfigModel>()
          .where(
            (m) => m.inputModalities.contains(Modality.audio),
          )
          .where((m) {
            final candidate = allProviders
                .where((p) => p.id == m.inferenceProviderId)
                .firstOrNull;
            if (candidate == null) return true; // keep orphans, fail later
            return !(candidate.inferenceProviderType ==
                    InferenceProviderType.mistral &&
                _isRealtimeOnlyModel(m.providerModelId));
          })
          .toList();

      for (final candidate in audioModels.toList()) {
        final candidateProvider = allProviders.firstWhereOrNull(
          (provider) => provider.id == candidate.inferenceProviderId,
        );
        if (candidateProvider?.inferenceProviderType ==
                InferenceProviderType.sherpa &&
            !await ref
                .read(sherpaModelRepositoryProvider)
                .isAvailable(candidate.providerModelId)) {
          audioModels.remove(candidate);
        }
      }
      if (audioModels.isEmpty) {
        throw Exception('No audio-capable models configured');
      }

      model = _selectBatchAudioModel(
        audioModels,
        allProviders,
      );

      // Get the provider for the selected model
      provider = providers.whereType<AiConfigInferenceProvider>().firstWhere(
        (p) => p.id == model.inferenceProviderId,
        orElse: () => throw Exception('Provider not found for audio model'),
      );
    }

    final bytes = await File(filePath).readAsBytes();
    final audioBase64 = base64Encode(bytes);
    final speechDictionaryTerms = mergeSpeechTerms(knownTerms, [
      for (final entry in await _dictionaryEntries(dictionaryCategoryId))
        entry.term,
    ]);

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

    final capture = _capture;
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
          yield speechDictionaryTerms.isEmpty
              ? content
              : correctTranscriptTerms(content, speechDictionaryTerms).text;
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

  /// [transcript] with the speech dictionary terms it misheard corrected by
  /// [target] — a model that can call tools — in one pinned tool call.
  ///
  /// The entries are those that reach [dictionaryCategoryId] (with none,
  /// those that apply to every category). The model reports quoted edits
  /// that code applies ([applyRecordingCorrections]), never a rewritten
  /// text, and every applied edit is learned as a misheard spelling of its
  /// term. Returns [transcript] unchanged when no entry reaches it or the
  /// call fails: a correction improves the words, and must never cost them.
  Future<String> correctTranscript(
    String transcript, {
    required ({AiConfigInferenceProvider provider, AiConfigModel model}) target,
    String? dictionaryCategoryId,
  }) async {
    if (transcript.trim().isEmpty) return transcript;
    final entries = await _dictionaryEntries(dictionaryCategoryId);
    if (entries.isEmpty) return transcript;

    final messages = transcriptCorrectionMessages(
      transcript: transcript,
      entries: entries,
    );
    final modelId = target.model.providerModelId;
    final provider = target.provider;
    final impactCollector =
        provider.inferenceProviderType == InferenceProviderType.melious
        ? InferenceImpactCollector()
        : null;
    Stream<CreateChatCompletionStreamResponse> invoke() => ref
        .read(cloudInferenceRepositoryProvider)
        .generate(
          messages.user,
          model: modelId,
          temperature: null,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          provider: provider,
          systemMessage: messages.system,
          tools: const [transcriptCorrectionTool],
          toolChoice: transcriptCorrectionToolChoiceFor(modelId),
          impactCollector: impactCollector,
        );
    final capture = _capture;
    try {
      final chunks =
          await (capture == null
                  ? invoke()
                  : capture.captureStream(
                      workType: AiWorkType.audioTranscription,
                      interactionKind: AiInteractionKind.textGeneration,
                      responseType:
                          AiConsumptionResponseType.audioTranscription,
                      providerType: provider.inferenceProviderType,
                      modelId: modelId,
                      requestText: '${messages.system}\n${messages.user}',
                      invoke: invoke,
                      responseText: (chunk) => [
                        for (final call
                            in chunk.choices?.firstOrNull?.delta?.toolCalls ??
                                const <
                                  ChatCompletionStreamMessageToolCallChunk
                                >[])
                          call.function?.arguments ?? '',
                      ].join(),
                      usageForChunk: (chunk) => switch (chunk.usage) {
                        final usage? => AiCapturedUsage(
                          inputTokens: usage.promptTokens,
                          outputTokens: usage.completionTokens,
                          totalTokens: usage.totalTokens,
                        ),
                        null => null,
                      },
                      impact: () => impactCollector?.impact,
                    ))
              .toList();
      final corrected = applyRecordingCorrections(
        transcript,
        parseTranscriptNameCorrections(
          _toolCallsOf(chunks),
          toolName: transcriptCorrectionToolName,
        ),
        entries,
      );
      if (corrected.applied.isNotEmpty) {
        try {
          await ref
              .read(speechDictionaryRepositoryProvider)
              .learnMisheardForms(corrected.applied);
        } catch (_) {
          // The corrected words are what matters; the next correction can
          // teach the same spelling.
        }
      }
      return corrected.text;
    } catch (_) {
      return transcript;
    }
  }
}

/// The tool calls [chunks] stream, reassembled — a provider sends one call's
/// arguments across many chunks.
List<ChatCompletionMessageToolCall> _toolCallsOf(
  List<CreateChatCompletionStreamResponse> chunks,
) {
  final accumulator = ToolCallAccumulator();
  for (final chunk in chunks) {
    accumulator.processChunk(chunk.choices?.firstOrNull?.delta);
  }
  return accumulator.toToolCalls();
}

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

  final embedded =
      audioModels
          .where(
            (model) => hasProviderType(model, InferenceProviderType.sherpa),
          )
          .toList()
        ..sort((left, right) => left.name.compareTo(right.name));
  if (embedded.isNotEmpty) return embedded.first;

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

  // Discovery must agree with the seeded Melious profile default, which
  // transcribes with Whisper Large v3 through `/audio/transcriptions` since
  // seed generation 2. Surfaces without an explicit target — onboarding's
  // first capture, Daily OS capture before a planner profile is bound — land
  // here, and preferring the Voxtral chat path would put them on the very
  // model the profile moved off.
  final meliousWhisperDefault = audioModels.firstWhereOrNull(
    (model) =>
        hasProviderType(model, InferenceProviderType.melious) &&
        model.providerModelId == meliousWhisperLargeV3ModelId,
  );
  if (meliousWhisperDefault != null) {
    return meliousWhisperDefault;
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

  return audioModels.firstWhere(
    (model) => model.providerModelId.contains(_kDefaultAudioModel),
    orElse: () => audioModels.first,
  );
}

final Provider<AudioTranscriptionService> audioTranscriptionServiceProvider =
    Provider<AudioTranscriptionService>((ref) {
      return AudioTranscriptionService(ref);
    });

/// Matches Mistral model IDs that only serve the WebSocket realtime API
/// (e.g. `voxtral-mini-transcribe-realtime-2602`); they cannot batch-​transcribe.
bool _isRealtimeOnlyModel(String model) =>
    model.contains('transcribe-realtime');
