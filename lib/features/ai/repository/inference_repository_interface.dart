import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';

/// Abstract interface for inference repositories.
///
/// Each provider (Ollama, Gemini, Mistral, generic OpenAI-compatible, etc.)
/// implements this contract so the conversation system can route requests
/// without provider-specific branching at the call site.
abstract class InferenceRepositoryInterface {
  /// Generate text with full conversation history.
  ///
  /// Parameters:
  /// - [messages]: Full conversation history.
  /// - [model]: Model identifier.
  /// - [temperature]: Sampling temperature.
  /// - [provider]: Provider configuration.
  /// - [maxCompletionTokens]: Optional output token limit.
  /// - [tools]: Optional function declarations.
  /// - [toolChoice]: Optional override of tool selection policy. When `null`
  ///   the provider defaults to `auto` (or `none` when no tools are provided).
  ///   Pass [AiToolChoiceFunction] to force a specific function — currently
  ///   honored only on the OpenAI-compatible path.
  /// - [thoughtSignatures]: Previous thought signatures for multi-turn
  ///   (Gemini 3).
  /// - [signatureCollector]: Collector for capturing new signatures from
  ///   response.
  /// - [turnIndex]: Current turn number for unique tool call ID generation.
  Stream<AiStreamChunk> generateTextWithMessages({
    required List<AiChatMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<AiTool>? tools,
    AiToolChoice? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
  });

  /// Generate text with a simple prompt (single-turn).
  Stream<AiStreamChunk> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<AiTool>? tools,
    AiToolChoice? toolChoice,
  }) {
    final messages = <AiChatMessage>[
      if (systemMessage != null) AiSystemMessage(systemMessage),
      AiUserMessage(AiUserTextContent(prompt)),
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
