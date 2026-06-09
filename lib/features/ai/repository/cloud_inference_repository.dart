import 'dart:async';
import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/providers/gemini_inference_repository_provider.dart';
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/dashscope_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/repository/openai_transcription_repository.dart';
import 'package:lotti/features/ai/repository/voxtral_inference_repository.dart';
import 'package:lotti/features/ai/repository/whisper_inference_repository.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'cloud_inference_repository.g.dart';
part 'cloud_inference_generate.dart';
part 'cloud_inference_generate_more.dart';

abstract class _CloudInferenceRepositoryBase {
  _CloudInferenceRepositoryBase(this.ref, {http.Client? httpClient})
    : _ollamaRepository = ref.read(ollamaInferenceRepositoryProvider),
      _geminiRepository = ref.read(geminiInferenceRepositoryProvider),
      _dashScopeRepository = ref.read(dashScopeInferenceRepositoryProvider),
      _mistralRepository = MistralInferenceRepository(httpClient: httpClient),
      _mistralTranscriptionRepository = MistralTranscriptionRepository(
        httpClient: httpClient,
      ),
      _whisperRepository = WhisperInferenceRepository(httpClient: httpClient),
      _voxtralRepository = VoxtralInferenceRepository(httpClient: httpClient),
      _openAiTranscriptionRepository = OpenAiTranscriptionRepository(
        httpClient: httpClient,
      );

  final Ref ref;
  final OllamaInferenceRepository _ollamaRepository;
  final GeminiInferenceRepository _geminiRepository;
  final DashScopeInferenceRepository _dashScopeRepository;
  final MistralInferenceRepository _mistralRepository;
  final MistralTranscriptionRepository _mistralTranscriptionRepository;
  final WhisperInferenceRepository _whisperRepository;
  final VoxtralInferenceRepository _voxtralRepository;
  final OpenAiTranscriptionRepository _openAiTranscriptionRepository;

  /// Helper method to create common request parameters
  CreateChatCompletionRequest _createBaseRequest({
    required List<ChatCompletionMessage> messages,
    required String model,
    double? temperature,
    int? maxCompletionTokens,
    int? maxTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    ReasoningEffort? reasoningEffort,
    bool stream = true,
  }) {
    final ChatCompletionToolChoiceOption? effectiveToolChoice;
    if (toolChoice != null) {
      effectiveToolChoice = toolChoice;
    } else if (tools != null && tools.isNotEmpty) {
      effectiveToolChoice = const ChatCompletionToolChoiceOption.mode(
        ChatCompletionToolChoiceMode.auto,
      );
    } else {
      effectiveToolChoice = null;
    }

    return CreateChatCompletionRequest(
      messages: messages,
      model: ChatCompletionModel.modelId(model),
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      maxTokens: maxTokens,
      reasoningEffort: reasoningEffort,
      stream: stream,
      tools: tools,
      toolChoice: effectiveToolChoice,
    );
  }

  /// Filters out Anthropic ping messages from the stream
  Stream<CreateChatCompletionStreamResponse> _filterAnthropicPings(
    Stream<CreateChatCompletionStreamResponse> stream,
  ) {
    // Use where to filter out errors instead of handleError
    final controller = StreamController<CreateChatCompletionStreamResponse>();

    stream.listen(
      controller.add,
      onError: (Object error, StackTrace stackTrace) {
        // Check if this is specifically an Anthropic ping message error
        final errorString = error.toString();

        // Anthropic ping messages cause a specific null subtype error when parsing choices
        final isAnthropicPingError =
            errorString.contains(
              "type 'Null' is not a subtype of type 'List<dynamic>'",
            ) &&
            errorString.contains('choices');

        if (isAnthropicPingError) {
          // Log but don't propagate the error
          developer.log(
            'Skipping Anthropic ping message',
            name: 'CloudInferenceRepository',
            error: error,
            stackTrace: stackTrace,
          );
          return;
        }
        // Propagate other errors
        controller.addError(error, stackTrace);
      },
      onDone: controller.close,
    );

    return controller.stream;
  }

  GeminiThinkingConfig _resolveGeminiThinkingConfig({
    GeminiThinkingMode? mode,
  }) {
    final base = GeminiThinkingConfig.fromMode(
      mode ?? GeminiThinkingMode.low,
    );

    // Always capture thoughts for thinking-capable models (budget != 0) so
    // they're available in the AI response modal's Thoughts tab. The chat UI
    // still decides whether inline thinking is displayed.
    return GeminiThinkingConfig(
      thinkingBudget: base.thinkingBudget,
      thinkingMode: base.thinkingMode,
      includeThoughts: base.thinkingBudget != 0,
    );
  }

  /// Maps a [GeminiThinkingMode] to the OpenAI-compatible `reasoning_effort`
  /// value for [model], collapsing modes that the model does not support
  /// (non-Flash Gemini 3 only accepts low/high) via
  /// [GeminiThinkingConfig.effectiveMode].
  ReasoningEffort _geminiReasoningEffort(
    String model,
    GeminiThinkingMode mode,
  ) {
    return switch (GeminiThinkingConfig.effectiveMode(model, mode)) {
      GeminiThinkingMode.minimal => ReasoningEffort.minimal,
      GeminiThinkingMode.low => ReasoningEffort.low,
      GeminiThinkingMode.medium => ReasoningEffort.medium,
      GeminiThinkingMode.high => ReasoningEffort.high,
    };
  }
}

class CloudInferenceRepository extends _CloudInferenceRepositoryBase
    with _CloudInferenceGenerate, _CloudInferenceGenerateMore {
  CloudInferenceRepository(super.ref, {super.httpClient});
}

@riverpod
CloudInferenceRepository cloudInferenceRepository(Ref ref) {
  final repo = CloudInferenceRepository(ref);
  ref.onDispose(repo.close);
  return repo;
}
