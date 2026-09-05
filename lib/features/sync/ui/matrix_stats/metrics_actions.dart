import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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
    final tokens = context.designTokens;

    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        Tooltip(
          message: messages.matrixStatsForceRescanTooltip,
          child: DesignSystemButton(
            key: const Key('matrixStats.forceRescan'),
            label: messages.matrixStatsForceRescan,
            leadingIcon: LottiIcons.sync,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onForceRescan,
          ),
        ),
        Tooltip(
          message: messages.matrixStatsRetryNowTooltip,
          child: DesignSystemButton(
            key: const Key('matrixStats.retryNow'),
            label: messages.matrixStatsRetryNow,
            leadingIcon: LottiIcons.bolt,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onRetryNow,
          ),
        ),
        Tooltip(
          message: messages.matrixStatsCopyDiagnosticsTooltip,
          child: DesignSystemButton(
            key: const Key('matrixStats.copyDiagnostics'),
            label: messages.matrixStatsCopyDiagnostics,
            leadingIcon: LottiIcons.copy,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onCopyDiagnostics,
          ),
        ),
        DesignSystemButton(
          key: const Key('matrixStats.refresh.metrics'),
          label: messages.matrixStatsRefresh,
          leadingIcon: LottiIcons.refresh,
          variant: DesignSystemButtonVariant.secondary,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}
