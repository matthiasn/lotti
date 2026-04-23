import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';

/// Shows a [DesignSystemToast] via the nearest [ScaffoldMessenger].
extension DesignSystemToastMessenger on BuildContext {
  /// Shows a [DesignSystemToast] as a floating SnackBar.
  ///
  /// Uses the shared [ScaffoldMessenger] queue without clearing it, so
  /// in-flight SnackBars (e.g. `CorrectionUndoSnackbarContent`) keep their
  /// undo affordance instead of being wiped by a new toast. Multiple rapid
  /// `showToast` calls will therefore queue behind each other.
  ///
  /// Passing `dismissible: false` hides the close action and disables
  /// swipe-to-dismiss so the toast stays up for the full [duration].
  ///
  // TODO(design-system): migrate to an isolated overlay / ToastController
  // so "only the latest toast is visible" can be enforced without affecting
  // other SnackBar types.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showToast({
    required DesignSystemToastTone tone,
    required String title,
    String? description,
    Duration duration = const Duration(seconds: 4),
    String? dismissSemanticsLabel,
    bool dismissible = true,
  }) {
    final messenger = ScaffoldMessenger.of(this);
    return messenger.showSnackBar(
      SnackBar(
        content: DesignSystemToast(
          tone: tone,
          title: title,
          description: description,
          onDismiss: dismissible ? messenger.hideCurrentSnackBar : null,
          dismissSemanticsLabel: dismissSemanticsLabel,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        dismissDirection: dismissible
            ? DismissDirection.down
            : DismissDirection.none,
        duration: duration,
      ),
    );
  }
}
