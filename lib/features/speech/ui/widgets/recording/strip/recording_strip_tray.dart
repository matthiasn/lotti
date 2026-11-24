import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/app_settings_opener.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_failure_callout.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_grabber.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_leading.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// The recording strip opened up: the full recorder ([RecordingStage]) drawn
/// above the strip's place, with no scrim, so the page above stays usable.
///
/// It carries what the slim row leaves out — the subject's title by the
/// way back, and discard ✕ (asked first) — over the level line and the
/// controls across its whole width, pause and Stop at the end where the
/// strip keeps them, and a grabber that folds it back (as does a swipe
/// down). When a start failed, it opens on that failure's card instead:
/// *Open settings* for a refused microphone, *Stop that recording* for a
/// take running elsewhere.
///
/// It is presentational, bound to the app-wide recorder: it never starts a
/// take of its own.
class RecordingStripTray extends ConsumerStatefulWidget {
  const RecordingStripTray({super.key});

  static const Key trayKey = ValueKey('recording-strip-tray');
  static const Key grabberKey = ValueKey('recording-strip-tray-grabber');

  @override
  ConsumerState<RecordingStripTray> createState() => _RecordingStripTrayState();
}

class _RecordingStripTrayState extends ConsumerState<RecordingStripTray> {
  /// True while the tray's own Stop or discard is on its way, and while
  /// *Stop that recording* saves the other take.
  bool _busy = false;

  RecordingSession get _session => ref.read(recordingSessionProvider);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    if (_busy) return;
    final messages = context.messages;
    final confirmed = await showConfirmationModal(
      context: context,
      title: messages.audioRecordingDiscardDialogTitle,
      message: messages.audioRecordingDiscardDialogBody,
      cancelLabel: messages.audioRecordingDiscardDialogCancel,
      confirmLabel: messages.audioRecordingDiscardDialogConfirm,
    );
    if (!confirmed || !mounted) return;
    await _run(_session.discard);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final tray = ref.read(recordingTrayControllerProvider.notifier);
    final failure = ref.watch(
      recordingTrayControllerProvider.select((state) => state.failure),
    );
    final state = ref.watch(audioRecorderControllerProvider);
    final recorder = ref.read(audioRecorderControllerProvider.notifier);
    final paused = state.status == AudioRecorderStatus.paused;
    final live = state.isTakeActive;

    return RecordingStrip.surface(
      context,
      key: RecordingStripTray.trayKey,
      radius: tokens.radii.xl,
      child: GestureDetector(
        // The whole tray takes the swipe, the gaps between its parts too.
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 0) tray.fold();
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step4,
            tokens.spacing.step2,
            tokens.spacing.step4,
            tokens.spacing.step4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Grabber(
                label: messages.recordingStripFoldRecorder,
                onTap: tray.fold,
              ),
              if (live) ...[
                const RecordingStripLeading(),
                SizedBox(height: tokens.spacing.step3),
              ],
              if (failure != null) ...[
                RecordingFailureCallout(
                  failure: failure,
                  stopping: _busy,
                  onOpenSettings: () => ref.read(appSettingsOpenerProvider)(),
                  onStopRunning: () => _run(_session.stop),
                ),
                if (live) SizedBox(height: tokens.spacing.step5),
              ],
              if (live) ...[
                Semantics(
                  label: paused
                      ? messages.checkInStatusPaused
                      : messages.audioRecordingLive,
                  child: ExcludeSemantics(
                    child: LayoutBuilder(
                      builder: (context, constraints) => RecordingLevelLine(
                        state: state,
                        width: constraints.maxWidth,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                RecordingTransportControls(
                  spread: true,
                  paused: paused,
                  progress: state.progress,
                  progressSemanticsLabel: spokenClockLabel(
                    messages,
                    state.progress,
                  ),
                  busy: _busy,
                  onDiscard: _discard,
                  onTogglePause: () =>
                      paused ? recorder.resume() : recorder.pause(),
                  onStop: () => _run(_session.stop),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The handle at the tray's top edge: a short bar, the whole strip of it
/// one button that folds the tray.
class _Grabber extends StatelessWidget {
  const _Grabber({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: RecordingStripTray.grabberKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: context.designTokens.spacing.step6,
          child: const Align(
            alignment: Alignment.topCenter,
            child: RecordingGrabber(),
          ),
        ),
      ),
    );
  }
}
