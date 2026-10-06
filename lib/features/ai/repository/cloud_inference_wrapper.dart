import 'package:lotti/classes/ai/ai_call_impact.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

/// Wrapper that adapts CloudInferenceRepository to work with the conversation system
///
/// This allows cloud providers (Gemini, OpenAI, etc.) to be used with the same
/// conversation approach that currently only works with Ollama.
///
/// For Gemini providers, this wrapper supports:
/// - Native multi-turn API with proper conversation history
/// - Thought signatures for multi-turn function calling
/// - Signature collection from responses
class CloudInferenceWrapper implements InferenceRepositoryInterface {
  CloudInferenceWrapper({
    required this.cloudRepository,
    this.geminiThinkingMode,
    this.reasoningEffort,
  });

  final CloudInferenceRepository cloudRepository;
  final GeminiThinkingMode? geminiThinkingMode;
  final ReasoningEffort? reasoningEffort;

  @override
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) {
    // Delegate to the cloud repository
    return cloudRepository.generate(
      prompt,
      model: model,
      temperature: temperature,
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      systemMessage: systemMessage,
      maxCompletionTokens: maxCompletionTokens,
      provider: provider,
      tools: tools,
      toolChoice: toolChoice,
      geminiThinkingMode: geminiThinkingMode,
      reasoningEffort: reasoningEffort,
    );
  }

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
    InferenceImpactCollector? impactCollector,
  }) async* {
    // Use the cloud repository's native multi-turn support, which routes to
    // Gemini's multi-turn API with signature support, logs the call and flags
    // malformed (concatenated) tool-call arguments. `async*` keeps the call
    // lazy, so a routing failure surfaces as a stream error.
    yield* cloudRepository.generateWithMessages(
      messages: messages,
      model: model,
      temperature: temperature,
      provider: provider,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
      toolChoice: toolChoice,
      thoughtSignatures: thoughtSignatures,
      signatureCollector: signatureCollector,
      turnIndex: turnIndex,
      geminiThinkingMode: geminiThinkingMode,
      reasoningEffort: reasoningEffort,
      impactCollector: impactCollector,
    );
  }
}
