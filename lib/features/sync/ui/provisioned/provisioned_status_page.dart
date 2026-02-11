import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/diagnostic_info_button.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage provisionedStatusPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: _StatusActionBar(
      pageIndexNotifier: pageIndexNotifier,
    ),
    title: context.messages.provisionedSyncTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: const ProvisionedStatusWidget(),
  );
}

class _StatusActionBar extends ConsumerWidget {
  const _StatusActionBar({
    required this.pageIndexNotifier,
  });

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: context.colorScheme.surface,
      child: Padding(
        padding: WoltModalConfig.pagePadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Spacer(),
            const SizedBox(width: 8),
            Flexible(
              child: OutlinedButton(
                onPressed: () {
                  // Keep notifier state predictable for future multi-step flows.
                  pageIndexNotifier.value = 0;
                  Navigator.of(context).pop();
                },
                child: Text(context.messages.tasksLabelsDialogClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProvisionedStatusWidget extends ConsumerWidget {
  const ProvisionedStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrixService = ref.watch(matrixServiceProvider);
    final messages = context.messages;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AutoVerificationLauncher(),
          const SyncFlowSection(
            child: DiagnosticInfoButton(),
          ),
          const SizedBox(height: 16),
          SyncFlowSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages.provisionedSyncVerifyDevicesTitle,
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const UnverifiedDevices(),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(height: 16),
            const _HandoverQrSection(),
          ],
          const SizedBox(height: 16),
          SyncFlowSection(
            child: LottiSecondaryButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(messages.syncDeleteConfigQuestion),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(messages.settingsMatrixCancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(messages.syncDeleteConfigConfirm),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) {
                  await matrixService.deleteConfig();
                  if (!context.mounted) return;
                  ref.read(provisioningControllerProvider.notifier).reset();
                  await Navigator.of(context).maybePop();
                }
              },
              label: messages.provisionedSyncDisconnect,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoVerificationLauncher extends ConsumerStatefulWidget {
  const _AutoVerificationLauncher();

  @override
  ConsumerState<_AutoVerificationLauncher> createState() =>
      _AutoVerificationLauncherState();
}

class _AutoVerificationLauncherState
    extends ConsumerState<_AutoVerificationLauncher> {
  bool _launchInFlight = false;
  String? _lastAutoLaunchedDeviceId;

  Future<void> _maybeLaunch(List<DeviceKeys> devices) async {
    if (!mounted || _launchInFlight || devices.isEmpty) return;
    final target = devices.first;
    final targetId = target.deviceId;

    if (_lastAutoLaunchedDeviceId == targetId) return;
    final lock = ref.read(matrixVerificationModalLockProvider.notifier);
    if (!lock.tryAcquire()) return;

    _launchInFlight = true;
    _lastAutoLaunchedDeviceId = targetId;
    try {
      await showVerificationModalSheet(
        context: context,
        title: context.messages.settingsMatrixVerifyLabel,
        child: VerificationModal(target),
      );
    } finally {
      if (mounted) {
        ref.invalidate(matrixUnverifiedControllerProvider);
      }
      lock.release();
      _launchInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unverifiedDevices =
        ref.watch(matrixUnverifiedControllerProvider).value ?? [];

    if (unverifiedDevices.isEmpty) {
      _lastAutoLaunchedDeviceId = null;
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeLaunch(unverifiedDevices));
    });

    return const SizedBox.shrink();
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
  bool _loadAttempted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_generate());
  }

  Future<void> _generate() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final data = await ref
          .read(provisioningControllerProvider.notifier)
          .regenerateHandover();
      if (mounted) {
        setState(() {
          _loadAttempted = true;
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
      if (_loading) {
        return const SyncFlowSection(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      if (_loadAttempted) {
        return SyncFlowSection(
          child: LottiSecondaryButton(
            onPressed: _generate,
            label: messages.provisionedSyncShowQr,
          ),
        );
      }

      return const SizedBox.shrink();
    }

    return SyncFlowSection(
      child: Column(
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
      ),
    );
  }
}
