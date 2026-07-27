import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A bump counter asking `AutoVerificationLauncher` to offer the SAS ceremony
/// again for a device it has already auto-launched once.
///
/// The launcher deliberately fires once per device, so a user who dismisses the
/// sheet — a backdrop tap is enough — never sees it again for that device.
/// Invalidating the unverified-devices provider cannot help: the guard lives in
/// the launcher's own `State`, and the device is still unverified, which is
/// exactly the condition that keeps it set. This is the one signal that clears
/// it, so "show the emoji again" can mean what it says.
final NotifierProvider<MatrixVerificationRelaunch, int>
matrixVerificationRelaunchProvider =
    NotifierProvider<MatrixVerificationRelaunch, int>(
      MatrixVerificationRelaunch.new,
      name: 'matrixVerificationRelaunchProvider',
    );

class MatrixVerificationRelaunch extends Notifier<int> {
  @override
  int build() => 0;

  /// Asks the launcher to drop its per-device guard and open the ceremony.
  void request() => state = state + 1;
}
