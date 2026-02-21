import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Displays a chronological list of recent agent messages.
///
/// Each message shows a timestamp, a colored kind badge, content preview
/// (truncated), and the tool name for action/toolResult kinds.
class AgentActivityLog extends ConsumerWidget {
  const AgentActivityLog({
    required this.agentId,
    super.key,
  });

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(agentRecentMessagesProvider(agentId));

    return messagesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages.agentMessagesErrorLoading(error.toString()),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      ),
      data: (messages) {
        if (messages.isEmpty) {
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
                  ),
                ) ??
                const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _MessageCard extends ConsumerStatefulWidget {
  const _MessageCard({required this.message, super.key});

  final AgentMessageEntity message;

  @override
  ConsumerState<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends ConsumerState<_MessageCard> {
  bool _expanded = false;

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
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      child: InkWell(
        onTap:
            isExpandable ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.cardPaddingCompact),
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
                  if (toolName != null)
                    Chip(
                      label: Text(
                        toolName,
                        style: monoTabularStyle(
                          fontSize: fontSizeSmall,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (isExpandable)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (_expanded && contentId != null)
                _ExpandedPayload(payloadId: contentId),
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

/// Loads and displays the text content of an observation payload.
class _ExpandedPayload extends ConsumerWidget {
  const _ExpandedPayload({required this.payloadId});

  final String payloadId;

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
        data: (text) => Text(
          text ?? context.messages.agentMessagePayloadEmpty,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurface,
          ),
        ),
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
