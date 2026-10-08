import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/capture_dbfs.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// The recorder embedded in the check-in composer's narrative field
/// (design 2026-09-13, options 1b / 2b), wearing the app's one voice
/// anatomy — Capture's: the short teal level strip over the Daily OS voice
/// orb, the orb breathing with the same level — then the running time, the
/// reassurance that audio is on disk as it goes, and Discard · Pause
/// centred beneath. The orb is the one Stop, as on Capture: tapping it
/// while live stops, while paused resumes, and while the stop is in flight
/// it dims and takes no tap. A filled Stop pill beside it gave the surface
/// two primaries for one act, which every reviewer read as a second app's
/// recorder. It starts recording the moment it is mounted — the user
/// already pressed *Dictate* — and reports one of three outcomes:
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

  /// How many level samples the strip keeps — enough to fill the widest
  /// composer at the painter's bar pitch.
  static const int amplitudeWindow = 64;

  @override
  ConsumerState<CheckInInlineRecorder> createState() =>
      _CheckInInlineRecorderState();
}

class _CheckInInlineRecorderState extends ConsumerState<CheckInInlineRecorder> {
  late final AudioRecorderController _controller;
  List<double> _amplitudes = const [];
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
    ref.listen<double>(
      audioRecorderControllerProvider.select((state) => state.dBFS),
      (_, dbfs) {
        final next = [..._amplitudes, normaliseDbfs(dbfs)];
        setState(() {
          _amplitudes = next.length > CheckInInlineRecorder.amplitudeWindow
              ? next.sublist(
                  next.length - CheckInInlineRecorder.amplitudeWindow,
                )
              : next;
        });
      },
    );
    final state = ref.watch(audioRecorderControllerProvider);
    final paused = state.status == AudioRecorderStatus.paused;
    final live = state.status == AudioRecorderStatus.recording;

    return Column(
      key: const ValueKey('check-in-inline-recorder'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Named, not live: the header's status line announces recording
        // and paused, so a reader hears each transition once.
        Semantics(
          label: live
              ? messages.audioRecordingLive
              : paused
              ? messages.checkInStatusPaused
              : '',
          child: ExcludeSemantics(
            // Capture's strip, to the pixel: its width and height, and its
            // default teal. A field-wide strip in the prose ink read as a
            // rule across the box rather than as the orb's meter.
            child: Center(
              child: LiveWaveform(
                amplitudes: _amplitudes,
                width: VoiceOrbZone.waveformWidth,
                height: VoiceOrbZone.waveformSlotHeight,
                barCount: CheckInInlineRecorder.amplitudeWindow ~/ 2,
              ),
            ),
          ),
        ),
        // `step5` air on both sides of the orb, the voice zone's own rule:
        // the listening shader spills past the button field, so the strip
        // above and the clock below need clearance for it to breathe.
        SizedBox(height: tokens.spacing.step5),
        // The orb is a control — the one Stop — so it stays outside the
        // strip's `ExcludeSemantics` and announces its own verb.
        Center(
          child: VoiceButton(
            key: const ValueKey('check-in-recorder-orb'),
            // Dimmed and inert while the stop is in flight, as Capture is
            // while it transcribes.
            phase: _busy
                ? CapturePhase.transcribing
                : live
                ? CapturePhase.listening
                : CapturePhase.idle,
            dbfs: state.dBFS,
            size: tokens.spacing.step11,
            semanticLabel: live
                ? messages.audioRecordingStop
                : messages.audioRecordingResume,
            // Inert until the take is actually running: before `record`
            // lands, or after a refused start, there is nothing to resume.
            onTap: _busy
                ? null
                : live
                ? _stop
                : paused
                ? () => _togglePause(state.status)
                : null,
          ),
        ),
        // The voice zone's own `step5` under the orb, so the caption sits
        // where Capture's does.
        SizedBox(height: tokens.spacing.step5),
        // The orb's verb in words, Capture's caption slot: the orb is the
        // one Stop, and a glowing picture does not say so to someone who
        // has not learned it — they tapped Pause and waited, or feared the
        // header's × would lose the take.
        Text(
          live
              ? messages.checkInOrbStopHint
              : paused
              ? messages.checkInOrbResumeHint
              : '',
          key: const ValueKey('check-in-recorder-orb-hint'),
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        // `step2` to the clock: caption and clock are one status group under
        // the orb; `step5` below, before Discard · Pause, so the actions read
        // as a second group rather than a fifth line of status.
        SizedBox(height: tokens.spacing.step2),
        // The feature's timestamp style over the heading tier — tabular
        // figures, so the tick never moves the controls beneath it, in the
        // UI face: this clock was the last monospace string on People.
        Text(
          checkInClockLabel(state.progress),
          key: const ValueKey('check-in-recorder-clock'),
          // In words for a reader: "23 seconds", not "zero colon two three".
          semanticsLabel: checkInSpokenClockLabel(messages, state.progress),
          textAlign: TextAlign.center,
          // `subtitle1`, not a heading: the orb is the recorder's one large
          // thing, and a heading-sized clock under it competed with it.
          style: relationshipTimestampStyle(
            tokens,
            base: tokens.typography.styles.subtitle.subtitle1,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LottiIcons.confirmCircled,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            ),
            SizedBox(width: tokens.spacing.step2),
            Flexible(
              child: Text(
                messages.checkInAudioSavedAsYouGo,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step5),
        // Centred under the orb, the secondary acts of a Capture-shaped
        // recorder: neither is the way forward — the orb is — so neither
        // wears the accent.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          // `step5` between the two: Discard sits beside Pause, and a
          // shaky thumb aiming at Pause must not land on the one control
          // here that throws the take away.
          spacing: tokens.spacing.step5,
          runSpacing: tokens.spacing.step3,
          children: [
            // Quiet: red on this surface is the live dot alone.
            DesignSystemButton(
              key: const ValueKey('check-in-recorder-discard'),
              label: messages.checkInDiscardRecording,
              variant: DesignSystemButtonVariant.quiet,
              size: DesignSystemButtonSize.medium,
              tapTargetSize: MaterialTapTargetSize.padded,
              onPressed: _busy ? null : _discard,
            ),
            DesignSystemButton(
              key: const ValueKey('check-in-recorder-pause'),
              label: paused
                  ? messages.audioRecordingResume
                  : messages.audioRecordingPause,
              leadingIcon: paused ? LottiIcons.play : LottiIcons.pause,
              variant: DesignSystemButtonVariant.outlined,
              size: DesignSystemButtonSize.medium,
              tapTargetSize: MaterialTapTargetSize.padded,
              onPressed: _busy ? null : () => _togglePause(state.status),
            ),
          ],
        ),
      ],
    );
  }
}
