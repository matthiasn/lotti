import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/shortcut_label_formatter.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
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
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

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

/// Opens the OS's settings for this app, where a refused microphone
/// permission is turned back on. A seam, so the composer's *Open settings*
/// is testable without the platform channel behind it.
typedef CheckInSettingsOpener = Future<bool> Function();

final checkInSettingsOpenerProvider = Provider<CheckInSettingsOpener>(
  (ref) => permissions.openAppSettings,
  name: 'checkInSettingsOpenerProvider',
);

/// What the composer's chrome needs from the form inside it — the pinned
/// action bar's save and delete intents and why Save is held, the header's
/// status line, the keyboard bar's one-line summary — published after every
/// state change; the chrome listens. The form still works on a plain page
/// and in a plain test: it publishes whether or not anyone is listening.
class CheckInFormHandle extends ChangeNotifier {
  Future<void> Function()? _save;
  Future<void> Function()? _delete;
  VoidCallback? _unfocus;
  AudioRecorderController? _recorder;
  CheckInSaveBlock _block = CheckInSaveBlock.emptyNarrative;
  CheckInComposerStatus _status = CheckInComposerStatus.idle;
  String _summary = '';
  bool _fieldFocused = false;

  bool get canSave => _block == CheckInSaveBlock.none;
  bool get canDelete => _delete != null;

  /// Why Save is held, for the bar to say so.
  CheckInSaveBlock get block => _block;

  /// What the field is doing, for the header's status line.
  CheckInComposerStatus get status => _status;

  /// `Call · Now · no duration`, for the slim bar above the keyboard.
  String get summary => _summary;

  /// Whether the narrative field has focus — on a phone, whether the
  /// keyboard is up. The sheet removes the keyboard inset from what its
  /// pinned bar can see, so focus is the signal the bar slims on.
  bool get fieldFocused => _fieldFocused;

  Future<void> save() => _save?.call() ?? Future.value();
  Future<void> delete() => _delete?.call() ?? Future.value();

  /// Drops the keyboard, so the chips the summary stands for come back.
  void unfocus() => _unfocus?.call();

  /// The form hands over the app-wide recorder the moment it starts a
  /// recording, so the sheet can put the floating indicator back once it
  /// has closed — and only then, and only if a recording was ever started:
  /// a composer that never dictated never touches the recorder at all.
  set recorder(AudioRecorderController recorder) => _recorder = recorder;

  /// The recorder a recording was started on, until the sheet releases it.
  AudioRecorderController? get recorder => _recorder;

  /// Shows the floating indicator again for a recording the sheet left
  /// running; a no-op when nothing was recorded.
  void releaseRecorder() {
    _recorder?.setModalVisible(modalVisible: false);
    _recorder = null;
  }

  void publish({
    required Future<void> Function()? save,
    required Future<void> Function()? delete,
    required VoidCallback? unfocus,
    required CheckInSaveBlock block,
    required CheckInComposerStatus status,
    required String summary,
    bool fieldFocused = false,
  }) {
    _save = save;
    _delete = delete;
    _unfocus = unfocus;
    // The callbacks are rebound on every publish; the chrome only needs a
    // frame when something it draws has changed — not on every keystroke.
    final changed =
        _block != block ||
        _status != status ||
        _summary != summary ||
        _fieldFocused != fieldFocused;
    _block = block;
    _status = status;
    _summary = summary;
    _fieldFocused = fieldFocused;
    if (changed) notifyListeners();
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

/// The inverse of [mergeCheckInNarrative] for *Re-record*: gives back
/// [textBefore] when [existing] is still exactly what merging [transcript]
/// into it produced — and leaves the text alone the moment the user has
/// changed anything, because an edit is theirs to keep. A suffix match
/// would not do: `Actually Spoken.` still ends with `Spoken.`.
String removeCheckInTranscript({
  required String existing,
  required String textBefore,
  required String transcript,
}) =>
    existing ==
        mergeCheckInNarrative(existing: textBefore, transcript: transcript)
    ? textBefore
    : existing;

/// Opens the check-in composer for a person (design 2026-09-13): one
/// surface that opens on the narrative, with *Dictate* inside the field.
/// Resolves to the created [CheckInEntry], or `null` when dismissed.
///
/// [prefilledInteractionType], [prefilledTime] and [prefilledDuration] let a
/// caller open the composer already describing an interaction that just
/// happened — the post-call prompt passes what it recorded when the user
/// left to make the call (plan v2 phase 7 item 5). They are starting values
/// only: everything stays editable, and nothing is saved until the user
/// says so. [startSpeaking] starts the recorder after the first frame —
/// the page's mic doorway, which means "say it" rather than "show me the
/// form".
Future<CheckInEntry?> showCheckInCaptureSheet({
  required BuildContext context,
  required String relationshipId,
  CheckInInteractionType? prefilledInteractionType,
  DateTime? prefilledTime,
  Duration? prefilledDuration,
  bool startSpeaking = false,
}) => _showComposer(
  context: context,
  relationshipId: relationshipId,
  title: context.messages.relationshipLogCheckIn,
  form: (handle) => CheckInCaptureForm(
    relationshipId: relationshipId,
    prefilledInteractionType: prefilledInteractionType,
    prefilledTime: prefilledTime,
    prefilledDuration: prefilledDuration,
    startSpeaking: startSpeaking,
    handle: handle,
  ),
);

/// Opens the same composer prefilled from [checkIn] for editing. Resolves
/// to the updated [CheckInEntry], or `null` when dismissed or deleted.
Future<CheckInEntry?> showCheckInEditSheet({
  required BuildContext context,
  required CheckInEntry checkIn,
}) => _showComposer(
  context: context,
  relationshipId: checkIn.data.relationshipId,
  title: context.messages.checkInEditTitle,
  form: (handle) => CheckInCaptureForm(
    relationshipId: checkIn.data.relationshipId,
    initial: checkIn,
    handle: handle,
  ),
);

Future<CheckInEntry?> _showComposer({
  required BuildContext context,
  required String relationshipId,
  required String title,
  required CheckInCaptureForm Function(CheckInFormHandle handle) form,
}) async {
  final handle = CheckInFormHandle();
  final tokens = context.designTokens;
  // The same width rule the modal picks its shape by, decided here on the
  // caller's window — inside the sheet the media query is the sheet's own.
  final dialog =
      MediaQuery.sizeOf(context).width >= WoltModalConfig.pageBreakpoint;
  try {
    return await ModalUtils.showSinglePageModal<CheckInEntry>(
      context: context,
      hasTopBarLayer: false,
      showCloseButton: false,
      navBarHeight: CheckInComposerHeader.height(
        tokens,
        MediaQuery.textScalerOf(context),
      ),
      leadingNavBarWidget: CheckInComposerHeader(
        relationshipId: relationshipId,
        handle: handle,
        title: title,
      ),
      padding: _formPadding(context),
      stickyActionBarBuilder: (_) =>
          CheckInStickyActions(handle: handle, dialog: dialog),
      builder: (modalContext) => form(handle),
    );
  } finally {
    // The inline recorder hides the floating indicator while it is up. A
    // sheet dismissed mid-recording leaves the recording running — the
    // recording sheet's own rule — so the indicator has to come back here,
    // once the sheet is gone, for the user to stop it from.
    handle.releaseRecorder();
  }
}

/// Air between the pinned header and the field, and room under the form
/// for the pinned action bar, so the last field can scroll fully above it.
EdgeInsets _formPadding(BuildContext context) {
  final tokens = context.designTokens;
  return EdgeInsets.fromLTRB(
    tokens.spacing.step5,
    tokens.spacing.step4,
    tokens.spacing.step5,
    tokens.spacing.step11 + tokens.spacing.step6,
  );
}

/// The composer's pinned actions (design 2026-09-13): *Save check-in* is
/// always visible, and when it is held the bar says why. Cancel beside it —
/// and, while editing, delete on the leading edge. On a phone with the
/// keyboard up the bar slims to the context summary and a short *Save*, so
/// the words the user is typing keep the room (option 1g). Reads the form
/// through its [handle].
class CheckInStickyActions extends StatelessWidget {
  const CheckInStickyActions({
    required this.handle,
    this.dialog = false,
    super.key,
  });

  final CheckInFormHandle handle;

  /// Whether the composer is the desktop dialog rather than the phone
  /// sheet: the reason then sits on the leading edge with the two actions
  /// together on the trailing edge, and the bar never slims for a keyboard.
  final bool dialog;

  /// The reason Save is held, or null when it is not.
  static String? blockLabel(
    AppLocalizations messages,
    CheckInSaveBlock block,
  ) => switch (block) {
    CheckInSaveBlock.none || CheckInSaveBlock.saving => null,
    CheckInSaveBlock.preparing => messages.checkInPreparingLabel,
    CheckInSaveBlock.recording => messages.checkInSaveBlockedRecording,
    CheckInSaveBlock.transcribing => messages.checkInSaveBlockedTranscribing,
    CheckInSaveBlock.emptyNarrative => messages.checkInSaveBlockedEmpty,
    CheckInSaveBlock.typeOrRetry => messages.checkInSaveBlockedRetry,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final wide = dialog;
    final padding = EdgeInsets.all(tokens.spacing.step5);

    return ListenableBuilder(
      listenable: handle,
      builder: (context, _) {
        final keyboardUp =
            !wide &&
            (handle.fieldFocused ||
                MediaQuery.viewInsetsOf(context).bottom > 0);
        final reason = blockLabel(messages, handle.block);
        final reasonStyle = tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.lowEmphasis,
        );

        if (keyboardUp) {
          return DesignSystemGlassStrip(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DesignSystemChip(
                        key: const ValueKey('check-in-context-summary'),
                        label: handle.summary,
                        trailing: const Icon(
                          LottiIcons.chevronUp,
                          size: IconSizes.s,
                        ),
                        size: DesignSystemChipSize.compactPillTouch,
                        onPressed: handle.unfocus,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  DesignSystemButton(
                    key: const ValueKey('check-in-save'),
                    label: messages.checkInSaveShortButton,
                    size: DesignSystemButtonSize.large,
                    onPressed: handle.canSave ? handle.save : null,
                  ),
                ],
              ),
            ),
          );
        }

        final delete = handle.canDelete
            ? IconButton(
                key: const ValueKey('check-in-delete'),
                tooltip: messages.deleteButton,
                onPressed: handle.delete,
                icon: Icon(
                  LottiIcons.delete,
                  color: tokens.colors.alert.error.ink,
                ),
              )
            : null;
        final cancel = DesignSystemButton(
          key: const ValueKey('check-in-cancel'),
          label: messages.cancelButton,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: () => Navigator.of(context).pop(),
        );
        final save = DesignSystemButton(
          key: const ValueKey('check-in-save'),
          label: messages.checkInSaveButton,
          size: DesignSystemButtonSize.large,
          fullWidth: !wide,
          onPressed: handle.canSave ? handle.save : null,
        );
        final reasonText = reason == null
            ? null
            : Text(
                reason,
                key: const ValueKey('check-in-save-reason'),
                style: reasonStyle,
              );

        if (wide) {
          // The dialog's footer: the reason on the leading edge where the
          // eye lands after the field, the two actions together on the
          // trailing edge.
          return DesignSystemModalActionBar(
            glass: true,
            padding: padding,
            layout: DesignSystemModalActionBarLayout.compactPrimary,
            secondary: [?delete, ?reasonText],
            primary: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                cancel,
                SizedBox(width: tokens.spacing.step3),
                save,
              ],
            ),
          );
        }

        return DesignSystemGlassStrip(
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                DesignSystemModalActionBar(
                  secondary: [?delete, cancel],
                  primary: save,
                ),
                if (reasonText != null) ...[
                  SizedBox(height: tokens.spacing.step3),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: reasonText,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The check-in composer (design 2026-09-13): the narrative field first,
/// with *Dictate* inside it and every speech phase rendered in place of the
/// text; then type · started · duration as one chip row; then sentiment,
/// topics and the "next time" guidance folded under *More*. Persists
/// through [RelationshipRepository]. With [initial] set it edits that
/// check-in instead, and offers deletion.
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

  /// Optional sentiment, topics and next-time guidance, folded by default;
  /// open from the start when a check-in being edited already has any of it.
  late bool _moreOpen;
  bool _isSaving = false;

  CheckInSpeechPhase _phase = const CheckInSpeechIdle();

  /// The person's category, read during the preflight, so the recording
  /// files where their other entries do.
  String? _categoryId;

  /// Whether the recorder attaches to this person's recording already
  /// running — a sheet dismissed mid-take and reopened — instead of
  /// starting one.
  bool _adoptRunning = false;

  /// The take *Re-record* will take back out of the field — once the new
  /// take exists, not before, so a discarded or failed retake leaves the
  /// words the user had.
  CheckInSpeechReady? _transcriptToReplace;

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
    )..addListener(_onNarrativeChanged);
    _payAttentionController = TextEditingController(
      text: data?.payAttentionTo ?? '',
    );
    _avoidController = TextEditingController(text: data?.avoid ?? '');
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
    _moreOpen =
        _sentiment != null ||
        _topicsController.text.isNotEmpty ||
        _payAttentionController.text.isNotEmpty ||
        _avoidController.text.isNotEmpty;
    if (widget.startSpeaking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_dictate());
      });
    }
  }

  @override
  void dispose() {
    _transcriptWait?.cancel();
    _closeTranscriptFailureSubscription();
    _narrativeController
      ..removeListener(_onNarrativeChanged)
      ..dispose();
    _narrativeFocus
      ..removeListener(_onNarrativeChanged)
      ..dispose();
    _topicsController.dispose();
    _payAttentionController.dispose();
    _avoidController.dispose();
    super.dispose();
  }

  /// The word count and the save rule both read the field, and the pinned
  /// bar reads its focus, so every keystroke and focus change is a state
  /// change here.
  void _onNarrativeChanged() {
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
    saving: _isSaving,
  );

  /// The chrome reads the form through its handle; publish after the frame
  /// so a listener never rebuilds while this widget is still building.
  void _publish(BuildContext context, {required bool recorderPaused}) {
    final messages = context.messages;
    final block = _block;
    final status = checkInComposerStatusOf(
      _phase,
      recorderPaused: recorderPaused,
    );
    final summary = messages.checkInContextSummary(
      checkInInteractionLabel(context, _interactionType),
      _startedLabel(context),
      _duration == Duration.zero
          ? messages.checkInNoDuration
          : checkInDurationLabel(context, _duration),
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.handle.publish(
        save: _handleSave,
        delete: _isEditing ? _handleDelete : null,
        unfocus: _narrativeFocus.unfocus,
        block: block,
        status: status,
        summary: summary,
        fieldFocused: _narrativeFocus.hasFocus,
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
      _interactionTime = _notAfterNow(
        DateTime(
          picked.year,
          picked.month,
          picked.day,
          _interactionTime.hour,
          _interactionTime.minute,
        ),
      );
    });
    final time = await _pickTime();
    if (!mounted || time == null) return;
    setState(() {
      _interactionTime = _notAfterNow(
        DateTime(
          _interactionTime.year,
          _interactionTime.month,
          _interactionTime.day,
          time.hour,
          time.minute,
        ),
      );
    });
  }

  /// A check-in started in the past by definition: the date picker stops at
  /// today, and this stops today's time of day at the current minute, so a
  /// future start can never become the person's "last contact".
  static DateTime _notAfterNow(DateTime candidate) {
    final now = clock.now();
    final nowMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    return candidate.isAfter(nowMinute) ? nowMinute : candidate;
  }

  Future<TimeOfDay?> _pickTime() {
    var chosen = TimeOfDay.fromDateTime(_interactionTime);
    return ModalUtils.showSinglePageModal<TimeOfDay>(
      context: context,
      title: context.messages.checkInStartedLabel,
      builder: (modalContext) => DesignSystemTimeWheel(
        key: const ValueKey('check-in-time-picker'),
        initialDateTime: _interactionTime,
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(modalContext),
        semanticsLabel: modalContext.messages.checkInStartedLabel,
        onDateTimeChanged: (time) => chosen = TimeOfDay.fromDateTime(time),
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

  /// *Duration*: the wheel behind the chip. Zero is "no duration".
  Future<void> _pickDuration() async {
    final picked = await showCheckInDurationPicker(
      context: context,
      initialDuration: _duration,
    );
    if (!mounted || picked == null) return;
    setState(() => _duration = picked);
  }

  Future<void> _pickType() async {
    final picked = await showCheckInTypePicker(
      context: context,
      current: _interactionType,
    );
    if (!mounted || picked == null) return;
    setState(() => _interactionType = picked);
  }

  bool get _speechIdle => switch (_phase) {
    CheckInSpeechIdle() ||
    CheckInSpeechReady() ||
    CheckInSpeechFailed() => true,
    _ => false,
  };

  /// *Dictate* / *Add more*: the preflight, then the recorder in place of
  /// the text.
  ///
  /// Audio is linked to the person, while transcription uses only the
  /// system's selected default inference profile. The recorder's automatic
  /// path is suppressed, so this explicit request runs once. Words remain
  /// editable and are only saved as a check-in when the user presses Save.
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
        _transcriptToReplace = null;
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
      developer.log(
        'Spoken check-in failed to start',
        name: 'CheckInCaptureForm',
        error: exception,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _transcriptToReplace = null;
      setState(
        () => _phase = const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.recordingFailed),
        ),
      );
    }
  }

  /// *Re-record*: the recorder returns, and the last transcript comes back
  /// out of the field the moment the new take exists.
  Future<void> _reRecord() async {
    if (_phase case final CheckInSpeechReady ready) {
      _transcriptToReplace = ready;
    }
    await _dictate();
  }

  void _onRecorded(String audioEntryId, Duration length) {
    if (_transcriptToReplace case final take?) {
      _transcriptToReplace = null;
      _narrativeController.text = removeCheckInTranscript(
        existing: _narrativeController.text,
        textBefore: take.textBefore,
        transcript: take.transcript,
      );
    }
    unawaited(_transcribe(audioEntryId: audioEntryId, length: length));
  }

  void _onRecordingDiscarded() {
    if (!mounted) return;
    _transcriptToReplace = null;
    setState(() => _phase = const CheckInSpeechIdle());
  }

  void _onRecordingFailed(CheckInSpeechFailureKind failure) {
    if (!mounted) return;
    _transcriptToReplace = null;
    // The recorder hid the floating indicator on the way in; a start that
    // never happened has nothing for it to point at, but a stop that could
    // not save may leave the app-wide recorder as it was — either way the
    // indicator is the user's again, now rather than when the sheet closes.
    widget.handle.releaseRecorder();
    setState(() => _phase = CheckInSpeechFailed(CheckInSpeechFailure(failure)));
  }

  /// Asks for the words of [audioEntryId] and folds them into the field
  /// when they land. The recorder suppressed automatic inference for this
  /// capture; the transcription service owns the one explicit request.
  Future<void> _transcribe({
    required String audioEntryId,
    required Duration length,
  }) async {
    final transcription = ref.read(checkInTranscriptionServiceProvider);
    final messages = context.messages;
    setState(
      () => _phase = CheckInSpeechTranscribing(
        audioEntryId: audioEntryId,
        length: length,
      ),
    );
    // The route is a courtesy on the saved-audio line: a slow read must
    // never hold the transcript, and a failed one must never fail it.
    unawaited(
      _labelRoute(
        transcription,
        audioEntryId: audioEntryId,
        length: length,
        via: messages.taskAgentRouteVia,
      ),
    );

    final wait = _transcriptWait = transcription.transcribe(
      audioEntryId: audioEntryId,
    );
    // Preserve the provider's error detail for the failure card, including
    // a failure that arrived before this subscription was attached.
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
      fireImmediately: true,
    );
    try {
      final transcript = await wait.result;
      if (!mounted) return;
      // The wait was abandoned by *Type instead*; the field is theirs.
      if (_phase is! CheckInSpeechTranscribing) return;
      if (transcript == null) {
        setState(
          () => _phase = CheckInSpeechFailed(
            CheckInSpeechFailure(
              CheckInSpeechFailureKind.transcriptMissing,
              audioEntryId: audioEntryId,
              length: length,
              detail: failureDetail,
            ),
          ),
        );
        return;
      }
      final textBefore = _narrativeController.text;
      _narrativeController.text = mergeCheckInNarrative(
        existing: textBefore,
        transcript: transcript,
      );
      setState(
        () => _phase = CheckInSpeechReady(
          transcript: transcript,
          textBefore: textBefore,
          length: length,
        ),
      );
    } finally {
      if (identical(_transcriptWait, wait)) _transcriptWait = null;
      _closeTranscriptFailureSubscription();
    }
  }

  Future<void> _labelRoute(
    CheckInTranscriptionService transcription, {
    required String audioEntryId,
    required Duration length,
    required String via,
  }) async {
    final CheckInTranscriptionRoute? route;
    try {
      route = await transcription.route();
    } catch (exception, stackTrace) {
      developer.log(
        'Could not name the transcription route',
        name: 'CheckInCaptureForm',
        error: exception,
        stackTrace: stackTrace,
      );
      return;
    }
    if (!mounted || route == null) return;
    final label = '${route.model} · $via ${route.provider}';
    if (_phase case CheckInSpeechTranscribing(
      audioEntryId: final current,
    ) when current == audioEntryId) {
      setState(
        () => _phase = CheckInSpeechTranscribing(
          audioEntryId: audioEntryId,
          length: length,
          route: label,
        ),
      );
    }
  }

  /// *Try again* on a missing transcript: the same recording, asked for
  /// once more — never a second recording.
  Future<void> _retryTranscript() async {
    if (_phase case CheckInSpeechFailed(
      failure: CheckInSpeechFailure(
        kind: CheckInSpeechFailureKind.transcriptMissing,
        audioEntryId: final audioEntryId?,
        :final length,
      ),
    )) {
      await _transcribe(
        audioEntryId: audioEntryId,
        length: length ?? Duration.zero,
      );
    }
  }

  /// *Type instead* / *Dismiss*: the field comes back as plain text. A
  /// transcript still in flight is abandoned; the audio stays in the
  /// journal either way.
  void _typeInstead() {
    _transcriptWait?.cancel();
    _transcriptWait = null;
    _closeTranscriptFailureSubscription();
    setState(() => _phase = const CheckInSpeechIdle());
    _narrativeFocus.requestFocus();
  }

  Future<void> _openSettings() => ref.read(checkInSettingsOpenerProvider)();

  void _closeTranscriptFailureSubscription() {
    _transcriptFailureSubscription?.close();
    _transcriptFailureSubscription = null;
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
  /// and the time — what the *Started* chip reads.
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
          onDictate: speechIdle ? _dictate : null,
          onAddMore: speechIdle ? _dictate : null,
          onReRecord: speechIdle ? _reRecord : null,
          onTypeInstead: _typeInstead,
          onRetryTranscript: _retryTranscript,
          onOpenSettings: _openSettings,
          onDismissFailure: _typeInstead,
        ),
        SizedBox(height: tokens.spacing.step4),
        CheckInContextChips(
          type: _interactionType,
          startedLabel: _startedLabel(context),
          durationLabel: _duration == Duration.zero
              ? messages.checkInDurationChip
              : checkInDurationLabel(context, _duration),
          hasDuration: _duration != Duration.zero,
          enabled: speechIdle,
          onPickType: _pickType,
          onPickStart: _pickStart,
          onPickDuration: _pickDuration,
        ),
        // Where the numbers came from (design §5): the offer's channel,
        // start and elapsed time, and that every one of them is editable.
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
        SizedBox(height: tokens.spacing.step5),
        _MoreHeader(
          open: _moreOpen,
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
          SizedBox(height: tokens.spacing.step6),

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

    if (shortcut == null) return body;
    return CallbackShortcuts(
      bindings: {
        shortcut.activator: () {
          if (_block == CheckInSaveBlock.none) unawaited(_handleSave());
        },
      },
      child: body,
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
