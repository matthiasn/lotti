import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/add_device_page.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';

/// Every session on the sync account: a header carrying the count, the
/// server and the page's one accent (Add device), a warning banner while any
/// unverified device is excluded from key sharing, a one-time hand-off offer
/// when a device joins and verifies while the roster is open, and one
/// [DeviceCard] per session — on a two-column grid where the pane affords it.
class SyncDevicesList extends ConsumerStatefulWidget {
  const SyncDevicesList({super.key, this.now});

  /// Test seam for the staleness computation; defaults to the wall clock.
  final DateTime Function()? now;

  @override
  ConsumerState<SyncDevicesList> createState() => _SyncDevicesListState();
}

class _SyncDevicesListState extends ConsumerState<SyncDevicesList> {
  bool _refreshing = false;
  bool _refreshQueued = false;

  /// The sessions present when this list first loaded, and the trust state
  /// each identity was last seen with. Together they answer "did a device
  /// join and get verified while I was looking?" — the moment the Add-device
  /// sheet used to own, and lost the instant it was closed.
  Set<String>? _initialIdentities;
  final Map<String, bool> _lastVerified = {};
  SyncDeviceInfo? _justJoined;
  bool _handOffDismissed = false;

  static String _identity(SyncDeviceInfo device) =>
      '${device.userId ?? 'self'}/${device.deviceId}';

  /// Latches the first non-current device that either appeared after the
  /// list opened and is verified, or flipped to verified while it was open.
  /// Pure derivation from the roster this widget already watches, and it
  /// only ever moves forward — so it runs in build without a setState.
  void _observeRoster(List<SyncDeviceInfo> devices) {
    final initial = _initialIdentities;
    if (initial == null) {
      _initialIdentities = devices.map(_identity).toSet();
      for (final device in devices) {
        _lastVerified[_identity(device)] = device.verified;
      }
      return;
    }
    for (final device in devices) {
      if (device.isCurrentDevice) continue;
      final identity = _identity(device);
      final wasVerified = _lastVerified[identity];
      final freshlyVerified =
          device.verified &&
          (wasVerified == false ||
              (wasVerified == null && !initial.contains(identity)));
      if (freshlyVerified && _identityOf(_justJoined) != identity) {
        // Each fresh arrival gets its own offer: latching only the first —
        // or keeping a dismissal across devices — would silently drop the
        // hand-off for every device paired after it.
        _justJoined = device;
        _handOffDismissed = false;
      }
      _lastVerified[identity] = device.verified;
    }
  }

  static String? _identityOf(SyncDeviceInfo? device) =>
      device == null ? null : _identity(device);

  Future<void> _refresh() async {
    // A card's post-deletion callback can arrive after the sheet closed.
    if (!mounted) return;
    // Coalesce instead of dropping: a refresh requested while one is in
    // flight (e.g. right after a deletion) must still observe its effect.
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    setState(() => _refreshing = true);
    try {
      final succeeded = await ref
          .read(syncDevicesControllerProvider.notifier)
          .refresh();
      // The sheet can close while the fetch was in flight; a disposed
      // state must not touch its ref again.
      if (!mounted) return;
      ref.invalidate(matrixUnverifiedControllerProvider);
      if (!succeeded && mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.syncDevicesLoadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
    if (_refreshQueued && mounted) {
      _refreshQueued = false;
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    // Close the loop when the last blocker disappears: the banner vanishing
    // silently would leave the user unsure whether removing/verifying worked.
    ref.listen(syncDevicesControllerProvider, (previous, next) {
      final wasBlocked =
          previous?.value?.any((d) => d.excludedFromSync) ?? false;
      final isBlocked = next.value?.any((d) => d.excludedFromSync) ?? false;
      if (wasBlocked && !isBlocked && mounted) {
        context.showToast(
          tone: DesignSystemToastTone.success,
          title: messages.syncDevicesSyncResumed,
        );
      }
    });

    final devicesAsync = ref.watch(syncDevicesControllerProvider);
    final devices = devicesAsync.value;

    final refreshButton = IconButton(
      key: const Key('sync_devices_refresh'),
      tooltip: messages.matrixStatsRefresh,
      padding: EdgeInsets.zero,
      onPressed: _refreshing || devicesAsync.isLoading
          ? null
          : () => unawaited(_refresh()),
      icon: _refreshing
          ? const DesignSystemSpinner(
              size: IconSizes.s,
              strokeWidth: BorderWidths.emphasis,
            )
          : const Icon(LottiIcons.refresh),
    );

    if (devices == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [refreshButton],
          ),
          SizedBox(height: tokens.spacing.step3),
          if (devicesAsync.hasError)
            Text(
              messages.syncDevicesLoadFailed,
              key: const Key('sync_devices_load_failed'),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.alert.error.ink,
              ),
            )
          else
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: tokens.spacing.step6,
                ),
                child: const DesignSystemSpinner(),
              ),
            ),
        ],
      );
    }

    _observeRoster(devices);

    // The server this roster actually talks to. The homeserver is the
    // authority — a Matrix ID's domain can differ from the host serving the
    // account — with the account-id domain as the fallback while the client
    // has not resolved one.
    final client = ref.watch(matrixServiceProvider).client;
    final userId = client.userID;
    final serverHost =
        client.homeserver?.host ??
        (userId == null || !userId.contains(':')
            ? null
            : userId.split(':').skip(1).join(':'));

    final blockers = devices
        .where((device) => device.excludedFromSync)
        .toList(growable: false);
    final blocked = blockers.isNotEmpty;
    // Point at the remedy the cards actually offer: a legacy foreign device
    // can only be verified, an own-account session the server dropped can
    // only be deleted.
    final String bannerText;
    if (blockers.every((device) => !device.ownAccount)) {
      bannerText = messages.syncDevicesPausedBannerVerifyOnly(blockers.length);
    } else if (blockers.every(
      (device) => device.ownAccount && !device.onServer,
    )) {
      bannerText = messages.syncDevicesPausedBannerDeleteOnly(blockers.length);
    } else {
      bannerText = messages.syncDevicesPausedBanner(blockers.length);
    }
    final referenceTime = widget.now?.call() ?? DateTime.now();
    final justJoined = _handOffDismissed ? null : _justJoined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One header: what this roster is (count, server) beside the page's
        // single accent. Pairing belongs where devices are managed — this is
        // the surface a person opens when they think "I want my other device
        // on here". A Wrap, not a Row: a long localized Add-device label or
        // a large text scale must break the count onto its own run instead
        // of overflowing two unshrinkable controls.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            // spaceBetween places a single-item run at the *leading* edge, so
            // as soon as the count takes a full run on a phone the actions
            // jumped to the left with nothing to align to. end keeps them
            // terminating on the right rail — the card border — at every
            // width, which is what the desktop layout already does.
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step2,
            children: [
              if (serverHost != null)
                Text(
                  // Only sessions the homeserver still lists: the roster can
                  // also carry cache-only leftovers (unverified keys the
                  // server no longer knows), and "N devices on <server>"
                  // must not count what the server explicitly does not have.
                  messages.syncDevicesCount(
                    devices.where((device) => device.onServer).length,
                    serverHost,
                  ),
                  key: const Key('sync_devices_count'),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                )
              else
                // Keeps spaceBetween pushing the actions to the far edge
                // even when there is no count to lead the row.
                const SizedBox.shrink(),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: tokens.spacing.step2,
                children: [
                  refreshButton,
                  DesignSystemButton(
                    key: const Key('sync_devices_add_device'),
                    label: messages.syncAddDeviceAction,
                    leadingIcon: LottiIcons.add,
                    tapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: () => unawaited(AddDeviceModal.show(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (blocked) ...[
          SizedBox(height: tokens.spacing.step3),
          DesignSystemInlineCallout(
            key: const Key('sync_devices_paused_banner'),
            icon: LottiIcons.warning,
            text: bannerText,
          ),
        ],
        if (justJoined != null) ...[
          SizedBox(height: tokens.spacing.step4),
          _JustJoinedBanner(
            device: justJoined,
            onDismiss: () => setState(() => _handOffDismissed = true),
          ),
        ],
        // A section step, not a card step: at step4 the header sat exactly as
        // far from the first card as the cards sit from each other, so
        // proximity read it as a peer of the roster rather than a level above.
        SizedBox(height: tokens.spacing.sectionGap),
        LayoutBuilder(
          builder: (context, constraints) {
            Widget card(SyncDeviceInfo device) => DeviceCard(
              device,
              refreshListCallback: () => unawaited(_refresh()),
              now: referenceTime,
              key: Key(
                'sync_device_${device.userId ?? 'self'}_'
                '${device.deviceId}',
              ),
            );

            final gap = tokens.spacing.cardItemSpacing;
            // Two columns only where each card still gets its own wide
            // layout; a grid of cramped cards is worse than a column.
            final twoColumns =
                constraints.maxWidth >= kDeviceCardWideBreakpoint * 2 + gap;
            if (!twoColumns) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < devices.length; i++) ...[
                    if (i > 0) SizedBox(height: gap),
                    card(devices[i]),
                  ],
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < devices.length; i += 2) ...[
                  if (i > 0) SizedBox(height: gap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: card(devices[i])),
                      SizedBox(width: gap),
                      Expanded(
                        child: i + 1 < devices.length
                            ? card(devices[i + 1])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        if (devices.length <= 1) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            messages.syncDevicesOnlyThisDevice,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ],
    );
  }
}

/// The one-time hand-off offer: a device joined the account and finished its
/// emoji ceremony while this roster was open. If the Add-device sheet was
/// already closed, this is what keeps the settings/history hand-off from
/// being lost in Maintenance.
class _JustJoinedBanner extends StatelessWidget {
  const _JustJoinedBanner({required this.device, required this.onDismiss});

  final SyncDeviceInfo device;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return DecoratedBox(
      key: const Key('sync_devices_just_joined'),
      decoration: BoxDecoration(
        color: tokens.colors.surface.selected,
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LottiIcons.aiSpark,
                  size: IconSizes.l,
                  color: tokens.colors.interactive.enabled,
                ),
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        messages.syncDevicesJustJoined(device.titleLabel),
                        style: tokens.typography.styles.subtitle.subtitle2,
                      ),
                      SizedBox(height: tokens.spacing.step1),
                      Text(
                        messages.syncDevicesJustJoinedHint,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('sync_devices_just_joined_dismiss'),
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).closeButtonTooltip,
                  padding: EdgeInsets.zero,
                  onPressed: onDismiss,
                  icon: Icon(
                    LottiIcons.close,
                    size: IconSizes.s,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step3),
            Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step2,
              children: [
                DesignSystemButton(
                  key: const Key('sync_devices_send_settings'),
                  label: messages.syncAddDeviceSendSettings,
                  leadingIcon: LottiIcons.compare,
                  onPressed: () => unawaited(SyncModal.show(context)),
                ),
                DesignSystemButton(
                  key: const Key('sync_devices_send_messages'),
                  label: messages.syncAddDeviceSendMessages,
                  leadingIcon: LottiIcons.restore,
                  variant: DesignSystemButtonVariant.outlined,
                  onPressed: () => unawaited(ReSyncModal.show(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
