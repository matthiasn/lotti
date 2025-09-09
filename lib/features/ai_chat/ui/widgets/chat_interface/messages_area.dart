import 'package:flutter/material.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/message_bubble.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/typing_indicator.dart';

class MessagesArea extends StatelessWidget {
  const MessagesArea({
    required this.messages,
    required this.scrollController,
    required this.showTypingIndicator,
    super.key,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final bool showTypingIndicator;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Stack(
        children: [
          const Positioned.fill(child: _EmptyState()),
          if (showTypingIndicator)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  TypingIndicator(isUser: false),
                ],
              ),
            ),
        ],
      );
    }

    final itemCount = messages.length + (showTypingIndicator ? 1 : 0);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < messages.length) {
          final message = messages[index];
          return MessageBubble(
            message: message,
            key: ValueKey(message.id),
          );
        }
        return const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: TypingIndicator(isUser: false),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask me about your tasks',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'I can help analyze your productivity patterns, summarize completed tasks, and provide insights about your work habits.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
