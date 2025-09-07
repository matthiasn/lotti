import 'dart:async';
import 'dart:convert';

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:openai_dart/openai_dart.dart';

/// Configuration data needed for AI inference
class AiInferenceConfig {
  const AiInferenceConfig({
    required this.provider,
    required this.model,
  });

  final AiConfigInferenceProvider provider;
  final AiConfigModel model;
}

/// Result of processing a stream response
class StreamProcessingResult {
  const StreamProcessingResult({
    required this.content,
    required this.toolCalls,
  });

  final String content;
  final List<ChatCompletionMessageToolCall> toolCalls;
}

/// Helper class to extract testable units from ChatRepository's sendMessage logic
class ChatMessageProcessor {
  ChatMessageProcessor({
    required this.aiConfigRepository,
    required this.cloudInferenceRepository,
    required this.taskSummaryRepository,
    required this.loggingService,
  });

  final AiConfigRepository aiConfigRepository;
  final CloudInferenceRepository cloudInferenceRepository;
  final TaskSummaryRepository taskSummaryRepository;
  final LoggingService loggingService;

  // Cache for AI configuration per model
  AiInferenceConfig? _cachedConfig;
  DateTime? _configCacheTime;
  String? _cachedModelId;

  /// Get AI configuration for a specific model (provider + model), cached per model
  Future<AiInferenceConfig> getAiConfigurationForModel(String modelId) async {
    const cacheDuration = Duration(minutes: 5); // Cache for 5 minutes

    if (_cachedConfig != null &&
        _cachedModelId == modelId &&
        _configCacheTime != null &&
        DateTime.now().difference(_configCacheTime!) < cacheDuration) {
      return _cachedConfig!;
    }

    final modelConfig = await aiConfigRepository.getConfigById(modelId);
    if (modelConfig is! AiConfigModel) {
      throw StateError('Model not found: $modelId');
    }
    if (!modelConfig.supportsFunctionCalling) {
      throw StateError('Selected model does not support function calling');
    }

    final providerConfig = await aiConfigRepository.getConfigById(
      modelConfig.inferenceProviderId,
    );
    if (providerConfig is! AiConfigInferenceProvider) {
      throw StateError(
          'Provider not found: ${modelConfig.inferenceProviderId}');
    }

    final config =
        AiInferenceConfig(provider: providerConfig, model: modelConfig);
    _cachedConfig = config;
    _cachedModelId = modelId;
    _configCacheTime = DateTime.now();
    return config;
  }

  /// Clear the cached configuration (useful for testing or config changes)
  void clearConfigCache() {
    _cachedConfig = null;
    _configCacheTime = null;
    _cachedModelId = null;
  }

  /// Backwards-compatible configuration getter used by some tests/utilities.
  /// Picks the first function-calling text model and resolves its provider.
  /// Not used by chat UI (which requires explicit model selection).
  Future<AiInferenceConfig> getAiConfiguration() async {
    if (_cachedConfig != null && _cachedModelId != null) {
      return _cachedConfig!;
    }

    final models =
        await aiConfigRepository.getConfigsByType(AiConfigType.model);
    final model = models.whereType<AiConfigModel>().firstWhere(
          (m) =>
              m.supportsFunctionCalling &&
              m.inputModalities.contains(Modality.text),
          orElse: () => throw StateError('No eligible models configured'),
        );
    final provider = await aiConfigRepository.getConfigById(
      model.inferenceProviderId,
    );
    if (provider is! AiConfigInferenceProvider) {
      throw StateError('Provider not found: ${model.inferenceProviderId}');
    }
    final config = AiInferenceConfig(provider: provider, model: model);
    _cachedConfig = config;
    _cachedModelId = model.id;
    _configCacheTime = DateTime.now();
    return config;
  }

  /// Convert conversation history to OpenAI messages, filtering out system messages
  List<ChatCompletionMessage> convertConversationHistory(
    List<ChatMessage> conversationHistory,
  ) {
    return conversationHistory
        .where((msg) => msg.role != ChatMessageRole.system)
        .map(_convertToOpenAIMessage)
        .toList();
  }

  /// Build messages list with system prompt and history
  List<ChatCompletionMessage> buildMessagesList(
    List<ChatCompletionMessage> previousMessages,
    String message,
    String systemMessage,
  ) {
    return <ChatCompletionMessage>[
      ChatCompletionMessage.system(content: systemMessage),
      ...previousMessages,
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(message),
      ),
    ];
  }

  /// Build conversation context for the prompt
  String buildPromptFromMessages(
    List<ChatCompletionMessage> previousMessages,
    String message,
  ) {
    final promptParts = <String>[];

    // Add previous messages to maintain context
    for (final msg in previousMessages) {
      if (msg.role == ChatCompletionMessageRole.user) {
        final content = msg.content is ChatCompletionUserMessageContent
            ? (msg.content! as ChatCompletionUserMessageContent).whenOrNull(
                  string: (text) => text,
                ) ??
                msg.content.toString()
            : msg.content?.toString() ?? '';
        promptParts.add('User: $content');
      } else if (msg.role == ChatCompletionMessageRole.assistant) {
        promptParts.add('Assistant: ${msg.content}');
      }
    }

    // Add current message
    promptParts.add('User: $message');

    return promptParts.join('\n\n');
  }

  /// Process stream response and extract content and tool calls
  Future<StreamProcessingResult> processStreamResponse(
    Stream<CreateChatCompletionStreamResponse> stream,
  ) async {
    final contentBuffer = StringBuffer();
    final toolCalls = <ChatCompletionMessageToolCall>[];
    // Buffer for accumulating tool call arguments by ID
    final toolCallArgumentBuffers = <String, StringBuffer>{};

    await for (final chunk in stream) {
      if (chunk.choices?.isNotEmpty ?? false) {
        final delta = chunk.choices!.first.delta;

        // Handle content streaming
        if (delta?.content != null) {
          contentBuffer.write(delta!.content);
        }

        // Collect tool calls
        if (delta?.toolCalls != null) {
          accumulateToolCalls(
              toolCalls, delta!.toolCalls!, toolCallArgumentBuffers);
        }
      }
    }

    return StreamProcessingResult(
      content: contentBuffer.toString(),
      toolCalls: toolCalls,
    );
  }

  /// Accumulate tool calls from deltas
  void accumulateToolCalls(
    List<ChatCompletionMessageToolCall> toolCalls,
    List<ChatCompletionStreamMessageToolCallChunk> toolCallDeltas,
    Map<String, StringBuffer> argumentBuffers,
  ) {
    for (final toolCallDelta in toolCallDeltas) {
      if (toolCallDelta.function != null) {
        final toolId = toolCallDelta.id ?? 'tool_${toolCalls.length}';

        // Initialize buffer for this tool call if needed
        argumentBuffers.putIfAbsent(toolId, StringBuffer.new);

        // Append arguments to buffer
        if (toolCallDelta.function?.arguments != null) {
          argumentBuffers[toolId]!.write(toolCallDelta.function!.arguments);
        }

        // Find or create tool call
        final existingIndex = toolCalls.indexWhere((tc) => tc.id == toolId);

        if (existingIndex >= 0) {
          // Update existing tool call with accumulated arguments
          final existing = toolCalls[existingIndex];
          toolCalls[existingIndex] = ChatCompletionMessageToolCall(
            id: existing.id,
            type: existing.type,
            function: ChatCompletionMessageFunctionCall(
              name: toolCallDelta.function?.name ?? existing.function.name,
              arguments: argumentBuffers[toolId]!.toString(),
            ),
          );
        } else {
          // Add new tool call
          toolCalls.add(ChatCompletionMessageToolCall(
            id: toolId,
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: toolCallDelta.function?.name ?? '',
              arguments: argumentBuffers[toolId]!.toString(),
            ),
          ));
        }
      }
    }
  }

  /// Process multiple tool calls and return tool response messages
  Future<List<ChatCompletionMessage>> processToolCalls(
    List<ChatCompletionMessageToolCall> toolCalls,
    String categoryId,
  ) async {
    loggingService.captureEvent(
      'Processing ${toolCalls.length} tool calls',
      domain: 'ChatMessageProcessor',
      subDomain: 'processToolCalls',
    );

    final toolMessages = <ChatCompletionMessage>[];

    for (final toolCall in toolCalls) {
      if (toolCall.function.name == TaskSummaryTool.name) {
        final toolResponse = await processTaskSummaryTool(
          toolCall: toolCall,
          categoryId: categoryId,
        );

        toolMessages.add(ChatCompletionMessage.tool(
          toolCallId: toolCall.id,
          content: toolResponse,
        ));
      }
    }

    return toolMessages;
  }

  /// Process a single task summary tool call
  Future<String> processTaskSummaryTool({
    required ChatCompletionMessageToolCall toolCall,
    required String categoryId,
  }) async {
    try {
      final args =
          jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;

      final request = TaskSummaryRequest.fromJson(args);

      loggingService.captureEvent(
        'Processing task summary tool call',
        domain: 'ChatMessageProcessor',
        subDomain: 'processTaskSummaryTool',
      );

      final summaries = await taskSummaryRepository.getTaskSummaries(
        categoryId: categoryId,
        request: request,
      );

      if (summaries.isEmpty) {
        return jsonEncode({
          'message': 'No tasks found in the specified date range.',
          'date_range': {
            'start': args['start_date'],
            'end': args['end_date'],
          },
          'debug': {
            'categoryId': categoryId,
            'requestedStart': request.startDate.toIso8601String(),
            'requestedEnd': request.endDate.toIso8601String(),
          },
        });
      }

      final response = summaries
          .map((s) => {
                'task_id': s.taskId,
                'title': s.taskTitle,
                'summary': s.summary,
                'date': s.taskDate.toIso8601String(),
                'status': s.status,
                'metadata': s.metadata,
              })
          .toList();

      return jsonEncode({
        'tasks': response,
        'count': summaries.length,
        'date_range': {
          'start': args['start_date'],
          'end': args['end_date'],
        },
      });
    } catch (e, stackTrace) {
      loggingService.captureException(
        e,
        domain: 'ChatMessageProcessor',
        subDomain: 'processTaskSummaryTool',
        stackTrace: stackTrace,
      );

      return jsonEncode({
        'error': 'Failed to retrieve task summaries: $e',
      });
    }
  }

  /// Build final prompt from all messages including tool results
  String buildFinalPromptFromMessages(List<ChatCompletionMessage> messages) {
    final finalPromptParts = <String>[];

    // Include all messages for context
    for (final msg in messages) {
      if (msg.role == ChatCompletionMessageRole.user) {
        final content = msg.content is ChatCompletionUserMessageContent
            ? (msg.content! as ChatCompletionUserMessageContent).whenOrNull(
                  string: (text) => text,
                ) ??
                msg.content.toString()
            : msg.content?.toString() ?? '';
        finalPromptParts.add('User: $content');
      } else if (msg.role == ChatCompletionMessageRole.assistant &&
          msg.content != null) {
        finalPromptParts.add('Assistant: ${msg.content}');
      } else if (msg.role == ChatCompletionMessageRole.tool) {
        finalPromptParts.add('Tool response: ${msg.content}');
      }
    }

    finalPromptParts.add(
        'Based on the conversation and tool results above, provide a helpful response to the user.');

    return finalPromptParts.join('\n\n');
  }

  /// Generate final response after tool calls
  Future<String> generateFinalResponse({
    required List<ChatCompletionMessage> messages,
    required AiInferenceConfig config,
    required String systemMessage,
  }) async {
    final finalPrompt = buildFinalPromptFromMessages(messages);

    final finalStream = cloudInferenceRepository.generate(
      finalPrompt,
      model: config.model.providerModelId,
      temperature: 0.7,
      baseUrl: config.provider.baseUrl,
      apiKey: config.provider.apiKey,
      systemMessage: systemMessage,
      provider: config.provider,
    );

    final finalResult = await processStreamResponse(finalStream);

    return finalResult.content;
  }

  /// Convert ChatMessage to OpenAI ChatCompletionMessage
  ChatCompletionMessage _convertToOpenAIMessage(ChatMessage message) {
    switch (message.role) {
      case ChatMessageRole.user:
        return ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(message.content),
        );
      case ChatMessageRole.assistant:
        return ChatCompletionMessage.assistant(
          content: message.content,
        );
      case ChatMessageRole.system:
        return ChatCompletionMessage.system(
          content: message.content,
        );
    }
  }
}
