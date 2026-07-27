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
/// [loginStateStreamProvider] is the missing signal: its transitions drive the
/// rebuild, and the service is then read for the current truth.
final Provider<bool> syncConfiguredProvider = Provider.autoDispose<bool>(
  (ref) {
    // Rebuild triggers. The values are deliberately not used directly: login
    // state alone does not tell us about the room, and provisioning state
    // tells us only about a pairing run in this session.
    ref
      ..watch(loginStateStreamProvider)
      ..watch(provisioningControllerProvider);

    final service = ref.watch(matrixServiceProvider);
    return service.isLoggedIn() && service.syncRoomId != null;
  },
  name: 'syncConfiguredProvider',
);
