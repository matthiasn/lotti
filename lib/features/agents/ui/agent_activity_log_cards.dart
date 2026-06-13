import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/report_content_parser.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Displays an agent report as a collapsible card.
///
/// When collapsed, shows only the TLDR section extracted from the report.
/// When expanded, renders the full [AgentReportEntity.content] via
/// [AgentMarkdownView].
class ReportSnapshotCard extends StatefulWidget {
  const ReportSnapshotCard({
    required this.report,
    this.initiallyExpanded = false,
    super.key,
  });

  final AgentReportEntity report;
  final bool initiallyExpanded;

  @override
  State<ReportSnapshotCard> createState() => _ReportSnapshotCardState();
}

class _ReportSnapshotCardState extends State<ReportSnapshotCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final timestamp = formatAgentDateTime(report.createdAt);
    final ai = context.designTokens.colors.aiCard;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPaddingHalf,
        vertical: AppTheme.spacingXSmall,
      ),
      color: ai.row,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        side: BorderSide(color: ai.rowBorder),
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
                      color: context.colorScheme.tertiary.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppTheme.spacingXSmall,
                      ),
                      border: Border.all(
                        color: context.colorScheme.tertiary.withValues(
                          alpha: 0.4,
                        ),
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
                    _expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (report.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingSmall),
                  child: _expanded
                      ? AgentMarkdownView(report.content)
                      : AgentMarkdownView(
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

class MessageCard extends ConsumerStatefulWidget {
  const MessageCard({
    required this.message,
    this.initiallyExpanded = false,
    super.key,
  });

  final AgentMessageEntity message;
  final bool initiallyExpanded;

  @override
  ConsumerState<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends ConsumerState<MessageCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final toolName = message.metadata.toolName;
    final contentId = message.contentEntryId;
    final isExpandable = contentId != null;
    final ai = context.designTokens.colors.aiCard;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPaddingHalf,
      ),
      color: ai.row,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.spacingSmall),
        side: BorderSide(color: ai.rowBorder),
      ),
      child: InkWell(
        onTap: isExpandable
            ? () => setState(() => _expanded = !_expanded)
            : null,
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
                  _KindBadge(message: message),
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
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 18,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (message.metadata.milestone != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingXSmall),
                  child: Text(
                    message.metadata.milestone!.name,
                    style: monoTabularStyle(
                      fontSize: fontSizeSmall,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
  const _KindBadge({required this.message});

  final AgentMessageEntity message;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _kindStyle(context, message);

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

  (String, Color) _kindStyle(BuildContext context, AgentMessageEntity message) {
    final scheme = context.colorScheme;
    final l10n = context.messages;
    return switch (message.kind) {
      AgentMessageKind.observation => (
        l10n.agentMessageKindObservation,
        scheme.primary,
      ),
      AgentMessageKind.user => (l10n.agentMessageKindUser, scheme.secondary),
      AgentMessageKind.thought => (
        l10n.agentMessageKindThought,
        scheme.tertiary,
      ),
      AgentMessageKind.action => (l10n.agentMessageKindAction, scheme.primary),
      AgentMessageKind.toolResult => (
        l10n.agentMessageKindToolResult,
        scheme.secondary,
      ),
      AgentMessageKind.summary => (
        l10n.agentMessageKindSummary,
        scheme.outline,
      ),
      // `system` is the log's bookkeeping kind — disambiguate what this row
      // actually is so "System" cannot be mistaken for the LLM system prompt
      // (which is the row carrying a payload).
      AgentMessageKind.system when message.metadata.milestone != null => (
        l10n.agentMessageKindMilestone,
        scheme.outline,
      ),
      AgentMessageKind.system
          when message.metadata.retractsContentEntryId != null =>
        (l10n.agentMessageKindRetraction, scheme.outline),
      AgentMessageKind.system when message.contentEntryId != null => (
        l10n.agentMessageKindSystemPrompt,
        scheme.tertiary,
      ),
      AgentMessageKind.system => (l10n.agentMessageKindSystem, scheme.outline),
    };
  }
}
