import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_sessions_controller.g.dart';

@riverpod
class ChatSessionsController extends _$ChatSessionsController {
  final LoggingService _loggingService = getIt<LoggingService>();

  @override
  ChatStateUiModel build(String categoryId) {
    // Initialize and load recent sessions
    _loadRecentSessions();
    return ChatStateUiModel.initial();
  }

  /// Load recent chat sessions for the category
  Future<void> _loadRecentSessions() async {
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final sessions = await chatRepository.getSessions(
        categoryId: categoryId,
        limit: 10, // Load last 10 sessions
      );

      final uiSessions = sessions.map(ChatSessionUiModel.fromDomain).toList();

      state = state.copyWith(recentSessions: uiSessions);
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionsController',
        subDomain: '_loadRecentSessions',
        stackTrace: stackTrace,
      );

      // Don't show error for loading recent sessions, just log it
    }
  }

  /// Create a new chat session
  Future<ChatSessionUiModel> createNewSession() async {
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final session =
          await chatRepository.createSession(categoryId: categoryId);

      final uiModel = ChatSessionUiModel.fromDomain(session);

      // Update current session and refresh recent sessions
      state = state.copyWith(currentSession: uiModel);
      await _loadRecentSessions();

      return uiModel;
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionsController',
        subDomain: 'createNewSession',
        stackTrace: stackTrace,
      );

      state = state.copyWith(error: 'Failed to create new session: $e');
      throw Exception('Failed to create new session: $e');
    }
  }

  /// Switch to an existing session
  Future<void> switchToSession(String sessionId) async {
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final session = await chatRepository.getSession(sessionId);

      if (session == null) {
        throw Exception('Session not found');
      }

      final uiModel = ChatSessionUiModel.fromDomain(session);
      state = state.copyWith(currentSession: uiModel);
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionsController',
        subDomain: 'switchToSession',
        stackTrace: stackTrace,
      );

      state = state.copyWith(error: 'Failed to switch to session: $e');
    }
  }

  /// Delete a chat session
  Future<void> deleteSession(String sessionId) async {
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      await chatRepository.deleteSession(sessionId);

      // If this was the current session, create a new one
      if (state.currentSession.id == sessionId) {
        await createNewSession();
      }

      // Refresh recent sessions
      await _loadRecentSessions();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionsController',
        subDomain: 'deleteSession',
        stackTrace: stackTrace,
      );

      state = state.copyWith(error: 'Failed to delete session: $e');
    }
  }

  /// Update the current session (used by individual session controllers)
  void updateCurrentSession(ChatSessionUiModel session) {
    state = state.copyWith(currentSession: session);
  }

  /// Clear any current error
  void clearError() {
    state = state.clearError();
  }

  /// Refresh all sessions
  Future<void> refresh() async {
    await _loadRecentSessions();
  }

  /// Search sessions by content or title
  Future<List<ChatSessionUiModel>> searchSessions(String query) async {
    if (query.trim().isEmpty) return state.recentSessions;

    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final sessions = await chatRepository.getSessions(
        categoryId: categoryId,
        limit: 50, // Get more sessions for search
      );

      final lowercaseQuery = query.toLowerCase();
      final filteredSessions = sessions.where((session) {
        final titleMatch = session.title.toLowerCase().contains(lowercaseQuery);
        final messageMatch = session.messages.any((message) =>
            message.content.toLowerCase().contains(lowercaseQuery));
        return titleMatch || messageMatch;
      }).toList();

      return filteredSessions.map(ChatSessionUiModel.fromDomain).toList();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionsController',
        subDomain: 'searchSessions',
        stackTrace: stackTrace,
      );

      return state.recentSessions;
    }
  }

  /// Get session statistics
  Map<String, int> getSessionStats() {
    final sessions = state.recentSessions;
    final totalSessions = sessions.length;
    final totalMessages = sessions.fold<int>(
      0,
      (sum, session) => sum + session.messages.length,
    );
    final sessionsWithMessages = sessions.where((s) => s.hasMessages).length;

    return {
      'totalSessions': totalSessions,
      'totalMessages': totalMessages,
      'activeSessionsCount': sessionsWithMessages,
      'averageMessagesPerSession':
          totalSessions > 0 ? totalMessages ~/ totalSessions : 0,
    };
  }
}
