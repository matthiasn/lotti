import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_relaunch_provider.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:matrix/matrix.dart';

/// Opens the SAS ceremony as soon as an unverified device appears, once per
/// device, guarded by the app-wide modal lock so two surfaces watching the
/// same provider cannot both open it.
///
/// Renders nothing. It reacts to
/// [matrixUnverifiedControllerProvider] rather than waiting a fixed delay for
/// device keys to arrive, so a slow key sync postpones the ceremony instead of
/// missing it.
class AutoVerificationLauncher extends ConsumerStatefulWidget {
  const AutoVerificationLauncher({super.key});

  @override
  ConsumerState<AutoVerificationLauncher> createState() =>
      _AutoVerificationLauncherState();
}

class _AutoVerificationLauncherState
    extends ConsumerState<AutoVerificationLauncher> {
  bool _launchInFlight = false;
  String? _lastAutoLaunchedDeviceId;

  Future<void> _maybeLaunch(List<DeviceKeys> devices) async {
    if (!mounted || _launchInFlight || devices.isEmpty) return;
    final target = devices.first;
    final targetId = target.deviceId;

    if (_lastAutoLaunchedDeviceId == targetId) return;
    final lock = ref.read(matrixVerificationModalLockProvider.notifier);
    if (!lock.tryAcquire()) {
      // Record it anyway. Two launchers can be mounted at once — the settings
      // pane embeds the roster while the setup modal is still open — and the
      // loser used to return without marking the device handled. When the
      // winner closed and invalidated the providers, the loser rebuilt, took
      // the freed lock, and reopened the sheet the user had just dismissed.
      _lastAutoLaunchedDeviceId = targetId;
      return;
    }

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
        ref
          ..invalidate(matrixUnverifiedControllerProvider)
          ..invalidate(syncDevicesControllerProvider);
      }
      lock.release();
      _launchInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // An explicit "show it again" clears the once-per-device guard. Nothing
    // else can: the device is still unverified, which is precisely the state
    // that keeps the guard set, so re-querying the providers changes nothing.
    ref.listen<int>(matrixVerificationRelaunchProvider, (_, _) {
      _lastAutoLaunchedDeviceId = null;
      final devices = ref.read(matrixUnverifiedControllerProvider).value ?? [];
      unawaited(_maybeLaunch(devices));
    });

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
