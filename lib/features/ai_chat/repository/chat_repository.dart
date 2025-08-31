import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/domain/models/chat_session.dart';
import 'package:lotti/features/ai_chat/domain/services/thinking_mode_service.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:openai_dart/openai_dart.dart';

final Provider<ChatRepository> chatRepositoryProvider = Provider((ref) {
  return ChatRepository(
    cloudInferenceRepository: ref.read(cloudInferenceRepositoryProvider),
    taskSummaryRepository: ref.read(taskSummaryRepositoryProvider),
    aiConfigRepository: ref.read(aiConfigRepositoryProvider),
    thinkingModeService: ThinkingModeServiceImpl(),
    loggingService: getIt<LoggingService>(),
  );
});

class ChatRepository {
  ChatRepository({
    required this.cloudInferenceRepository,
    required this.taskSummaryRepository,
    required this.aiConfigRepository,
    required this.thinkingModeService,
    required this.loggingService,
  });

  final CloudInferenceRepository cloudInferenceRepository;
  final TaskSummaryRepository taskSummaryRepository;
  final AiConfigRepository aiConfigRepository;
  final ThinkingModeService thinkingModeService;
  final LoggingService loggingService;

  // In-memory storage for sessions (could be replaced with database storage)
  final Map<String, ChatSession> _sessions = {};
  final Map<String, ChatMessage> _messages = {};

  Stream<String> sendMessage({
    required String message,
    required List<ChatMessage> conversationHistory,
    String? categoryId,
    bool enableThinking = false,
  }) async* {
    if (categoryId == null) {
      throw ArgumentError('categoryId is required for sending messages');
    }

    final completer = Completer<void>();
    final streamController = StreamController<String>();

    // Get AI configuration
    final providers = await aiConfigRepository
        .getConfigsByType(AiConfigType.inferenceProvider);
    final geminiProvider = providers
        .whereType<AiConfigInferenceProvider>()
        .where((p) => p.inferenceProviderType == InferenceProviderType.gemini)
        .firstOrNull;

    if (geminiProvider == null) {
      throw StateError('Gemini provider not configured');
    }

    final models =
        await aiConfigRepository.getConfigsByType(AiConfigType.model);
    final geminiModel = models
        .whereType<AiConfigModel>()
        .where((m) =>
            m.inferenceProviderId == geminiProvider.id &&
            m.providerModelId.contains('flash'))
        .firstOrNull;

    if (geminiModel == null) {
      throw StateError('Gemini Flash model not found');
    }

    // Convert chat messages to OpenAI format
    final previousMessages = conversationHistory
        .where((msg) => msg.role != ChatMessageRole.system)
        .map(_convertToOpenAIMessage)
        .toList();

    try {
      loggingService.captureEvent(
        'Starting chat message processing',
        domain: 'ChatRepository',
        subDomain: 'sendMessage',
      );

      // Build messages list with system prompt and history
      final messages = <ChatCompletionMessage>[
        ChatCompletionMessage.system(
          content: _getSystemMessage(enableThinking),
        ),
        ...previousMessages,
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(message),
        ),
      ];

      // Define tools
      final tools = [TaskSummaryTool.toolDefinition];

      // Build conversation context for the prompt
      final promptParts = <String>[];

      // Add previous messages to maintain context
      for (final msg in previousMessages) {
        if (msg.role == ChatCompletionMessageRole.user) {
          promptParts.add('User: ${msg.content}');
        } else if (msg.role == ChatCompletionMessageRole.assistant) {
          promptParts.add('Assistant: ${msg.content}');
        }
      }

      // Add current message
      promptParts.add('User: $message');

      final fullPrompt = promptParts.join('\n\n');

      // Call AI with tools and full conversation context
      final stream = cloudInferenceRepository.generate(
        fullPrompt,
        model: geminiModel.providerModelId,
        temperature: 0.7,
        baseUrl: geminiProvider.baseUrl,
        apiKey: geminiProvider.apiKey,
        systemMessage: _getSystemMessage(enableThinking),
        provider: geminiProvider,
        tools: tools,
      );

      final contentBuffer = StringBuffer();
      final toolCalls = <ChatCompletionMessageToolCall>[];

      // Process the streaming response
      await for (final chunk in stream) {
        if (chunk.choices?.isNotEmpty ?? false) {
          final delta = chunk.choices!.first.delta;

          // Handle content streaming
          if (delta?.content != null) {
            contentBuffer.write(delta!.content);
            var processedContent = contentBuffer.toString();

            // Process thinking mode if enabled
            if (enableThinking &&
                thinkingModeService.containsThinkingTags(processedContent)) {
              processedContent =
                  thinkingModeService.removeThinkingTags(processedContent);
            }

            if (!streamController.isClosed) {
              streamController.add(processedContent);
            }
          }

          // Collect tool calls
          if (delta?.toolCalls != null) {
            for (final toolCallDelta in delta!.toolCalls!) {
              if (toolCallDelta.function != null) {
                // Find or create tool call
                final existingIndex = toolCallDelta.id != null
                    ? toolCalls.indexWhere((tc) => tc.id == toolCallDelta.id)
                    : -1;

                if (existingIndex >= 0) {
                  // Update existing tool call
                  final existing = toolCalls[existingIndex];
                  toolCalls[existingIndex] = ChatCompletionMessageToolCall(
                    id: existing.id,
                    type: existing.type,
                    function: ChatCompletionMessageFunctionCall(
                      name: existing.function.name,
                      arguments: existing.function.arguments +
                          (toolCallDelta.function!.arguments ?? ''),
                    ),
                  );
                } else {
                  // Add new tool call
                  toolCalls.add(ChatCompletionMessageToolCall(
                    id: toolCallDelta.id ?? 'tool_${toolCalls.length}',
                    type: ChatCompletionMessageToolCallType.function,
                    function: ChatCompletionMessageFunctionCall(
                      name: toolCallDelta.function!.name ?? '',
                      arguments: toolCallDelta.function!.arguments ?? '',
                    ),
                  ));
                }
              }
            }
          }
        }
      }

      // If we have tool calls, process them and get the final response
      if (toolCalls.isNotEmpty) {
        loggingService.captureEvent(
          'Processing ${toolCalls.length} tool calls',
          domain: 'ChatRepository',
          subDomain: 'sendMessage',
        );

        // Add assistant message with tool calls to history
        messages.add(ChatCompletionMessage.assistant(
          toolCalls: toolCalls,
        ));

        // Process each tool call
        for (final toolCall in toolCalls) {
          if (toolCall.function.name == TaskSummaryTool.name) {
            final toolResponse = await _processTaskSummaryTool(
              toolCall: toolCall,
              categoryId: categoryId,
            );

            // Add tool response to messages
            messages.add(ChatCompletionMessage.tool(
              toolCallId: toolCall.id,
              content: toolResponse,
            ));
          }
        }

        // Get final response after tool calls
        if (!streamController.isClosed) {
          streamController.add('Generating response...');
        }

        // Convert full conversation including tool results to prompt
        final finalPromptParts = <String>[];

        // Include all messages for context
        for (final msg in messages) {
          if (msg.role == ChatCompletionMessageRole.user) {
            finalPromptParts.add('User: ${msg.content}');
          } else if (msg.role == ChatCompletionMessageRole.assistant &&
              msg.content != null) {
            finalPromptParts.add('Assistant: ${msg.content}');
          } else if (msg.role == ChatCompletionMessageRole.tool) {
            finalPromptParts.add('Tool response: ${msg.content}');
          }
        }

        finalPromptParts.add(
            'Based on the conversation and tool results above, provide a helpful response to the user.');

        final finalStream = cloudInferenceRepository.generate(
          finalPromptParts.join('\n\n'),
          model: geminiModel.providerModelId,
          temperature: 0.7,
          baseUrl: geminiProvider.baseUrl,
          apiKey: geminiProvider.apiKey,
          systemMessage: _getSystemMessage(enableThinking),
          provider: geminiProvider,
        );

        final finalBuffer = StringBuffer();
        await for (final chunk in finalStream) {
          if (chunk.choices?.isNotEmpty ?? false) {
            final delta = chunk.choices!.first.delta;
            if (delta?.content != null) {
              finalBuffer.write(delta!.content);
              var processedContent = finalBuffer.toString();

              // Process thinking mode if enabled
              if (enableThinking &&
                  thinkingModeService.containsThinkingTags(processedContent)) {
                processedContent =
                    thinkingModeService.removeThinkingTags(processedContent);
              }

              if (!streamController.isClosed) {
                streamController.add(processedContent);
              }
            }
          }
        }

        if (!streamController.isClosed) {
          await streamController.close();
        }
        completer.complete();
      } else {
        // No tool calls, just close the stream
        if (!streamController.isClosed) {
          await streamController.close();
        }
        completer.complete();
      }
    } catch (e, stackTrace) {
      loggingService.captureException(
        e,
        domain: 'ChatRepository',
        subDomain: 'sendMessage',
        stackTrace: stackTrace,
      );

      if (!streamController.isClosed) {
        streamController.addError(Exception('Chat error: $e'));
      }
      completer.completeError(Exception('Chat error: $e'));
    }

    yield* streamController.stream;
    await completer.future;
  }

  Future<ChatSession> createSession({
    String? categoryId,
    String? title,
  }) async {
    final session = ChatSession.create(
      categoryId: categoryId,
      title: title,
    );

    _sessions[session.id] = session;
    return session;
  }

  Future<ChatSession> saveSession(ChatSession session) async {
    _sessions[session.id] = session;

    // Save all messages in the session
    for (final message in session.messages) {
      _messages[message.id] = message;
    }

    return session;
  }

  Future<ChatSession?> getSession(String sessionId) async {
    return _sessions[sessionId];
  }

  Future<List<ChatSession>> getSessions({
    String? categoryId,
    int limit = 20,
  }) async {
    var sessions = _sessions.values.toList();

    if (categoryId != null) {
      sessions = sessions.where((s) => s.categoryId == categoryId).toList();
    }

    // Sort by last message time, most recent first
    sessions.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    if (sessions.length > limit) {
      sessions = sessions.take(limit).toList();
    }

    return sessions;
  }

  Future<void> deleteSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session != null) {
      // Delete all messages in the session
      for (final message in session.messages) {
        _messages.remove(message.id);
      }

      _sessions.remove(sessionId);
    }
  }

  Future<ChatMessage> saveMessage(ChatMessage message) async {
    _messages[message.id] = message;
    return message;
  }

  Future<void> deleteMessage(String messageId) async {
    _messages.remove(messageId);
  }

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

  Future<String> _processTaskSummaryTool({
    required ChatCompletionMessageToolCall toolCall,
    required String categoryId,
  }) async {
    try {
      final args =
          jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;

      final request = TaskSummaryRequest(
        startDate: DateTime.parse(args['start_date'] as String),
        endDate: DateTime.parse(args['end_date'] as String),
        limit: (args['limit'] as int?) ?? 100,
      );

      loggingService.captureEvent(
        'Processing task summary tool call',
        domain: 'ChatRepository',
        subDomain: '_processTaskSummaryTool',
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
        domain: 'ChatRepository',
        subDomain: '_processTaskSummaryTool',
        stackTrace: stackTrace,
      );

      return jsonEncode({
        'error': 'Failed to retrieve task summaries: $e',
      });
    }
  }

  String _getSystemMessage(bool enableThinking) {
    final baseMessage = '''
You are an AI assistant helping users explore and understand their tasks.
You have access to a tool that can retrieve task summaries for specified date ranges.
When users ask about their tasks, use the get_task_summaries tool to fetch relevant information.

Today's date is ${DateTime.now().toIso8601String().split('T')[0]}.

When interpreting time-based queries, use these guidelines:
- "today" = from start of today to end of today
- "yesterday" = from start of yesterday to end of yesterday
- "this week" = last 7 days including today
- "recently" or "lately" = last 14 days
- "this month" = last 30 days
- "last week" = the previous 7-day period (8-14 days ago)
- "last month" = the previous 30-day period (31-60 days ago)

For date ranges, always use full ISO 8601 timestamps:
- start_date: beginning of the day, e.g., "2025-08-26T00:00:00.000"
- end_date: end of the day, e.g., "2025-08-26T23:59:59.999"

Example: For "yesterday" on 2025-08-27, use:
- start_date: "2025-08-26T00:00:00.000"
- end_date: "2025-08-26T23:59:59.999"

Be concise but helpful in your responses. When showing task summaries, organize them by date and status for clarity.''';

    if (!enableThinking) {
      return baseMessage;
    }

    return thinkingModeService.enhanceSystemPrompt(baseMessage,
        useThinking: enableThinking);
  }
}
