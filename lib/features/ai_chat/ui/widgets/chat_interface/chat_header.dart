import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';

class ChatHeader extends ConsumerWidget {
  const ChatHeader({
    required this.sessionTitle,
    required this.canClearChat,
    required this.onClearChat,
    required this.onNewSession,
    required this.categoryId,
    required this.selectedModelId,
    required this.isStreaming,
    required this.onSelectModel,
    super.key,
  });

  final String sessionTitle;
  final bool canClearChat;
  final VoidCallback onClearChat;
  final VoidCallback onNewSession;
  final String categoryId;
  final String? selectedModelId;
  final bool isStreaming;
  final ValueChanged<String> onSelectModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.psychology_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Assistant',
                  style: theme.textTheme.titleMedium,
                ),
                if (sessionTitle.isNotEmpty)
                  Text(
                    sessionTitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Assistant settings',
            onPressed: () {
              showDialog<void>(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.32),
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(16),
                  child: AssistantSettingsSheet(categoryId: categoryId),
                ),
              );
            },
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
