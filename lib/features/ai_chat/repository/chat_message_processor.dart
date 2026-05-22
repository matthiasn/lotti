import 'dart:async';
import 'dart:convert';

import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// A clock function used for time-dependent logic.
///
/// Defaults to `DateTime.now`, but can be injected in tests to ensure
/// deterministic behavior (e.g. for cache-expiry checks) or to simulate
/// specific points in time without relying on real wall-clock time.
typedef Now = DateTime Function();

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
  final List<AiToolCall> toolCalls;
}

/// Helper class to extract testable units from ChatRepository's sendMessage logic
class ChatMessageProcessor {
  ChatMessageProcessor({
    required this.aiConfigRepository,
    required this.cloudInferenceRepository,
    required this.taskSummaryRepository,
    required this.loggingService,
    Now? now,
  }) : _now = now ?? DateTime.now;

  final AiConfigRepository aiConfigRepository;
  final CloudInferenceRepository cloudInferenceRepository;
  final TaskSummaryRepository taskSummaryRepository;
  final DomainLogger loggingService;

  // Cache for AI configuration per model
  static const Duration configCacheDuration = Duration(minutes: 5);
  AiInferenceConfig? _cachedConfig;
  DateTime? _configCacheTime;
  String? _cachedModelId;
  final Now _now;

  /// Get AI configuration for a specific model (provider + model), cached per model
  Future<AiInferenceConfig> getAiConfigurationForModel(String modelId) async {
    if (_cachedConfig != null &&
        _cachedModelId == modelId &&
        _configCacheTime != null &&
        _now().difference(_configCacheTime!) < configCacheDuration) {
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
        'Provider not found: ${modelConfig.inferenceProviderId}',
      );
    }

    final config = AiInferenceConfig(
      provider: providerConfig,
      model: modelConfig,
    );
    _cachedConfig = config;
    _cachedModelId = modelId;
    _configCacheTime = _now();
    return config;
  }

  /// Clear the cached configuration (useful for testing or config changes)
  void clearConfigCache() {
    _cachedConfig = null;
    _configCacheTime = null;
    _cachedModelId = null;
  }

  /// Convert UI chat history into provider messages, dropping system entries.
  List<AiChatMessage> convertConversationHistory(
    List<ChatMessage> conversationHistory,
  ) {
    return conversationHistory
        .where((msg) => msg.role != ChatMessageRole.system)
        .map(_convertToProviderMessage)
        .toList();
  }

  /// Build a messages list with system prompt and history.
  List<AiChatMessage> buildMessagesList(
    List<AiChatMessage> previousMessages,
    String message,
    String systemMessage,
  ) {
    return <AiChatMessage>[
      AiSystemMessage(systemMessage),
      ...previousMessages,
      AiUserMessage(AiUserTextContent(message)),
    ];
  }

  List<String> _buildConversationContextLines(List<AiChatMessage> messages) {
    final parts = <String>[];
    for (final msg in messages) {
      final line = switch (msg) {
        AiUserMessage(:final content) => 'User: ${_extractUserText(content)}',
        AiAssistantMessage(:final content) when content != null =>
          'Assistant: $content',
        AiAssistantMessage() => null,
        AiToolResultMessage(:final content) => 'Tool response: $content',
        AiSystemMessage() => null,
      };
      if (line != null) parts.add(line);
    }
    return parts;
  }

  String _extractUserText(AiUserContent content) {
    return switch (content) {
      AiUserTextContent(:final text) => text,
      AiUserPartsContent(:final parts) =>
        parts.whereType<AiTextPart>().map((p) => p.text).join(' '),
    };
  }

  /// Build conversation context for the prompt.
  String buildPromptFromMessages(
    List<AiChatMessage> previousMessages,
    String message,
  ) {
    final promptParts = _buildConversationContextLines(previousMessages)
      ..add('User: $message');
    return promptParts.join('\n\n');
  }

  /// Process a provider stream and extract both visible content and
  /// accumulated tool calls.
  ///
  /// The returned `content` is the full concatenation of content deltas.
  /// Tool call arguments are accumulated across deltas by tool id.
  ///
  /// Note: Reasoning/thinking text (if present) is not stripped here.
  /// The chat UI uses `thinking_parser.dart` to hide/show thinking blocks
  /// without altering provider semantics.
  Future<StreamProcessingResult> processStreamResponse(
    Stream<AiStreamChunk> stream,
  ) async {
    final contentBuffer = StringBuffer();
    final toolCalls = <AiToolCall>[];
    final toolCallArgumentBuffers = <String, StringBuffer>{};

    await for (final chunk in stream) {
      if (chunk.choices.isEmpty) continue;
      final delta = chunk.choices.first.delta;

      if (delta.content != null) contentBuffer.write(delta.content);

      final chunks = delta.toolCalls;
      if (chunks != null) {
        accumulateToolCalls(toolCalls, chunks, toolCallArgumentBuffers);
      }
    }

    return StreamProcessingResult(
      content: contentBuffer.toString(),
      toolCalls: toolCalls,
    );
  }

  /// Accumulate tool calls from deltas.
  ///
  /// For a given tool id, arguments are appended until the tool call is
  /// complete. The method is idempotent across multiple invocations on the
  /// same buffers.
  void accumulateToolCalls(
    List<AiToolCall> toolCalls,
    List<AiToolCallChunk> toolCallDeltas,
    Map<String, StringBuffer> argumentBuffers,
  ) {
    for (final toolCallDelta in toolCallDeltas) {
      // A chunk is meaningful only if it carries a name or arguments delta.
      if (toolCallDelta.name == null && toolCallDelta.arguments == null) {
        continue;
      }

      // Use a stable deterministic id within the stream. Prefer provided id;
      // otherwise derive one from index. Skip as malformed if neither.
      final toolId =
          toolCallDelta.id ??
          (toolCallDelta.index != null ? 'tool_${toolCallDelta.index}' : null);
      if (toolId == null) {
        loggingService.log(
          LogDomain.chat,
          'Malformed tool call stream: missing id and index. delta: $toolCallDelta',
          subDomain: 'accumulateToolCalls',
        );
        continue;
      }

      argumentBuffers.putIfAbsent(toolId, StringBuffer.new);

      // Append arguments. If both existing and incoming are complete JSON
      // objects, replace instead of concatenating — guards against providers
      // that resend full args.
      final incoming = toolCallDelta.arguments;
      if (incoming != null) {
        final buf = argumentBuffers[toolId]!;
        if (_isCompleteJson(incoming) && _isCompleteJson(buf.toString())) {
          argumentBuffers[toolId] = StringBuffer(incoming);
        } else {
          buf.write(incoming);
        }
      }

      final existingIndex = toolCalls.indexWhere((tc) => tc.id == toolId);
      if (existingIndex >= 0) {
        final existing = toolCalls[existingIndex];
        toolCalls[existingIndex] = AiToolCall(
          id: existing.id,
          name: toolCallDelta.name ?? existing.name,
          arguments: argumentBuffers[toolId]!.toString(),
        );
      } else {
        toolCalls.add(
          AiToolCall(
            id: toolId,
            name: toolCallDelta.name ?? '',
            arguments: argumentBuffers[toolId]!.toString(),
          ),
        );
      }
    }
  }

  /// Process multiple tool calls and return tool response messages.
  Future<List<AiChatMessage>> processToolCalls(
    List<AiToolCall> toolCalls,
    String categoryId,
  ) async {
    loggingService.log(
      LogDomain.chat,
      'Processing ${toolCalls.length} tool calls',
      subDomain: 'processToolCalls',
    );

    final toolMessages = <AiChatMessage>[];

    for (final toolCall in toolCalls) {
      if (toolCall.name == TaskSummaryTool.name) {
        final toolResponse = await processTaskSummaryTool(
          toolCall: toolCall,
          categoryId: categoryId,
        );

        toolMessages.add(
          AiToolResultMessage(
            toolCallId: toolCall.id,
            content: toolResponse,
          ),
        );
      }
    }

    return toolMessages;
  }

  /// Process a single task summary tool call.
  Future<String> processTaskSummaryTool({
    required AiToolCall toolCall,
    required String categoryId,
  }) async {
    try {
      final args = jsonDecode(toolCall.arguments) as Map<String, dynamic>;

      final request = TaskSummaryRequest.fromJson(args);

      loggingService.log(
        LogDomain.chat,
        'Processing task summary tool call',
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
            'requestedStart': request.startDate,
            'requestedEnd': request.endDate,
          },
        });
      }

      final response = summaries
          .map(
            (s) => {
              'task_id': s.taskId,
              'title': s.taskTitle,
              'summary': s.summary,
              'date': s.taskDate.toIso8601String(),
              'status': s.status,
              'metadata': s.metadata,
            },
          )
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
      loggingService.error(
        LogDomain.chat,
        e,
        stackTrace: stackTrace,
        subDomain: 'processTaskSummaryTool',
      );

      return jsonEncode({
        'error': 'Failed to retrieve task summaries: $e',
      });
    }
  }

  /// Build final prompt from all messages including tool results.
  String buildFinalPromptFromMessages(List<AiChatMessage> messages) {
    final parts = _buildConversationContextLines(messages)
      ..add(
        'Based on the conversation and tool results above, provide a helpful response to the user.',
      );
    return parts.join('\n\n');
  }

  /// Generate final response after tool calls.
  Future<String> generateFinalResponse({
    required List<AiChatMessage> messages,
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
      geminiThinkingMode: config.model.geminiThinkingMode,
    );

    final finalResult = await processStreamResponse(finalStream);

    return finalResult.content;
  }

  /// Generate final response after tool calls, streaming content chunks.
  Stream<String> generateFinalResponseStream({
    required List<AiChatMessage> messages,
    required AiInferenceConfig config,
    required String systemMessage,
  }) async* {
    final finalPrompt = buildFinalPromptFromMessages(messages);

    final finalStream = cloudInferenceRepository.generate(
      finalPrompt,
      model: config.model.providerModelId,
      temperature: 0.7,
      baseUrl: config.provider.baseUrl,
      apiKey: config.provider.apiKey,
      systemMessage: systemMessage,
      provider: config.provider,
      geminiThinkingMode: config.model.geminiThinkingMode,
    );

    await for (final chunk in finalStream) {
      if (chunk.choices.isEmpty) continue;
      final content = chunk.choices.first.delta.content;
      if (content != null && content.isNotEmpty) {
        yield content;
      }
    }
  }

  /// Convert UI [ChatMessage] to provider [AiChatMessage].
  AiChatMessage _convertToProviderMessage(ChatMessage message) {
    return switch (message.role) {
      ChatMessageRole.user => AiUserMessage(AiUserTextContent(message.content)),
      ChatMessageRole.assistant => AiAssistantMessage(content: message.content),
      ChatMessageRole.system => AiSystemMessage(message.content),
    };
  }
}

// Checks whether a string parses to a JSON object (Map).
bool _isCompleteJson(String s) {
  try {
    final decoded = jsonDecode(s);
    return decoded is Map;
  } catch (_) {
    return false;
  }
}
