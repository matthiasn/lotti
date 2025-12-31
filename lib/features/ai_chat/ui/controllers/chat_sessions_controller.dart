import 'package:lotti/features/ai_chat/models/chat_exceptions.dart';
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
    if (!ref.mounted) return;
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final sessions = await chatRepository.getSessions(
        categoryId: categoryId,
        limit: 10, // Load last 10 sessions
      );
      if (!ref.mounted) return;

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
  Future<ChatSessionUiModel?> createNewSession() async {
    // Early exit if provider is disposed - can happen when callback is stale
    if (!ref.mounted) return null;

    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final session =
          await chatRepository.createSession(categoryId: categoryId);

      final uiModel = ChatSessionUiModel.fromDomain(session);

      // Only update state if still mounted
      if (ref.mounted) {
        state = state.copyWith(currentSession: uiModel);
        await _loadRecentSessions();
      }

      return uiModel;
    } catch (e, stackTrace) {
      // Don't log or rethrow if provider was disposed during operation
      if (!ref.mounted) return null;

      _loggingService.captureException(
        e,
        domain: 'ChatSessionsController',
        subDomain: 'createNewSession',
        stackTrace: stackTrace,
      );
      state = state.copyWith(error: 'Failed to create new session: $e');
      throw ChatRepositoryException('Failed to create new session: $e', e);
    }
  }

  /// Switch to an existing session
  Future<void> switchToSession(String sessionId) async {
    if (!ref.mounted) return;
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final session = await chatRepository.getSession(sessionId);
      if (!ref.mounted) return;

      if (session == null) {
        throw const ChatRepositoryException('Session not found');
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
      if (!ref.mounted) return;
      state = state.copyWith(error: 'Failed to switch to session: $e');
    }
  }

  /// Delete a chat session
  Future<void> deleteSession(String sessionId) async {
    if (!ref.mounted) return;
    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      await chatRepository.deleteSession(sessionId);
      if (!ref.mounted) return;

      // If this was the current session, create a new one
      final currentSession = state.currentSession;
      if (currentSession != null && currentSession.id == sessionId) {
        await createNewSession();
      } else {
        // Refresh recent sessions (createNewSession already does this)
        await _loadRecentSessions();
      }
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionsController',
        subDomain: 'deleteSession',
        stackTrace: stackTrace,
      );
      if (!ref.mounted) return;
      state = state.copyWith(error: 'Failed to delete session: $e');
    }
  }

  /// Update the current session (used by individual session controllers)
  void updateCurrentSession(ChatSessionUiModel session) {
    if (!ref.mounted) return;
    state = state.copyWith(currentSession: session);
  }

  /// Clear any current error
  void clearError() {
    if (!ref.mounted) return;
    state = state.clearError();
  }

  /// Refresh all sessions
  Future<void> refresh() async {
    if (!ref.mounted) return;
    await _loadRecentSessions();
  }

  /// Search sessions by content or title using optimized repository method
  Future<List<ChatSessionUiModel>> searchSessions(String query) async {
    if (!ref.mounted) return [];
    if (query.trim().isEmpty) return state.recentSessions;

    try {
      final chatRepository = ref.read(chatRepositoryProvider);
      final sessions = await chatRepository.searchSessions(
        query: query,
        categoryId: categoryId,
      );

      return sessions.map(ChatSessionUiModel.fromDomain).toList();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'ChatSessionsController',
        subDomain: 'searchSessions',
        stackTrace: stackTrace,
      );
      if (!ref.mounted) return [];
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
