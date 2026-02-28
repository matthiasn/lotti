import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:intl/intl.dart';
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

    final threads = threadsAsync.value;

    if (threadsAsync.isLoading && threads == null) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (threadsAsync.hasError && threads == null) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages
              .agentMessagesErrorLoading(threadsAsync.error.toString()),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      );
    }

    if (threads == null || threads.isEmpty) {
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
      final report = entity.mapOrNull(agentReport: (AgentReportEntity r) => r);
      if (report?.threadId != null) {
        reportsByThread[report!.threadId!] = report;
      }
    }

    // agentMessagesByThreadProvider already returns threads ordered
    // most-recent-first, so keep that ordering here.
    final orderedKeys = threads.keys.toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orderedKeys.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        indent: AppTheme.cardPadding,
        endIndent: AppTheme.cardPadding,
        color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
      itemBuilder: (context, index) {
        final threadId = orderedKeys[index];
        final messages = threads[threadId]!;
        return _ThreadTile(
          threadId: threadId,
          agentId: agentId,
          messages: messages.cast<AgentMessageEntity>(),
          report: reportsByThread[threadId],
          initiallyExpanded: index == 0,
        );
      },
    );
  }
}

class _ThreadTile extends ConsumerWidget {
  const _ThreadTile({
    required this.threadId,
    required this.messages,
    required this.agentId,
    this.report,
    this.initiallyExpanded = false,
  });

  final String threadId;
  final String agentId;
  final List<AgentMessageEntity> messages;
  final AgentReportEntity? report;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }
    final firstMsg = messages.first;
    final lastMsg = messages.last;
    final toolCallCount =
        messages.where((m) => m.kind == AgentMessageKind.action).length;
    final startTimestamp = formatAgentDateTime(firstMsg.createdAt);
    final duration = lastMsg.createdAt.difference(firstMsg.createdAt);
    final durationStr = _formatDuration(duration);

    final shortId = threadId.length > 7 ? threadId.substring(0, 7) : threadId;

    // Resolve the model that was used for this specific conversation,
    // from the template version recorded at wake time.
    final modelAsync = ref.watch(modelIdForThreadProvider(agentId, threadId));
    final model = modelAsync.whenData((modelId) {
      if (modelId == null) return null;
      // Strip prefix like 'models/' for display.
      final slashIndex = modelId.lastIndexOf('/');
      return slashIndex >= 0 ? modelId.substring(slashIndex + 1) : modelId;
    }).value;

    // Per-thread token usage.
    final locale = Localizations.localeOf(context).toString();
    final tokenNumberFormat = NumberFormat.decimalPattern(locale);
    final tokenUsageAsync =
        ref.watch(tokenUsageForThreadProvider(agentId, threadId));
    final tokenUsage = tokenUsageAsync.value;

    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
      ),
      title: Text(
        durationStr.isNotEmpty
            ? '$startTimestamp ($durationStr)'
            : startTimestamp,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        [
          context.messages.agentConversationThreadSummary(
            messages.length,
            toolCallCount,
            shortId,
          ),
          if (tokenUsage != null)
            context.messages.agentConversationTokenCount(
              tokenNumberFormat.format(tokenUsage.totalTokens),
            ),
          if (model != null) model,
        ].join(' · '),
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

/// Format a [Duration] as a human-readable string (e.g., "2m 30s", "1h 5m").
String _formatDuration(Duration d) {
  if (d.inSeconds < 1) return '';
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.cardPaddingCompact,
        ),
        childrenPadding: const EdgeInsets.only(
          left: AppTheme.cardPaddingCompact,
          right: AppTheme.cardPaddingCompact,
          bottom: AppTheme.cardPaddingCompact,
        ),
        title: Row(
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
                  color: context.colorScheme.tertiary.withValues(alpha: 0.4),
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
        children: [
          GptMarkdown(report.content),
        ],
      ),
    );
  }
}
