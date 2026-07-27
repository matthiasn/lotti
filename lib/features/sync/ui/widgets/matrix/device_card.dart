import 'package:flutter/material.dart';
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
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:matrix/matrix.dart';

/// Card width at which the name and its trust badges stop stacking. Below it
/// a phone card would cramp; above it the stacked layout wastes most of the
/// row.
const double kDeviceCardWideBreakpoint = 420;

/// One session of the sync account: name, trust state, last-seen, and the
/// actions that apply to it.
///
/// Every deletable card keeps its removal action in the same bottom zone;
/// only the weight changes — a quiet outlined button on healthy cards
/// escalating to the large danger primary on a card excluded from sync.
class DeviceCard extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<DeviceCard> {
  /// True while a deletion network call is in flight — the buttons show it
  /// instead of leaving a confirm-to-toast silence.
  bool _busy = false;

  SyncDeviceInfo get device => widget.device;

  /// Formats [date] with non-breaking spaces so a date can never split
  /// across lines — it is the evidence this surface exists to show.
  String _formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(date).replaceAll(' ', ' ');
  }

  Future<void> _deleteDevice(BuildContext context) async {
    final matrixService = ref.read(matrixServiceProvider);
    final deviceName = device.titleLabel;
    final confirmed = await showConfirmationModal(
      context: context,
      title: context.messages.deleteDeviceLabel,
      message: context.messages.deviceDeleteQuestion(deviceName),
      confirmLabel: context.messages.deleteDeviceLabel,
      cancelLabel: context.messages.settingsMatrixCancel,
    );
    if (!confirmed || !context.mounted || _busy) return;

    setState(() => _busy = true);
    try {
      await matrixService.deleteDeviceById(device.deviceId);
      widget.refreshListCallback();
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.success,
          title: context.messages.deviceDeletedSuccess(deviceName),
        );
      }
    } on MatrixException catch (e, stackTrace) {
      // The raw exception goes to the log, not to a toast: `M_LIMIT_EXCEEDED:
      // Too many requests` told the user nothing they could act on.
      getIt<DomainLogger>().error(
        LogDomain.sync,
        e,
        stackTrace: stackTrace,
        subDomain: 'deleteDevice',
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: e.errcode == 'M_FORBIDDEN'
              ? context.messages.deviceDeleteFailedForbidden
              : context.messages.deviceDeleteFailedGeneric,
        );
      }
    } catch (e, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        e,
        stackTrace: stackTrace,
        subDomain: 'deleteDevice',
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.deviceDeleteFailedGeneric,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyDevice(BuildContext context) async {
    final keys = device.keys;
    if (keys == null || _busy) return;

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
      widget.refreshListCallback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final stale = device.isStaleAt(widget.now);
    final lastSeen = device.lastSeen;
    // An own-account session the homeserver no longer lists can never
    // answer an interactive verification; a foreign device (legacy
    // one-user-per-device rooms) can be verified but never deleted.
    final canVerify =
        !device.isCurrentDevice &&
        !device.verified &&
        device.keys != null &&
        (device.onServer || !device.ownAccount);
    final canDelete = !device.isCurrentDevice && device.ownAccount;

    // A stale, unverified device is almost certainly dead: removal — not
    // verification — is the realistic remedy, so it escalates to the
    // labeled danger primary.
    final removalIsPrimary =
        canDelete && !device.verified && (stale || !device.onServer);

    final pairedAt = device.pairedAt;
    final pairingHash = device.pairingHash;
    final metaLine = pairedAt == null
        ? device.metaLabel
        : [
            messages.syncDevicesPaired(_formatDate(context, pairedAt)),
            ?pairingHash,
          ].join(' · ');

    // Keyless sessions cannot be verified and hold nothing to exclude — an
    // amber chip would cry wolf, so they get the neutral outlined variant
    // and an explanatory hint instead.
    final keyless =
        !device.isCurrentDevice && !device.verified && device.keys == null;

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
      else if (keyless)
        DesignSystemBadge.outlined(
          label: messages.syncDevicesUnverifiedChip,
          tone: DesignSystemBadgeTone.secondary,
        )
      else
        DesignSystemBadge.filled(
          label: messages.syncDevicesUnverifiedChip,
          tone: DesignSystemBadgeTone.warning,
        ),
    ];

    return SyncFlowSection(
      accentColor: device.excludedFromSync
          ? tokens.colors.alert.warning.defaultColor
          : null,
      // Stretch so every card fills the section width regardless of how
      // short its content happens to be.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wide enough, the name and its trust state share a row: on a
          // desktop card the stacked version left roughly two thirds of the
          // width empty while keeping the card its full mobile height.
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                device.titleLabel,
                style: tokens.typography.styles.subtitle.subtitle2,
                softWrap: true,
              );
              final badges = Wrap(
                spacing: tokens.spacing.step3,
                runSpacing: tokens.spacing.step2,
                children: trustBadges,
              );

              if (constraints.maxWidth < kDeviceCardWideBreakpoint) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    SizedBox(height: tokens.spacing.step2),
                    badges,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loose, not Expanded: the badges belong beside the name,
                  // not pinned to the far edge with a void between them.
                  Flexible(child: title),
                  SizedBox(width: tokens.spacing.step3),
                  badges,
                ],
              );
            },
          ),
          if (metaLine != null) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              metaLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
          // Last-seen has one fixed slot on every card so the dead-device
          // hunt is a straight column scan; the blocking card adds the amber
          // "probably dead" hint on its own line above it, so the label-date
          // pair never wraps apart on the one card the user must judge.
          if (stale) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              messages.syncDevicesStaleHint,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: device.excludedFromSync
                    ? tokens.colors.alert.warning.ink
                    : tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
          if (lastSeen != null) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              // The date itself is atomic (non-breaking, via _formatDate);
              // the localized label may wrap freely so long translations
              // cannot overflow narrow cards.
              messages.syncDevicesLastSeen(_formatDate(context, lastSeen)),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
          if (keyless) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              messages.syncDevicesKeylessHint,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
          if (canDelete || canVerify) ...[
            SizedBox(height: tokens.spacing.step4),
            Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (removalIsPrimary) ...[
                  DesignSystemButton(
                    key: const Key('matrix_remove_device_primary'),
                    size: DesignSystemButtonSize.large,
                    variant: DesignSystemButtonVariant.danger,
                    isLoading: _busy,
                    onPressed: () => _deleteDevice(context),
                    label: messages.deleteDeviceLabel,
                  ),
                  if (canVerify)
                    DesignSystemButton(
                      size: DesignSystemButtonSize.large,
                      variant: DesignSystemButtonVariant.outlined,
                      onPressed: _busy ? null : () => _verifyDevice(context),
                      label: messages.settingsMatrixVerifyLabel,
                    ),
                ] else ...[
                  if (canVerify)
                    DesignSystemButton(
                      size: DesignSystemButtonSize.large,
                      onPressed: _busy ? null : () => _verifyDevice(context),
                      label: messages.settingsMatrixVerifyLabel,
                    ),
                  if (canDelete)
                    DesignSystemButton(
                      key: const Key('matrix_delete_device'),
                      // Match a sibling Verify's height; standing alone on a
                      // healthy card it stays small so destruction is never
                      // the focal element of a card needing nothing done.
                      // Borderless, and on the card's own text rail: with the
                      // button's internal padding the label sat visibly right
                      // of the name, badges and last-seen above it.
                      alignsLabelToLeadingEdge: true,
                      // Borderless on a healthy card: a routine cleanup
                      // action must not read louder than "Add device" on the
                      // page around it. The blocking case above keeps its
                      // fill, because there removal *is* the primary act.
                      variant: DesignSystemButtonVariant.dangerTertiary,
                      isLoading: _busy,
                      onPressed: () => _deleteDevice(context),
                      label: messages.deleteDeviceLabel,
                    ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
