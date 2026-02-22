import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Displays agent messages grouped by thread (wake cycle).
///
/// Each thread renders as an [ExpansionTile] with the thread's timestamp as
/// header and a summary (e.g., "2 tool calls"). Inside, messages are shown
/// chronologically with full expandability. Threads are sorted
/// most-recent-first.
class AgentConversationLog extends ConsumerWidget {
  const AgentConversationLog({
    required this.agentId,
    super.key,
  });

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(agentMessagesByThreadProvider(agentId));

    return threadsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          error.toString(),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      ),
      data: (threads) {
        if (threads.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: Text(
              context.messages.agentConversationEmpty,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        // Sort threads most-recent-first by latest message timestamp.
        final sortedKeys = threads.keys.toList()
          ..sort((a, b) {
            final aLast = threads[a]!.last as AgentMessageEntity;
            final bLast = threads[b]!.last as AgentMessageEntity;
            return bLast.createdAt.compareTo(aLast.createdAt);
          });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final threadId = sortedKeys[index];
            final messages = threads[threadId]!;
            return _ThreadTile(
              threadId: threadId,
              messages: messages.cast<AgentMessageEntity>(),
              initiallyExpanded: index == 0,
            );
          },
        );
      },
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.threadId,
    required this.messages,
    this.initiallyExpanded = false,
  });

  final String threadId;
  final List<AgentMessageEntity> messages;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final firstMsg = messages.first;
    final toolCallCount =
        messages.where((m) => m.kind == AgentMessageKind.action).length;
    final timestamp = formatAgentDateTime(firstMsg.createdAt);

    final shortId = threadId.length > 7 ? threadId.substring(0, 7) : threadId;

    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
      ),
      title: Text(
        timestamp,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${messages.length} messages, $toolCallCount tool calls '
        '· $shortId',
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.outline,
        ),
      ),
      children: [
        AgentActivityLog.fromMessages(
          agentId: firstMsg.agentId,
          messages: messages,
          expandToolCalls: true,
        ),
        const SizedBox(height: AppTheme.spacingSmall),
      ],
    );
  }
}
