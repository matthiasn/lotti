import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_handled_provider.dart';
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

  /// The identity this launcher last actually showed a ceremony for — the one
  /// the user was looking at, and therefore the one "show the emoji again"
  /// means.
  String? _lastOffered;

  static String _identity(DeviceKeys device) =>
      MatrixVerificationHandled.identityOf(
        userId: device.userId,
        deviceId: device.deviceId ?? '',
      );

  Future<void> _maybeLaunch(List<DeviceKeys> devices) async {
    if (!mounted || _launchInFlight || devices.isEmpty) return;
    final handled = ref.read(matrixVerificationHandledProvider.notifier);

    // The first device not yet shown, rather than simply the first: a stale or
    // legacy unverified peer can sort ahead of the one actually being paired.
    final target = devices
        .where((d) => !handled.contains(_identity(d)))
        .firstOrNull;
    if (target == null) return;
    final targetId = _identity(target);

    final lock = ref.read(matrixVerificationModalLockProvider.notifier);
    // Deferred, not handled. Something else owns the lock — a manual or an
    // incoming ceremony — and recording the device here would consume it
    // without ever showing it. `VerificationModal` invalidates the unverified
    // provider repeatedly while its sheet is open, so with several peers this
    // branch would burn through all of them and leave a newly paired device
    // with no ceremony once the lock freed up. A later rebuild retries.
    if (!lock.tryAcquire()) return;

    _launchInFlight = true;
    handled.markShown(targetId);
    _lastOffered = targetId;
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
    // "Show it again" makes exactly one device eligible: the one last shown.
    // Clearing the whole set restarts selection at the head of the list, which
    // reopens a stale peer instead of the ceremony just dismissed. Re-querying
    // the providers cannot help either — the device is still unverified, which
    // is precisely the state that keeps it marked.
    ref.listen<int>(matrixVerificationRelaunchProvider, (_, _) {
      final last = _lastOffered;
      if (last != null) {
        ref.read(matrixVerificationHandledProvider.notifier).release(last);
      }
      final devices = ref.read(matrixUnverifiedControllerProvider).value ?? [];
      unawaited(_maybeLaunch(devices));
    });

    final unverifiedDevices =
        ref.watch(matrixUnverifiedControllerProvider).value ?? [];

    if (unverifiedDevices.isEmpty) {
      _lastOffered = null;
      ref.read(matrixVerificationHandledProvider.notifier).clear();
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeLaunch(unverifiedDevices));
    });

    return const SizedBox.shrink();
  }
}
