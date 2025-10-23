import 'package:flutter/material.dart';

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
          child: OutlinedButton.icon(
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: const Text('Legend'),
            onPressed: () {},
          ),
        ),
        Tooltip(
          message: 'Force rescan and catch-up now',
          child: OutlinedButton.icon(
            key: const Key('matrixStats.forceRescan'),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Force Rescan'),
            onPressed: onForceRescan,
          ),
        ),
        Tooltip(
          message: 'Retry pending failures now',
          child: OutlinedButton.icon(
            key: const Key('matrixStats.retryNow'),
            icon: const Icon(Icons.flash_on_rounded),
            label: const Text('Retry Now'),
            onPressed: onRetryNow,
          ),
        ),
        Tooltip(
          message: 'Copy sync diagnostics to clipboard',
          child: OutlinedButton.icon(
            key: const Key('matrixStats.copyDiagnostics'),
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Copy Diagnostics'),
            onPressed: onCopyDiagnostics,
          ),
        ),
        OutlinedButton.icon(
          key: const Key('matrixStats.refresh.metrics'),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}
