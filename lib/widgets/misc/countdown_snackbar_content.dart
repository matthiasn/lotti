import 'package:flutter/material.dart';

/// A SnackBar content widget with a countdown progress indicator.
///
/// The progress bar at the top animates from [initialProgress] to 0 over
/// [duration]. Typically used inside a [SnackBar] with `padding:
/// EdgeInsets.zero` so the progress bar spans the full width.
class CountdownSnackBarContent extends StatefulWidget {
  const CountdownSnackBarContent({
    required this.duration,
    required this.child,
    this.initialProgress = 1.0,
    super.key,
  });

  /// Total animation duration for the progress bar.
  final Duration duration;

  /// Content displayed below the progress indicator.
  final Widget child;

  /// Starting progress value (1.0 = full bar, 0.0 = empty).
  /// Defaults to 1.0. Use a value < 1.0 when resuming a countdown
  /// that has already partially elapsed.
  final double initialProgress;

  @override
  State<CountdownSnackBarContent> createState() =>
      _CountdownSnackBarContentState();
}

class _CountdownSnackBarContentState extends State<CountdownSnackBarContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProgress.clamp(0.0, 1.0);
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: initial,
    );
    _controller.reverse(from: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: _controller.value,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.primary,
              ),
              minHeight: 3,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

/// Helper to show a floating [SnackBar] with a countdown progress indicator.
///
/// Replaces any current SnackBar, then shows one that auto-dismisses after
/// [duration] (plus a small buffer so the bar reaches zero before the
/// SnackBar fades). Use [actionLabel]/[onAction] to add an undo button
/// inside the content (avoids Flutter's `SnackBarAction` which can prevent
/// auto-dismiss on some platforms).
void showCountdownSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required Duration duration,
  String? actionLabel,
  VoidCallback? onAction,
  Color? backgroundColor,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: CountdownSnackBarContent(
          duration: duration,
          child: _CountdownSnackBarBody(
            message: message,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: duration + const Duration(seconds: 1),
        padding: EdgeInsets.zero,
        backgroundColor: backgroundColor,
      ),
    );
}

/// Standard body layout for [showCountdownSnackBar]: message + optional action.
class _CountdownSnackBarBody extends StatelessWidget {
  const _CountdownSnackBarBody({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
