import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/countdown_snackbar_content.dart';

/// A snackbar content widget that displays a pending correction with
/// a countdown timer and undo button.
///
/// The countdown visually indicates when the correction will be saved.
/// The user can tap "UNDO" to cancel the correction before it's saved.
///
/// Composes [CountdownSnackBarContent] for the progress indicator and
/// adds correction-specific content (seconds display, before/after text).
class CorrectionUndoSnackbarContent extends StatefulWidget {
  const CorrectionUndoSnackbarContent({
    required this.pending,
    required this.onUndo,
    super.key,
  });

  /// The pending correction to display.
  final PendingCorrection pending;

  /// Callback when the user taps the undo button.
  final VoidCallback onUndo;

  @override
  State<CorrectionUndoSnackbarContent> createState() =>
      _CorrectionUndoSnackbarContentState();
}

class _CorrectionUndoSnackbarContentState
    extends State<CorrectionUndoSnackbarContent> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Update remaining time display periodically (500ms is sufficient since
    // secondsLeft only changes once per second)
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final remaining = widget.pending.remainingTime;
    final secondsLeft = (remaining.inMilliseconds / 1000).ceil();
    final initialProgress =
        remaining.inMilliseconds / kCorrectionSaveDelay.inMilliseconds;

    return CountdownSnackBarContent(
      duration: remaining,
      initialProgress: initialProgress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.messages.correctionExamplePending(secondsLeft),
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${widget.pending.before}" \u2192 "${widget.pending.after}"',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: widget.onUndo,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Text(
                context.messages.correctionExampleCancel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
