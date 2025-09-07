import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_exceptions.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/chat_message_processor.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/features/ai_chat/services/system_message_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:openai_dart/openai_dart.dart';

final Provider<ChatRepository> chatRepositoryProvider = Provider((ref) {
  return ChatRepository(
    cloudInferenceRepository: ref.read(cloudInferenceRepositoryProvider),
    taskSummaryRepository: ref.read(taskSummaryRepositoryProvider),
    aiConfigRepository: ref.read(aiConfigRepositoryProvider),
    systemMessageService: ref.read(systemMessageServiceProvider),
    loggingService: getIt<LoggingService>(),
  );
});

class ChatRepository {
  ChatRepository({
    required this.cloudInferenceRepository,
    required this.taskSummaryRepository,
    required this.aiConfigRepository,
    required this.systemMessageService,
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
  final SystemMessageService systemMessageService;
  final LoggingService loggingService;
  final ChatMessageProcessor _messageProcessor;

  static const int defaultSessionLimit = 20;
  static const int defaultSearchLimit = 50;

  // In-memory storage for sessions (could be replaced with database storage)
  final Map<String, ChatSession> _sessions = {};
  final Map<String, ChatMessage> _messages = {};

  Stream<String> sendMessage({
    required String message,
    required List<ChatMessage> conversationHistory,
    required String modelId,
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

      // Get AI configuration for the specified model
      final config =
          await _messageProcessor.getAiConfigurationForModel(modelId);
      final systemMessage = systemMessageService.getSystemMessage();

      // Convert conversation history and build messages
      final previousMessages =
          _messageProcessor.convertConversationHistory(conversationHistory);
      final messages = _messageProcessor.buildMessagesList(
        previousMessages,
        message,
        systemMessage,
      );

      // Build conversation context for the prompt (string with history)
      final fullPrompt =
          _messageProcessor.buildPromptFromMessages(previousMessages, message);
      final tools = [TaskSummaryTool.toolDefinition];

      // Initial response stream
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

      // Accumulate tool calls while streaming content to UI
      final toolCalls = <ChatCompletionMessageToolCall>[];
      final toolCallArgBuffers = <String, StringBuffer>{};

      await for (final chunk in stream) {
        if (chunk.choices?.isNotEmpty ?? false) {
          final delta = chunk.choices!.first.delta;

          // Stream content deltas directly to UI
          final content = delta?.content;
          if (content != null && content.isNotEmpty) {
            yield content;
          }

          // Accumulate tool call deltas
          if (delta?.toolCalls != null) {
            _messageProcessor.accumulateToolCalls(
              toolCalls,
              delta!.toolCalls!,
              toolCallArgBuffers,
            );
          }
        }
      }

      // If we have tool calls, process them and then stream the final response
      if (toolCalls.isNotEmpty) {
        // Add assistant message with tool calls to history
        messages.add(
          ChatCompletionMessage.assistant(toolCalls: toolCalls),
        );

        // Process tool calls (fetch data, etc.)
        final toolResults = await _messageProcessor.processToolCalls(
          toolCalls,
          categoryId,
        );
        messages.addAll(toolResults);

        // Stream the final response generated from tool results
        await for (final finalDelta
            in _messageProcessor.generateFinalResponseStream(
          messages: messages,
          config: config,
          systemMessage: systemMessage,
        )) {
          yield finalDelta;
        }
      }
    } catch (e, stackTrace) {
      loggingService.captureException(
        e,
        domain: 'ChatRepository',
        subDomain: 'sendMessage',
        stackTrace: stackTrace,
      );
      throw ChatRepositoryException('Failed to send message: $e', e);
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
    int limit = defaultSessionLimit,
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
    int limit = defaultSearchLimit,
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
}
