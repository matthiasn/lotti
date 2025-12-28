import 'package:flutter/material.dart';
import 'package:lotti/features/sync/ui/matrix_stats/incoming_stats.dart';
import 'package:lotti/features/sync/ui/widgets/add_device_qr_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

export 'matrix_stats/incoming_stats.dart';

SliverWoltModalSheetPage matrixStatsPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        padding: WoltModalConfig.pagePadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: LottiSecondaryButton(
                label: context.messages.settingsMatrixPreviousPage,
                onPressed: () =>
                    pageIndexNotifier.value = pageIndexNotifier.value - 1,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: LottiPrimaryButton(
                onPressed: () => Navigator.of(context).pop(),
                label: context.messages.settingsMatrixDone,
              ),
            ),
          ],
        ),
      ),
    ),
    title: context.messages.settingsMatrixStatsTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: const _MatrixStatsContent(),
  );
}

/// Content for the Matrix Stats page including stats and Add Device button.
class _MatrixStatsContent extends StatelessWidget {
  const _MatrixStatsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add Device button
        _AddDeviceButton(),
        const SizedBox(height: 24),
        // Stats content
        const IncomingStats(),
      ],
    );
  }
}

/// Button to add another device via QR code.
class _AddDeviceButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _showAddDeviceDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.devices,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.messages.syncAddDevice,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.messages.syncAddDeviceDescription,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDeviceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.messages.syncAddDevice),
        content: const SizedBox(
          width: 320,
          height: 450,
          child: AddDeviceQrWidget(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.messages.settingsMatrixDone),
          ),
        ],
      ),
    );
  }
}
