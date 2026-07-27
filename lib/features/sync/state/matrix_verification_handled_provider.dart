import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The `(userId, deviceId)` identities an automatic SAS ceremony has already
/// been offered for.
///
/// App-wide rather than per-widget because two `AutoVerificationLauncher`s can
/// be mounted at once — the settings pane embeds the device roster while the
/// setup modal is still open. Held in each launcher's own `State`, the one
/// that lost the modal lock knew nothing about what the winner had shown, so
/// after the winner closed and invalidated the providers the loser reopened the
/// sheet the user had just dismissed.
///
/// A device is recorded only when its ceremony is actually **shown**. Recording
/// on a failed lock acquisition looks equivalent and is not: a manual or
/// incoming verification sheet owning the lock invalidates the unverified-device
/// provider repeatedly while it is open, so every rebuild would burn through the
/// remaining peers and leave a newly paired device with no ceremony once the
/// lock freed up.
final NotifierProvider<MatrixVerificationHandled, Set<String>>
matrixVerificationHandledProvider =
    NotifierProvider<MatrixVerificationHandled, Set<String>>(
      MatrixVerificationHandled.new,
      name: 'matrixVerificationHandledProvider',
    );

class MatrixVerificationHandled extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Identity key for a device. Device ids are unique only within a Matrix
  /// user, and the unverified set deliberately spans users so legacy
  /// one-account-per-device pairings still appear.
  static String identityOf({
    required String? userId,
    required String deviceId,
  }) => '${userId ?? 'self'}/$deviceId';

  bool contains(String identity) => state.contains(identity);

  void markShown(String identity) => state = {...state, identity};

  /// Makes a single device eligible again — what "show the emoji again" means.
  ///
  /// Deliberately not a reset: clearing everything restarts selection at the
  /// head of the list, which reopens a stale peer sorting ahead of the device
  /// the user was actually looking at.
  void release(String identity) => state = {...state}..remove(identity);

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}
