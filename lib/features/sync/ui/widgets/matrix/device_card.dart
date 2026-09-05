import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_reauth_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Card width at which the name and its trust badges stop stacking. Below it
/// a phone card would cramp; above it the stacked layout wastes most of the
/// row.
const double kDeviceCardWideBreakpoint = 420;

/// The homeserver's answer when user-interactive authentication is rejected —
/// for a device removal that means the stored password, not the request.
const String _forbidden = 'M_FORBIDDEN';

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
    final refused = await _attemptRemoval(context, matrixService, deviceName);
    // The card stops reading as "working" before the recovery sheet opens:
    // from here the removal is waiting on the user, not on the homeserver.
    if (mounted) setState(() => _busy = false);

    if (refused && context.mounted) {
      // The homeserver refused the *credential*, not the removal: the stored
      // password was rotated elsewhere while this device kept syncing on its
      // access token. That is recoverable by typing the current password, so
      // the flow continues instead of dead-ending in a toast.
      await _reauthenticateAndRemove(context, deviceName);
    }
  }

  /// Runs one removal attempt, reporting the outcome to the user.
  ///
  /// Returns true when the homeserver rejected the stored credential and the
  /// caller should offer the re-authentication sheet.
  Future<bool> _attemptRemoval(
    BuildContext context,
    MatrixService matrixService,
    String deviceName,
  ) async {
    try {
      await matrixService.deleteDeviceById(device.deviceId);
      widget.refreshListCallback();
      if (context.mounted) _showRemovedToast(context, deviceName);
    } on MatrixException catch (e, stackTrace) {
      // The raw exception goes to the log, not to a toast: `M_LIMIT_EXCEEDED:
      // Too many requests` told the user nothing they could act on.
      _logRemovalFailure(e, stackTrace);
      if (e.errcode == _forbidden) return true;
      if (context.mounted) _showRemovalFailed(context);
    } catch (e, stackTrace) {
      _logRemovalFailure(e, stackTrace);
      if (context.mounted) _showRemovalFailed(context);
    }
    return false;
  }

  /// Re-runs the removal behind a password prompt, staying open until the
  /// homeserver accepts or the user backs out.
  Future<void> _reauthenticateAndRemove(
    BuildContext context,
    String deviceName,
  ) async {
    final matrixService = ref.read(matrixServiceProvider);
    final messages = context.messages;
    var removed = false;

    Future<String?> retry(String password) async {
      try {
        await matrixService.deleteDeviceById(
          device.deviceId,
          reauthPassword: password,
        );
        removed = true;
        return null;
      } on MatrixException catch (e, stackTrace) {
        _logRemovalFailure(e, stackTrace);
        return e.errcode == _forbidden
            ? messages.syncReauthInvalidPassword
            : messages.deviceDeleteFailedGeneric;
      } catch (e, stackTrace) {
        _logRemovalFailure(e, stackTrace);
        return messages.deviceDeleteFailedGeneric;
      }
    }

    // The homeserver call outlives the sheet: closing it, tapping its barrier
    // or going back mid-retry pops the modal while the removal is still in
    // flight. The outcome is therefore tracked here rather than taken from
    // the modal's result, and awaited before it is read — otherwise a
    // dismissed sheet would silently drop a removal that did succeed.
    Future<String?>? attempt;
    await showSyncReauthModal(
      context: context,
      deviceName: deviceName,
      onSubmit: (password) => attempt = retry(password),
    );
    await attempt;

    if (!removed) return;
    widget.refreshListCallback();
    if (context.mounted) _showRemovedToast(context, deviceName);
  }

  void _showRemovedToast(BuildContext context, String deviceName) {
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.deviceDeletedSuccess(deviceName),
    );
  }

  void _showRemovalFailed(BuildContext context) {
    context.showToast(
      tone: DesignSystemToastTone.error,
      title: context.messages.deviceDeleteFailedGeneric,
    );
  }

  void _logRemovalFailure(Object error, StackTrace stackTrace) {
    getIt<DomainLogger>().error(
      LogDomain.sync,
      error,
      stackTrace: stackTrace,
      subDomain: 'deleteDevice',
    );
  }

  Future<void> _verifyDevice(BuildContext context) async {
    final keys = device.keys;
    if (keys == null || _busy) return;

    // A session the homeserver has not heard from in weeks almost certainly
    // cannot answer an emoji ceremony, and a waiting ceremony looks identical
    // to one that is merely slow. Say so before the modal opens rather than
    // leaving the user to guess how long "connecting" is worth.
    if (device.isStaleAt(widget.now)) {
      final messages = context.messages;
      final proceed = await showConfirmationModal(
        context: context,
        title: messages.syncVerifyStaleTitle,
        message: messages.syncVerifyStaleMessage(device.titleLabel),
        confirmLabel: messages.syncVerifyStaleConfirm,
        cancelLabel: messages.settingsMatrixCancel,
        isDestructive: false,
      );
      if (!proceed || !context.mounted) return;
    }

    final lock = ref.read(matrixVerificationModalLockProvider.notifier);
    if (!lock.tryAcquire()) return;

    try {
      await showVerificationModalSheet(
        context: context,
        title: context.messages.syncVerifyModalTitle,
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
        // Filled, not outlined: an outlined badge keeps its tone at full
        // saturation on the border, which made "This device" the
        // highest-contrast edge on the page while carrying the one fact the
        // user needs least. Filled/secondary keeps the blue hue (so identity
        // still reads apart from the green trust state) at ink weight, on the
        // same surface fill as the leading glyph tile below.
        DesignSystemBadge.filled(
          label: messages.syncDevicesThisDeviceChip,
          tone: DesignSystemBadgeTone.secondary,
        ),
      if (device.verified)
        DesignSystemBadge.filled(
          label: messages.syncDevicesVerifiedChip,
          tone: DesignSystemBadgeTone.success,
        )
      else if (keyless)
        // Neutral, not secondary: keyless "Unverified" is a quiet status,
        // and dressing it like the outlined "This device" identity chip made
        // state and identity read as one category.
        DesignSystemBadge.outlined(
          label: messages.syncDevicesUnverifiedChip,
          tone: DesignSystemBadgeTone.neutral,
        )
      else
        DesignSystemBadge.filled(
          label: messages.syncDevicesUnverifiedChip,
          tone: DesignSystemBadgeTone.warning,
        ),
    ];

    // Healthy cards keep removal available but quiet: an icon in the card's
    // corner rather than a labeled button competing with Verify. The
    // escalated card below keeps its labeled danger primary, because there
    // removal *is* the primary act.
    final cornerDelete = canDelete && !removalIsPrimary;

    return SyncFlowSection(
      accentColor: device.excludedFromSync
          ? tokens.colors.alert.warning.defaultColor
          : null,
      // Stretch so every card fills the section width regardless of how
      // short its content happens to be.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DeviceIconTile(device: device),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.titleLabel,
                      style: tokens.typography.styles.subtitle.subtitle2,
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    Wrap(
                      spacing: tokens.spacing.step3,
                      runSpacing: tokens.spacing.step2,
                      children: trustBadges,
                    ),
                  ],
                ),
              ),
              if (cornerDelete) ...[
                SizedBox(width: tokens.spacing.step2),
                IconButton(
                  key: const Key('matrix_delete_device'),
                  // Removal can sit in the server's key-refresh timeout for
                  // many seconds; a frozen glyph read as "nothing happened".
                  // The tooltip doubles as the semantics label, so assistive
                  // technology hears the busy state too.
                  tooltip: _busy
                      ? messages.syncDeviceRemovalInProgress
                      : messages.deleteDeviceLabel,
                  padding: EdgeInsets.zero,
                  onPressed: _busy ? null : () => _deleteDevice(context),
                  icon: _busy
                      ? const DesignSystemSpinner(
                          size: IconSizes.m,
                        )
                      : Icon(
                          LottiIcons.delete,
                          size: IconSizes.m,
                          color: tokens.colors.text.lowEmphasis,
                        ),
                ),
              ],
            ],
          ),
          if (metaLine != null) ...[
            // Name and chips are identity and trust; paired/last-seen are
            // evidence. One step of separation makes the card two blocks
            // instead of one undifferentiated column.
            SizedBox(height: tokens.spacing.step4),
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
              // Same tier as the paired line above it. These are both
              // metadata; the hierarchy used to be inverted, with the lower,
              // more repetitive line rendered larger and brighter. The prose
              // hints keep bodySmall, so the tier split now carries meaning.
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
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
          if (removalIsPrimary || canVerify) ...[
            SizedBox(height: tokens.spacing.step4),
            Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (removalIsPrimary) ...[
                  DesignSystemButton(
                    key: const Key('matrix_remove_device_primary'),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    variant: DesignSystemButtonVariant.danger,
                    isLoading: _busy,
                    onPressed: () => _deleteDevice(context),
                    label: messages.deleteDeviceLabel,
                  ),
                  if (canVerify)
                    // Constructive-outlined, not neutral outlined: beside a
                    // danger primary the neutral treatment read as Cancel,
                    // and Verify is the *good* way out of this card.
                    DesignSystemButton(
                      tapTargetSize: MaterialTapTargetSize.padded,
                      variant: DesignSystemButtonVariant.constructiveOutlined,
                      onPressed: _busy ? null : () => _verifyDevice(context),
                      label: messages.settingsMatrixVerifyLabel,
                    ),
                ] else if (canVerify)
                  DesignSystemButton(
                    tapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: _busy ? null : () => _verifyDevice(context),
                    label: messages.settingsMatrixVerifyLabel,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The card's leading figure: a rounded tile with a device glyph, so the
/// roster reads as a grid of machines rather than rows of prose. The current
/// session gets its own platform's silhouette; peers get the generic pair.
class _DeviceIconTile extends StatelessWidget {
  const _DeviceIconTile({required this.device});

  final SyncDeviceInfo device;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.surface.enabled,
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: SizedBox(
        width: ControlSizes.iconChip,
        height: ControlSizes.iconChip,
        child: Center(
          child: Icon(
            device.isCurrentDevice
                ? (isDesktop ? LottiIcons.laptop : LottiIcons.phone)
                : LottiIcons.devices,
            size: IconSizes.l,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}
