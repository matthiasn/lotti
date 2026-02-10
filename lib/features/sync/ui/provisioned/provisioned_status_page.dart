import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/matrix_logged_in_config_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage provisionedStatusPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: _StatusActionBar(pageIndexNotifier: pageIndexNotifier),
    title: context.messages.provisionedSyncTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: const ProvisionedStatusWidget(),
  );
}

class _StatusActionBar extends ConsumerWidget {
  const _StatusActionBar({required this.pageIndexNotifier});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: WoltModalConfig.pagePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: OutlinedButton(
              onPressed: () => pageIndexNotifier.value = 0,
              child: Text(context.messages.settingsMatrixPreviousPage),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.messages.tasksLabelsDialogClose),
            ),
          ),
        ],
      ),
    );
  }
}

class ProvisionedStatusWidget extends ConsumerWidget {
  const ProvisionedStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrixService = ref.watch(matrixServiceProvider);
    final userId = matrixService.client.userID ?? '';
    final roomId = matrixService.syncRoomId ?? '';
    final messages = context.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _StatusInfoRow(
          label: messages.provisionedSyncSummaryUser,
          value: userId,
        ),
        const SizedBox(height: 12),
        _StatusInfoRow(
          label: messages.provisionedSyncSummaryRoom,
          value: roomId,
        ),
        const SizedBox(height: 24),
        const DiagnosticInfoButton(),
        const SizedBox(height: 16),
        LottiSecondaryButton(
          onPressed: () async {
            await matrixService.deleteConfig();
            ref.read(provisioningControllerProvider.notifier).reset();
          },
          label: messages.provisionedSyncDisconnect,
        ),
      ],
    );
  }
}

class _StatusInfoRow extends StatelessWidget {
  const _StatusInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: context.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
