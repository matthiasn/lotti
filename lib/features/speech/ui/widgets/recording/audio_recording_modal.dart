import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/speech/state/checkbox_visibility_provider.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/ui/app_fonts.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/ui/lotti_animated_checkbox.dart';

/// Entry point for the full-screen audio recording sheet.
class AudioRecordingModal {
  /// Presents the recording modal as a single-page Wolt sheet.
  ///
  /// Before showing, it flips the controller's `modalVisible` flag (so the
  /// floating recording indicator hides while the sheet is up) and seeds the
  /// optional [categoryId]; [linkedId] ties any recording to a parent entry.
  /// `modalVisible` is always cleared again once the sheet is dismissed — by
  /// the stop button, back gesture, or tapping outside. [useRootNavigator]
  /// selects which navigator hosts the sheet.
  static Future<void> show(
    BuildContext context, {
    String? linkedId,
    String? categoryId,
    bool useRootNavigator = true,
  }) async {
    // Get the controller before showing the modal
    final container = ProviderScope.containerOf(context);
    final controller = container.read(audioRecorderControllerProvider.notifier)
      // Set modal visible before showing
      ..setModalVisible(modalVisible: true);
    if (categoryId != null) {
      controller.setCategoryId(categoryId);
    }

    String? createdId;
    try {
      createdId = await ModalUtils.showSinglePageModal<String>(
        context: context,
        useRootNavigator: useRootNavigator,
        hasTopBarLayer: false,
        showCloseButton: false,
        padding: ModalUtils.defaultPadding(
          context,
        ).copyWith(bottom: context.designTokens.spacing.step5),
        builder: (BuildContext _) {
          return AudioRecordingModalContent(
            linkedId: linkedId,
            categoryId: categoryId,
          );
        },
      );
    } finally {
      // Modal has been dismissed (either by stop button, back gesture, or tapping outside)
      // Always set modal visibility to false after dismissal
      controller.setModalVisible(modalVisible: false);
    }

    // Navigate only after Wolt has completed the modal route. Starting a page
    // navigation from inside the sheet's own teardown can make Flutter try to
    // reactivate an element that the nested navigator has already removed.
    if (linkedId == null && createdId != null) {
      beamToNamed('/journal/$createdId');
    }
  }
}

/// Body of the recording sheet: the analog VU meter, elapsed-time readout,
/// the record/stop(/cancel) controls, and the automatic-prompt checkboxes.
///
/// Drives [AudioRecorderController] — `record` to start and `stop`/`cancel`
/// to finish the file-backed recording flow.
class AudioRecordingModalContent extends ConsumerStatefulWidget {
  const AudioRecordingModalContent({
    super.key,
    this.linkedId,
    this.categoryId,
  });

  /// Optional parent entry id to link any created audio entry to.
  final String? linkedId;

  /// Optional category id scoping the recording and prompt options.
  final String? categoryId;

  @override
  ConsumerState<AudioRecordingModalContent> createState() =>
      _AudioRecordingModalContentState();
}

class _AudioRecordingModalContentState
    extends ConsumerState<AudioRecordingModalContent> {
  bool _terminalActionInProgress = false;

  @override
  void initState() {
    super.initState();
    // Modal visibility is now managed in the show() method
  }

  @override
  void dispose() {
    // Modal visibility is now managed in the show() method
    super.dispose();
  }

  String formatDuration(String str) {
    return str.substring(0, str.length - 7);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(audioRecorderControllerProvider);
    final controller = ref.read(audioRecorderControllerProvider.notifier);
    final recordingStyle = ref.watch(recordingStyleProvider).asData?.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildVisualizer(state, recordingStyle, theme),

            // Duration display
            Text(
              formatDuration(state.progress.toString()),
              style: AppFonts.inconsolata(
                fontSize: fontSizeLarge,
                fontWeight: FontWeight.w300,
                color: theme.colorScheme.primaryFixedDim,
              ),
            ),

            const SizedBox(height: 20),

            // Control buttons in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Record/Stop button
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isRecording(state)
                      ? _buildStopButton(context, theme, state, controller)
                      : _buildRecordButton(context, controller, theme),
                ),
              ],
            ),

            // Automatic prompt options (shown when category or linked task
            // may provide automatic prompts, including profile-driven skills).
            if (widget.categoryId != null || widget.linkedId != null) ...[
              const SizedBox(height: 10),
              _buildAutomaticPromptOptions(context, controller, state, theme),
            ],
          ],
        ),
      ],
    );
  }

  /// Picks the primary level visualizer per [RecordingStyleController]'s
  /// persisted preference: [AiVoiceInputShader] (the orb) for
  /// [RecordingStyle.modern], the skeuomorphic [AnalogVuMeter] otherwise —
  /// including while the preference is still loading (`null`), so the meter
  /// never flashes to the orb and back on first frame.
  ///
  /// Unlike the onboarding preview, [AudioRecorderState] has no amplitude
  /// history, so only the primary visualizer swaps — the onboarding
  /// meter/orb + waveform "pair" isn't reproduced here.
  Widget _buildVisualizer(
    AudioRecorderState state,
    RecordingStyle? style,
    ThemeData theme,
  ) {
    if (style == RecordingStyle.modern) {
      final tokens = context.designTokens;
      return AiVoiceInputShader(
        dbfs: state.dBFS,
        size: 220,
        intensity: 1,
        primaryColor: tokens.colors.interactive.enabled,
        secondaryColor: tokens.colors.text.highEmphasis,
        backgroundColor: Colors.transparent,
      );
    }
    return AnalogVuMeter(
      vu: state.vu,
      dBFS: state.dBFS,
      size: 400,
      colorScheme: theme.colorScheme,
    );
  }

  bool _isRecording(AudioRecorderState state) {
    return state.status == AudioRecorderStatus.recording ||
        state.status == AudioRecorderStatus.paused;
  }

  Future<void> _stop() async {
    if (_terminalActionInProgress) return;

    setState(() => _terminalActionInProgress = true);
    final controller = ref.read(audioRecorderControllerProvider.notifier);

    String? createdId;
    try {
      createdId = await controller.stop();
    } catch (_) {}

    if (!mounted) return;

    // Pop exactly once and return the created entry to [AudioRecordingModal].
    // The previous catch-all called pop a second time when the first pop or the
    // following navigation failed, racing Wolt's inactive-element teardown.
    Navigator.of(context).pop(createdId);
  }

  /// Discards the in-progress recording entirely and closes the sheet.
  ///
  /// Unlike [_stop], no journal entry is created and no transcription / task
  /// summary is triggered — the page returns to exactly how it was before
  /// recording started.
  Future<void> _cancel() async {
    if (_terminalActionInProgress) return;

    final confirmed = await _confirmCancel();
    if (!confirmed || !mounted) return;

    setState(() => _terminalActionInProgress = true);
    final controller = ref.read(audioRecorderControllerProvider.notifier);
    try {
      await controller.cancel();
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _confirmCancel() async {
    final messages = context.messages;
    return showConfirmationModal(
      context: context,
      title: messages.audioRecordingDiscardDialogTitle,
      message: messages.audioRecordingDiscardDialogBody,
      cancelLabel: messages.audioRecordingDiscardDialogCancel,
      confirmLabel: messages.audioRecordingDiscardDialogConfirm,
    );
  }

  /// Compact circular X control that discards the recording. Rendered to the
  /// left of the stop button while recording. Uses the localized cancel
  /// label for accessibility/tooltip.
  Widget _buildCancelButton(BuildContext context, ThemeData theme) {
    final tokens = context.designTokens;
    return Tooltip(
      message: context.messages.audioRecordingCancel,
      child: Semantics(
        button: true,
        label: context.messages.audioRecordingCancel,
        child: GestureDetector(
          key: const ValueKey('cancel_recording'),
          // Make the whole 48×48 ring tappable, not just the inner icon — the
          // Container fill is transparent so without this hits only land on
          // the icon.
          behavior: HitTestBehavior.opaque,
          onTap: _terminalActionInProgress ? null : _cancel,
          child: Container(
            width: tokens.spacing.step9,
            height: tokens.spacing.step9,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              Icons.close,
              size: 22,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// Circular pause / resume control shown between the cancel and stop buttons
  /// while a recording is in progress.
  ///
  /// Tapping toggles [AudioRecorderController.pause] and
  /// [AudioRecorderController.resume]; the glyph swaps pause ↔ play and the
  /// accessibility/tooltip label follows. Tinted with the primary accent so it
  /// reads as a distinct, benign transport control next to the grey destructive
  /// cancel — a fumbled pause can't be mistaken for discard. Mirrors
  /// [_buildCancelButton]'s 48×48 ring so the whole control is tappable.
  /// Disabled while a terminal stop/cancel is already underway.
  Widget _buildPauseResumeButton(
    BuildContext context,
    AudioRecorderController controller,
    AudioRecorderState state,
    ThemeData theme,
  ) {
    final tokens = context.designTokens;
    final isPaused = state.status == AudioRecorderStatus.paused;
    final label = isPaused
        ? context.messages.audioRecordingResume
        : context.messages.audioRecordingPause;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          // Static key: a key that changed with [isPaused] would tear down and
          // rebuild this subtree on every toggle, so the AnimatedSwitcher below
          // could never run its cross-fade. The icon swap is animated by the
          // switcher's own child key instead.
          key: const ValueKey('pause_resume_button'),
          behavior: HitTestBehavior.opaque,
          onTap: _terminalActionInProgress
              ? null
              : () {
                  if (isPaused) {
                    controller.resume();
                  } else {
                    controller.pause();
                  }
                },
          child: Container(
            width: tokens.spacing.step9,
            height: tokens.spacing.step9,
            decoration: BoxDecoration(
              // A touch more fill + a stronger ring than a bare outline so the
              // circle body stays visible on the near-black surface and the
              // purple identity doesn't rely on the glyph alone.
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.85),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Padding(
                key: ValueKey(isPaused),
                // The play triangle's ink sits left of the glyph's geometric
                // center, so nudge it right to optically center it in the ring;
                // the symmetric pause bars need no offset.
                padding: EdgeInsets.only(
                  left: isPaused ? tokens.spacing.step1 : 0,
                ),
                child: Icon(
                  isPaused ? Icons.play_arrow : Icons.pause,
                  // Matches the sibling cancel (X) glyph size so the two
                  // circular controls read as one family.
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStopButton(
    BuildContext context,
    ThemeData theme,
    AudioRecorderState state,
    AudioRecorderController controller,
  ) {
    final tokens = context.designTokens;
    return Row(
      key: const ValueKey('stop_controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cancel (X) button — discards the whole recording without creating
        // an entry.
        _buildCancelButton(context, theme),
        SizedBox(width: tokens.spacing.step4),
        _buildPauseResumeButton(context, controller, state, theme),
        SizedBox(width: tokens.spacing.step4),
        // Stop button
        GestureDetector(
          onTap: _terminalActionInProgress ? null : _stop,
          child: Container(
            width: 120,
            height: tokens.spacing.step9,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.radii.xl),
              border: Border.all(
                color: theme.colorScheme.error,
                width: 2,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: tokens.spacing.step3,
                    height: tokens.spacing.step3,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.messages.audioRecordingStop,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton(
    BuildContext context,
    AudioRecorderController controller,
    ThemeData theme,
  ) {
    return GestureDetector(
      key: const ValueKey('record'),
      onTap: () => controller.record(linkedId: widget.linkedId),
      child: Container(
        width: 120,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            'RECORD',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutomaticPromptOptions(
    BuildContext context,
    AudioRecorderController controller,
    AudioRecorderState state,
    ThemeData theme,
  ) {
    // Use the extracted provider to compute visibility
    // This makes the logic testable independently from the widget
    final visibility = ref.watch(
      checkboxVisibilityProvider((
        categoryId: widget.categoryId,
        linkedId: widget.linkedId,
      )),
    );

    if (visibility.none) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        children: [
          if (visibility.speech)
            LottiAnimatedCheckbox(
              key: const Key('speech_recognition_checkbox'),
              label: context.messages.speechModalTitle,
              value: state.enableSpeechRecognition ?? true,
              onChanged: (value) {
                controller.setEnableSpeechRecognition(enable: value);
              },
            ),
        ],
      ),
    );
  }
}
