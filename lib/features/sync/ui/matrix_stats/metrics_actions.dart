import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Tooltip(
          message:
              'Legend:\n• processed.<type> = processed sync messages by payload type\n• droppedByType.<type> = per‑type drops after retries/older ignores\n• dbApplied = DB rows written\n• dbIgnoredByVectorClock = incoming older/same ignored by DB\n• conflictsCreated = concurrent vector clocks logged\n• dbMissingBase = skipped while awaiting missing dependency/base row\n• staleAttachmentPurges = cached stale descriptors purged before refresh',
          child: DesignSystemButton(
            label: 'Legend',
            leadingIcon: Icons.info_outline_rounded,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: () {},
          ),
        ),
        Tooltip(
          message: 'Force rescan and catch-up now',
          child: DesignSystemButton(
            key: const Key('matrixStats.forceRescan'),
            label: 'Force Rescan',
            leadingIcon: Icons.sync_rounded,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onForceRescan,
          ),
        ),
        Tooltip(
          message: 'Retry pending failures now',
          child: DesignSystemButton(
            key: const Key('matrixStats.retryNow'),
            label: 'Retry Now',
            leadingIcon: Icons.flash_on_rounded,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onRetryNow,
          ),
        ),
        Tooltip(
          message: 'Copy sync diagnostics to clipboard',
          child: DesignSystemButton(
            key: const Key('matrixStats.copyDiagnostics'),
            label: 'Copy Diagnostics',
            leadingIcon: Icons.copy_all_rounded,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onCopyDiagnostics,
          ),
        ),
        DesignSystemButton(
          key: const Key('matrixStats.refresh.metrics'),
          label: 'Refresh',
          leadingIcon: Icons.refresh_rounded,
          variant: DesignSystemButtonVariant.secondary,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}
