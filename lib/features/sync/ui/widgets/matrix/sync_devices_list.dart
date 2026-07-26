import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Every session on the sync account: a header with a refresh action, a
/// "sync is paused" banner while any device still blocks sending, and one
/// [DeviceCard] per session with its applicable actions.
class SyncDevicesList extends ConsumerWidget {
  const SyncDevicesList({super.key, this.now});

  /// Test seam for the staleness computation; defaults to the wall clock.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final devicesAsync = ref.watch(syncDevicesControllerProvider);
    final devices = devicesAsync.value;

    void refresh() {
      ref.read(syncDevicesControllerProvider.notifier).refresh();
      ref.invalidate(matrixUnverifiedControllerProvider);
    }

    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          messages.syncDevicesSectionTitle,
          style: tokens.typography.styles.subtitle.subtitle1,
        ),
        IconButton(
          key: const Key('sync_devices_refresh'),
          onPressed: refresh,
          icon: const Icon(MdiIcons.refresh),
        ),
      ],
    );

    if (devices == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          SizedBox(height: tokens.spacing.step2),
          if (devicesAsync.hasError)
            Text(
              messages.syncDevicesLoadFailed,
              key: const Key('sync_devices_load_failed'),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.alert.error.ink,
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      );
    }

    final blocked = devices.any((device) => device.blocksSync);
    final referenceTime = now?.call() ?? DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (blocked) ...[
          SizedBox(height: tokens.spacing.step2),
          Row(
            key: const Key('sync_devices_paused_banner'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.sync_problem_rounded,
                size: tokens.typography.lineHeight.bodySmall,
                color: tokens.colors.alert.warning.ink,
              ),
              SizedBox(width: tokens.spacing.step2),
              Expanded(
                child: Text(
                  messages.syncDevicesPausedBanner,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.alert.warning.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: tokens.spacing.step3),
        for (final device in devices) ...[
          DeviceCard(
            device,
            refreshListCallback: refresh,
            now: referenceTime,
            key: Key('sync_device_${device.deviceId}'),
          ),
          SizedBox(height: tokens.spacing.step2),
        ],
        if (devices.length <= 1)
          Text(
            messages.syncDevicesOnlyThisDevice,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
      ],
    );
  }
}
