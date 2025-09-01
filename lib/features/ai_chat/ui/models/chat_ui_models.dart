import 'package:lotti/features/ai_chat/domain/models/chat_session.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';

/// UI model for chat session with presentation-specific properties
class ChatSessionUiModel {
  const ChatSessionUiModel({
    required this.id,
    required this.title,
    required this.messages,
    required this.isLoading,
    required this.isStreaming,
    this.error,
    this.streamingMessageId,
  });

  /// Create initial empty session for UI
  factory ChatSessionUiModel.empty() {
    return const ChatSessionUiModel(
      id: '',
      title: 'New Chat',
      messages: [],
      isLoading: false,
      isStreaming: false,
    );
  }

  /// Factory constructor from domain model
  factory ChatSessionUiModel.fromDomain(
    ChatSession session, {
    bool isLoading = false,
    bool isStreaming = false,
    String? error,
    String? streamingMessageId,
  }) {
    return ChatSessionUiModel(
      id: session.id,
      title: session.title,
      messages: session.messages,
      isLoading: isLoading,
      isStreaming: isStreaming,
      error: error,
      streamingMessageId: streamingMessageId,
    );
  }

  final String id;
  final String title;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isStreaming;
  final String? error;
  final String? streamingMessageId;

  ChatSessionUiModel copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isStreaming,
    Object? error = const Object(),
    Object? streamingMessageId = const Object(),
  }) {
    return ChatSessionUiModel(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error == const Object() ? this.error : error as String?,
      streamingMessageId: streamingMessageId == const Object()
          ? this.streamingMessageId
          : streamingMessageId as String?,
    );
  }

  /// Convert to domain model
  ChatSession toDomain() {
    return ChatSession(
      id: id,
      title: title,
      createdAt: messages.isEmpty ? DateTime.now() : messages.first.timestamp,
      lastMessageAt:
          messages.isEmpty ? DateTime.now() : messages.last.timestamp,
      messages: messages,
    );
  }

  /// Get non-streaming messages
  List<ChatMessage> get completedMessages =>
      messages.where((m) => !m.isStreaming).toList();

  /// Get current streaming message if any
  ChatMessage? get streamingMessage =>
      messages.where((m) => m.isStreaming).firstOrNull;

  /// Check if chat has any messages
  bool get hasMessages => messages.isNotEmpty;

  /// Check if chat is in a valid state to send messages
  bool get canSendMessage => !isLoading && !isStreaming;

  /// Get display title (with fallback)
  String get displayTitle => title.isEmpty ? 'New Chat' : title;
}

/// UI model for chat state aggregated from multiple sessions
class ChatStateUiModel {
  const ChatStateUiModel({
    required this.recentSessions,
    this.currentSession,
    this.error,
  });
  factory ChatStateUiModel.initial() {
    return ChatStateUiModel(
      currentSession: ChatSessionUiModel.empty(),
      recentSessions: [],
    );
  }

  final ChatSessionUiModel? currentSession;
  final List<ChatSessionUiModel> recentSessions;
  final String? error;

  ChatStateUiModel copyWith({
    ChatSessionUiModel? currentSession,
    List<ChatSessionUiModel>? recentSessions,
    Object? error = const Object(),
  }) {
    return ChatStateUiModel(
      currentSession: currentSession ?? this.currentSession,
      recentSessions: recentSessions ?? this.recentSessions,
      error: error == const Object() ? this.error : error as String?,
    );
  }

  /// Clear current error
  ChatStateUiModel clearError() => copyWith(error: null);

  /// Check if any session is loading
  bool get isAnySessionLoading =>
      (currentSession?.isLoading ?? false) || recentSessions.any((s) => s.isLoading);
}
