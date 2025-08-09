import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/util/content_extraction_helper.dart';
import 'package:openai_dart/openai_dart.dart';

/// Wrapper that adapts CloudInferenceRepository to work with the conversation system
///
/// This allows cloud providers (Gemini, OpenAI, etc.) to be used with the same
/// conversation approach that currently only works with Ollama
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
  }) async* {
    developer.log(
      'CloudInferenceWrapper: Converting ${messages.length} messages for cloud provider ${provider.inferenceProviderType}',
      name: 'CloudInferenceWrapper',
    );

    // For now, we'll convert the conversation to a simple prompt
    // This is a simplified approach - a more sophisticated implementation
    // would maintain the full conversation context

    // Extract system message if present
    String? systemMessage;
    final userMessages = <String>[];
    final assistantMessages = <String>[];

    for (final message in messages) {
      developer.log(
        'Processing message: role=${message.role.name}, '
        'hasContent=${message.content != null}',
        name: 'CloudInferenceWrapper',
      );

      switch (message.role) {
        case ChatCompletionMessageRole.system:
          if (message.content is String) {
            systemMessage = message.content! as String;
          }
        case ChatCompletionMessageRole.user:
          final content = _extractContent(message.content);
          if (content != null) {
            userMessages.add(content);
          }
        case ChatCompletionMessageRole.assistant:
          final content = _extractContent(message.content);
          if (content != null) {
            assistantMessages.add(content);
          }
        // Note: Assistant messages may have tool calls in newer SDK versions
        // but they're not directly accessible as a property
        case ChatCompletionMessageRole.tool:
          // Tool responses - we'll include these in the context
          final content = _extractContent(message.content);
          if (content != null) {
            assistantMessages.add('Tool response: $content');
          }
        case ChatCompletionMessageRole.function:
          // Function responses - we'll include these in the context
          final content = _extractContent(message.content);
          if (content != null) {
            assistantMessages.add('Function response: $content');
          }
        case ChatCompletionMessageRole.developer:
          // Developer messages - typically used for system debugging
          final content = _extractContent(message.content);
          if (content != null) {
            developer.log(
              'Developer message in conversation: $content',
              name: 'CloudInferenceWrapper',
            );
          }
      }
    }

    // Build the prompt from the conversation history
    // For cloud providers, we need to condense the conversation into a single prompt
    final promptParts = <String>[];

    // Add conversation context if there are previous messages
    if (assistantMessages.isNotEmpty) {
      promptParts.add('Previous conversation:');
      for (var i = 0;
          i < userMessages.length - 1 && i < assistantMessages.length;
          i++) {
        promptParts
          ..add('User: ${userMessages[i]}')
          ..add('Assistant: ${assistantMessages[i]}');
      }
      promptParts.add(''); // Empty line
    }

    // Add the current user message
    if (userMessages.isNotEmpty) {
      promptParts.add(userMessages.last);
    }

    final prompt = promptParts.join('\n');

    developer.log(
      'CloudInferenceWrapper: Calling cloud inference with prompt length: ${prompt.length}, '
      'tools: ${tools?.length ?? 0}',
      name: 'CloudInferenceWrapper',
    );

    // Call the cloud inference repository and process the stream
    final stream = cloudRepository.generate(
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
              // For now, we'll let it pass through and let the conversation processor handle it
              // In the future, we might want to split these here
            }
          }
        }
      }
      yield chunk;
    }
  }

  String? _extractContent(dynamic content) {
    if (content == null) return null;

    if (content is String) {
      return content;
    }

    if (content is ChatCompletionUserMessageContent) {
      return ContentExtractionHelper.extractTextFromUserContent(content);
    }

    // Fallback
    return content.toString();
  }
}
