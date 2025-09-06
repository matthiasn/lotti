import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/chat_message_processor.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:openai_dart/openai_dart.dart';

final Provider<ChatRepository> chatRepositoryProvider = Provider((ref) {
  return ChatRepository(
    cloudInferenceRepository: ref.read(cloudInferenceRepositoryProvider),
    taskSummaryRepository: ref.read(taskSummaryRepositoryProvider),
    aiConfigRepository: ref.read(aiConfigRepositoryProvider),
    loggingService: getIt<LoggingService>(),
  );
});

class ChatRepository {
  ChatRepository({
    required this.cloudInferenceRepository,
    required this.taskSummaryRepository,
    required this.aiConfigRepository,
    required this.loggingService,
  }) : _messageProcessor = ChatMessageProcessor(
          aiConfigRepository: aiConfigRepository,
          cloudInferenceRepository: cloudInferenceRepository,
          taskSummaryRepository: taskSummaryRepository,
          loggingService: loggingService,
        );

  final CloudInferenceRepository cloudInferenceRepository;
  final TaskSummaryRepository taskSummaryRepository;
  final AiConfigRepository aiConfigRepository;
  final LoggingService loggingService;
  final ChatMessageProcessor _messageProcessor;

  // In-memory storage for sessions (could be replaced with database storage)
  final Map<String, ChatSession> _sessions = {};
  final Map<String, ChatMessage> _messages = {};

  Stream<String> sendMessage({
    required String message,
    required List<ChatMessage> conversationHistory,
    String? categoryId,
  }) async* {
    if (categoryId == null) {
      throw ArgumentError('categoryId is required for sending messages');
    }

    try {
      loggingService.captureEvent(
        'Starting chat message processing',
        domain: 'ChatRepository',
        subDomain: 'sendMessage',
      );

      // Get AI configuration
      final config = await _messageProcessor.getAiConfiguration();
      final systemMessage = _getSystemMessage();

      // Convert conversation history and build messages
      final previousMessages =
          _messageProcessor.convertConversationHistory(conversationHistory);
      final messages = _messageProcessor.buildMessagesList(
          previousMessages, message, systemMessage);

      // Build conversation context for the prompt
      final fullPrompt =
          _messageProcessor.buildPromptFromMessages(previousMessages, message);
      final tools = [TaskSummaryTool.toolDefinition];

      // Get initial response stream
      final stream = cloudInferenceRepository.generate(
        fullPrompt,
        model: config.model.providerModelId,
        temperature: 0.7,
        baseUrl: config.provider.baseUrl,
        apiKey: config.provider.apiKey,
        systemMessage: systemMessage,
        provider: config.provider,
        tools: tools,
      );

      // Process the initial stream
      final streamResult =
          await _messageProcessor.processStreamResponse(stream);

      // Yield content from initial response
      if (streamResult.content.isNotEmpty) {
        yield streamResult.content;
      }

      // If we have tool calls, process them and get final response
      if (streamResult.toolCalls.isNotEmpty) {
        // Add assistant message with tool calls to history
        messages.add(ChatCompletionMessage.assistant(
          toolCalls: streamResult.toolCalls,
        ));

        // Process tool calls
        final toolResults = await _messageProcessor.processToolCalls(
          streamResult.toolCalls,
          categoryId,
        );
        messages.addAll(toolResults);

        // Generate final response
        yield 'Generating response...';

        final finalResponse = await _messageProcessor.generateFinalResponse(
          messages: messages,
          config: config,
          systemMessage: systemMessage,
        );

        if (finalResponse.isNotEmpty) {
          yield finalResponse;
        }
      }
    } catch (e, stackTrace) {
      loggingService.captureException(
        e,
        domain: 'ChatRepository',
        subDomain: 'sendMessage',
        stackTrace: stackTrace,
      );
      throw Exception('Chat error: $e');
    }
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

  /// Search sessions by title or message content with optimized filtering
  Future<List<ChatSession>> searchSessions({
    required String query,
    String? categoryId,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) {
      return getSessions(categoryId: categoryId, limit: limit);
    }

    final lowercaseQuery = query.toLowerCase();
    var sessions = _sessions.values.toList();

    // Filter by category first
    if (categoryId != null) {
      sessions = sessions.where((s) => s.categoryId == categoryId).toList();
    }

    // Filter by search query (title or message content)
    final matchingSessions = sessions.where((session) {
      // Check title match
      if (session.title.toLowerCase().contains(lowercaseQuery)) {
        return true;
      }

      // Check message content match
      return session.messages.any(
          (message) => message.content.toLowerCase().contains(lowercaseQuery));
    }).toList()

      // Sort by last message time, most recent first
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    // Apply limit
    return matchingSessions.length > limit
        ? matchingSessions.take(limit).toList()
        : matchingSessions;
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

  String _getSystemMessage() {
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

    return baseMessage;
  }
}
