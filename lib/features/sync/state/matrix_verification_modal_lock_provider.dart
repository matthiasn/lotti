import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global lock to ensure at most one verification modal is shown at a time.
final matrixVerificationModalLockProvider =
    NotifierProvider<MatrixVerificationModalLock, bool>(
      MatrixVerificationModalLock.new,
    );

/// Single-holder lock (state = `true` when held) that serialises the device
/// verification modal so two concurrent verification requests cannot stack two
/// modals on top of each other.
class MatrixVerificationModalLock extends Notifier<bool> {
  @override
  bool build() => false;

  /// Acquires the lock, returning `true` if it was free (and is now held) or
  /// `false` if another holder already owns it.
  bool tryAcquire() {
    if (state) return false;
    state = true;
    return true;
  }

  /// Releases the lock so the next requester can [tryAcquire] it.
  void release() {
    state = false;
  }
}
