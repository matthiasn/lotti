import 'dart:async';
import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:openai_dart/openai_dart.dart';

/// Stateless request/stream helpers shared by the cloud-inference generate
/// collaborators (`CloudInferenceGenerate` and `CloudInferenceGenerateMore`).
///
/// Extracted from `CloudInferenceRepository`'s former base mixin so the shared
/// OpenAI request shaping, Anthropic-ping filtering, and Gemini thinking
/// mapping live in one independently testable unit. Holds no state and takes no
/// dependencies, so a single instance is injected into both generate
/// collaborators.
class CloudInferenceRequestHelpers {
  const CloudInferenceRequestHelpers();

  /// Helper method to create common request parameters
  CreateChatCompletionRequest createBaseRequest({
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
  Stream<CreateChatCompletionStreamResponse> filterAnthropicPings(
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

  GeminiThinkingConfig resolveGeminiThinkingConfig({
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
  ReasoningEffort geminiReasoningEffort(
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
