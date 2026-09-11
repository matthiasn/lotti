import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference_chunk.dart';
import 'package:lotti/features/ai/model/inference_message.dart';
import 'package:lotti/features/ai/model/inference_tool.dart';

/// Abstract interface for inference repositories
/// This allows different providers (Ollama, Cloud) to be used interchangeably
/// in the conversation system
///
/// Implementations speak Lotti's own inference types rather than the client
/// library's; see `openai_compat_adapter.dart` for the boundary.
abstract class InferenceRepositoryInterface {
  /// Generate text with full conversation history
  /// This is the main method used by the conversation system
  ///
  /// Parameters:
  /// - [messages]: Full conversation history
  /// - [model]: Model identifier
  /// - [temperature]: Sampling temperature
  /// - [provider]: Provider configuration
  /// - [maxCompletionTokens]: Optional output token limit
  /// - [tools]: Optional function declarations
  /// - [toolChoice]: Optional override of tool selection policy. When `null`
  ///   the provider defaults to `auto` (or `none` when no tools are provided).
  ///   Pass `LottiToolChoice.specific(...)` to force the model to call a
  ///   specific function — currently honored only on the OpenAI-compatible
  ///   path.
  /// - [thoughtSignatures]: Previous thought signatures for multi-turn (Gemini 3)
  /// - [signatureCollector]: Collector for capturing new signatures from response
  /// - [turnIndex]: Current turn number for unique tool call ID generation
  Stream<LottiInferenceChunk> generateTextWithMessages({
    required List<LottiMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
    InferenceImpactCollector? impactCollector,
  });

  /// Optional: Generate text with a simple prompt (for backwards compatibility)
  Stream<LottiInferenceChunk> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice,
  }) {
    // Default implementation converts simple prompt to messages format
    final messages = <LottiMessage>[
      if (systemMessage != null) LottiMessage.system(systemMessage),
      LottiMessage.userText(prompt),
    ];

    return generateTextWithMessages(
      messages: messages,
      model: model,
      temperature: temperature,
      provider: provider,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
      toolChoice: toolChoice,
    );
  }
}
