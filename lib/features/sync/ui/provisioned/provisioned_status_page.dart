import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/matrix_logged_in_config_page.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
        const SizedBox(height: 24),
        Text(
          messages.provisionedSyncVerifyDevicesTitle,
          style: context.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const UnverifiedDevices(),
        if (isDesktop) ...[
          const SizedBox(height: 16),
          const _HandoverQrSection(),
        ],
        const SizedBox(height: 16),
        LottiSecondaryButton(
          onPressed: () async {
            const deleteKey = 'deleteKey';
            final result = await showModalActionSheet<String>(
              context: context,
              title: messages.syncDeleteConfigQuestion,
              actions: [
                ModalSheetAction(
                  icon: Icons.warning,
                  label: messages.syncDeleteConfigConfirm,
                  key: deleteKey,
                  isDestructiveAction: true,
                ),
              ],
            );
            if (result == deleteKey && context.mounted) {
              await matrixService.deleteConfig();
              ref.read(provisioningControllerProvider.notifier).reset();
            }
          },
          label: messages.provisionedSyncDisconnect,
        ),
      ],
    );
  }
}

class _HandoverQrSection extends ConsumerStatefulWidget {
  const _HandoverQrSection();

  @override
  ConsumerState<_HandoverQrSection> createState() => _HandoverQrSectionState();
}

class _HandoverQrSectionState extends ConsumerState<_HandoverQrSection> {
  String? _handoverBase64;
  bool _loading = false;
  bool _revealed = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final data = await ref
          .read(provisioningControllerProvider.notifier)
          .regenerateHandover();
      if (mounted) {
        setState(() {
          _handoverBase64 = data;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    if (_handoverBase64 == null) {
      return LottiSecondaryButton(
        onPressed: _loading ? null : _generate,
        label: messages.provisionedSyncShowQr,
      );
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: _handoverBase64!,
                padding: EdgeInsets.zero,
                size: 240,
                key: const Key('statusHandoverQrImage'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          messages.provisionedSyncReady,
          style: context.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _revealed
                  ? SelectableText(
                      _handoverBase64!,
                      style: context.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    )
                  : Text(
                      '\u2022' * 24,
                      style: context.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
            ),
            IconButton(
              key: const Key('statusToggleHandoverVisibility'),
              icon: Icon(
                _revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _revealed = !_revealed),
            ),
            IconButton(
              key: const Key('statusCopyHandoverData'),
              icon: const Icon(Icons.copy),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final copiedMessage =
                    context.messages.provisionedSyncCopiedToClipboard;
                await Clipboard.setData(
                  ClipboardData(text: _handoverBase64!),
                );
                messenger.showSnackBar(
                  SnackBar(content: Text(copiedMessage)),
                );
              },
            ),
          ],
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
