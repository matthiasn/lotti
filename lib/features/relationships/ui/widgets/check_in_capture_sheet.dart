import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/shortcut_label_formatter.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_facts.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_composer_header.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_context_chips.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_duration_picker.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_narrative_field.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

part 'check_in_capture_sheet_actions_part.dart';
part 'check_in_capture_sheet_form_part.dart';
part 'check_in_capture_sheet_launch_part.dart';

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

/// Opens the OS's settings for this app, where a refused microphone
/// permission is turned back on. A seam, so the composer's *Open settings*
/// is testable without the platform channel behind it.
typedef CheckInSettingsOpener = Future<bool> Function();

final checkInSettingsOpenerProvider = Provider<CheckInSettingsOpener>(
  (ref) => permissions.openAppSettings,
  name: 'checkInSettingsOpenerProvider',
);

/// The context chips a dictation can fill.
enum CheckInContextField { type, start, duration }

/// The check-in composer (design 2026-09-13): the narrative field first,
/// with *Dictate* inside it and every speech phase rendered in place of the
/// text; then type · started · duration as one chip row; then sentiment,
/// topics and the "next time" guidance folded under *More*. Persists
/// through [RelationshipRepository]. With [initial] set it edits that
/// check-in instead, and offers deletion.
///
/// A take's words fill the chips they name — start, length, channel — that
/// the user has not chosen, read on the device
/// (`extractCheckInDictationFacts`); the words themselves stay on the take.
class CheckInCaptureForm extends ConsumerStatefulWidget {
  const CheckInCaptureForm({
    required this.relationshipId,
    required this.handle,
    this.initial,
    this.prefilledInteractionType,
    this.prefilledTime,
    this.prefilledDuration,
    this.startSpeaking = false,
    this.dialog = false,
    super.key,
  });

  final String relationshipId;

  /// Whether the composer is the desktop dialog: the field then takes
  /// focus at once, since the typed common case is open → type → ⌘↩ and
  /// no keyboard rises over the form.
  final bool dialog;

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

  /// Opens straight into a spoken check-in: the recorder replaces the field
  /// after the first frame. Everything else about the form is unchanged,
  /// and discarding the recording leaves the form as it was.
  final bool startSpeaking;

  /// The chrome's view of this form — its only way out: the form has no
  /// inline actions.
  final CheckInFormHandle handle;

  @override
  ConsumerState<CheckInCaptureForm> createState() => _CheckInCaptureFormState();
}

class _CheckInCaptureFormState extends ConsumerState<CheckInCaptureForm> {
  /// Read once in [initState]: failures land after awaits that can outlive
  /// this state, when reading through `ref` throws.
  late final DomainLogger _logger;
  late final TextEditingController _topicsController;
  late final TextEditingController _narrativeController;
  late final TextEditingController _payAttentionController;
  late final TextEditingController _avoidController;
  final FocusNode _narrativeFocus = FocusNode(debugLabel: 'check-in-narrative');
  late CheckInInteractionType _interactionType;
  late CheckInSentiment? _sentiment;
  late DateTime _interactionTime;

  /// The check-in's length; zero means "no duration". Kept across a change
  /// of the start time so editing when a call began does not erase how
  /// long it ran.
  late Duration _duration;

  /// The context the composer opened with — the edited check-in's, the
  /// post-call offer's or the defaults — so a changed chip counts as a draft
  /// worth guarding just as changed words do.
  late final CheckInInteractionType _openingType;
  late final DateTime _openingTime;
  late final Duration _openingDuration;

  /// The context fields dictation must leave alone: the ones the user
  /// picked, and — when the composer opened on a call placed from this page
  /// — all three, since they were measured rather than guessed.
  final Set<CheckInContextField> _heldFields = {};

  /// The context fields whose value came from what was said, so the caption
  /// under the chips can say so. A field the user picks again leaves it.
  final Set<CheckInContextField> _dictatedFields = {};

  /// Optional sentiment, topics and next-time guidance, folded by default;
  /// open from the start when a check-in being edited already has any of it.
  late bool _moreOpen;

  bool _isSaving = false;

  /// The narrative as last seen, so a focus change is not mistaken for typing.
  String _lastNarrative = '';

  CheckInSpeechPhase _phase = const CheckInSpeechIdle();

  /// The person's category, read during the preflight, so the recording
  /// files where their other entries do.
  String? _categoryId;

  /// Whether the recorder attaches to this person's recording already
  /// running — a sheet dismissed mid-take and reopened — instead of
  /// starting one.
  bool _adoptRunning = false;

  /// The recordings made here, oldest first — the check-in's entries once
  /// it is saved (ADR 0062).
  List<CheckInTake> _takes = const [];

  /// Each take's in-flight transcript wait, so dismissing the sheet stops
  /// them instead of leaving database listeners running out the timeout.
  /// The transcription itself runs on: its words land on the recording.
  final Map<String, CheckInTranscriptWait> _transcriptWaits = {};

  /// Watches the inference-error controller for each take being
  /// transcribed, so a failed run ends its wait instead of running it out.
  final Map<String, ProviderSubscription<String?>> _transcriptFailures = {};

  bool get _isEditing => widget.initial != null;

  /// Whether the composer offers *Dictate*: only for a new check-in. A saved
  /// one is added to from its timeline, where a recording becomes its entry
  /// at once.
  bool get _offersDictation => !_isEditing;

  /// An existing check-in's length, or null when there is none to keep.
  static Duration? _lengthOf(CheckInEntry? entry) {
    if (entry == null) return null;
    return entry.meta.dateTo.difference(entry.meta.dateFrom);
  }

  @override
  void initState() {
    super.initState();
    _logger = ref.read(domainLoggerProvider);
    final initial = widget.initial;
    final data = initial?.data;
    // The detail fields rebuild the form as they change, so the pop guard's
    // `canPop` — read at build time — never lags an edit made only there.
    _topicsController = TextEditingController(
      text: data?.topics.join(', ') ?? '',
    )..addListener(_onDetailChanged);
    _narrativeController = TextEditingController(
      text: initial?.entryText?.plainText ?? '',
    )..addListener(_onNarrativeChanged);
    _lastNarrative = _narrativeController.text;
    _payAttentionController = TextEditingController(
      text: data?.payAttentionTo ?? '',
    )..addListener(_onDetailChanged);
    _avoidController = TextEditingController(text: data?.avoid ?? '')
      ..addListener(_onDetailChanged);
    _narrativeFocus.addListener(_onNarrativeChanged);
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
    _openingType = _interactionType;
    _openingTime = _interactionTime;
    _openingDuration = _duration;
    // A start handed in comes from a call or message placed from this page
    // (`showCheckInForInteraction`): it, and the elapsed time and channel
    // handed in with it, were measured, so dictation leaves each one alone.
    // A type handed in without a start is only how the two last connected —
    // a guess the words may correct.
    if (widget.prefilledTime != null) {
      _heldFields.add(CheckInContextField.start);
      if (widget.prefilledInteractionType != null) {
        _heldFields.add(CheckInContextField.type);
      }
    }
    if (widget.prefilledDuration != null) {
      _heldFields.add(CheckInContextField.duration);
    }
    _moreOpen =
        _sentiment != null ||
        _topicsController.text.isNotEmpty ||
        _payAttentionController.text.isNotEmpty ||
        _avoidController.text.isNotEmpty;
    // On the desktop dialog the typed common case is open → type → ⌘↩,
    // so the field takes focus at once; a phone would raise its keyboard
    // over the sheet, so there the first tap still chooses.
    if (widget.dialog && !widget.startSpeaking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _narrativeFocus.requestFocus();
      });
    }
    if (widget.startSpeaking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_dictate());
      });
    }
  }

  @override
  void dispose() {
    for (final wait in _transcriptWaits.values) {
      wait.cancel();
    }
    for (final subscription in _transcriptFailures.values) {
      subscription.close();
    }
    _transcriptWaits.clear();
    _transcriptFailures.clear();
    _narrativeController
      ..removeListener(_onNarrativeChanged)
      ..dispose();
    _narrativeFocus
      ..removeListener(_onNarrativeChanged)
      ..dispose();
    _topicsController
      ..removeListener(_onDetailChanged)
      ..dispose();
    _payAttentionController
      ..removeListener(_onDetailChanged)
      ..dispose();
    _avoidController
      ..removeListener(_onDetailChanged)
      ..dispose();
    super.dispose();
  }

  /// The word count and the save rule both read the field, and the pinned
  /// bar reads its focus, so every keystroke and focus change is a state
  /// change here. Typing under a failure card is the user choosing to type
  /// instead, so the card goes.
  void _onNarrativeChanged() {
    if (!mounted) return;
    final text = _narrativeController.text;
    final typed = text != _lastNarrative;
    _lastNarrative = text;
    if (_phase is CheckInSpeechFailed && typed && text.trim().isNotEmpty) {
      _phase = const CheckInSpeechIdle();
    }
    setState(() {});
  }

  /// A detail edit is a state change for the pop guard, which reads
  /// [_isDirty] at build time.
  void _onDetailChanged() {
    if (mounted) setState(() {});
  }

  List<String> get _topics => _topicsController.text
      .split(',')
      .map((topic) => topic.trim())
      .where((topic) => topic.isNotEmpty)
      .toList();

  bool get _hasWords => checkInWordCount(_narrativeController.text) > 0;

  CheckInSaveBlock get _block => checkInSaveBlockOf(
    phase: _phase,
    hasWords: _hasWords,
    hasTakes: _takes.isNotEmpty,
    saving: _isSaving,
  );

  /// *Started*: the day, then the time ([pickCheckInStart]).
  Future<void> _pickStart() async {
    final picked = await pickCheckInStart(
      context: context,
      initial: _interactionTime,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _interactionTime = picked;
      _hold(CheckInContextField.start);
    });
  }

  /// *Duration*: the wheel behind the chip. Zero is "no duration".
  Future<void> _pickDuration() async {
    final picked = await showCheckInDurationPicker(
      context: context,
      initialDuration: _duration,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _duration = picked;
      _hold(CheckInContextField.duration);
    });
  }

  Future<void> _pickType() async {
    final picked = await showCheckInTypePicker(
      context: context,
      current: _interactionType,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _interactionType = picked;
      _hold(CheckInContextField.type);
    });
  }

  /// The user chose [field]: dictation leaves it alone from now on.
  void _hold(CheckInContextField field) {
    _heldFields.add(field);
    _dictatedFields.remove(field);
  }

  /// Fills the start, length and channel the takes' words name
  /// ([extractCheckInDictationFacts], on-device) into every field the user
  /// has not chosen.
  ///
  /// Read over every take that has words, oldest first, each field taking
  /// the newest take that names it — so a correction in a later take wins
  /// however the transcripts happen to arrive: two takes in flight can land
  /// in either order. A value the user picked is never replaced.
  void _fillFromDictation() {
    final now = clock.now();
    DateTime? start;
    Duration? length;
    CheckInInteractionType? type;
    for (final take in _takes) {
      final words = take.transcript;
      if (words == null) continue;
      final facts = extractCheckInDictationFacts(words, now: now);
      start = facts.startedAt ?? start;
      length = facts.duration ?? length;
      type = facts.interactionType ?? type;
    }
    bool free(CheckInContextField field) => !_heldFields.contains(field);
    setState(() {
      if (start != null && free(CheckInContextField.start)) {
        _interactionTime = start;
        _dictatedFields.add(CheckInContextField.start);
      }
      if (length != null && free(CheckInContextField.duration)) {
        _duration = length;
        _dictatedFields.add(CheckInContextField.duration);
      }
      if (type != null && free(CheckInContextField.type)) {
        _interactionType = type;
        _dictatedFields.add(CheckInContextField.type);
      }
    });
  }

  bool get _speechIdle => switch (_phase) {
    CheckInSpeechIdle() || CheckInSpeechFailed() => true,
    _ => false,
  };

  /// *Dictate*: the preflight, then the recorder in place of the text.
  ///
  /// Audio is linked to the person — the check-in does not exist yet — and
  /// becomes the check-in's entry when it is saved. Transcription uses only
  /// the system's selected default inference profile; the recorder's
  /// automatic path is suppressed, so this explicit request runs once.
  /// Preflight refuses recording if the default has no transcription slot.
  Future<void> _dictate() async {
    if (!_speechIdle || _isSaving) return;
    // The keyboard goes first: the recorder is about to take the field.
    _narrativeFocus.unfocus();
    setState(() => _phase = const CheckInSpeechPreparing());
    // Every provider is read up front: each `await` below can outlive this
    // widget, and reading through `ref` after that throws.
    final repository = ref.read(relationshipRepositoryProvider);
    final transcription = ref.read(checkInTranscriptionServiceProvider);
    try {
      // Both reads hit the database and neither depends on the other;
      // running them in series doubled the delay before the recorder
      // appeared.
      final (relationship, canTranscribe) = await (
        repository.getRelationshipById(widget.relationshipId),
        transcription.canTranscribe(),
      ).wait.timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (!canTranscribe) {
        setState(
          () => _phase = const CheckInSpeechFailed(
            CheckInSpeechFailure(
              CheckInSpeechFailureKind.transcriptionUnavailable,
            ),
          ),
        );
        return;
      }
      _categoryId = relationship?.meta.categoryId;
      // The app-wide recorder may already be running: this person's take,
      // left running when the sheet was dismissed, is adopted; anyone
      // else's is left alone, because `record()` on a running recorder
      // toggles it OFF — the earlier take would be saved wordless and the
      // new one would never start.
      final running = ref.read(audioRecorderControllerProvider);
      final busy = running.status != AudioRecorderStatus.stopped;
      if (busy && running.linkedId != widget.relationshipId) {
        setState(
          () => _phase = const CheckInSpeechFailed(
            CheckInSpeechFailure(CheckInSpeechFailureKind.recorderBusy),
          ),
        );
        return;
      }
      _adoptRunning = busy;
      widget.handle.recorder = ref.read(
        audioRecorderControllerProvider.notifier,
      );
      setState(() => _phase = const CheckInSpeechRecording());
    } catch (exception, stackTrace) {
      _logger.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'CheckInCaptureForm',
        message: 'Spoken check-in failed to start',
      );
      if (!mounted) return;
      setState(
        () => _phase = const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.recordingFailed),
        ),
      );
    }
  }

  void _onRecorded(String audioEntryId, Duration length) {
    setState(() {
      _phase = const CheckInSpeechIdle();
      _takes = [
        ..._takes,
        CheckInTake(audioEntryId: audioEntryId, length: length),
      ];
    });
    unawaited(_transcribe(audioEntryId));
  }

  void _onRecordingDiscarded() {
    if (!mounted) return;
    setState(() => _phase = const CheckInSpeechIdle());
  }

  void _onRecordingFailed(CheckInSpeechFailureKind failure) {
    if (!mounted) return;
    // The recorder hid the floating indicator on the way in; a start that
    // never happened has nothing for it to point at, but a stop that could
    // not save may leave the app-wide recorder as it was — either way the
    // indicator is the user's again, now rather than when the sheet closes.
    widget.handle.releaseRecorder();
    setState(() => _phase = CheckInSpeechFailed(CheckInSpeechFailure(failure)));
  }

  /// Replaces the take for [audioEntryId] through [update], when it is
  /// still one of this composer's.
  void _updateTake(
    String audioEntryId,
    CheckInTake Function(CheckInTake) update,
  ) {
    if (!mounted) return;
    setState(
      () => _takes = [
        for (final take in _takes)
          if (take.audioEntryId == audioEntryId) update(take) else take,
      ],
    );
  }

  bool _holds(String audioEntryId) =>
      _takes.any((take) => take.audioEntryId == audioEntryId);

  /// *Try again* on a take whose words never came: the same recording,
  /// asked for once more — never a second recording.
  void _retryTake(String audioEntryId) => unawaited(_transcribe(audioEntryId));

  /// *Remove recording*: the take stays out of the check-in. Its audio stays
  /// in the journal, linked to the person, as the discard question says.
  void _removeTake(String audioEntryId) {
    _closeTranscriptWait(audioEntryId);
    setState(
      () => _takes = [
        for (final take in _takes)
          if (take.audioEntryId != audioEntryId) take,
      ],
    );
  }

  /// *Type instead* on a failure card: the field comes back as plain text.
  void _typeInstead() {
    setState(() => _phase = const CheckInSpeechIdle());
    _narrativeFocus.requestFocus();
  }

  Future<void> _openSettings() => ref.read(checkInSettingsOpenerProvider)();

  /// Stops listening for [audioEntryId]'s words.
  void _closeTranscriptWait(String audioEntryId) {
    _transcriptWaits[audioEntryId]?.cancel();
    _forgetTranscriptWait(audioEntryId);
  }

  /// Drops a wait that has ended, and its failure watch.
  void _forgetTranscriptWait(String audioEntryId) {
    _transcriptWaits.remove(audioEntryId);
    _transcriptFailures.remove(audioEntryId)?.close();
  }

  Future<void> _handleSave() async {
    if (_block != CheckInSaveBlock.none) return;
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
    final entryText = EntryText(plainText: narrative);

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
        // The recordings become the check-in's entries. The check-in is
        // saved either way: a link that fails is logged by the repository
        // and must not turn into "save failed", which a retry would answer
        // with a duplicate check-in.
        if (created != null && _takes.isNotEmpty) {
          await repository.attachEntriesToCheckIn(
            checkInId: created.id,
            entryIds: [for (final take in _takes) take.audioEntryId],
          );
        }
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
      _logger.error(
        LogDomain.general,
        e,
        stackTrace: s,
        subDomain: 'CheckInCaptureForm',
        message: 'Failed to save check-in',
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
      _logger.error(
        LogDomain.general,
        e,
        stackTrace: s,
        subDomain: 'CheckInCaptureForm',
        message: 'Failed to delete check-in',
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
  /// and the time — what the *Started* chip reads.
  String _startedLabel(BuildContext context) =>
      checkInStartedLabelOf(context, _interactionTime);

  /// The save shortcut and its label — desktop only, where a keyboard is a
  /// given and the field's footer has room to say so.
  ({SingleActivator activator, String label})? _saveShortcut(
    BuildContext context,
  ) {
    if (!isDesktop) return null;
    final platform = Theme.of(context).platform;
    final activator = platform == TargetPlatform.macOS
        ? const SingleActivator(LogicalKeyboardKey.enter, meta: true)
        : const SingleActivator(LogicalKeyboardKey.enter, control: true);
    return (
      activator: activator,
      label: ShortcutLabelFormatter.activatorLabel(
        context.messages,
        activator,
        platform,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final recording = _phase is CheckInSpeechRecording;
    // Watched only while the recorder is up, so an idle form never
    // rebuilds on the app-wide recorder's level ticks.
    final recorderPaused =
        recording &&
        ref.watch(
          audioRecorderControllerProvider.select(
            (state) => state.status == AudioRecorderStatus.paused,
          ),
        );
    _publish(context, recorderPaused: recorderPaused);

    // One level under the fold trigger: the same size, the quieter ink.
    Widget sectionLabel(String text) => Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Text(
        text,
        style: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: tokens.colors.text.mediumEmphasis,
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
    final shortcut = _saveShortcut(context);
    final speechIdle = _speechIdle && !_isSaving;

    // One scrollable, not two. The modal page already scrolls its child and
    // adds a top bar, padding and the bottom safe area on top of it, so a
    // form that also capped itself at `modalMaxHeightFraction` of the SCREEN
    // overflowed the page — and because the inner `SingleChildScrollView`
    // consumed the drag, the outer one never moved and the action row below
    // it could not be reached at all. Let the page own the scrolling.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckInNarrativeField(
          controller: _narrativeController,
          focusNode: _narrativeFocus,
          phase: _phase,
          wordCount: checkInWordCount(_narrativeController.text),
          shortcutHint: shortcut?.label,
          restMinLines: widget.dialog ? 2 : 3,
          offersDictation: _offersDictation,
          recorder: recording
              ? CheckInInlineRecorder(
                  linkedId: widget.relationshipId,
                  categoryId: _categoryId,
                  adoptRunning: _adoptRunning,
                  onRecorded: _onRecorded,
                  onDiscarded: _onRecordingDiscarded,
                  onFailed: _onRecordingFailed,
                )
              : null,
          takes: _takes,
          onDictate: speechIdle ? _dictate : null,
          onRetryTake: _isSaving ? null : _retryTake,
          onRemoveTake: _isSaving ? null : _removeTake,
          onOpenSettings: _openSettings,
          onDismissFailure: _typeInstead,
        ),
        SizedBox(height: tokens.spacing.step5),
        CheckInContextChips(
          type: _interactionType,
          startedLabel: _startedLabel(context),
          durationLabel: _duration == Duration.zero
              ? messages.checkInDurationChip
              : checkInDurationLabel(context, _duration),
          enabled: speechIdle,
          onPickType: _pickType,
          onPickStart: _pickStart,
          onPickDuration: _pickDuration,
        ),
        // Where the numbers came from (design §5): the offer's channel,
        // start and elapsed time, and that every one of them is editable.
        // A composer opened on a call holds all three, so dictation never
        // fills one beside this strip.
        if (_dictatedFields.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            messages.checkInSourceDictation,
            key: const ValueKey('check-in-dictation-strip'),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        if (prefilledFrom != null) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            prefilledFrom == CheckInInteractionType.call
                ? messages.checkInSourceCall
                : messages.checkInSourceMessage,
            key: const ValueKey('check-in-source-strip'),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step3),
        _MoreHeader(
          open: _moreOpen,
          caption: _moreCaption(messages),
          enabled: speechIdle,
          onToggle: () => setState(() => _moreOpen = !_moreOpen),
        ),
        if (_moreOpen) ...[
          SizedBox(height: tokens.spacing.step4),
          sectionLabel(messages.checkInSentimentLabel),
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step3,
            children: [
              for (final sentiment in CheckInSentiment.values)
                DesignSystemChip(
                  key: ValueKey('check-in-sentiment-${sentiment.name}'),
                  label: checkInSentimentLabel(context, sentiment),
                  // The chosen feeling carries a glyph as well as its fill,
                  // so the choice reads without colour.
                  leadingIcon: _sentiment == sentiment
                      ? LottiIcons.confirm
                      : null,
                  selected: _sentiment == sentiment,
                  size: DesignSystemChipSize.touch,
                  // Tapping the selected sentiment clears it again —
                  // sentiment is optional, never forced.
                  onPressed: () => setState(
                    () =>
                        _sentiment = _sentiment == sentiment ? null : sentiment,
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          caption(messages.checkInSentimentOptional),
          // One section gap between the folded sections, whatever each
          // holds: the edit sheet opens on all of them at once.
          SizedBox(height: tokens.spacing.sectionGap),

          // The design system's own input, so the folded details wear the
          // same chrome as the rest of the sheet.
          // Every section under More wears the same heading, one level
          // under the fold trigger, so the inputs read as its children.
          sectionLabel(messages.checkInTopicsLabel),
          DesignSystemTextInput(
            key: const ValueKey('check-in-topics'),
            controller: _topicsController,
            semanticsLabel: messages.checkInTopicsLabel,
            hintText: messages.checkInTopicsHint,
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          sectionLabel(messages.checkInPayAttentionLabel),
          DesignSystemTextInput(
            key: const ValueKey('check-in-pay-attention'),
            controller: _payAttentionController,
            semanticsLabel: messages.checkInPayAttentionLabel,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          sectionLabel(messages.checkInAvoidLabel),
          DesignSystemTextInput(
            key: const ValueKey('check-in-avoid'),
            controller: _avoidController,
            semanticsLabel: messages.checkInAvoidLabel,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        _BarSlack(handle: widget.handle),
      ],
    );

    // The sheet's own ways out — the back gesture, the barrier — come
    // through here too, so a draft is guarded however the user leaves.
    final guarded = PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_dismiss());
      },
      child: body,
    );
    if (shortcut == null) return guarded;
    return CallbackShortcuts(
      bindings: {
        shortcut.activator: () {
          if (_block == CheckInSaveBlock.none) unawaited(_handleSave());
        },
      },
      child: guarded,
    );
  }
}
