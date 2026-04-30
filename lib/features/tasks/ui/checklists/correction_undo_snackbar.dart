import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// SnackBar content that shows a pending text-correction with a countdown
/// bar and an UNDO action, rendered through [DesignSystemToast] so the
/// correction-capture flow shares the same visual language as the rest of
/// the design-system toasts.
///
/// The widget ticks every 500ms to refresh the "save in N s" title; the
/// countdown bar drains continuously off a single [DesignSystemToast]
/// animation controller (started once with the initial remaining time) so
/// the bar isn't stuttered by parent rebuilds.
class CorrectionUndoSnackbarContent extends StatefulWidget {
  const CorrectionUndoSnackbarContent({
    required this.pending,
    required this.onUndo,
    super.key,
  });

  /// The pending correction to display.
  final PendingCorrection pending;

  /// Callback when the user taps the undo action.
  final VoidCallback onUndo;

  @override
  State<CorrectionUndoSnackbarContent> createState() =>
      _CorrectionUndoSnackbarContentState();
}

class _CorrectionUndoSnackbarContentState
    extends State<CorrectionUndoSnackbarContent> {
  Timer? _tick;
  late final Duration _initialRemaining;
  late final double _initialProgress;

  @override
  void initState() {
    super.initState();
    _initialRemaining = widget.pending.remainingTime;
    _initialProgress =
        (_initialRemaining.inMilliseconds / kCorrectionSaveDelay.inMilliseconds)
            .clamp(0.0, 1.0);
    // 500ms is sufficient — the visible counter only changes once per second.
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.pending.remainingTime;
    final secondsLeft = (remaining.inMilliseconds / 1000).ceil().clamp(0, 999);

    return DesignSystemToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.correctionExamplePending(secondsLeft),
      description: '"${widget.pending.before}" → "${widget.pending.after}"',
      action: ToastAction(
        label: context.messages.correctionExampleCancel,
        onPressed: widget.onUndo,
      ),
      countdownDuration: _initialRemaining,
      initialCountdownProgress: _initialProgress,
    );
  }
}
