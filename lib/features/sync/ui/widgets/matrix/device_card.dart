import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:matrix/matrix.dart';

/// One session of the sync account: name, trust state, last-seen, and the
/// actions that apply to it (verify when it has keys and is unverified,
/// remove when it is not the session the app itself runs as).
class DeviceCard extends ConsumerWidget {
  const DeviceCard(
    this.device, {
    required this.refreshListCallback,
    required this.now,
    super.key,
  });

  final SyncDeviceInfo device;
  final VoidCallback refreshListCallback;

  /// Reference time for the staleness hint, injected for determinism.
  final DateTime now;

  Future<void> _deleteDevice(BuildContext context, WidgetRef ref) async {
    final matrixService = ref.read(matrixServiceProvider);
    final deviceName = device.label;
    final confirmed = await showConfirmationModal(
      context: context,
      title: context.messages.deleteDeviceLabel,
      message: context.messages.deviceDeleteQuestion(deviceName),
      confirmLabel: context.messages.deleteDeviceLabel,
      cancelLabel: context.messages.settingsMatrixCancel,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await matrixService.deleteDeviceById(device.deviceId);
      refreshListCallback();
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.success,
          title: context.messages.deviceDeletedSuccess(deviceName),
        );
      }
    } on MatrixException catch (e) {
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: e.errcode == 'M_FORBIDDEN'
              ? context.messages.deviceDeleteFailedForbidden
              : context.messages.deviceDeleteFailed('$e'),
        );
      }
    } catch (e) {
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.deviceDeleteFailed('$e'),
        );
      }
    }
  }

  Future<void> _verifyDevice(BuildContext context, WidgetRef ref) async {
    final keys = device.keys;
    if (keys == null) return;

    final lock = ref.read(matrixVerificationModalLockProvider.notifier);
    if (!lock.tryAcquire()) return;

    try {
      await showVerificationModalSheet(
        context: context,
        title: context.messages.settingsMatrixVerifyLabel,
        child: VerificationModal(keys),
      );
    } finally {
      lock.release();
      refreshListCallback();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final stale = device.isStaleAt(now);
    final lastSeen = device.lastSeen;

    final trustBadge = device.isCurrentDevice
        ? DesignSystemBadge.outlined(
            label: messages.syncDevicesThisDeviceChip,
            tone: DesignSystemBadgeTone.secondary,
          )
        : device.verified
        ? DesignSystemBadge.filled(
            label: messages.syncDevicesVerifiedChip,
            tone: DesignSystemBadgeTone.success,
          )
        : DesignSystemBadge.filled(
            label: messages.syncDevicesUnverifiedChip,
            tone: DesignSystemBadgeTone.warning,
          );

    return SyncFlowSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  device.label,
                  style: tokens.typography.styles.body.bodyMedium,
                  softWrap: true,
                ),
              ),
              if (!device.isCurrentDevice)
                IconButton(
                  key: const Key('matrix_delete_device'),
                  padding: EdgeInsets.all(tokens.spacing.step2),
                  icon: Semantics(
                    label: messages.deleteDeviceLabel,
                    child: const Icon(MdiIcons.trashCanOutline),
                  ),
                  onPressed: () => _deleteDevice(context, ref),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          Wrap(
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              trustBadge,
              if (lastSeen != null)
                Text(
                  messages.syncDevicesLastSeen(
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(lastSeen),
                  ),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              if (stale)
                Text(
                  messages.syncDevicesStaleHint,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.alert.warning.ink,
                  ),
                ),
            ],
          ),
          if (!device.isCurrentDevice &&
              !device.verified &&
              device.keys != null) ...[
            SizedBox(height: tokens.spacing.step3),
            DesignSystemButton(
              size: DesignSystemButtonSize.large,
              onPressed: () => _verifyDevice(context, ref),
              label: messages.settingsMatrixVerifyLabel,
            ),
          ],
        ],
      ),
    );
  }
}
