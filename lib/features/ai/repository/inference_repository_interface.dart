import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:openai_dart/openai_dart.dart';

/// Abstract interface for inference repositories
/// This allows different providers (Ollama, Cloud) to be used interchangeably
/// in the conversation system
abstract class InferenceRepositoryInterface {
  /// Generate text with full conversation history
  /// This is the main method used by the conversation system
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
  });

  /// Optional: Generate text with a simple prompt (for backwards compatibility)
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
  }) {
    // Default implementation converts simple prompt to messages format
    final messages = <ChatCompletionMessage>[];
    if (systemMessage != null) {
      messages.add(ChatCompletionMessage.system(content: systemMessage));
    }
    messages.add(ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(prompt),
    ));

    return generateTextWithMessages(
      messages: messages,
      model: model,
      temperature: temperature,
      provider: provider,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
    );
  }
}
