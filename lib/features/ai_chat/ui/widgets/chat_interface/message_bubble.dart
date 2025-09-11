import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/bubble_corner_action.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/message_timestamp.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/streaming_content.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    super.key,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;
    final theme = Theme.of(context);
    final isAssistant = message.role == ChatMessageRole.assistant;

    bool isThinkingOnlyMessage(String content) {
      try {
        final segments = splitThinkingSegments(content);
        if (segments.isEmpty) return false;
        return segments.every((s) => s.isThinking);
      } catch (_) {
        return false;
      }
    }

    final hideTimestamp = isAssistant &&
        !message.isStreaming &&
        isThinkingOnlyMessage(message.content);

    return Padding(
      padding: EdgeInsets.only(
        bottom: hideTimestamp ? 8 : 16,
        left: isUser ? 20 : 0,
        right: isUser ? 0 : 20,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: isUser
                            ? theme.colorScheme.primary.withValues(alpha: 0.4)
                            : theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          if (isUser)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        // Outer stroke for definition: subtle on user, outlineVariant on assistant
                        border: Border.all(
                          color: isUser
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isUser
                              ? theme.colorScheme.onPrimary
                                  .withValues(alpha: 0.10)
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.06),
                        ),
                      ),
                      child: _MessageContent(
                        message: message,
                        isUser: isUser,
                        theme: theme,
                      ),
                    ),
                    if (isUser)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.10),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.7],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!isUser &&
                        !message.isStreaming &&
                        ThinkingUtils.stripThinking(message.content)
                            .trim()
                            .isNotEmpty)
                      Positioned(
                        top: -10,
                        right: -10,
                        child: BubbleCornerAction(
                          tooltip: 'Copy',
                          icon: Icons.copy,
                          onTap: () async {
                            // Copy strips hidden thinking by default to share only the visible answer.
                            final text =
                                ThinkingUtils.stripThinking(message.content);
                            await Clipboard.setData(ClipboardData(text: text));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied to clipboard')),
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (!hideTimestamp)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MessageTimestamp(
                        timestamp: message.timestamp,
                        isUser: isUser,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
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
      return StreamingContent(
        content: message.content,
        isUser: isUser,
        theme: theme,
      );
    }

    if (isUser) {
      return SelectionArea(
        child: DefaultTextStyle.merge(
          style: TextStyle(color: theme.colorScheme.onPrimary),
          child: GptMarkdown(message.content),
        ),
      );
    }

    final segments = splitThinkingSegments(message.content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final seg in segments)
          if (seg.isThinking)
            ThinkingDisclosure(thinking: seg.text)
          else
            SelectionArea(child: GptMarkdown(seg.text)),
      ],
    );
  }
}
