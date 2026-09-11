import 'dart:async';
import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/openai_compat_adapter.dart';

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
  LottiInferenceRequest createBaseRequest({
    required List<LottiMessage> messages,
    required String model,
    double? temperature,
    int? maxCompletionTokens,
    int? maxTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice,
    LottiReasoningEffort? reasoningEffort,
  }) {
    final LottiToolChoice? effectiveToolChoice;
    if (toolChoice != null) {
      effectiveToolChoice = toolChoice;
    } else if (tools != null && tools.isNotEmpty) {
      effectiveToolChoice = const LottiToolChoice.auto();
    } else {
      effectiveToolChoice = null;
    }

    return LottiInferenceRequest(
      messages: messages,
      model: model,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      maxTokens: maxTokens,
      reasoningEffort: reasoningEffort,
      tools: tools,
      toolChoice: effectiveToolChoice,
    );
  }

  /// Drops keep-alive frames that the client cannot read as chat chunks.
  ///
  /// Anthropic interleaves ping frames carrying no `choices`. The older client
  /// surfaced those as a raw cast error; the current one reports a parse
  /// failure instead. Both are recognized, because a single unreadable frame
  /// must not tear down an otherwise healthy stream — and because matching
  /// only the old spelling would let this protection lapse unnoticed.
  Stream<LottiInferenceChunk> filterAnthropicPings(
    Stream<LottiInferenceChunk> stream,
  ) {
    // Use where to filter out errors instead of handleError
    final controller = StreamController<LottiInferenceChunk>();

    stream.listen(
      controller.add,
      onError: (Object error, StackTrace stackTrace) {
        final errorString = error.toString();

        // The pre-1.0 client threw a raw cast error on a frame without
        // `choices`; the current one raises a typed parse failure.
        final isAnthropicPingError =
            (errorString.contains(
                  "type 'Null' is not a subtype of type 'List<dynamic>'",
                ) &&
                errorString.contains('choices')) ||
            isUnparseableStreamFrame(error);

        if (isAnthropicPingError) {
          // Log but don't propagate the error
          developer.log(
            'Skipping unreadable stream frame (Anthropic ping)',
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
  LottiReasoningEffort geminiReasoningEffort(
    String model,
    GeminiThinkingMode mode,
  ) {
    return switch (GeminiThinkingConfig.effectiveMode(model, mode)) {
      GeminiThinkingMode.minimal => LottiReasoningEffort.minimal,
      GeminiThinkingMode.low => LottiReasoningEffort.low,
      GeminiThinkingMode.medium => LottiReasoningEffort.medium,
      GeminiThinkingMode.high => LottiReasoningEffort.high,
    };
  }
}
