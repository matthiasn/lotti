import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/capture_dbfs.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// The recorder embedded in the check-in composer's narrative field
/// (design 2026-09-13, options 1b / 2b): a live level strip, the running
/// time, the reassurance that audio is on disk as it goes, and Discard ·
/// Pause · Stop. It starts recording the moment it is mounted — the user
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
/// screen. Being dismissed with the sheet does *not* stop the recording —
/// the same rule the sheet follows — so the composer's sheet brings the
/// indicator back once it has closed, and the user can stop the recording
/// from there; the audio then lands in the journal linked to the person,
/// without a transcript.
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
      message: messages.audioRecordingDiscardDialogBody,
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
            child: LayoutBuilder(
              builder: (context, constraints) => LiveWaveform(
                amplitudes: _amplitudes,
                width: constraints.maxWidth,
                height: tokens.spacing.step7,
                barCount: CheckInInlineRecorder.amplitudeWindow ~/ 2,
                color: paused
                    ? tokens.colors.text.lowEmphasis
                    : tokens.colors.interactive.enabled,
              ),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        // Tabular mono figures, so the tick never moves the controls beneath
        // it; the same `m:ss` shape the saved-audio line and the chip use.
        Text(
          checkInClockLabel(state.progress),
          key: const ValueKey('check-in-recorder-clock'),
          textAlign: TextAlign.center,
          style: monoMetaStyle(
            tokens,
            tokens.colors,
            base: tokens.typography.styles.heading.heading3,
            color: tokens.colors.text.highEmphasis,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: tokens.spacing.step4,
          runSpacing: tokens.spacing.step3,
          children: [
            // Destructive ink, like the edit sheet's delete: the accent is
            // for the way forward, never for throwing a take away.
            DesignSystemButton(
              key: const ValueKey('check-in-recorder-discard'),
              label: messages.checkInDiscardRecording,
              variant: DesignSystemButtonVariant.dangerTertiary,
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
            DesignSystemButton(
              key: const ValueKey('check-in-recorder-stop'),
              label: messages.audioRecordingStop,
              leadingIcon: LottiIcons.stop,
              size: DesignSystemButtonSize.medium,
              tapTargetSize: MaterialTapTargetSize.padded,
              isLoading: _busy,
              onPressed: _busy ? null : _stop,
            ),
          ],
        ),
      ],
    );
  }
}
