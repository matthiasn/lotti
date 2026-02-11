import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/matrix.dart';

class DeviceCard extends ConsumerWidget {
  const DeviceCard(
    this.deviceKeys, {
    required this.refreshListCallback,
    super.key,
  });

  final DeviceKeys deviceKeys;
  final VoidCallback refreshListCallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceKeys = this.deviceKeys;
    final matrixService = ref.read(matrixServiceProvider);
    return Card(
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                deviceKeys.deviceDisplayName ?? deviceKeys.deviceId ?? '',
                softWrap: true,
              ),
            ),
            IconButton(
              padding: const EdgeInsets.all(10),
              icon: Semantics(
                label: 'Delete device',
                child: Icon(MdiIcons.trashCanOutline),
              ),
              onPressed: () async {
                try {
                  await matrixService.deleteDevice(deviceKeys);
                  refreshListCallback();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Device ${deviceKeys.deviceDisplayName ?? deviceKeys.deviceId ?? 'unknown'} deleted successfully',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete device: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        subtitle: Column(
          children: [
            Opacity(
              opacity: 0.5,
              child: Text(
                deviceKeys.userId,
                style: context.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 10),
            LottiPrimaryButton(
              onPressed: () async {
                final lock = ref.read(
                  matrixVerificationModalLockProvider.notifier,
                );
                if (!lock.tryAcquire()) return;

                try {
                  await showVerificationModalSheet(
                    context: context,
                    title: context.messages.settingsMatrixVerifyLabel,
                    child: VerificationModal(deviceKeys),
                  );
                } finally {
                  lock.release();
                  refreshListCallback();
                }
              },
              label: context.messages.settingsMatrixVerifyLabel,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
