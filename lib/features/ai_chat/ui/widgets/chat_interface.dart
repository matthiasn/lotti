import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_sessions_controller.dart';

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
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize session when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    final controller =
        ref.read(chatSessionControllerProvider(widget.categoryId).notifier);
    await controller.initializeSession(sessionId: widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState =
        ref.watch(chatSessionControllerProvider(widget.categoryId));
    final sessionController =
        ref.read(chatSessionControllerProvider(widget.categoryId).notifier);
    final sessionsController =
        ref.read(chatSessionsControllerProvider(widget.categoryId).notifier);

    return Column(
      children: [
        // Header with session management
        _ChatHeader(
          sessionTitle: sessionState.displayTitle,
          canClearChat: sessionState.hasMessages,
          onClearChat: sessionController.clearChat,
          onNewSession: sessionsController.createNewSession,
        ),

        // Messages area
        Expanded(
          child: _MessagesArea(
            messages: sessionState.messages,
            scrollController: _scrollController,
          ),
        ),

        // Error display
        if (sessionState.error != null)
          _ErrorBanner(
            error: sessionState.error!,
            onRetry: sessionController.retryLastMessage,
            onDismiss: sessionController.clearError,
          ),

        // Input area
        _InputArea(
          controller: _textController,
          scrollController: _scrollController,
          isLoading: sessionState.isLoading,
          canSend: sessionState.canSendMessage,
          onSendMessage: sessionController.sendMessage,
        ),
      ],
    );
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
            tooltip: 'New chat',
          ),
          if (canClearChat)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: onClearChat,
              tooltip: 'Clear current chat',
            ),
        ],
      ),
    );
  }
}

class _MessagesArea extends StatelessWidget {
  const _MessagesArea({
    required this.messages,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _EmptyState();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(
          message: message,
          key: ValueKey(message.id),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask me about your tasks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'I can help analyze your productivity patterns, summarize completed tasks, and provide insights about your work habits.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _SuggestionChips(),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'What did I work on this week?',
      'Show me my productivity patterns',
      'Summarize completed tasks',
    ];

    return Wrap(
      spacing: 8,
      children: suggestions
          .map((suggestion) => ActionChip(
                label: Text(suggestion),
                onPressed: () {
                  // This would need to be connected to the input controller
                  // For now it's just a visual element
                },
              ))
          .toList(),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    super.key,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _MessageAvatar(
              icon: Icons.psychology,
              backgroundColor: theme.colorScheme.secondary,
              borderColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                  ),
                  child: _MessageContent(
                    message: message,
                    isUser: isUser,
                    theme: theme,
                  ),
                ),
                const SizedBox(height: 4),
                _MessageTimestamp(timestamp: message.timestamp, isUser: isUser),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            _MessageAvatar(
              icon: Icons.person,
              backgroundColor: theme.colorScheme.primary,
              borderColor: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: backgroundColor.withValues(alpha: 0.1),
        child: Icon(
          icon,
          size: 16,
          color: backgroundColor,
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.isUser,
    required this.theme,
  });

  final ChatMessage message;
  final bool isUser;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (message.isStreaming) {
      return _StreamingContent(
        content: message.content,
        isUser: isUser,
        theme: theme,
      );
    }

    if (isUser) {
      return SelectableText(
        message.content,
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
        ),
      );
    }

    return SelectionArea(
      child: GptMarkdown(message.content),
    );
  }
}

class _StreamingContent extends StatelessWidget {
  const _StreamingContent({
    required this.content,
    required this.isUser,
    required this.theme,
  });

  final String content;
  final bool isUser;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isUser
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Thinking...',
            style: TextStyle(
              color: isUser
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isUser)
          Text(
            content,
            style: TextStyle(color: theme.colorScheme.onPrimary),
          )
        else
          GptMarkdown(content),
        const SizedBox(height: 4),
        _TypingIndicator(isUser: isUser),
      ],
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.isUser});

  final bool isUser;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 3; i++)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (widget.isUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant)
                      .withValues(
                    alpha: (_animationController.value + i * 0.3) % 1.0 > 0.5
                        ? 1.0
                        : 0.3,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessageTimestamp extends StatelessWidget {
  const _MessageTimestamp({
    required this.timestamp,
    required this.isUser,
  });

  final DateTime timestamp;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeString =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Text(
      timeString,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        fontSize: 10,
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
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
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
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onDismiss,
            iconSize: 18,
          ),
        ],
      ),
    );
  }
}

class _InputArea extends StatefulWidget {
  const _InputArea({
    required this.controller,
    required this.scrollController,
    required this.isLoading,
    required this.canSend,
    required this.onSendMessage,
  });

  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isLoading;
  final bool canSend;
  final ValueChanged<String> onSendMessage;

  @override
  State<_InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<_InputArea> {
  void _sendMessage([String? text]) {
    final message = text ?? widget.controller.text.trim();
    if (message.isEmpty || !widget.canSend) return;

    widget.onSendMessage(message);
    widget.controller.clear();

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: 'Ask about your tasks and productivity...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  suffixIcon: widget.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: widget.canSend ? _sendMessage : null,
                enabled: widget.canSend,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: widget.canSend ? _sendMessage : null,
              tooltip: widget.canSend ? 'Send message' : 'Please wait...',
            ),
          ],
        ),
      ),
    );
  }
}
