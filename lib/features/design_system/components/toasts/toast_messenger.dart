import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';

/// Viewport width at or above which the toast is considered "desktop":
/// the SnackBar is constrained to roughly 75% of the viewport (clamped
/// between [_toastDesktopMinWidth] and [_toastDesktopMaxWidth]) and
/// floats bottom-centered. Below this width the SnackBar uses Flutter's
/// default floating layout — full width minus theme margin.
const double _toastDesktopBreakpoint = 720;

/// Fraction of the viewport width the desktop toast targets before the
/// clamps apply.
const double _toastDesktopWidthFactor = 0.75;

/// Lower clamp for the desktop toast width — narrow enough to keep
/// short success messages compact without truncating the icon + title +
/// dismiss row.
const double _toastDesktopMinWidth = 360;

/// Upper clamp for the desktop toast width — keeps the toast from
/// stretching across an ultrawide window where 75% of the viewport
/// would dominate the bottom edge.
const double _toastDesktopMaxWidth = 1200;

/// Returns the explicit pixel width to apply to the floating SnackBar
/// for the supplied messenger context, or `null` to fall back to
/// Flutter's default full-width-minus-margin layout.
///
/// Setting `width` on a floating SnackBar centers it horizontally — so
/// constraining the width is also what gives the desktop toast its
/// bottom-center placement.
double? _desktopSnackBarWidth(BuildContext context) {
  final viewport = MediaQuery.maybeOf(context)?.size.width;
  if (viewport == null || viewport < _toastDesktopBreakpoint) {
    return null;
  }
  return (viewport * _toastDesktopWidthFactor).clamp(
    _toastDesktopMinWidth,
    _toastDesktopMaxWidth,
  );
}

/// Shared SnackBar wrapper used by both the `BuildContext.showToast`
/// sugar and the `ScaffoldMessengerState.showDesignSystemToast` form.
SnackBar _buildToastSnackBar({
  required ScaffoldMessengerState messenger,
  required DesignSystemToastTone tone,
  required String title,
  required String? description,
  required Duration duration,
  required String? dismissSemanticsLabel,
  required bool dismissible,
  required ToastAction? action,
  required bool countdown,
  required double initialCountdownProgress,
}) {
  return SnackBar(
    content: DesignSystemToast(
      tone: tone,
      title: title,
      description: description,
      action: action,
      onDismiss: dismissible ? messenger.hideCurrentSnackBar : null,
      dismissSemanticsLabel: dismissSemanticsLabel,
      countdownDuration: countdown ? duration : null,
      initialCountdownProgress: initialCountdownProgress,
    ),
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    behavior: SnackBarBehavior.floating,
    width: _desktopSnackBarWidth(messenger.context),
    dismissDirection: dismissible
        ? DismissDirection.down
        : DismissDirection.none,
    // Give the countdown bar a beat to reach zero before the SnackBar
    // fades; otherwise the bar appears clipped on dismissal.
    duration: countdown ? duration + const Duration(seconds: 1) : duration,
  );
}

/// Shows a [DesignSystemToast] via a [ScaffoldMessengerState] captured
/// up-front. Use this from async callbacks that may outlive the calling
/// widget (e.g. swipe-to-dismiss `onDismissed`, where the row is removed
/// from the tree before the toast fires).
extension DesignSystemMessengerToast on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  showDesignSystemToast({
    required DesignSystemToastTone tone,
    required String title,
    String? description,
    Duration duration = const Duration(seconds: 4),
    String? dismissSemanticsLabel,
    bool dismissible = true,
    ToastAction? action,
    bool countdown = false,
    double initialCountdownProgress = 1.0,
    bool replaceCurrent = false,
    bool clearQueue = false,
  }) {
    if (clearQueue) {
      clearSnackBars();
    } else if (replaceCurrent) {
      hideCurrentSnackBar();
    }
    return showSnackBar(
      _buildToastSnackBar(
        messenger: this,
        tone: tone,
        title: title,
        description: description,
        duration: duration,
        dismissSemanticsLabel: dismissSemanticsLabel,
        dismissible: dismissible,
        action: action,
        countdown: countdown,
        initialCountdownProgress: initialCountdownProgress,
      ),
    );
  }
}

/// Shows a [DesignSystemToast] via the nearest [ScaffoldMessenger].
extension DesignSystemToastMessenger on BuildContext {
  /// Shows a [DesignSystemToast] as a floating SnackBar.
  ///
  /// Uses the shared [ScaffoldMessenger] queue. Passing
  /// `replaceCurrent: true` calls [ScaffoldMessengerState.hideCurrentSnackBar]
  /// first so the new toast displays immediately instead of waiting for the
  /// in-flight one to finish — items already queued behind it still appear
  /// afterwards. Passing `clearQueue: true` calls
  /// [ScaffoldMessengerState.clearSnackBars] instead, dropping every queued
  /// item so the new toast is the only one the user will see; use this for
  /// terminal status reporting (e.g. "all confirmed" / "all failed") that
  /// supersedes prior in-flight per-item toasts. The default keeps the
  /// queue intact so plain confirmation toasts don't wipe an unrelated
  /// in-flight undo.
  ///
  /// Passing `dismissible: false` hides the close action and disables
  /// swipe-to-dismiss so the toast stays up for the full [duration].
  ///
  /// Provide [action] to render a labelled call-to-action button (e.g.
  /// "UNDO") inline with the dismiss icon. Provide [countdown: true] to
  /// paint a tone-coloured progress strip along the toast's top edge that
  /// drains over [duration] — used for undoable transient actions.
  ///
  /// Toasts share `ScaffoldMessenger`'s queue; pass [replaceCurrent] /
  /// [clearQueue] when only the latest should be visible.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showToast({
    required DesignSystemToastTone tone,
    required String title,
    String? description,
    Duration duration = const Duration(seconds: 4),
    String? dismissSemanticsLabel,
    bool dismissible = true,
    ToastAction? action,
    bool countdown = false,
    double initialCountdownProgress = 1.0,
    bool replaceCurrent = false,
    bool clearQueue = false,
  }) {
    return ScaffoldMessenger.of(this).showDesignSystemToast(
      tone: tone,
      title: title,
      description: description,
      duration: duration,
      dismissSemanticsLabel: dismissSemanticsLabel,
      dismissible: dismissible,
      action: action,
      countdown: countdown,
      initialCountdownProgress: initialCountdownProgress,
      replaceCurrent: replaceCurrent,
      clearQueue: clearQueue,
    );
  }
}
