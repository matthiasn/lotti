import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart'
    as lotti_models;
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_sessions_controller.dart';

/// Refactored ChatInterface using flutter_gen_ai_chat_ui library
class ChatInterface extends ConsumerStatefulWidget {
  const ChatInterface({
    required this.categoryId,
    this.sessionId,
    super.key,
  });

  final String categoryId;
  final String? sessionId;

  @override
  ConsumerState<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends ConsumerState<ChatInterface> {
  late ChatMessagesController _messagesController;

  // Define users for the chat
  final _currentUser = const ChatUser(
    id: 'user',
  );

  final _aiUser = const ChatUser(
    id: 'assistant',
  );

  @override
  void initState() {
    super.initState();
    _messagesController = ChatMessagesController();

    // Initialize session when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  @override
  void didUpdateWidget(covariant ChatInterface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      // Reset when session changes
      _messagesController.clearMessages();
      _initializeSession();
    }
  }

  @override
  void dispose() {
    _messagesController.dispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    final controller =
        ref.read(chatSessionControllerProvider(widget.categoryId).notifier);
    await controller.initializeSession(sessionId: widget.sessionId);
  }

  // Convert our ChatMessage to library's ChatMessage format
  ChatMessage _convertToLibraryMessage(lotti_models.ChatMessage message) {
    return ChatMessage(
      text: message.content,
      user: message.role == lotti_models.ChatMessageRole.user
          ? _currentUser
          : _aiUser,
      createdAt: message.timestamp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState =
        ref.watch(chatSessionControllerProvider(widget.categoryId));
    final sessionController =
        ref.read(chatSessionControllerProvider(widget.categoryId).notifier);
    final sessionsController =
        ref.read(chatSessionsControllerProvider(widget.categoryId).notifier);

    // Sync messages when state changes
    _syncMessages(sessionState.messages);

    return Column(
      children: [
        // Custom header with session management
        _ChatHeader(
          sessionTitle: sessionState.displayTitle,
          canClearChat: sessionState.hasMessages,
          onClearChat: sessionController.clearChat,
          onNewSession: () async {
            await sessionsController.createNewSession();
            _messagesController.clearMessages();
          },
        ),

        // Main chat widget from library
        Expanded(
          child: AiChatWidget(
            currentUser: _currentUser,
            aiUser: _aiUser,
            controller: _messagesController,
            onSendMessage: (ChatMessage message) {
              // The library passes a ChatMessage object
              sessionController.sendMessage(message.text);
            },
            messageOptions: MessageOptions(
              timeFormat: (DateTime dt) => DateFormat.Hm().format(dt),
              bubbleStyle: BubbleStyle(
                userBubbleColor:
                    Theme.of(context).colorScheme.primary.withAlpha(30),
                aiBubbleColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            inputOptions: InputOptions.minimal(
              hintText: 'Ask about your tasks and productivity...',
              borderRadius: 24,
            ),
          ),
        ),

        // Error display
        if (sessionState.error != null)
          _ErrorBanner(
            error: sessionState.error!,
            onRetry: sessionController.retryLastMessage,
            onDismiss: sessionController.clearError,
          ),
      ],
    );
  }

  void _syncMessages(List<lotti_models.ChatMessage> messages) {
    // Simple sync - only show completed messages
    _messagesController.clearMessages();

    for (final message in messages) {
      if (!message.isStreaming) {
        _messagesController.addMessage(_convertToLibraryMessage(message));
      }
    }
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.sessionTitle,
    required this.canClearChat,
    required this.onClearChat,
    required this.onNewSession,
  });

  final String sessionTitle;
  final bool canClearChat;
  final VoidCallback onClearChat;
  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.psychology_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (sessionTitle.isNotEmpty)
                  Text(
                    sessionTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: onNewSession,
            tooltip: 'New Chat',
          ),
          if (canClearChat)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: onClearChat,
              tooltip: 'Clear Chat',
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.error,
    required this.onRetry,
    required this.onDismiss,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
