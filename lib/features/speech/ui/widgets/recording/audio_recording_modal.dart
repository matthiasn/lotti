import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/app_settings_opener.dart';
import 'package:lotti/features/speech/state/checkbox_visibility_provider.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_failure_callout.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// What a recording is about, as a sheet or an indicator names it: the
/// title of the task, project, goal or person it is linked to, else the
/// first words of the entry. Null when there is nothing to name.
String? recordingSubjectTitle(JournalEntity? subject) {
  final title = switch (subject) {
    Task(:final data) => data.title,
    ProjectEntry(:final data) => data.title,
    GoalEntry(:final data) => data.title,
    RelationshipEntry(:final data) => data.title,
    _ => subject?.entryText?.plainText,
  }?.trim();
  return title == null || title.isEmpty ? null : title;
}

/// Entry point for the audio recording sheet.
class AudioRecordingModal {
  /// Presents the recording sheet — a bottom sheet on a phone, a dialog on
  /// a wide window — titled with what the recording is about, and already
  /// recording: the user pressed a microphone to get here.
  ///
  /// [categoryId] files the recording (null clears an earlier category);
  /// [linkedId] ties it to a parent entry, whose title heads the sheet.
  /// [transcriptionHandledByCaller] suppresses automatic inference and hides
  /// its option for this sheet; the caller starts transcription after save.
  /// The floating recording indicator is hidden while the sheet is up and
  /// handed back once it is dismissed — by Stop, the back gesture, or a tap
  /// outside — so a take left running can be stopped from there.
  /// [useRootNavigator] selects which navigator hosts the sheet. A recording
  /// with no [linkedId] opens as its own entry once saved, unless
  /// [openCreatedEntry] is false — for a caller that links the recording
  /// itself afterwards (a goal's charter recording, which must not take the
  /// parent link a check-in has) and stays where it is.
  ///
  /// Returns the id of the audio entry the recording created, or `null` when
  /// the sheet was dismissed or the recording discarded.
  static Future<String?> show(
    BuildContext context, {
    String? linkedId,
    String? categoryId,
    bool useRootNavigator = true,
    bool transcriptionHandledByCaller = false,
    bool openCreatedEntry = true,
  }) async {
    final container = ProviderScope.containerOf(context);
    final fallbackTitle = context.messages.taskFirstRunRecordAudio;
    // Before the first await: a tap queued behind this one finds the sheet
    // already claimed and does not open a second, and an uncategorized
    // subject never inherits an earlier category.
    final controller = container.read(audioRecorderControllerProvider.notifier)
      ..setModalVisible(modalVisible: true)
      ..setCategoryId(categoryId);

    String? createdId;
    try {
      String? subject;
      if (linkedId != null) {
        try {
          subject = recordingSubjectTitle(
            await container.read(journalDbProvider).journalEntityById(linkedId),
          );
        } catch (_) {
          // A subject that cannot be read is a sheet with the plain title.
        }
        if (!context.mounted) return null;
      }
      createdId = await DsActionModal.show<String>(
        context: context,
        title: subject ?? fallbackTitle,
        useRootNavigator: useRootNavigator,
        builder: (BuildContext _) {
          return AudioRecordingModalContent(
            linkedId: linkedId,
            categoryId: categoryId,
            showTranscriptionOptions: !transcriptionHandledByCaller,
          );
        },
      );
    } finally {
      // The floating indicator is hidden while the sheet is up; a sheet
      // gone mid-take hands it back, for the take to be stopped there.
      controller.setModalVisible(modalVisible: false);
    }

    // Navigate only after Wolt has completed the modal route. Starting a page
    // navigation from inside the sheet's own teardown can make Flutter try to
    // reactivate an element that the nested navigator has already removed.
    if (openCreatedEntry && linkedId == null && createdId != null) {
      beamToNamed('/journal/$createdId');
    }
    return createdId;
  }
}

/// Body of the recording sheet: the shared [InlineRecorder], recording from
/// the moment the sheet opens, with the *Transcribe* option under it.
///
/// Stop pops the sheet with the saved entry's id; a confirmed discard pops
/// it with nothing. A recorder that could not record rests the sheet on a
/// [RecordingFailureCallout] over one *Record* button to try again.
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
  var _recording = true;
  var _stopping = false;
  InlineRecordingFailure? _failure;

  /// Stops the take running elsewhere in the app. `stop` saves it under the
  /// subject it was started for, so nothing is lost and nothing is misfiled.
  Future<void> _stopRunning() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    String? saved;
    try {
      saved = await ref.read(audioRecorderControllerProvider.notifier).stop();
    } finally {
      if (mounted) {
        setState(() {
          _stopping = false;
          _failure = saved == null ? InlineRecordingFailure.notSaved : null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final failure = _failure;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          RecordingFailureCallout(
            failure: failure,
            stopping: _stopping,
            onOpenSettings: () => ref.read(appSettingsOpenerProvider)(),
            onStopRunning: _stopRunning,
          ),
          SizedBox(height: tokens.spacing.step5),
        ],
        if (_recording)
          InlineRecorder(
            linkedId: widget.linkedId,
            categoryId: widget.categoryId,
            transcriptionHandledByCaller: !widget.showTranscriptionOptions,
            footer: _transcribeOption(),
            // Pop exactly once, with the created entry.
            onRecorded: (id, _) => Navigator.of(context).pop(id),
            onDiscarded: () => Navigator.of(context).pop(),
            onFailed: (failure) => setState(() {
              _failure = failure;
              _recording = false;
            }),
          )
        else
          DesignSystemButton(
            key: const ValueKey('record'),
            label: context.messages.audioRecordingRecord,
            leadingIcon: LottiIcons.mic,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
            onPressed: _stopping
                ? null
                : () => setState(() {
                    _failure = null;
                    _recording = true;
                  }),
          ),
      ],
    );
  }

  /// The *Transcribe* toggle under the recorder, or nothing where no
  /// transcription would run.
  Widget? _transcribeOption() {
    if (!widget.showTranscriptionOptions ||
        (widget.categoryId == null && widget.linkedId == null)) {
      return null;
    }
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
      value:
          ref.watch(
            audioRecorderControllerProvider.select(
              (state) => state.enableSpeechRecognition,
            ),
          ) ??
          true,
      onChanged: (value) => ref
          .read(audioRecorderControllerProvider.notifier)
          .setEnableSpeechRecognition(enable: value),
    );
  }
}
