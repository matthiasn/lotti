import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// Why an [InlineRecorder] has no recording to hand back.
enum InlineRecordingFailure {
  /// The OS refused the microphone.
  microphoneDenied,

  /// The recorder could not start.
  startFailed,

  /// The app-wide recorder is running a take that is not this subject's —
  /// started elsewhere, or for something else. It has to be stopped from the
  /// recording indicator first.
  recorderBusy,

  /// The recorder ran but could not be stopped and saved. The take is lost.
  notSaved,
}

/// A recording's length in words for a screen reader: "23 seconds", not
/// "zero colon two three".
String spokenClockLabel(AppLocalizations messages, Duration length) {
  final total = length.inSeconds.clamp(0, 1 << 31);
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return [
    if (minutes > 0) messages.checkInSpokenMinutes(minutes),
    if (seconds > 0 || minutes == 0) messages.checkInSpokenSeconds(seconds),
  ].join(' ');
}

/// The recorder a sheet or a page embeds to record about one subject — a
/// person's check-in, a goal's — wearing the app's one recorder anatomy
/// (`recording_controls.dart`): the level visualizer the user chose, the
/// running clock, and discard ✕ · pause ⏸ · the red Stop.
///
/// It starts recording the moment it is mounted — the user already pressed
/// *Speak* or *Dictate* — and reports one of three outcomes:
///
/// - [onRecorded] with the audio entry the recording became and how long it
///   ran;
/// - [onDiscarded] after a confirmed Discard, with nothing written;
/// - [onFailed] with the reason, so the host can draw the right card rather
///   than a toast.
///
/// **It never takes over another subject's take.** The app-wide recorder's
/// `record()` is a toggle: called while a take is running it stops and saves
/// that take — under whatever subject the caller just named. So before
/// starting, the recorder looks: a take already running for [linkedId] is
/// adopted (a sheet dismissed mid-take and reopened simply attaches to it),
/// and a take running for anything else is left alone and reported as
/// [InlineRecordingFailure.recorderBusy]. [adoptRunning] says the host
/// already knows the running take is this subject's.
///
/// It drives the app-wide [AudioRecorderController] the way the recording
/// sheet does, and hides the floating recording indicator while it is on
/// screen. Being unmounted does *not* stop the recording — the recording
/// sheet's own rule — so each host decides what leaving means, and brings
/// the indicator back if a take does escape, so the user can stop it from
/// there; the audio then lands in the journal linked to the subject.
class InlineRecorder extends ConsumerStatefulWidget {
  const InlineRecorder({
    required this.linkedId,
    required this.onRecorded,
    required this.onDiscarded,
    required this.onFailed,
    this.categoryId,
    this.adoptRunning = false,
    this.compact = false,
    this.showStatus = false,
    this.transcriptionHandledByCaller = true,
    super.key,
  });

  /// The entry the recording is linked to.
  final String linkedId;

  /// Its category, so the audio entry files where its other entries do.
  final String? categoryId;

  final void Function(String audioEntryId, Duration length) onRecorded;
  final VoidCallback onDiscarded;
  final void Function(InlineRecordingFailure failure) onFailed;

  /// Attach to the recording already running rather than starting one.
  final bool adoptRunning;

  /// Whether to leave the orb or meter out, as a page's dock does, so
  /// recording never covers the thing it adds to.
  final bool compact;

  /// Whether the recorder says *Recording* / *Paused* itself — for a host
  /// with no status line of its own — in the header's own grammar: the red
  /// dot, or the pause glyph.
  final bool showStatus;

  /// True when the host transcribes the take itself; false leaves it to the
  /// recorder's own post-recording automation, which also covers a take
  /// stopped from the floating indicator after the host is gone.
  final bool transcriptionHandledByCaller;

  @override
  ConsumerState<InlineRecorder> createState() => _InlineRecorderState();
}

class _InlineRecorderState extends ConsumerState<InlineRecorder> {
  late final AudioRecorderController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(audioRecorderControllerProvider.notifier);
    // After the first frame, not in initState: the recorder is a provider,
    // and a provider may not change while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await _start();
    });
  }

  Future<void> _start() async {
    final running = ref.read(audioRecorderControllerProvider);
    final taking =
        running.status == AudioRecorderStatus.recording ||
        running.status == AudioRecorderStatus.paused;
    if (taking && !widget.adoptRunning && running.linkedId != widget.linkedId) {
      // Someone else's take: calling `record()` would stop it and file it
      // under this subject.
      widget.onFailed(InlineRecordingFailure.recorderBusy);
      return;
    }
    _controller.setModalVisible(modalVisible: true);
    if (widget.adoptRunning || taking) return;
    _controller.setCategoryId(widget.categoryId);
    final failure = await _controller.record(
      linkedId: widget.linkedId,
      transcriptionHandledByCaller: widget.transcriptionHandledByCaller,
      shouldCancel: () => !mounted,
    );
    if (!mounted || failure == null) return;
    widget.onFailed(switch (failure) {
      AudioRecordingFailure.permissionDenied =>
        InlineRecordingFailure.microphoneDenied,
      // `busy` here is a start or a stop still in flight — a start that did
      // not happen, so it reads as a failed start.
      AudioRecordingFailure.startFailed ||
      AudioRecordingFailure.busy => InlineRecordingFailure.startFailed,
    });
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
      widget.onFailed(InlineRecordingFailure.notSaved);
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

  Future<void> _togglePause(AudioRecorderStatus status) =>
      status == AudioRecorderStatus.paused
      ? _controller.resume()
      : _controller.pause();

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
      // Named, not live: the status line announces recording and paused, so
      // a reader hears each transition once.
      levelSemanticsLabel: live
          ? messages.audioRecordingLive
          : paused
          ? messages.checkInStatusPaused
          : null,
      controls: RecordingTransportControls(
        paused: paused,
        progress: state.progress,
        // In words for a reader: "23 seconds", not "zero colon two three".
        progressSemanticsLabel: spokenClockLabel(messages, state.progress),
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
