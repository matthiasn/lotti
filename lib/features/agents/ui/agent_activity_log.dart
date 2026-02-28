import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/report_content_parser.dart';
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
  })  : _preloadedMessages = null,
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
      return _buildMessageList(context, _preloadedMessages!);
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
          context.messages
              .agentMessagesErrorLoading(messagesAsync.error.toString()),
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
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppTheme.spacingXSmall),
      itemBuilder: (context, index) {
        final entity = messages[index];
        return entity.mapOrNull(
              agentMessage: (msg) => _MessageCard(
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
    final observationsAsync =
        ref.watch(agentObservationMessagesProvider(agentId));

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
          context.messages
              .agentMessagesErrorLoading(observationsAsync.error.toString()),
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
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppTheme.spacingXSmall),
      itemBuilder: (context, index) {
        final entity = observations[index];
        return entity.mapOrNull(
              agentMessage: (msg) => _MessageCard(
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

        return _ReportSnapshotCard(
          key: ValueKey(report.id),
          report: report,
          initiallyExpanded: index == 0,
        );
      },
    );
  }
}

/// Displays an agent report as a collapsible card.
///
/// When collapsed, shows only the TLDR section extracted from the report.
/// When expanded, renders the full [AgentReportEntity.content] via
/// [GptMarkdown].
class _ReportSnapshotCard extends StatefulWidget {
  const _ReportSnapshotCard({
    required this.report,
    this.initiallyExpanded = false,
    super.key,
  });

  final AgentReportEntity report;
  final bool initiallyExpanded;

  @override
  State<_ReportSnapshotCard> createState() => _ReportSnapshotCardState();
}

class _ReportSnapshotCardState extends State<_ReportSnapshotCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final timestamp = formatAgentDateTime(report.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPaddingHalf,
        vertical: AppTheme.spacingXSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
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
                      color:
                          context.colorScheme.tertiary.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppTheme.spacingXSmall),
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
                  Expanded(
                    child: Text(
                      timestamp,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (report.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingSmall),
                  child: _expanded
                      ? GptMarkdown(report.content)
                      : GptMarkdown(
                          parseReportContent(report.content).tldr,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends ConsumerStatefulWidget {
  const _MessageCard({
    required this.message,
    this.initiallyExpanded = false,
    super.key,
  });

  final AgentMessageEntity message;
  final bool initiallyExpanded;

  @override
  ConsumerState<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends ConsumerState<_MessageCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final toolName = message.metadata.toolName;
    final contentId = message.contentEntryId;
    final isExpandable = contentId != null;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPaddingHalf,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.spacingSmall),
      ),
      child: InkWell(
        onTap:
            isExpandable ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(AppTheme.spacingSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSmall + 2,
            vertical: AppTheme.spacingSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _KindBadge(kind: message.kind),
                  const SizedBox(width: AppTheme.spacingSmall),
                  Expanded(
                    child: Text(
                      formatAgentTimestamp(message.createdAt),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ),
                  if (isExpandable)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (toolName != null && toolName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingXSmall),
                  child: Text(
                    toolName,
                    style: monoTabularStyle(
                      fontSize: fontSizeSmall,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (_expanded && contentId != null)
                _ExpandedPayload(
                  payloadId: contentId,
                  kind: message.kind,
                ),
              if (message.metadata.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingXSmall),
                  child: Text(
                    message.metadata.errorMessage!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.error,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads and displays the text content of a message payload.
///
/// For action and toolResult kinds, content is rendered in monospace
/// (selectable) to improve readability of JSON arguments and tool output.
class _ExpandedPayload extends ConsumerWidget {
  const _ExpandedPayload({
    required this.payloadId,
    required this.kind,
  });

  final String payloadId;
  final AgentMessageKind kind;

  bool get _isCode =>
      kind == AgentMessageKind.action || kind == AgentMessageKind.toolResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textAsync = ref.watch(agentMessagePayloadTextProvider(payloadId));

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingSmall),
      child: textAsync.when(
        loading: () => const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (error, _) => Text(
          error.toString(),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
        data: (text) {
          final content = text ?? context.messages.agentMessagePayloadEmpty;

          if (_isCode) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingSmall),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
              ),
              child: SelectableText(
                content,
                style: monoTabularStyle(fontSize: fontSizeSmall).copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
            );
          }

          return SelectableText(
            content,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurface,
            ),
          );
        },
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final AgentMessageKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _kindStyle(context, kind);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color) _kindStyle(BuildContext context, AgentMessageKind kind) {
    final scheme = context.colorScheme;
    final l10n = context.messages;
    return switch (kind) {
      AgentMessageKind.observation => (
          l10n.agentMessageKindObservation,
          scheme.primary
        ),
      AgentMessageKind.user => (l10n.agentMessageKindUser, scheme.secondary),
      AgentMessageKind.thought => (
          l10n.agentMessageKindThought,
          scheme.tertiary
        ),
      AgentMessageKind.action => (l10n.agentMessageKindAction, scheme.primary),
      AgentMessageKind.toolResult => (
          l10n.agentMessageKindToolResult,
          scheme.secondary
        ),
      AgentMessageKind.summary => (
          l10n.agentMessageKindSummary,
          scheme.outline
        ),
      AgentMessageKind.system => (l10n.agentMessageKindSystem, scheme.outline),
    };
  }
}
