import 'package:lotti/features/ai_chat/data/repositories/chat_repository_impl.dart';
import 'package:lotti/features/ai_chat/domain/models/chat_session.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'chat_session_controller.g.dart';

@riverpod
class ChatSessionController extends _$ChatSessionController {
  final LoggingService _loggingService = getIt<LoggingService>();
  String? _currentStreamingMessageId;

  @override
  ChatSessionUiModel build(String categoryId) {
    return ChatSessionUiModel.empty();
  }

  /// Initialize or load an existing chat session
  Future<void> initializeSession({String? sessionId}) async {
    try {
      final chatRepository = ref.read(chatRepositoryProvider);

      ChatSession session;
      if (sessionId != null) {
        final existingSession = await chatRepository.getSession(sessionId);
        session = existingSession ??
            await chatRepository.createSession(categoryId: categoryId);
      } else {
        session = await chatRepository.createSession(categoryId: categoryId);
      }

      state = ChatSessionUiModel.fromDomain(session);
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionController',
        subDomain: 'initializeSession',
        stackTrace: stackTrace,
      );

      state = state.copyWith(error: 'Failed to initialize session: $e');
    }
  }

  /// Send a new message in the current session
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || !state.canSendMessage) return;

    // Add user message to state
    final userMessage = ChatMessage.user(content);
    final updatedMessages = [...state.messages, userMessage];

    // Create streaming placeholder for AI response
    _currentStreamingMessageId = const Uuid().v4();
    final streamingMessage = ChatMessage(
      id: _currentStreamingMessageId!,
      content: '',
      role: ChatMessageRole.assistant,
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...updatedMessages, streamingMessage],
      isLoading: true,
      isStreaming: true,
      streamingMessageId: _currentStreamingMessageId,
    );

    try {
      final chatRepository = ref.read(chatRepositoryProvider);

      // Get conversation history (excluding the streaming message)
      final conversationHistory = state.completedMessages;

      // Stream the AI response
      await for (final chunk in chatRepository.sendMessage(
        message: content,
        conversationHistory: conversationHistory,
        categoryId: categoryId,
        enableThinking: true, // Enable thinking mode for better responses
      )) {
        _updateStreamingMessage(chunk);
      }

      // Finalize the streaming message
      _finalizeStreamingMessage();

      // Save the updated session to the repository
      await _saveCurrentSession();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionController',
        subDomain: 'sendMessage',
        stackTrace: stackTrace,
      );

      // Remove streaming message on error and show error
      _removeStreamingMessage();
      state = state.copyWith(
        error: 'Failed to send message: $e',
        isLoading: false,
        isStreaming: false,
      );
    }
  }

  /// Update the content of the currently streaming message
  void _updateStreamingMessage(String content) {
    if (_currentStreamingMessageId == null) return;

    final updatedMessages = state.messages.map((msg) {
      if (msg.id == _currentStreamingMessageId) {
        return msg.copyWith(content: content);
      }
      return msg;
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  /// Finalize the streaming message (mark as completed)
  void _finalizeStreamingMessage() {
    if (_currentStreamingMessageId == null) return;

    final updatedMessages = state.messages.map((msg) {
      if (msg.id == _currentStreamingMessageId) {
        return msg.copyWith(isStreaming: false);
      }
      return msg;
    }).toList();

    state = state.copyWith(
      messages: updatedMessages,
      isLoading: false,
      isStreaming: false,
    );

    _currentStreamingMessageId = null;
  }

  /// Remove the streaming message (used on errors)
  void _removeStreamingMessage() {
    if (_currentStreamingMessageId == null) return;

    final updatedMessages = state.messages
        .where((msg) => msg.id != _currentStreamingMessageId)
        .toList();

    state = state.copyWith(
      messages: updatedMessages,
      isLoading: false,
      isStreaming: false,
    );

    _currentStreamingMessageId = null;
  }

  /// Save the current session state to the repository
  Future<void> _saveCurrentSession() async {
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final domainSession = state.toDomain();
      await chatRepository.saveSession(domainSession);

      // Update the session ID if it was generated by the repository
      if (state.id != domainSession.id) {
        state = state.copyWith(id: domainSession.id);
      }
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionController',
        subDomain: '_saveCurrentSession',
        stackTrace: stackTrace,
      );
      // Don't show error to user for save failures, just log them
    }
  }

  /// Clear the current chat session
  Future<void> clearChat() async {
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final newSession =
          await chatRepository.createSession(categoryId: categoryId);
      state = ChatSessionUiModel.fromDomain(newSession);
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionController',
        subDomain: 'clearChat',
        stackTrace: stackTrace,
      );

      // Fallback to empty session
      state = ChatSessionUiModel.empty();
    }
  }

  /// Delete the current session
  Future<void> deleteSession() async {
    if (state.id.isEmpty) return;

    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      await chatRepository.deleteSession(state.id);

      // Create a new empty session
      await clearChat();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionController',
        subDomain: 'deleteSession',
        stackTrace: stackTrace,
      );

      state = state.copyWith(error: 'Failed to delete session: $e');
    }
  }

  /// Clear any current error
  void clearError() {
    state = state.copyWith();
  }

  /// Retry the last failed message
  Future<void> retryLastMessage() async {
    final messages = state.completedMessages;
    if (messages.isEmpty) return;

    final lastUserMessage = messages.reversed
        .where((m) => m.role == ChatMessageRole.user)
        .firstOrNull;

    if (lastUserMessage != null) {
      // Remove the last AI message if it exists and retry
      final messagesWithoutLastAI = messages
          .where((m) => !(m.role == ChatMessageRole.assistant &&
              m.timestamp.isAfter(lastUserMessage.timestamp)))
          .toList();

      state = state.copyWith(messages: messagesWithoutLastAI);
      await sendMessage(lastUserMessage.content);
    }
  }
}
