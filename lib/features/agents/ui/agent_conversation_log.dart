import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
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
/// chronologically with full expandability, followed by the report snapshot
/// produced during that wake cycle (if any). Threads are sorted
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
    final reportsAsync = ref.watch(agentReportHistoryProvider(agentId));

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

        // Build a threadId → report lookup from report history.
        final reportsByThread = <String, AgentReportEntity>{};
        final reports = reportsAsync.value ?? [];
        for (final entity in reports) {
          final report =
              entity.mapOrNull(agentReport: (AgentReportEntity r) => r);
          if (report?.threadId != null) {
            reportsByThread[report!.threadId!] = report;
          }
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
              report: reportsByThread[threadId],
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
    this.report,
    this.initiallyExpanded = false,
  });

  final String threadId;
  final List<AgentMessageEntity> messages;
  final AgentReportEntity? report;
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
        if (report != null && report!.content.isNotEmpty)
          _ThreadReportCard(report: report!),
        const SizedBox(height: AppTheme.spacingSmall),
      ],
    );
  }
}

/// Inline report card shown at the end of a conversation thread.
class _ThreadReportCard extends StatelessWidget {
  const _ThreadReportCard({required this.report});

  final AgentReportEntity report;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPaddingHalf,
        vertical: AppTheme.spacingXSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      color: context.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPaddingCompact),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSmall,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
                    border: Border.all(
                      color:
                          context.colorScheme.tertiary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    context.messages.agentReportHistoryBadge,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                Text(
                  context.messages.agentThreadReportLabel,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            GptMarkdown(report.content),
          ],
        ),
      ),
    );
  }
}
