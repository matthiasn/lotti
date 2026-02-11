import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global lock to ensure at most one verification modal is shown at a time.
final matrixVerificationModalLockProvider =
    NotifierProvider<MatrixVerificationModalLock, bool>(
  MatrixVerificationModalLock.new,
);

class MatrixVerificationModalLock extends Notifier<bool> {
  @override
  bool build() => false;

  bool tryAcquire() {
    if (state) return false;
    state = true;
    return true;
  }

  void release() {
    state = false;
  }
}
