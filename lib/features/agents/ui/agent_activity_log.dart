import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log_cards.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Displays a chronological list of recent agent messages.
///
/// Each message shows a timestamp, a colored kind badge, content preview
/// (truncated), and the tool name for action/toolResult kinds.
///
/// Use the default constructor to watch the [agentRecentMessagesProvider],
/// or [AgentActivityLog.fromMessages] to render a pre-fetched list.
class AgentActivityLog extends ConsumerWidget {
  const AgentActivityLog({
    required this.agentId,
    super.key,
  }) : _preloadedMessages = null,
       expandToolCalls = false;

  /// Render a pre-fetched list of messages (e.g., from a thread group).
  ///
  /// When [expandToolCalls] is true, action and toolResult messages are
  /// initially expanded so the user can see arguments and results at a glance.
  const AgentActivityLog.fromMessages({
    required this.agentId,
    required List<AgentMessageEntity> messages,
    this.expandToolCalls = false,
    super.key,
  }) : _preloadedMessages = messages;

  final String agentId;
  final List<AgentMessageEntity>? _preloadedMessages;

  /// When true, action/toolResult cards start expanded.
  final bool expandToolCalls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_preloadedMessages != null) {
      return _buildMessageList(context, _preloadedMessages);
    }

    final messagesAsync = ref.watch(agentRecentMessagesProvider(agentId));
    final messages = messagesAsync.value;

    if (messagesAsync.isLoading && messages == null) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (messagesAsync.hasError && messages == null) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages.agentMessagesErrorLoading(
            messagesAsync.error.toString(),
          ),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      );
    }

    if (messages == null || messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages.agentMessagesEmpty,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return _buildMessageList(context, messages);
  }

  Widget _buildMessageList(
    BuildContext context,
    List<AgentDomainEntity> messages,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: messages.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppTheme.spacingXSmall),
      itemBuilder: (context, index) {
        final entity = messages[index];
        return entity.mapOrNull(
              agentMessage: (msg) => MessageCard(
                key: ValueKey(msg.id),
                message: msg,
                initiallyExpanded: expandToolCalls && _isToolCall(msg.kind),
              ),
            ) ??
            const SizedBox.shrink();
      },
    );
  }

  static bool _isToolCall(AgentMessageKind kind) =>
      kind == AgentMessageKind.action || kind == AgentMessageKind.toolResult;
}

/// Displays only observation messages, all expanded by default.
///
/// Watches [agentObservationMessagesProvider] and renders each observation
/// card with its payload text immediately visible, so the user can scan
/// the agent's insights without expanding individual cards.
class AgentObservationLog extends ConsumerWidget {
  const AgentObservationLog({
    required this.agentId,
    super.key,
  });

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observationsAsync = ref.watch(
      agentObservationMessagesProvider(agentId),
    );

    final observations = observationsAsync.value;

    if (observationsAsync.isLoading && observations == null) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (observationsAsync.hasError && observations == null) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages.agentMessagesErrorLoading(
            observationsAsync.error.toString(),
          ),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      );
    }

    if (observations == null || observations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages.agentObservationsEmpty,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: observations.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppTheme.spacingXSmall),
      itemBuilder: (context, index) {
        final entity = observations[index];
        return entity.mapOrNull(
              agentMessage: (msg) => MessageCard(
                key: ValueKey(msg.id),
                message: msg,
                initiallyExpanded: true,
              ),
            ) ??
            const SizedBox.shrink();
      },
    );
  }
}

/// Displays report history snapshots as expandable cards.
///
/// Each card shows the report's timestamp and, when expanded, the full
/// markdown content. Most recent report is expanded by default.
class AgentReportHistoryLog extends ConsumerWidget {
  const AgentReportHistoryLog({
    required this.agentId,
    super.key,
  });

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(agentReportHistoryProvider(agentId));

    final reports = historyAsync.value;

    if (historyAsync.isLoading && reports == null) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (historyAsync.hasError && reports == null) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages.agentReportHistoryError,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      );
    }

    if (reports == null || reports.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages.agentReportHistoryEmpty,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final entity = reports[index];
        final report = entity.mapOrNull(agentReport: (r) => r);
        if (report == null) return const SizedBox.shrink();

        return ReportSnapshotCard(
          key: ValueKey(report.id),
          report: report,
          initiallyExpanded: index == 0,
        );
      },
    );
  }
}
