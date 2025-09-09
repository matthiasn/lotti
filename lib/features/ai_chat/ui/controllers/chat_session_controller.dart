import 'package:collection/collection.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'chat_session_controller.g.dart';

/// Riverpod controller for a single AI chat session.
///
/// Owns UI-facing state (messages, streaming flags, errors) and delegates
/// sending to `ChatRepository`. Enforces explicit model selection and manages
/// streaming placeholders for assistant messages.
@riverpod
class ChatSessionController extends _$ChatSessionController {
  final LoggingService _loggingService = getIt<LoggingService>();
  static const int maxStreamingContentSize = 1000000; // 1MB cap
  String? _currentStreamingMessageId;
  // Tracks if the current streaming message (if any) represents a visible
  // answer segment. Thinking segments are emitted as discrete, completed
  // messages and never streamed into.
  bool _streamingIsVisibleSegment = false;

  @override
  ChatSessionUiModel build(String categoryId) {
    return ChatSessionUiModel.empty();
  }

  /// Initialize or load an existing chat session.
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

  /// Send a new message in the current session.
  ///
  /// Behavior change: thinking vs. answer are emitted as separate bubbles.
  /// - Thinking segments are added as their own assistant messages (collapsed
  ///   reasoning UI), never merged into the visible answer bubble.
  /// - Visible text segments stream into a dedicated assistant message.
  /// - When the segment type switches (e.g., thinking -> visible or visible ->
  ///   thinking), the previous streaming message is finalized and a new
  ///   message is started for the new segment type.
  Future<void> sendMessage(String content) async {
    // Only allow sending non-empty messages when not busy.
    // Note: The UI requires model selection before this can be called.
    if (content.trim().isEmpty || state.isLoading || state.isStreaming) {
      return;
    }

    // Ensure a model is selected (required, no fallback)
    final modelId = state.selectedModelId;
    if (modelId == null) {
      state = state.copyWith(
        error: 'Please select a model before sending messages',
      );
      return;
    }

    // Add user message to state
    final userMessage = ChatMessage.user(content);
    final updatedMessages = [...state.messages, userMessage];

    // Start streaming state (no assistant placeholder yet — we will create
    // messages per segment as chunks arrive).
    _currentStreamingMessageId = null;
    _streamingIsVisibleSegment = false;
    state = state.copyWith(
      messages: [...updatedMessages],
      isLoading: true,
      isStreaming: true,
      streamingMessageId: null,
    );

    try {
      final chatRepository = ref.read(chatRepositoryProvider);

      // Get conversation history (excluding the streaming message)
      final conversationHistory = state.completedMessages;

      await for (final chunk in chatRepository.sendMessage(
        message: content,
        conversationHistory: conversationHistory,
        modelId: modelId,
        categoryId: categoryId,
      )) {
        // Split the incoming chunk into ordered thinking/visible segments
        final segments = splitThinkingSegments(chunk);
        for (final seg in segments) {
          if (seg.isThinking) {
            // If we were streaming a visible answer, finalize it before
            // appending a new thinking bubble.
            if (_currentStreamingMessageId != null &&
                _streamingIsVisibleSegment) {
              _finalizeStreamingMessage();
            }

            // Append a completed assistant message that only contains the
            // thinking block (wrapped so UI recognizes it as reasoning).
            final thinkingWrapped = '<thinking>\n${seg.text}\n</thinking>';
            final thinkingMessage = ChatMessage(
              id: const Uuid().v4(),
              content: thinkingWrapped,
              role: ChatMessageRole.assistant,
              timestamp: DateTime.now(),
            );
            state = state.copyWith(
              messages: [...state.messages, thinkingMessage],
            );
            // Ensure no active streaming message is tracked.
            _currentStreamingMessageId = null;
            _streamingIsVisibleSegment = false;
          } else {
            // Visible text segment: stream into a dedicated assistant message.
            if (_currentStreamingMessageId == null ||
                !_streamingIsVisibleSegment) {
              // Start a new streaming assistant message for visible content.
              _currentStreamingMessageId = const Uuid().v4();
              _streamingIsVisibleSegment = true;
              final streamingMessage = ChatMessage(
                id: _currentStreamingMessageId!,
                content: seg.text,
                role: ChatMessageRole.assistant,
                timestamp: DateTime.now(),
                isStreaming: true,
              );
              state = state.copyWith(
                messages: [...state.messages, streamingMessage],
                streamingMessageId: _currentStreamingMessageId,
              );
            } else {
              // Append to existing visible streaming message.
              _updateStreamingMessage(seg.text);
            }
          }
        }
      }

      // Finalize any remaining visible streaming message
      if (_currentStreamingMessageId != null && _streamingIsVisibleSegment) {
        _finalizeStreamingMessage();
      }
      // Ensure global streaming flags are cleared even if we ended on a
      // thinking segment (no active streaming message to finalize).
      if (state.isLoading || state.isStreaming) {
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          streamingMessageId: null,
        );
      }

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

  /// Update the content of the currently streaming assistant message.
  void _updateStreamingMessage(String content) {
    if (_currentStreamingMessageId == null) return;

    final updatedMessages = state.messages.map((msg) {
      if (msg.id == _currentStreamingMessageId) {
        // If already truncated, ignore further chunks to avoid extra work
        if (msg.content.endsWith('…')) return msg;

        var newContent = '${msg.content}$content';
        if (newContent.length > maxStreamingContentSize) {
          // Truncate to cap and add ellipsis
          newContent = '${newContent.substring(0, maxStreamingContentSize)}…';
        }
        return msg.copyWith(content: newContent);
      }
      return msg;
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  /// Finalize the streaming assistant message (mark as completed).
  void _finalizeStreamingMessage({bool preserveStreamingFlags = false}) {
    if (_currentStreamingMessageId == null) return;

    final updatedMessages = state.messages.map((msg) {
      if (msg.id == _currentStreamingMessageId) {
        return msg.copyWith(isStreaming: false);
      }
      return msg;
    }).toList();

    state = state.copyWith(
      messages: updatedMessages,
      isLoading: preserveStreamingFlags && state.isLoading,
      isStreaming: preserveStreamingFlags && state.isStreaming,
    );

    _currentStreamingMessageId = null;
  }

  /// Remove the streaming assistant message (used on errors).
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

  /// Save the current session state to the repository.
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

  /// Clear the current chat session.
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

  /// Delete the current session.
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

  /// Clear any current error.
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Retry the last failed message, re-sending the most recent user message.
  Future<void> retryLastMessage() async {
    final messages = state.completedMessages;
    if (messages.isEmpty) return;

    final lastUserMessage = messages.reversed
        .where((m) => m.role == ChatMessageRole.user)
        .firstWhereOrNull((_) => true);

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

  /// Set the selected model for this chat session
  Future<void> setModel(String modelId) async {
    // Update UI state immediately
    final previousModelId = state.selectedModelId;
    final updated = state.copyWith(selectedModelId: modelId, error: null);
    state = updated;

    // Persist to repository (session domain)
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final domainSession = updated.toDomain();
      await chatRepository.saveSession(domainSession);
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionController',
        subDomain: 'setModel',
        stackTrace: stackTrace,
      );
      // Revert UI state to maintain consistency
      state = state.copyWith(selectedModelId: previousModelId);
    }
  }
}
