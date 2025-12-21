import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_list_item_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// Displays a single outbox entry using a mobile-optimized stacked layout.
class OutboxListItem extends StatelessWidget {
  const OutboxListItem({
    required this.item,
    this.onRetry,
    this.showRetry = false,
    this.onDelete,
    this.showDelete = false,
    super.key,
  });

  final OutboxItem item;
  final Future<void> Function()? onRetry;
  final bool showRetry;
  final Future<void> Function()? onDelete;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final viewModel =
        OutboxListItemViewModel.fromItem(context: context, item: item);
    final theme = Theme.of(context);
    final hasActions =
        (showRetry && onRetry != null) || (showDelete && onDelete != null);

    return Semantics(
      label: viewModel.semanticsLabel,
      child: ModernBaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Header with date, status icon, chips, and action buttons
            Row(
              children: [
                // Status icon
                Icon(
                  viewModel.statusIcon,
                  size: 18,
                  color: viewModel.statusColor,
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                // Date/timestamp
                Expanded(
                  child: Text(
                    viewModel.timestampLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Action buttons (icon-only, compact)
                if (hasActions) ...[
                  if (showDelete && onDelete != null)
                    _CompactIconButton(
                      key: ValueKey('outboxDelete-${item.id}'),
                      icon: Icons.delete_outline_rounded,
                      color: theme.colorScheme.error,
                      onPressed: () => unawaited(onDelete!.call()),
                      tooltip: context.messages.outboxMonitorDelete,
                    ),
                  if (showRetry && onRetry != null)
                    _CompactIconButton(
                      key: ValueKey('outboxRetry-${item.id}'),
                      icon: Icons.replay_rounded,
                      color: theme.colorScheme.primary,
                      onPressed: () => unawaited(onRetry!.call()),
                      tooltip: context.messages.outboxMonitorRetry,
                    ),
                ],
              ],
            ),

            const SizedBox(height: AppTheme.spacingSmall),

            // Row 2: Status and type chips
            Wrap(
              spacing: AppTheme.spacingSmall,
              runSpacing: 4,
              children: [
                ModernStatusChip(
                  label: viewModel.statusLabel,
                  color: viewModel.statusColor,
                  icon: viewModel.statusChipIcon,
                ),
                _CompactChip(label: viewModel.payloadKindLabel),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMedium),

            // Row 3: Full-width metadata content
            _MetaRow(
              icon: Icons.restart_alt_rounded,
              label: context.messages.outboxMonitorRetriesLabel,
              value: viewModel.retriesLabel,
            ),
            const SizedBox(height: 4),
            _MetaRow(
              icon: Icons.widgets_rounded,
              label: context.messages.syncListPayloadKindLabel,
              value: viewModel.payloadKindLabel,
            ),
            if (viewModel.subjectValue != null) ...[
              const SizedBox(height: 4),
              _MetaRow(
                icon: Icons.tag_rounded,
                label: context.messages.outboxMonitorSubjectLabel,
                value: viewModel.subjectValue!,
              ),
            ],
            const SizedBox(height: 4),
            _MetaRow(
              icon: viewModel.attachmentIcon,
              label: context.messages.outboxMonitorAttachmentLabel,
              value: viewModel.attachmentValue,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon button for action buttons
class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

/// Compact chip for labels
class _CompactChip extends StatelessWidget {
  const _CompactChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 11,
    );
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 11,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label: ', style: labelStyle),
                TextSpan(text: value, style: valueStyle),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
