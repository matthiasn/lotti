import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The localized label for an interaction type — shared by the capture sheet
/// and the detail page's check-in rows.
String checkInInteractionLabel(
  BuildContext context,
  CheckInInteractionType type,
) => switch (type) {
  CheckInInteractionType.inPerson =>
    context.messages.checkInInteractionInPerson,
  CheckInInteractionType.call => context.messages.checkInInteractionCall,
  CheckInInteractionType.videoCall =>
    context.messages.checkInInteractionVideoCall,
  CheckInInteractionType.message => context.messages.checkInInteractionMessage,
  CheckInInteractionType.other => context.messages.checkInInteractionOther,
};

/// The icon for an interaction type — shared by the detail page's check-in
/// rows and the journal card, so the two can't drift apart.
IconData checkInInteractionIcon(CheckInInteractionType type) => switch (type) {
  CheckInInteractionType.inPerson => Icons.people_rounded,
  CheckInInteractionType.call => Icons.call_rounded,
  CheckInInteractionType.videoCall => Icons.videocam_rounded,
  CheckInInteractionType.message => Icons.chat_rounded,
  CheckInInteractionType.other => Icons.forum_rounded,
};

/// The localized label for a sentiment — shared by the capture sheet and the
/// detail page's check-in rows.
String checkInSentimentLabel(
  BuildContext context,
  CheckInSentiment sentiment,
) => switch (sentiment) {
  CheckInSentiment.delightful => context.messages.checkInSentimentDelightful,
  CheckInSentiment.good => context.messages.checkInSentimentGood,
  CheckInSentiment.neutral => context.messages.checkInSentimentNeutral,
  CheckInSentiment.strained => context.messages.checkInSentimentStrained,
  CheckInSentiment.difficult => context.messages.checkInSentimentDifficult,
};

/// Opens the recording sheet for a spoken check-in and resolves to the audio
/// entry it created, or `null` when the user backed out.
///
/// A seam rather than a direct call so the capture sheet's own behaviour —
/// what it does with a transcript, a refusal, or a dismissal — is testable
/// without standing up the recorder, the microphone permission and the
/// inference stack behind it.
typedef CheckInRecorderLauncher =
    Future<String?> Function({
      required BuildContext context,
      required String relationshipId,
      String? categoryId,
    });

/// The real launcher: the shared recording sheet, with the person as the
/// recording's linked entity so the generalized automation resolves *their*
/// profile, and their category so the sheet offers the same speech options a
/// recording made anywhere else in that category would.
Future<String?> showCheckInRecorder({
  required BuildContext context,
  required String relationshipId,
  String? categoryId,
}) => AudioRecordingModal.show(
  context,
  linkedId: relationshipId,
  categoryId: categoryId,
);

final checkInRecorderLauncherProvider = Provider<CheckInRecorderLauncher>(
  (ref) => showCheckInRecorder,
  name: 'checkInRecorderLauncherProvider',
);

/// Folds a fresh [transcript] into whatever the narrative field already holds.
///
/// Speaking never destroys typing. A transcript arriving on top of text the
/// user already entered is appended below it, blank-line separated, so a
/// second recording adds to the account rather than replacing it — the
/// check-in stays user-authored (ADR 0038) and every word remains editable
/// before save.
String mergeCheckInNarrative({
  required String existing,
  required String transcript,
}) {
  final addition = transcript.trim();
  if (addition.isEmpty) return existing;
  final kept = existing.trim();
  if (kept.isEmpty) return addition;
  return '$kept\n\n$addition';
}

/// Opens the responsive check-in capture overlay for [relationshipId].
/// Resolves to the created [CheckInEntry], or `null` when dismissed.
///
/// [prefilledInteractionType] and [prefilledTime] let a caller open the form
/// already describing an interaction that just happened — the post-call
/// prompt passes what it recorded when the user left to make the call
/// (plan v2 phase 7 item 5). They are starting values only: everything stays
/// editable, and nothing is saved until the user says so.
Future<CheckInEntry?> showCheckInCaptureSheet({
  required BuildContext context,
  required String relationshipId,
  CheckInInteractionType? prefilledInteractionType,
  DateTime? prefilledTime,
}) {
  return ModalUtils.showSinglePageModal<CheckInEntry>(
    context: context,
    title: context.messages.relationshipLogCheckIn,
    builder: (modalContext) => CheckInCaptureForm(
      relationshipId: relationshipId,
      prefilledInteractionType: prefilledInteractionType,
      prefilledTime: prefilledTime,
    ),
  );
}

/// Opens the capture overlay prefilled from [checkIn] for editing. Resolves
/// to the updated [CheckInEntry], or `null` when dismissed or deleted.
Future<CheckInEntry?> showCheckInEditSheet({
  required BuildContext context,
  required CheckInEntry checkIn,
}) {
  return ModalUtils.showSinglePageModal<CheckInEntry>(
    context: context,
    title: context.messages.checkInEditTitle,
    builder: (modalContext) => CheckInCaptureForm(
      relationshipId: checkIn.data.relationshipId,
      initial: checkIn,
    ),
  );
}

/// The check-in capture form: interaction type, date, optional sentiment
/// (explicit user judgment — never pre-filled), topics, narrative, and the
/// "next time" guidance fields. Persists through [RelationshipRepository].
/// With [initial] set it edits that check-in instead, and offers deletion.
class CheckInCaptureForm extends ConsumerStatefulWidget {
  const CheckInCaptureForm({
    required this.relationshipId,
    this.initial,
    this.prefilledInteractionType,
    this.prefilledTime,
    super.key,
  });

  final String relationshipId;

  /// When set, the form edits this check-in instead of creating one.
  final CheckInEntry? initial;

  /// Starting interaction type for a new check-in, when the caller already
  /// knows what happened. Ignored while editing, where [initial] is the
  /// authority.
  final CheckInInteractionType? prefilledInteractionType;

  /// Starting interaction time for a new check-in — when the call was
  /// actually placed, rather than when the user got round to logging it.
  final DateTime? prefilledTime;

  @override
  ConsumerState<CheckInCaptureForm> createState() => _CheckInCaptureFormState();
}

class _CheckInCaptureFormState extends ConsumerState<CheckInCaptureForm> {
  late final TextEditingController _topicsController;
  late final TextEditingController _narrativeController;
  late final TextEditingController _payAttentionController;
  late final TextEditingController _avoidController;
  late CheckInInteractionType _interactionType;
  late CheckInSentiment? _sentiment;
  late DateTime _interactionTime;
  bool _isSaving = false;
  bool _isTranscribing = false;

  /// The in-flight transcript wait, so dismissing the sheet stops it instead
  /// of leaving a database listener running out the timeout.
  CheckInTranscriptWait? _transcriptWait;

  /// Watches the inference-error controller for the recording being
  /// transcribed, so a failed run ends the wait instead of running it out.
  ///
  /// Nulled out the moment it is closed, so the sheet being dismissed
  /// mid-wait cannot close the same subscription twice.
  ProviderSubscription<String?>? _transcriptFailureSubscription;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final data = initial?.data;
    _topicsController = TextEditingController(
      text: data?.topics.join(', ') ?? '',
    );
    _narrativeController = TextEditingController(
      text: initial?.entryText?.plainText ?? '',
    );
    _payAttentionController = TextEditingController(
      text: data?.payAttentionTo ?? '',
    );
    _avoidController = TextEditingController(text: data?.avoid ?? '');
    _interactionType =
        data?.interactionType ??
        widget.prefilledInteractionType ??
        CheckInInteractionType.inPerson;
    // Sentiment is never pre-filled, by any caller: it is the user's own
    // judgment of how it felt, and a default would put words in their mouth
    // (ADR 0038).
    _sentiment = data?.sentiment;
    _interactionTime =
        initial?.meta.dateFrom ?? widget.prefilledTime ?? clock.now();
  }

  @override
  void dispose() {
    _transcriptWait?.cancel();
    _closeTranscriptFailureSubscription();
    _topicsController.dispose();
    _narrativeController.dispose();
    _payAttentionController.dispose();
    _avoidController.dispose();
    super.dispose();
  }

  List<String> get _topics => _topicsController.text
      .split(',')
      .map((topic) => topic.trim())
      .where((topic) => topic.isNotEmpty)
      .toList();

  Future<void> _pickDate() async {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = await showDesignSystemDatePicker(
      context: context,
      title: context.messages.checkInDateLabel,
      initialDate: _interactionTime,
      firstDate: DateTime(today.year - 50),
      lastDate: today,
    );
    final picked = result?.date;
    if (!mounted || picked == null) return;
    // Keep the existing time of day — the picker is date-only, and a
    // check-in edited to another day shouldn't jump to midnight.
    setState(() {
      _interactionTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _interactionTime.hour,
        _interactionTime.minute,
      );
    });
  }

  /// Records a spoken check-in and prefills the narrative with its transcript.
  ///
  /// The recording is linked to the person, so the generalized automation path
  /// resolves *their* profile (or their category's) rather than declining for
  /// want of a task. The audio entry is a journal entry like any other — the
  /// spoken words survive even when the user abandons this sheet.
  ///
  /// Nothing here saves: the transcript lands in the text field for the user
  /// to edit and confirm, matching the sentiment rule that a check-in is
  /// authored by the person, never by inference.
  ///
  /// Refuses **before** recording when no transcription model is configured
  /// at all — recording for a transcript that can never arrive wastes the
  /// user's words and a five-minute spinner. Note the check is not the
  /// automatic-inference switch: this is a gesture, so it only needs a model,
  /// not the consent gate that governs unattended runs.
  Future<void> _handleSpeak() async {
    if (_isSaving || _isTranscribing) return;

    // Every provider is read up front: each `await` below can outlive this
    // widget, and reading through `ref` after that throws.
    final messages = context.messages;
    final repository = ref.read(relationshipRepositoryProvider);
    final launchRecorder = ref.read(checkInRecorderLauncherProvider);
    final transcription = ref.read(checkInTranscriptionServiceProvider);

    // Both reads hit the database and neither depends on the other; running
    // them in series doubled the delay before the recorder appeared.
    final (relationship, canTranscribe) = await (
      repository.getRelationshipById(widget.relationshipId),
      transcription.canTranscribe(widget.relationshipId),
    ).wait;
    if (!mounted) return;
    if (!canTranscribe) {
      context.showToast(
        tone: DesignSystemToastTone.warning,
        title: messages.checkInTranscriptUnavailable,
      );
      return;
    }

    final audioEntryId = await launchRecorder(
      context: context,
      relationshipId: widget.relationshipId,
      categoryId: relationship?.meta.categoryId,
    );
    // A cancelled or dismissed recording creates no entry and leaves the
    // narrative exactly as the user left it.
    if (!mounted || audioEntryId == null) return;

    // The recording sheet carries its own speech-recognition opt-out, and the
    // recorder keeps that choice after stopping. Unchecking it means "do not
    // transcribe this one" — so say so now rather than holding the sheet on
    // "Transcribing…" for the whole timeout to reach the same answer. The
    // audio entry still exists; only the transcript was declined.
    final speechEnabled = ref
        .read(audioRecorderControllerProvider)
        .enableSpeechRecognition;
    if (speechEnabled == false) {
      context.showToast(
        tone: DesignSystemToastTone.warning,
        title: messages.checkInTranscriptFailed,
      );
      return;
    }

    setState(() => _isTranscribing = true);
    final wait = _transcriptWait = transcription.transcribe(
      audioEntryId: audioEntryId,
      subjectId: widget.relationshipId,
    );
    // A failed run writes no transcript, so the wait alone cannot tell a
    // provider outage from a slow model — it would hold "Transcribing…" for
    // the full five minutes and then blame nothing in particular. The error
    // controller is set by whichever path ran (the service's own request, or
    // the recorder's automatic one), so watching it covers both and carries
    // the provider's verbatim reason into the toast.
    String? failureDetail;
    _closeTranscriptFailureSubscription();
    _transcriptFailureSubscription = ref.listenManual<String?>(
      inferenceErrorControllerProvider((
        id: audioEntryId,
        aiResponseType: AiResponseType.audioTranscription,
      )),
      (previous, next) {
        final detail = next?.trim();
        if (detail == null || detail.isEmpty) return;
        failureDetail = detail;
        wait.cancel();
      },
    );
    try {
      final transcript = await wait.result;
      if (!mounted) return;
      if (transcript == null) {
        context.showToast(
          tone: DesignSystemToastTone.warning,
          title: messages.checkInTranscriptFailed,
          description: failureDetail,
        );
        return;
      }
      _narrativeController.text = mergeCheckInNarrative(
        existing: _narrativeController.text,
        transcript: transcript,
      );
    } finally {
      _transcriptWait = null;
      _closeTranscriptFailureSubscription();
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  void _closeTranscriptFailureSubscription() {
    _transcriptFailureSubscription?.close();
    _transcriptFailureSubscription = null;
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final repository = ref.read(relationshipRepositoryProvider);
    final narrative = _narrativeController.text.trim();
    final payAttentionTo = _payAttentionController.text.trim();
    final avoid = _avoidController.text.trim();
    final data = CheckInData(
      relationshipId: widget.relationshipId,
      interactionType: _interactionType,
      sentiment: _sentiment,
      topics: _topics,
      payAttentionTo: payAttentionTo.isEmpty ? null : payAttentionTo,
      avoid: avoid.isEmpty ? null : avoid,
    );
    final entryText = narrative.isEmpty
        ? null
        : EntryText(plainText: narrative);

    try {
      if (_isEditing) {
        final initial = widget.initial!;
        final updated = initial.copyWith(
          data: data,
          entryText: entryText,
          meta: initial.meta.copyWith(
            dateFrom: _interactionTime,
            dateTo: _interactionTime,
          ),
        );
        final success = await repository.updateCheckIn(updated);
        if (!mounted) return;
        if (success) {
          Navigator.of(context).pop(updated);
        } else {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.checkInErrorCreateFailed,
          );
        }
      } else {
        final created = await repository.createCheckIn(
          data: data,
          entryText: entryText,
          dateFrom: _interactionTime,
        );
        if (!mounted) return;
        if (created != null) {
          Navigator.of(context).pop(created);
        } else {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.checkInErrorCreateFailed,
          );
        }
      }
    } catch (e, s) {
      developer.log(
        'Failed to save check-in',
        name: 'CheckInCaptureForm',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorCreateFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final initial = widget.initial;
    if (initial == null || _isSaving) return;

    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.checkInDeleteConfirmMessage,
      confirmLabel: context.messages.deleteButton,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final deleted = await ref
          .read(relationshipRepositoryProvider)
          .deleteCheckIn(initial.id);
      if (!mounted) return;
      if (deleted) {
        Navigator.of(context).pop();
      } else {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorDeleteFailed,
        );
      }
    } catch (e, s) {
      developer.log(
        'Failed to delete check-in',
        name: 'CheckInCaptureForm',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorDeleteFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    Widget sectionLabel(String text) => Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Text(
        text,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );

    // One scrollable, not two. The modal page already scrolls its child and
    // adds a top bar, padding and the bottom safe area on top of it, so a
    // form that also capped itself at `modalMaxHeightFraction` of the SCREEN
    // overflowed the page — and because the inner `SingleChildScrollView`
    // consumed the drag, the outer one never moved and the action row below
    // it could not be reached at all. Let the page own the scrolling.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        sectionLabel(messages.checkInInteractionLabel),
        Wrap(
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step3,
          children: [
            for (final type in CheckInInteractionType.values)
              ChoiceChip(
                label: Text(checkInInteractionLabel(context, type)),
                selected: _interactionType == type,
                onSelected: (_) => setState(() => _interactionType = type),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.step5),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: messages.checkInDateLabel,
              prefixIcon: const Icon(Icons.calendar_today_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radii.s),
              ),
            ),
            child: Text(
              _interactionTime.ymd,
              style: tokens.typography.styles.body.bodyLarge.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        sectionLabel(messages.checkInSentimentLabel),
        Wrap(
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step3,
          children: [
            for (final sentiment in CheckInSentiment.values)
              ChoiceChip(
                label: Text(
                  checkInSentimentLabel(context, sentiment),
                ),
                selected: _sentiment == sentiment,
                // Tapping the selected sentiment clears it again —
                // sentiment is optional, never forced.
                onSelected: (_) => setState(
                  () => _sentiment = _sentiment == sentiment ? null : sentiment,
                ),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.step5),
        LottiTextField(
          controller: _narrativeController,
          labelText: messages.checkInNarrativeLabel,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        SizedBox(height: tokens.spacing.step3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DesignSystemButton(
            key: const Key('check_in_speak_button'),
            label: _isTranscribing
                ? messages.checkInTranscribingLabel
                : messages.checkInSpeakButton,
            variant: DesignSystemButtonVariant.outlined,
            leadingIcon: Icons.mic_rounded,
            isLoading: _isTranscribing,
            onPressed: _isSaving || _isTranscribing ? null : _handleSpeak,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        LottiTextField(
          controller: _topicsController,
          labelText: messages.checkInTopicsLabel,
          hintText: messages.checkInTopicsHint,
        ),
        SizedBox(height: tokens.spacing.step5),
        LottiTextField(
          controller: _payAttentionController,
          labelText: messages.checkInPayAttentionLabel,
          textCapitalization: TextCapitalization.sentences,
        ),
        SizedBox(height: tokens.spacing.step5),
        LottiTextField(
          controller: _avoidController,
          labelText: messages.checkInAvoidLabel,
          textCapitalization: TextCapitalization.sentences,
        ),
        SizedBox(height: tokens.spacing.step6),
        Row(
          children: [
            if (_isEditing)
              IconButton(
                tooltip: messages.deleteButton,
                onPressed: _isSaving ? null : _handleDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            const Spacer(),
            DesignSystemButton(
              label: messages.cancelButton,
              variant: DesignSystemButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            SizedBox(width: tokens.spacing.step4),
            DesignSystemButton(
              // Held while a transcript is in flight: saving would pop the
              // sheet and drop the words the user is waiting for, with the
              // saved check-in silently missing its narrative.
              label: messages.saveButton,
              onPressed: _isSaving || _isTranscribing ? null : _handleSave,
            ),
          ],
        ),
        // Breathing room under the action row, so the last control clears the
        // sheet's bottom edge (and the home indicator) instead of sitting
        // flush against it once the content has been scrolled to the end.
        SizedBox(height: tokens.spacing.step6),
      ],
    );
  }
}
