import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_time_picker.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_duration_picker.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

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
  CheckInInteractionType.inPerson => LottiIcons.people,
  CheckInInteractionType.call => LottiIcons.call,
  CheckInInteractionType.videoCall => LottiIcons.video,
  CheckInInteractionType.message => LottiIcons.chat,
  CheckInInteractionType.other => LottiIcons.forum,
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

/// What the modal's pinned action bar needs from the form inside it: the
/// save and delete intents and whether they are currently allowed. The form
/// publishes after every state change; the bar listens. The form still
/// draws its own action row when it has no handle, so it stays usable on a
/// plain page and in a plain test.
class CheckInFormHandle extends ChangeNotifier {
  Future<void> Function()? _save;
  Future<void> Function()? _delete;
  bool _canSave = false;

  bool get canSave => _canSave;
  bool get canDelete => _delete != null;

  Future<void> save() => _save?.call() ?? Future.value();
  Future<void> delete() => _delete?.call() ?? Future.value();

  void publish({
    required Future<void> Function()? save,
    required Future<void> Function()? delete,
    required bool canSave,
  }) {
    _save = save;
    _delete = delete;
    _canSave = canSave;
    notifyListeners();
  }
}

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
  Duration? prefilledDuration,
  bool startSpeaking = false,
}) {
  final handle = CheckInFormHandle();
  return ModalUtils.showSinglePageModal<CheckInEntry>(
    context: context,
    title: context.messages.relationshipLogCheckIn,
    padding: _formPadding(context),
    stickyActionBarBuilder: (_) => CheckInStickyActions(handle: handle),
    builder: (modalContext) => CheckInCaptureForm(
      relationshipId: relationshipId,
      prefilledInteractionType: prefilledInteractionType,
      prefilledTime: prefilledTime,
      prefilledDuration: prefilledDuration,
      startSpeaking: startSpeaking,
      handle: handle,
    ),
  );
}

/// Room under the form for the pinned action bar, so the last field can
/// scroll fully above it.
EdgeInsets _formPadding(BuildContext context) {
  final tokens = context.designTokens;
  return EdgeInsets.fromLTRB(
    tokens.spacing.step5,
    tokens.spacing.step4,
    tokens.spacing.step5,
    tokens.spacing.step11 + tokens.spacing.step6,
  );
}

/// Opens the capture overlay prefilled from [checkIn] for editing. Resolves
/// to the updated [CheckInEntry], or `null` when dismissed or deleted.
Future<CheckInEntry?> showCheckInEditSheet({
  required BuildContext context,
  required CheckInEntry checkIn,
}) {
  final handle = CheckInFormHandle();
  return ModalUtils.showSinglePageModal<CheckInEntry>(
    context: context,
    title: context.messages.checkInEditTitle,
    padding: _formPadding(context),
    stickyActionBarBuilder: (_) => CheckInStickyActions(handle: handle),
    builder: (modalContext) => CheckInCaptureForm(
      relationshipId: checkIn.data.relationshipId,
      initial: checkIn,
      handle: handle,
    ),
  );
}

/// The modal's pinned actions (design 2026-09-06 §5): *Save check-in*
/// reachable without scrolling, Cancel beside it, and — while editing —
/// delete at the bottom-left, the desktop dialog's corner. Reads the form
/// through its [handle].
class CheckInStickyActions extends StatelessWidget {
  const CheckInStickyActions({required this.handle, super.key});

  final CheckInFormHandle handle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return ListenableBuilder(
      listenable: handle,
      builder: (context, _) => DesignSystemModalActionBar(
        glass: true,
        padding: EdgeInsets.all(tokens.spacing.step5),
        secondary: [
          if (handle.canDelete)
            IconButton(
              key: const ValueKey('check-in-delete'),
              tooltip: messages.deleteButton,
              onPressed: handle.delete,
              icon: Icon(
                LottiIcons.delete,
                color: tokens.colors.alert.error.ink,
              ),
            ),
          DesignSystemButton(
            key: const ValueKey('check-in-cancel'),
            label: messages.cancelButton,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.large,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        primary: DesignSystemButton(
          key: const ValueKey('check-in-save'),
          label: messages.checkInSaveButton,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
          onPressed: handle.canSave ? handle.save : null,
        ),
      ),
    );
  }
}

/// The check-in capture form (design 2026-09-06 §5), in the order the
/// design argued for: how it felt (optional sentiment — explicit user
/// judgment, never pre-filled), what you talked about (narrative, or *Speak
/// instead*), when and how long (type · started · duration), then topics and
/// the "next time" guidance folded under *More*. Persists through
/// [RelationshipRepository].
/// With [initial] set it edits that check-in instead, and offers deletion.
class CheckInCaptureForm extends ConsumerStatefulWidget {
  const CheckInCaptureForm({
    required this.relationshipId,
    required this.handle,
    this.initial,
    this.prefilledInteractionType,
    this.prefilledTime,
    this.prefilledDuration,
    this.startSpeaking = false,
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

  /// How long the interaction lasted, when the caller already knows — the
  /// post-call offer's elapsed time. Persisted as the check-in's end time
  /// (`dateTo − dateFrom` is the duration; no schema change), so the
  /// duration the offer quoted is the one the log shows. Ignored while
  /// editing, where the existing check-in's own length is kept.
  final Duration? prefilledDuration;

  /// Opens straight into a spoken check-in: the page's mic doorway, which
  /// means "say it" rather than "show me the form". The recording sheet is
  /// launched after the first frame; everything else about the form is
  /// unchanged, and cancelling the recording leaves the form as it was.
  final bool startSpeaking;

  /// When set, the form's actions live in the modal's pinned bar and the
  /// form publishes to it instead of drawing its own action row.
  /// The pinned bar's view of this form — its only way out: the form has
  /// no inline actions.
  final CheckInFormHandle handle;

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

  /// The check-in's length; zero means "no duration". Kept across a change
  /// of the start time so editing when a call began does not erase how
  /// long it ran.
  late Duration _duration;

  /// The *More* section (topics · next time · avoid), folded by default;
  /// open from the start when a check-in being edited already has any of it.
  late bool _moreOpen;
  bool _isSaving = false;
  bool _isTranscribing = false;

  /// Set synchronously the moment a spoken check-in starts and cleared once
  /// the whole flow has ended, so the page's mic (`startSpeaking`) and a
  /// press on *Speak* during the pre-flight awaits cannot open the recorder
  /// twice. [_isTranscribing] only covers the wait that follows a recording.
  bool _isSpeaking = false;

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

  /// An existing check-in's length, or null when there is none to keep.
  static Duration? _lengthOf(CheckInEntry? entry) {
    if (entry == null) return null;
    return entry.meta.dateTo.difference(entry.meta.dateFrom);
  }

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
    final length =
        _lengthOf(initial) ?? widget.prefilledDuration ?? Duration.zero;
    _duration = length.isNegative ? Duration.zero : length;
    _moreOpen =
        _topicsController.text.isNotEmpty ||
        _payAttentionController.text.isNotEmpty ||
        _avoidController.text.isNotEmpty;
    if (widget.startSpeaking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_handleSpeak());
      });
    }
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

  /// The pinned bar reads the form through its handle; publish after the
  /// frame so a listener never rebuilds while this widget is still building.
  void _publish() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.handle.publish(
        save: _handleSave,
        delete: _isEditing ? _handleDelete : null,
        canSave: !_isSaving && !_isTranscribing,
      );
    });
  }

  /// *Started*: the day, then the time, as two design-system pickers — a
  /// check-in edited to another day keeps its time of day, and one edited
  /// to another time keeps its day.
  Future<void> _pickStart() async {
    final messages = context.messages;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = await showDesignSystemDatePicker(
      context: context,
      title: messages.checkInStartedLabel,
      initialDate: _interactionTime,
      firstDate: DateTime(today.year - 50),
      lastDate: today,
    );
    final picked = result?.date;
    if (!mounted || picked == null) return;
    setState(() {
      _interactionTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _interactionTime.hour,
        _interactionTime.minute,
      );
    });
    final time = await _pickTime();
    if (!mounted || time == null) return;
    setState(() {
      _interactionTime = DateTime(
        _interactionTime.year,
        _interactionTime.month,
        _interactionTime.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<TimeOfDay?> _pickTime() {
    var chosen = TimeOfDay.fromDateTime(_interactionTime);
    return ModalUtils.showSinglePageModal<TimeOfDay>(
      context: context,
      title: context.messages.checkInStartedLabel,
      builder: (modalContext) => DesignSystemTimePicker(
        key: const ValueKey('check-in-time-picker'),
        initialTime: chosen,
        onTimeChanged: (time) => chosen = time,
      ),
      stickyActionBarBuilder: (modalContext) => DesignSystemModalActionBar(
        glass: true,
        padding: EdgeInsets.all(modalContext.designTokens.spacing.step5),
        primary: DesignSystemButton(
          key: const ValueKey('check-in-time-done'),
          label: modalContext.messages.doneButton,
          leadingIcon: LottiIcons.confirm,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
          onPressed: () => Navigator.of(modalContext).pop(chosen),
        ),
      ),
    );
  }

  /// *Duration*: the wheel behind the tile. Zero is "no duration".
  Future<void> _pickDuration() async {
    final picked = await showCheckInDurationPicker(
      context: context,
      initialDuration: _duration,
    );
    if (!mounted || picked == null) return;
    setState(() => _duration = picked);
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
    if (_isSaving || _isTranscribing || _isSpeaking) return;
    setState(() => _isSpeaking = true);
    try {
      await _speak();
    } finally {
      // Whatever ended the flow — a refused pre-flight, a cancelled
      // recording, a transcript, an error — the button comes back.
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _speak() async {
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
            dateTo: _interactionTime.add(_duration),
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
          dateTo: _interactionTime.add(_duration),
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

  /// `Now · 12:46` while the start is this very minute, otherwise the day
  /// and the time — what the *Started* tile reads.
  String _startedLabel(BuildContext context) {
    final now = clock.now();
    final sameMinute =
        _interactionTime.year == now.year &&
        _interactionTime.month == now.month &&
        _interactionTime.day == now.day &&
        _interactionTime.hour == now.hour &&
        _interactionTime.minute == now.minute;
    final day = sameMinute
        ? context.messages.journalDateNowButton
        : relationshipDayLabelOf(context, _interactionTime);
    return '$day · ${relationshipTimeLabel(_interactionTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    _publish();

    Widget sectionLabel(String text) => Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Text(
        text,
        style: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );
    Widget caption(String text) => Text(
      text,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.lowEmphasis,
      ),
    );

    final prefilledFrom =
        !_isEditing &&
            widget.prefilledInteractionType != null &&
            widget.prefilledTime != null &&
            widget.prefilledDuration != null
        ? widget.prefilledInteractionType
        : null;

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
        // Where the numbers came from (design §5): the offer's channel, start
        // and elapsed time, and that every one of them is editable.
        if (prefilledFrom != null) ...[
          _SourceStrip(
            type: prefilledFrom,
            startedAt: widget.prefilledTime!,
            duration: widget.prefilledDuration!,
          ),
          SizedBox(height: tokens.spacing.step5),
        ],
        sectionLabel(messages.checkInSentimentLabel),
        Wrap(
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step3,
          children: [
            for (final sentiment in CheckInSentiment.values)
              DesignSystemChip(
                key: ValueKey('check-in-sentiment-${sentiment.name}'),
                label: checkInSentimentLabel(context, sentiment),
                selected: _sentiment == sentiment,
                size: DesignSystemChipSize.touch,
                // Tapping the selected sentiment clears it again —
                // sentiment is optional, never forced.
                onPressed: () => setState(
                  () => _sentiment = _sentiment == sentiment ? null : sentiment,
                ),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        caption(messages.checkInSentimentOptional),
        SizedBox(height: tokens.spacing.step6),
        sectionLabel(messages.checkInNarrativeLabel),
        LottiTextField(
          key: const ValueKey('check-in-narrative'),
          controller: _narrativeController,
          hintText: messages.checkInNarrativeHint,
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
                : messages.checkInSpeakInstead,
            variant: DesignSystemButtonVariant.outlined,
            leadingIcon: LottiIcons.mic,
            isLoading: _isTranscribing,
            onPressed: _isSaving || _isTranscribing || _isSpeaking
                ? null
                : _handleSpeak,
          ),
        ),
        SizedBox(height: tokens.spacing.step6),
        sectionLabel(messages.checkInWhenAndHowLong),
        Wrap(
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step3,
          children: [
            for (final type in CheckInInteractionType.values)
              DesignSystemChip(
                key: ValueKey('check-in-type-${type.name}'),
                label: checkInInteractionLabel(context, type),
                selected: _interactionType == type,
                size: DesignSystemChipSize.touch,
                onPressed: () => setState(() => _interactionType = type),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.step4),
        // IntrinsicHeight, so the two tiles match heights inside the modal's
        // unbounded scroll view — a stretch there has no height to take.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ValueTile(
                  key: const ValueKey('check-in-started'),
                  label: messages.checkInStartedLabel,
                  value: _startedLabel(context),
                  onTap: _pickStart,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: _ValueTile(
                  key: const ValueKey('check-in-duration'),
                  label: messages.journalDurationLabel,
                  value: checkInDurationLabel(context, _duration),
                  muted: _duration == Duration.zero,
                  trailing: LottiIcons.chevronDown,
                  onTap: _pickDuration,
                ),
              ),
            ],
          ),
        ),
        if (_duration == Duration.zero) ...[
          SizedBox(height: tokens.spacing.step3),
          caption(messages.checkInDurationHint),
        ],
        SizedBox(height: tokens.spacing.step6),
        _MoreHeader(
          open: _moreOpen,
          onToggle: () => setState(() => _moreOpen = !_moreOpen),
        ),
        if (_moreOpen) ...[
          SizedBox(height: tokens.spacing.step4),
          LottiTextField(
            key: const ValueKey('check-in-topics'),
            controller: _topicsController,
            labelText: messages.checkInTopicsLabel,
            hintText: messages.checkInTopicsHint,
          ),
          SizedBox(height: tokens.spacing.step5),
          LottiTextField(
            key: const ValueKey('check-in-pay-attention'),
            controller: _payAttentionController,
            labelText: messages.checkInPayAttentionLabel,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: tokens.spacing.step5),
          LottiTextField(
            key: const ValueKey('check-in-avoid'),
            controller: _avoidController,
            labelText: messages.checkInAvoidLabel,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ],
    );
  }
}

/// The prefilled sheet's first line: which channel, when it started and how
/// long it has been, then the sentence that says where those came from.
class _SourceStrip extends StatelessWidget {
  const _SourceStrip({
    required this.type,
    required this.startedAt,
    required this.duration,
  });

  final CheckInInteractionType type;
  final DateTime startedAt;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = tokens.colors.interactive.enabled;
    return Container(
      key: const ValueKey('check-in-source-strip'),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: SurfaceAlphas.tint),
          tokens.colors.background.level02,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: accent.withValues(alpha: SurfaceAlphas.washChip),
        ),
      ),
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(checkInInteractionIcon(type), size: IconSizes.s, color: accent),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages.checkInSourceMeta(
                    checkInInteractionLabel(context, type),
                    relationshipTimeLabel(startedAt),
                    duration.inMinutes,
                  ),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  type == CheckInInteractionType.call
                      ? messages.checkInSourceCall
                      : messages.checkInSourceMessage,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable tile with a caption over a mono value — *Started* and
/// *Duration*.
class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
    this.muted = false,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: tokens.colors.background.level03,
      borderRadius: BorderRadius.circular(tokens.radii.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: relationshipTimestampStyle(
                        tokens,
                        color: muted
                            ? tokens.colors.text.lowEmphasis
                            : tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing case final trailing?)
                Icon(
                  trailing,
                  size: IconSizes.s,
                  color: tokens.colors.text.mediumEmphasis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The *More* row: the section name, what it holds, and the chevron.
class _MoreHeader extends StatelessWidget {
  const _MoreHeader({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return InkWell(
      key: const ValueKey('check-in-more'),
      onTap: onToggle,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: Row(
          children: [
            Text(
              messages.checkInMoreSection,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            // Flexible, so a narrow phone or large text trims the caption
            // rather than pushing the chevron off the row.
            if (!open)
              Expanded(
                child: Text(
                  messages.checkInMoreCaption,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              )
            else
              const Spacer(),
            SizedBox(width: tokens.spacing.step2),
            Icon(
              open ? LottiIcons.chevronUp : LottiIcons.chevronDown,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ],
        ),
      ),
    );
  }
}
