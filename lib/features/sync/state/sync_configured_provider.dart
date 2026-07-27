import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/providers/service_providers.dart';

/// Whether this device has a usable sync configuration — logged in, with a
/// sync room — for the surfaces that choose between the device roster and the
/// pairing setup card.
///
/// Watching [matrixServiceProvider] alone does not work, and the failure is
/// silent: it hands back one stable service object, so it never notifies when
/// that object's login and room fields change. `MatrixService.init()` is
/// started unawaited during bootstrap, so a settings route opened while
/// startup is still connecting evaluated this as false and kept showing the
/// setup card until the user navigated away and back.
/// [provisioningControllerProvider] does not rescue it either — it stays
/// `initial` for a session that was restored rather than freshly paired.
///
/// Login state alone is not enough either, and the gap is not theoretical:
/// `SyncSessionManager.connect()` drops a persisted room the account can no
/// longer join (`M_FORBIDDEN`/`M_NOT_FOUND`) *after* the login event has
/// fired, so a login-only signal leaves the device roster on screen for a room
/// that no longer exists. [syncRoomChangesProvider] closes that.
final Provider<bool> syncConfiguredProvider = Provider.autoDispose<bool>(
  (ref) {
    // Rebuild triggers. The values are deliberately not used directly: each
    // signal covers a different transition, and the service is then read once
    // for the current truth.
    ref
      ..watch(loginStateStreamProvider)
      ..watch(syncRoomChangesProvider)
      ..watch(provisioningControllerProvider);

    final service = ref.watch(matrixServiceProvider);
    return service.isLoggedIn() && service.syncRoomId != null;
  },
  name: 'syncConfiguredProvider',
);

/// Sync-room transitions, including clears.
final StreamProvider<String?> syncRoomChangesProvider =
    StreamProvider.autoDispose<String?>(
      (ref) => ref.watch(matrixServiceProvider).syncRoomIdChanges,
      name: 'syncRoomChangesProvider',
    );
