import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/ui/view_models/conflict_list_item_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

class ConflictListItem extends StatelessWidget {
  const ConflictListItem({
    required this.conflict,
    this.onTap,
    super.key,
  });

  final Conflict conflict;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final viewModel = ConflictListItemViewModel.fromConflict(
      context: context,
      conflict: conflict,
    );

    return Semantics(
      label: viewModel.semanticsLabel,
      child: ModernBaseCard(
        onTap: onTap,
        child: ModernCardContent(
          leading: ModernIconContainer(
            icon: viewModel.statusIcon,
            iconColor: viewModel.statusColor,
          ),
          title: viewModel.timestampLabel,
          trailing:
              onTap == null ? null : const Icon(Icons.chevron_right_rounded),
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernStatusChip(
                label: viewModel.statusLabel,
                color: viewModel.statusColor,
                icon: viewModel.statusChipIcon,
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                '${context.messages.conflictEntityLabel}: ${viewModel.entityLabel}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                '${context.messages.conflictIdLabel}: ${viewModel.conflictIdValue}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: AppTheme.alphaSurfaceVariant),
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                viewModel.vectorClockLabel,
                style: monoTabularStyle(fontSize: fontSizeSmall).copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: AppTheme.alphaSurfaceVariant),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
