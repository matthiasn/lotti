import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Owns one correction-capture toast listener for an editable details page.
///
/// Keep this at the page boundary instead of individual checklist cards so a
/// global correction event is handled once per visible details surface. The
/// app shell leaves inactive tabs mounted with [TickerMode] disabled, so those
/// background surfaces must ignore the event. An active task details page
/// resolves the toast to its nested [ScaffoldMessenger], while an active
/// journal details page keeps the same undo affordance through the app-level
/// messenger.
class CorrectionCaptureToastListener extends ConsumerWidget {
  const CorrectionCaptureToastListener({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActiveSurface = TickerMode.valuesOf(context).enabled;

    ref.listen<PendingCorrection?>(
      correctionCaptureProvider,
      (previous, next) {
        if (!isActiveSurface || next == null || previous == next) return;

        final captureNotifier = ref.read(correctionCaptureProvider.notifier);
        final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: CorrectionUndoSnackbarContent(
              pending: next,
              onUndo: () {
                captureNotifier.cancel();
                messenger.hideCurrentSnackBar();
              },
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.zero,
            behavior: SnackBarBehavior.floating,
            dismissDirection: DismissDirection.down,
            duration: kCorrectionSaveDelay + const Duration(seconds: 1),
          ),
        );
      },
    );

    return child;
  }
}

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
