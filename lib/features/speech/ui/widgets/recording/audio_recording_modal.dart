import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/checkbox_visibility_provider.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Entry point for the full-screen audio recording sheet.
class AudioRecordingModal {
  /// Presents the recording modal as a single-page Wolt sheet.
  ///
  /// Before showing, it flips the controller's `modalVisible` flag (so the
  /// floating recording indicator hides while the sheet is up) and seeds the
  /// [categoryId] (including clearing an earlier category when null);
  /// [linkedId] ties any recording to a parent entry. [transcriptionHandledByCaller]
  /// suppresses automatic inference and hides its controls for this sheet;
  /// the caller starts transcription after save. Shared preferences are unchanged.
  /// `modalVisible` is always cleared again once the sheet is dismissed — by
  /// the stop button, back gesture, or tapping outside. [useRootNavigator]
  /// selects which navigator hosts the sheet.
  ///
  /// Returns the id of the audio entry the recording created, or `null` when
  /// the sheet was dismissed or the recording cancelled. Callers that want to
  /// do something with the recording — the check-in sheet waits for its
  /// transcript — need the id; the ones that only wanted the side effect can
  /// keep ignoring it.
  static Future<String?> show(
    BuildContext context, {
    String? linkedId,
    String? categoryId,
    bool useRootNavigator = true,
    bool transcriptionHandledByCaller = false,
  }) async {
    // Get the controller before showing the modal
    final container = ProviderScope.containerOf(context);
    final controller = container.read(audioRecorderControllerProvider.notifier)
      // Set modal visible before showing
      ..setModalVisible(modalVisible: true)
      // An uncategorized person must not inherit an earlier category.
      ..setCategoryId(categoryId);

    String? createdId;
    try {
      createdId = await ModalUtils.showSinglePageModal<String>(
        context: context,
        useRootNavigator: useRootNavigator,
        hasTopBarLayer: false,
        showCloseButton: false,
        padding: ModalUtils.defaultPadding(context),
        builder: (BuildContext _) {
          return AudioRecordingModalContent(
            linkedId: linkedId,
            categoryId: categoryId,
            showTranscriptionOptions: !transcriptionHandledByCaller,
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
    return createdId;
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
    this.showTranscriptionOptions = true,
  });

  /// Optional parent entry id to link any created audio entry to.
  final String? linkedId;

  /// Optional category id scoping the recording and prompt options.
  final String? categoryId;

  /// False when the caller owns transcription instead of recorder automation.
  final bool showTranscriptionOptions;

  @override
  ConsumerState<AudioRecordingModalContent> createState() =>
      _AudioRecordingModalContentState();
}

class _AudioRecordingModalContentState
    extends ConsumerState<AudioRecordingModalContent> {
  bool _terminalActionInProgress = false;
  bool _starting = false;
  String? _failure;

  Future<void> _record() async {
    if (_starting || _terminalActionInProgress) return;
    setState(() {
      _starting = true;
      _failure = null;
    });
    // A popped route remains mounted throughout its exit animation.
    final route = ModalRoute.of(context);
    try {
      final failure = await ref
          .read(audioRecorderControllerProvider.notifier)
          .record(
            linkedId: widget.linkedId,
            transcriptionHandledByCaller: !widget.showTranscriptionOptions,
            shouldCancel: () => !mounted || (route != null && !route.isCurrent),
          );
      if (!mounted) return;
      setState(
        () => _failure = switch (failure) {
          AudioRecordingFailure.permissionDenied =>
            context.messages.chatInputRecordingNoMicPermission,
          AudioRecordingFailure.startFailed =>
            context.messages.chatInputRecordingFailed,
          AudioRecordingFailure.busy || null => null,
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _failure = context.messages.chatInputRecordingFailed);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(audioRecorderControllerProvider);
    final controller = ref.read(audioRecorderControllerProvider.notifier);

    final tokens = context.designTokens;
    return RecordingStage(
      state: state,
      levelSemanticsLabel: state.status == AudioRecorderStatus.recording
          ? context.messages.audioRecordingLive
          : null,
      announceLevel: true,
      notice: _failure == null
          ? null
          : Semantics(
              liveRegion: true,
              child: Text(
                _failure!,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.alert.error.ink,
                ),
              ),
            ),
      // No cross-fade between the record button and the transport row:
      // AnimatedSwitcher stacks both for the whole transition, and their
      // footprints differ so much that any fade shows the one overlapping
      // the other, which reads as broken rather than smooth.
      controls: _isRecording(state)
          ? RecordingTransportControls(
              key: const ValueKey('stop_controls'),
              paused: state.status == AudioRecorderStatus.paused,
              progress: state.progress,
              busy: _terminalActionInProgress,
              onDiscard: _cancel,
              onTogglePause: () => state.status == AudioRecorderStatus.paused
                  ? controller.resume()
                  : controller.pause(),
              onStop: _stop,
            )
          : _buildRecordButton(context, controller, theme),
      // Automatic prompt options (shown when category or linked task may
      // provide automatic prompts, including profile-driven skills).
      footer:
          widget.showTranscriptionOptions &&
              (widget.categoryId != null || widget.linkedId != null)
          ? _speechRecognitionOption(context, controller, state)
          : null,
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
    // Captured now: the widget may be gone by the time the stop fails.
    final logger = ref.read(domainLoggerProvider);

    String? createdId;
    try {
      createdId = await controller.stop();
    } catch (error, stackTrace) {
      // The user sees the failure below; the log keeps its cause.
      logger.error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'AudioRecordingModal.stop',
      );
    }

    if (!mounted) return;

    if (createdId == null) {
      setState(() {
        _terminalActionInProgress = false;
        _failure = context.messages.chatInputRecordingFailed;
      });
      return;
    }

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

  Widget _buildRecordButton(
    BuildContext context,
    AudioRecorderController controller,
    ThemeData theme,
  ) => DesignSystemButton(
    key: const ValueKey('record'),
    label: context.messages.audioRecordingRecord.toUpperCase(),
    leadingIcon: LottiIcons.mic,
    size: DesignSystemButtonSize.large,
    onPressed: _starting || _terminalActionInProgress ? null : _record,
  );

  /// The *Transcribe* toggle for the recorder's footer, or nothing where
  /// no transcription would run.
  Widget? _speechRecognitionOption(
    BuildContext context,
    AudioRecorderController controller,
    AudioRecorderState state,
  ) {
    // Use the extracted provider to compute visibility
    // This makes the logic testable independently from the widget
    final visibility = ref.watch(
      checkboxVisibilityProvider((
        categoryId: widget.categoryId,
        linkedId: widget.linkedId,
      )),
    );

    if (visibility.none) return null;
    return RecordingOption(
      key: const Key('speech_recognition_checkbox'),
      label: context.messages.audioRecordingTranscribeOption,
      value: state.enableSpeechRecognition ?? true,
      onChanged: (value) =>
          controller.setEnableSpeechRecognition(enable: value),
    );
  }
}
