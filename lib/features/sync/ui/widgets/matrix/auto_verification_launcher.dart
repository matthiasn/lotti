import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_handled_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_relaunch_provider.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the SAS ceremony as soon as an unverified device appears, once per
/// device, guarded by the app-wide modal lock so two surfaces watching the
/// same provider cannot both open it.
///
/// Renders nothing. It reacts to
/// [matrixUnverifiedControllerProvider] rather than waiting a fixed delay for
/// device keys to arrive, so a slow key sync postpones the ceremony instead of
/// missing it.
///
/// The launch rules are model-checked in `specs/tla/VerificationLaunch.tla`.
class AutoVerificationLauncher extends ConsumerStatefulWidget {
  const AutoVerificationLauncher({super.key});

  @override
  ConsumerState<AutoVerificationLauncher> createState() =>
      _AutoVerificationLauncherState();
}

class _AutoVerificationLauncherState
    extends ConsumerState<AutoVerificationLauncher> {
  bool _launchInFlight = false;

  static String _identity(SyncDeviceInfo device) =>
      MatrixVerificationHandled.identityOf(
        userId: device.userId,
        deviceId: device.deviceId,
      );

  /// The device to open: [preferred] while it is still unverified — the one a
  /// relaunch asked for — else the first device **not yet shown**, rather than
  /// simply the first: a stale or legacy unverified peer can sort ahead of the
  /// one actually being paired.
  static SyncDeviceInfo? _pick(
    List<SyncDeviceInfo> devices,
    MatrixVerificationHandled handled,
    String? preferred,
  ) {
    if (preferred != null) {
      final wanted = devices
          .where((d) => _identity(d) == preferred)
          .firstOrNull;
      if (wanted != null) return wanted;
    }
    return devices.where((d) => !handled.contains(_identity(d))).firstOrNull;
  }

  /// A request the target itself already sent and nobody has answered.
  ///
  /// Starting a ceremony of our own beside it is the glare the SDK does not
  /// resolve — two transactions, each device's sheet waiting on the other —
  /// so the peer's is answered instead. The emoji are the same either way.
  SyncVerificationState? _waitingRequestFrom(String targetId) {
    final request = ref.read(matrixServiceProvider).incomingVerification;
    if (request == null || !request.isPending) return null;
    final deviceId = request.peerDeviceId;
    if (deviceId == null) return null;
    final sender = MatrixVerificationHandled.identityOf(
      userId: request.peerUserId,
      deviceId: deviceId,
    );
    return sender == targetId ? request : null;
  }

  Future<void> _maybeLaunch(
    List<SyncDeviceInfo> devices, {
    String? preferred,
  }) async {
    if (!mounted || _launchInFlight || devices.isEmpty) return;
    final handled = ref.read(matrixVerificationHandledProvider.notifier);
    final target = _pick(devices, handled, preferred);
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
    final service = ref.read(matrixServiceProvider);
    final waiting = _waitingRequestFrom(targetId);
    try {
      await showVerificationModalSheet(
        context: context,
        title: context.messages.syncVerifyModalTitle,
        child: waiting != null
            ? IncomingVerificationModal(waiting)
            : VerificationModal(target),
      );
    } finally {
      // The ceremony this sheet showed: the peer's request if that is what
      // was answered — and only while the service still holds that one,
      // since it keeps the latest incoming ceremony and a newer peer's is
      // not this sheet's to cancel — else this device's own, or, after a
      // handoff, the peer's ceremony the sheet carried on with, which lives
      // on the same runner slot.
      final String? shownId;
      if (waiting != null) {
        final live = service.incomingVerification;
        shownId = live?.id == waiting.id ? waiting.id : null;
      } else {
        shownId = service.outgoingVerification?.id;
      }
      if (shownId != null) await service.cancelVerification(shownId);
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
    // "Show it again" makes exactly one device eligible and asks for it by
    // name: the one last shown on this device, whichever launcher showed it.
    // Clearing the whole set restarts selection at the head of the list, and
    // releasing without preferring lets a device whose keys landed during the
    // ceremony take the slot — either way a stale peer opens instead of the
    // ceremony just dismissed. Re-querying the providers cannot help either —
    // the device is still unverified, which is precisely the state that keeps
    // it marked. The request has already released it, once for every
    // launcher; releasing here as well let a second launcher undo the
    // record the first one had just made.
    ref.listen<int>(matrixVerificationRelaunchProvider, (_, _) {
      final last = ref
          .read(matrixVerificationHandledProvider.notifier)
          .lastShown;
      final devices = ref.read(matrixUnverifiedControllerProvider).value ?? [];
      unawaited(_maybeLaunch(devices, preferred: last));
    });

    final unverifiedDevices =
        ref.watch(matrixUnverifiedControllerProvider).value ?? [];

    if (unverifiedDevices.isEmpty) {
      // Deferred because Riverpod rejects a provider write during widget
      // construction. This branch runs on any empty list — including initial
      // mount — but only writes when the set is non-empty, which is reached by
      // the *successful* verification of the last pending device. Clearing
      // inline therefore left the common case silent and turned the normal
      // success transition into a provider-modification exception.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(matrixVerificationHandledProvider.notifier).clear();
        }
      });
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeLaunch(unverifiedDevices));
    });

    return const SizedBox.shrink();
  }
}
