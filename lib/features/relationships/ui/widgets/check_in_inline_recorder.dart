import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// The recorder embedded in the check-in composer's narrative field and in
/// the check-in page's action bar, wearing the app's one recorder anatomy
/// (`recording_controls.dart`) — the recording sheet's: the level
/// visualizer the user chose, the running clock, and discard ✕ · pause ⏸ ·
/// the red Stop — then the reassurance that audio is on disk as it goes.
/// It replaced a Capture-shaped recorder whose orb doubled as Stop, which
/// read as a second app's recorder beside the sheet a task's microphone
/// opens. It starts recording the moment it is mounted —
/// the user already pressed *Dictate* — and reports one of three outcomes:
///
/// - [onRecorded] with the audio entry the recording became and how long it
///   ran;
/// - [onDiscarded] after a confirmed Discard, with nothing written;
/// - [onFailed] with the composer's own failure kind — a refused
///   microphone, a start that failed, or a stop that could not save — so
///   the composer can draw the right card rather than a toast.
///
/// With [adoptRunning] set the recorder does not start a new take: the
/// app-wide recorder is already running this person's recording — a sheet
/// dismissed mid-take and reopened — and the controls simply attach to it.
/// Calling `record()` then would *toggle* the running take off, which is
/// the recorder's contract for a second press.
///
/// It drives the app-wide [AudioRecorderController] the way the recording
/// sheet does, and hides the floating recording indicator while it is on
/// screen. Being unmounted does *not* stop the recording — the recording
/// sheet's own rule — so each host decides what leaving means: the
/// composer and the check-in page both ask the Discard question and cancel
/// the take on Discard, and both bring the indicator back if a take does
/// escape (a sheet swiped away, a page torn down by a route change), so
/// the user can stop it from there; the audio then lands in the journal
/// linked to the host, without a transcript.
class CheckInInlineRecorder extends ConsumerStatefulWidget {
  const CheckInInlineRecorder({
    required this.linkedId,
    required this.onRecorded,
    required this.onDiscarded,
    required this.onFailed,
    this.categoryId,
    this.adoptRunning = false,
    this.compact = false,
    this.showStatus = false,
    super.key,
  });

  /// The person the recording is linked to.
  final String linkedId;

  /// Their category, so the audio entry files where their other entries do.
  final String? categoryId;

  final void Function(String audioEntryId, Duration length) onRecorded;
  final VoidCallback onDiscarded;
  final void Function(CheckInSpeechFailureKind failure) onFailed;

  /// Attach to the recording already running rather than starting one.
  final bool adoptRunning;

  /// Whether to leave the orb or meter out, as the check-in page's dock
  /// does, so dictating never covers the check-in it adds to.
  final bool compact;

  /// Whether the recorder says *Recording* / *Paused* itself — the page's
  /// dock, which has no header of its own; the composer's header says it
  /// there — in the header's own grammar: the red dot, or the pause glyph.
  final bool showStatus;

  @override
  ConsumerState<CheckInInlineRecorder> createState() =>
      _CheckInInlineRecorderState();
}

class _CheckInInlineRecorderState extends ConsumerState<CheckInInlineRecorder> {
  late final AudioRecorderController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(audioRecorderControllerProvider.notifier);
    // After the first frame, not in initState: the recorder is a provider,
    // and a provider may not change while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    _controller.setModalVisible(modalVisible: true);
    if (widget.adoptRunning) return;
    _controller.setCategoryId(widget.categoryId);
    final failure = await _controller.record(
      linkedId: widget.linkedId,
      transcriptionHandledByCaller: true,
      shouldCancel: () => !mounted,
    );
    if (!mounted || failure == null) return;
    widget.onFailed(CheckInSpeechFailure.fromRecorder(failure).kind);
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Read before stopping: stop resets the elapsed time to zero.
    final length = ref.read(audioRecorderControllerProvider).progress;
    String? createdId;
    try {
      createdId = await _controller.stop();
    } catch (_) {
      createdId = null;
    }
    if (!mounted) return;
    if (createdId == null) {
      setState(() => _busy = false);
      widget.onFailed(CheckInSpeechFailureKind.recordingNotSaved);
      return;
    }
    widget.onRecorded(createdId, length);
  }

  Future<void> _discard() async {
    if (_busy) return;
    final messages = context.messages;
    final confirmed = await showConfirmationModal(
      context: context,
      title: messages.audioRecordingDiscardDialogTitle,
      // This surface's own words: the audio goes, the check-in stays.
      message: messages.checkInDiscardRecordingBody,
      cancelLabel: messages.audioRecordingDiscardDialogCancel,
      confirmLabel: messages.audioRecordingDiscardDialogConfirm,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await _controller.cancel();
    } finally {
      if (mounted) widget.onDiscarded();
    }
  }

  void _togglePause(AudioRecorderStatus status) {
    if (status == AudioRecorderStatus.paused) {
      unawaited(_controller.resume());
    } else {
      unawaited(_controller.pause());
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(audioRecorderControllerProvider);
    final paused = state.status == AudioRecorderStatus.paused;
    final live = state.status == AudioRecorderStatus.recording;

    return RecordingStage(
      key: const ValueKey('check-in-inline-recorder'),
      state: state,
      compact: widget.compact,
      notice: widget.showStatus
          ? Semantics(
              liveRegion: true,
              child: Row(
                key: const ValueKey('check-in-recorder-status'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (paused)
                    Icon(
                      LottiIcons.pause,
                      size: IconSizes.s,
                      color: tokens.colors.text.mediumEmphasis,
                    )
                  else
                    const DesignSystemBadge.dot(
                      tone: DesignSystemBadgeTone.danger,
                      excludeFromSemantics: true,
                    ),
                  SizedBox(width: tokens.spacing.step2),
                  Text(
                    paused
                        ? messages.checkInStatusPaused
                        : messages.checkInStatusRecording,
                    // The composer header's own tier, so the two status lines
                    // read alike.
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ),
            )
          : null,
      // Named, not live: the header's status line announces recording and
      // paused, so a reader hears each transition once.
      levelSemanticsLabel: live
          ? messages.audioRecordingLive
          : paused
          ? messages.checkInStatusPaused
          : null,
      controls: RecordingTransportControls(
        paused: paused,
        progress: state.progress,
        // In words for a reader: "23 seconds", not "zero colon two three".
        progressSemanticsLabel: checkInSpokenClockLabel(
          messages,
          state.progress,
        ),
        // Inert while a stop or discard is in flight, and until the take is
        // actually running: before `record` lands, or after a refused
        // start, there is nothing to pause or stop.
        busy: _busy || !(live || paused),
        discardLabel: messages.checkInDiscardRecording,
        discardKey: const ValueKey('check-in-recorder-discard'),
        pauseKey: const ValueKey('check-in-recorder-pause'),
        stopKey: const ValueKey('check-in-recorder-stop'),
        onDiscard: _discard,
        onTogglePause: () => _togglePause(state.status),
        onStop: _stop,
      ),
    );
  }
}
