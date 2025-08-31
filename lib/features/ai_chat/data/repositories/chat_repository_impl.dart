import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/domain/models/chat_session.dart';
import 'package:lotti/features/ai_chat/domain/repositories/chat_repository.dart';
import 'package:lotti/features/ai_chat/domain/services/thinking_mode_service.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/repository/ai_chat_repository.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:openai_dart/openai_dart.dart';

final Provider<ChatRepository> chatRepositoryProvider = Provider((ref) {
  return ChatRepositoryImpl(
    aiChatRepository: ref.read(aiChatRepositoryProvider),
    cloudInferenceRepository: ref.read(cloudInferenceRepositoryProvider),
    taskSummaryRepository: ref.read(taskSummaryRepositoryProvider),
    aiConfigRepository: ref.read(aiConfigRepositoryProvider),
    thinkingModeService: ThinkingModeServiceImpl(),
  );
});

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required this.aiChatRepository,
    required this.cloudInferenceRepository,
    required this.taskSummaryRepository,
    required this.aiConfigRepository,
    required this.thinkingModeService,
  });

  final AiChatRepository aiChatRepository;
  final CloudInferenceRepository cloudInferenceRepository;
  final TaskSummaryRepository taskSummaryRepository;
  final AiConfigRepository aiConfigRepository;
  final ThinkingModeService thinkingModeService;

  // In-memory storage for sessions (could be replaced with database storage)
  final Map<String, ChatSession> _sessions = {};
  final Map<String, ChatMessage> _messages = {};

  @override
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

    // Process the message using existing repository
    await aiChatRepository.processMessage(
      message: message,
      previousMessages: previousMessages,
      model: geminiModel,
      provider: geminiProvider,
      cloudRepo: cloudInferenceRepository,
      categoryId: categoryId,
      taskSummaryRepo: taskSummaryRepository,
      onStreamingUpdate: (content) {
        // Process thinking mode if enabled
        var processedContent = content;
        if (enableThinking &&
            thinkingModeService.containsThinkingTags(content)) {
          processedContent = thinkingModeService.removeThinkingTags(content);
        }

        if (!streamController.isClosed) {
          streamController.add(processedContent);
        }
      },
      onComplete: (finalContent) {
        // Process thinking mode if enabled
        var processedContent = finalContent;
        if (enableThinking &&
            thinkingModeService.containsThinkingTags(finalContent)) {
          processedContent =
              thinkingModeService.removeThinkingTags(finalContent);
        }

        if (!streamController.isClosed) {
          streamController
            ..add(processedContent)
            ..close();
        }
        completer.complete();
      },
      onError: (error) {
        if (!streamController.isClosed) {
          streamController.addError(Exception('Chat error: $error'));
        }
        completer.completeError(Exception('Chat error: $error'));
      },
    );

    yield* streamController.stream;
    await completer.future;
  }

  @override
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

  @override
  Future<ChatSession> saveSession(ChatSession session) async {
    _sessions[session.id] = session;

    // Save all messages in the session
    for (final message in session.messages) {
      _messages[message.id] = message;
    }

    return session;
  }

  @override
  Future<ChatSession?> getSession(String sessionId) async {
    return _sessions[sessionId];
  }

  @override
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

  @override
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

  @override
  Future<ChatMessage> saveMessage(ChatMessage message) async {
    _messages[message.id] = message;
    return message;
  }

  @override
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
}
