import 'package:flutter/material.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_list_item_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// Displays a single outbox entry using the modern card system.
class OutboxListItem extends StatelessWidget {
  const OutboxListItem({
    required this.item,
    this.onRetry,
    this.showRetry = false,
    super.key,
  });

  final OutboxItem item;
  final Future<void> Function()? onRetry;
  final bool showRetry;

  @override
  Widget build(BuildContext context) {
    final viewModel =
        OutboxListItemViewModel.fromItem(context: context, item: item);

    final trailing = showRetry && onRetry != null
        ? FilledButton.icon(
            key: ValueKey('outboxRetry-${item.id}'),
            onPressed: () => onRetry!.call(),
            icon: const Icon(Icons.replay_rounded),
            label: Text(viewModel.retryButtonLabel),
          )
        : null;

    return Semantics(
      label: viewModel.semanticsLabel,
      child: ModernBaseCard(
        child: ModernCardContent(
          leading: ModernIconContainer(
            icon: viewModel.statusIcon,
            iconColor: viewModel.statusColor,
          ),
          title: viewModel.timestampLabel,
          trailing: trailing,
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppTheme.spacingSmall,
                runSpacing: AppTheme.spacingSmall,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ModernStatusChip(
                    label: viewModel.statusLabel,
                    color: viewModel.statusColor,
                    icon: viewModel.statusChipIcon,
                  ),
                  Chip(
                    label: Text(
                      viewModel.payloadKindLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMedium),
              _MetaRow(
                icon: Icons.restart_alt_rounded,
                label: context.messages.outboxMonitorRetriesLabel,
                value: viewModel.retriesLabel,
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              _MetaRow(
                icon: Icons.widgets_rounded,
                label: context.messages.syncListPayloadKindLabel,
                value: viewModel.payloadKindLabel,
              ),
              if (viewModel.subjectValue != null) ...[
                const SizedBox(height: AppTheme.spacingSmall),
                _MetaRow(
                  icon: Icons.tag_rounded,
                  label: context.messages.outboxMonitorSubjectLabel,
                  value: viewModel.subjectValue!,
                ),
              ],
              const SizedBox(height: AppTheme.spacingSmall),
              _MetaRow(
                icon: viewModel.attachmentIcon,
                label: context.messages.outboxMonitorAttachmentLabel,
                value: viewModel.attachmentValue,
              ),
            ],
          ),
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
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: AppTheme.letterSpacingSubtitle,
    );
    final valueStyle = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: AppTheme.letterSpacingSubtitle,
      height: AppTheme.lineHeightSubtitle,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: AppTheme.iconSizeCompact,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                  alpha: AppTheme.alphaSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSmall),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label: ', style: labelStyle),
                TextSpan(text: value, style: valueStyle),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
