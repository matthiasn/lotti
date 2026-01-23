import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_config.dart';
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
  });

  final CloudInferenceRepository cloudRepository;

  @override
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
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
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
  }) async* {
    developer.log(
      'CloudInferenceWrapper: Processing ${messages.length} messages for '
      'cloud provider ${provider.inferenceProviderType}, '
      'hasSignatures: ${thoughtSignatures?.isNotEmpty ?? false}, '
      'turnIndex: $turnIndex',
      name: 'CloudInferenceWrapper',
    );

    // Use the cloud repository's native multi-turn support
    // This properly routes to Gemini's multi-turn API with signature support
    final stream = cloudRepository.generateWithMessages(
      messages: messages,
      model: model,
      temperature: temperature,
      provider: provider,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
      thoughtSignatures: thoughtSignatures,
      signatureCollector: signatureCollector,
      turnIndex: turnIndex,
    );

    // Pass through the stream but log any tool calls we see
    await for (final chunk in stream) {
      // Check if this chunk has tool calls that might be malformed
      if (chunk.choices?.isNotEmpty ?? false) {
        final delta = chunk.choices!.first.delta;
        if (delta?.toolCalls != null) {
          for (final toolCall in delta!.toolCalls!) {
            if (toolCall.function?.arguments != null &&
                toolCall.function!.arguments!.contains('}{')) {
              developer.log(
                'WARNING: Detected concatenated JSON in tool call arguments. '
                'Provider ${provider.inferenceProviderType} may be returning malformed tool calls.',
                name: 'CloudInferenceWrapper',
              );
            }
          }
        }
      }
      yield chunk;
    }
  }
}
