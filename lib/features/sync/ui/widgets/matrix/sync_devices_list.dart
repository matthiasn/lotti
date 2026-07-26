import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Every session on the sync account: a header with a refresh action, a
/// warning banner while any unverified device is excluded from key sharing,
/// and one [DeviceCard] per session with its applicable actions.
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

    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          messages.syncDevicesSectionTitle,
          style: tokens.typography.styles.subtitle.subtitle1,
        ),
        IconButton(
          key: const Key('sync_devices_refresh'),
          tooltip: messages.matrixStatsRefresh,
          padding: EdgeInsets.zero,
          onPressed: _refreshing || devicesAsync.isLoading
              ? null
              : () => unawaited(_refresh()),
          icon: _refreshing
              ? DesignSystemSpinner(
                  size: tokens.spacing.step5,
                  strokeWidth: tokens.spacing.step1,
                )
              : const Icon(MdiIcons.refresh),
        ),
      ],
    );

    if (devices == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (blocked) ...[
          SizedBox(height: tokens.spacing.step3),
          // The toast's warning-callout grammar (level02 surface, warning
          // border and icon, high-emphasis text): clearly a message, not a
          // control, and distinct from the cards' hairline outline.
          DecoratedBox(
            key: const Key('sync_devices_paused_banner'),
            decoration: BoxDecoration(
              color: tokens.colors.background.level02,
              border: Border.all(
                color: tokens.colors.alert.warning.defaultColor,
              ),
              borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
            ),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: tokens.spacing.step6,
                    color: tokens.colors.alert.warning.defaultColor,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Text(
                      bannerText,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step4),
        for (var i = 0; i < devices.length; i++) ...[
          if (i > 0) SizedBox(height: tokens.spacing.cardItemSpacing),
          DeviceCard(
            devices[i],
            refreshListCallback: () => unawaited(_refresh()),
            now: referenceTime,
            key: Key(
              'sync_device_${devices[i].userId ?? 'self'}_'
              '${devices[i].deviceId}',
            ),
          ),
        ],
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
