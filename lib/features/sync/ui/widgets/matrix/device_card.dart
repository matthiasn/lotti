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
    final canVerify =
        !device.isCurrentDevice && !device.verified && device.keys != null;

    // A stale, unverified device is almost certainly dead: removal — not
    // verification — is what resumes sync, so removal gets the labeled
    // primary action and the corner trash icon disappears.
    final removalIsPrimary =
        stale && !device.isCurrentDevice && !device.verified;

    final locale = Localizations.localeOf(context).toString();
    final pairedAt = device.pairedAt;
    final pairingHash = device.pairingHash;
    final metaLine = pairedAt == null
        ? device.metaLabel
        : [
            messages.syncDevicesPaired(
              DateFormat.yMMMd(locale).format(pairedAt),
            ),
            ?pairingHash,
          ].join(' · ');

    final trustBadges = <Widget>[
      if (device.isCurrentDevice)
        DesignSystemBadge.outlined(
          label: messages.syncDevicesThisDeviceChip,
          tone: DesignSystemBadgeTone.secondary,
        ),
      if (device.verified)
        DesignSystemBadge.filled(
          label: messages.syncDevicesVerifiedChip,
          tone: DesignSystemBadgeTone.success,
        )
      else
        DesignSystemBadge.filled(
          label: messages.syncDevicesUnverifiedChip,
          tone: DesignSystemBadgeTone.warning,
        ),
    ];

    return SyncFlowSection(
      accentColor: device.blocksSync
          ? tokens.colors.alert.warning.defaultColor
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.titleLabel,
                      style: tokens.typography.styles.subtitle.subtitle2,
                      softWrap: true,
                    ),
                    if (metaLine != null) ...[
                      SizedBox(height: tokens.spacing.step1),
                      Text(
                        metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!device.isCurrentDevice && !removalIsPrimary)
                IconButton(
                  key: const Key('matrix_delete_device'),
                  icon: Semantics(
                    label: messages.deleteDeviceLabel,
                    child: const Icon(MdiIcons.trashCanOutline),
                  ),
                  onPressed: () => _deleteDevice(context, ref),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...trustBadges,
              if (lastSeen != null)
                Text(
                  messages.syncDevicesLastSeen(
                    DateFormat.yMMMd(locale).format(lastSeen),
                  ),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    // On a stale card the date is the evidence for removal;
                    // it carries the warning ink instead of the hint prose.
                    color: stale
                        ? tokens.colors.alert.warning.ink
                        : tokens.colors.text.mediumEmphasis,
                  ),
                ),
            ],
          ),
          if (stale) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              messages.syncDevicesStaleHint,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
          if (removalIsPrimary) ...[
            SizedBox(height: tokens.spacing.step4),
            Row(
              children: [
                DesignSystemButton(
                  key: const Key('matrix_remove_device_primary'),
                  size: DesignSystemButtonSize.large,
                  variant: DesignSystemButtonVariant.danger,
                  onPressed: () => _deleteDevice(context, ref),
                  label: messages.deleteDeviceLabel,
                ),
                if (canVerify) ...[
                  SizedBox(width: tokens.spacing.step3),
                  DesignSystemButton(
                    size: DesignSystemButtonSize.large,
                    variant: DesignSystemButtonVariant.secondary,
                    onPressed: () => _verifyDevice(context, ref),
                    label: messages.settingsMatrixVerifyLabel,
                  ),
                ],
              ],
            ),
          ] else if (canVerify) ...[
            SizedBox(height: tokens.spacing.step4),
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
