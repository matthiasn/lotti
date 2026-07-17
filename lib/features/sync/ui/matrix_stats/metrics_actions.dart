import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class MetricsActions extends StatelessWidget {
  const MetricsActions({
    required this.onForceRescan,
    required this.onRetryNow,
    required this.onCopyDiagnostics,
    required this.onRefresh,
    super.key,
  });

  final VoidCallback onForceRescan;
  final VoidCallback onRetryNow;
  final VoidCallback onCopyDiagnostics;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Tooltip(
          message: messages.matrixStatsLegendTooltip,
          child: DesignSystemButton(
            label: messages.matrixStatsLegend,
            leadingIcon: Icons.info_outline_rounded,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: () {},
          ),
        ),
        Tooltip(
          message: messages.matrixStatsForceRescanTooltip,
          child: DesignSystemButton(
            key: const Key('matrixStats.forceRescan'),
            label: messages.matrixStatsForceRescan,
            leadingIcon: Icons.sync_rounded,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onForceRescan,
          ),
        ),
        Tooltip(
          message: messages.matrixStatsRetryNowTooltip,
          child: DesignSystemButton(
            key: const Key('matrixStats.retryNow'),
            label: messages.matrixStatsRetryNow,
            leadingIcon: Icons.flash_on_rounded,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onRetryNow,
          ),
        ),
        Tooltip(
          message: messages.matrixStatsCopyDiagnosticsTooltip,
          child: DesignSystemButton(
            key: const Key('matrixStats.copyDiagnostics'),
            label: messages.matrixStatsCopyDiagnostics,
            leadingIcon: Icons.copy_all_rounded,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onCopyDiagnostics,
          ),
        ),
        DesignSystemButton(
          key: const Key('matrixStats.refresh.metrics'),
          label: messages.matrixStatsRefresh,
          leadingIcon: Icons.refresh_rounded,
          variant: DesignSystemButtonVariant.secondary,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}
