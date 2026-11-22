import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_duration.dart';
import 'package:lotti/features/speech/state/app_settings_opener.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:material_ui/material_ui.dart';

/// Saves a written check-in spanning `started` plus `timeSpent`. Returns
/// whether it landed.
typedef GoalCheckInTextSaver =
    Future<bool> Function({
      required String text,
      required String goalEntryId,
      required DateTime started,
      required Duration timeSpent,
      String? categoryId,
    });

/// How the check-in sheet opens.
enum GoalCheckInStart {
  /// Already recording: the user pressed *Speak*.
  speaking,

  /// With the text field up: the user chose to write.
  writing,

  /// Neither yet — a banner brought the user here, and turning the mic on
  /// for them would be a surprise. *Speak* is one tap away.
  idle,
}

/// The anytime check-in, in one sheet: it opens already listening, with the
/// agent's question still in view while the user answers it.
///
/// A check-in used to take three taps and two stacked sheets — the mic, then
/// *Record a check-in*, then *Record* on a second sheet that covered the
/// question and named neither the goal nor what was being recorded. It now
/// records with the shared [InlineRecorder], the recorder a person's
/// check-in uses, so the two look and behave alike:
///
/// - **Speaking** — the recorder, started on open. Stop saves the take,
///   linked to the goal, and closes the sheet; Discard returns to the sheet
///   at rest. A sheet dismissed mid-take leaves the take running behind the
///   app's recording indicator, where stopping it saves and transcribes it.
/// - **At rest** — one *Speak* button and *Write instead*, after a discard,
///   a failure, or when opened from a banner.
/// - **Writing** — the text field and the time the check-in counts for.
///
/// A recorder that could not record says why in a callout with the way
/// forward: *Open settings* for a refused microphone, *Try again* otherwise,
/// and *Write instead* always — never a red line under a glowing orb.
///
/// Deliberately a lighter sheet rather than a mode of the day reflection.
/// The reflection is a judgement about a finished day; a check-in is a
/// moment. The agent's line is read from what the last wake already
/// authored, so opening this costs no inference.
class GoalCheckInComposer extends ConsumerStatefulWidget {
  const GoalCheckInComposer({
    required this.agentId,
    required this.goalTitle,
    this.start = GoalCheckInStart.idle,
    this.preparedLine,
    this.personaName,
    this.categoryId,
    this.saveText = saveCheckInText,
    this.pickDuration = showGoalCheckInDurationPicker,
    super.key,
  });

  /// Seams for the side effects, defaulted to the real ones, so the save
  /// path is testable without standing up the journal stack.
  final GoalCheckInTextSaver saveText;
  final Future<Duration?> Function({
    required BuildContext context,
    required Duration initialDuration,
  })
  pickDuration;

  final String agentId;
  final String goalTitle;
  final GoalCheckInStart start;

  /// One agent-authored sentence to reflect on. Absent is normal and fine —
  /// the composer's job is capture, and the prompt is additive.
  final String? preparedLine;
  final String? personaName;

  /// The goal's category, when the host already has it; otherwise the
  /// composer reads it from the goal row before it writes anything.
  final String? categoryId;

  /// Opens the composer as the app's action sheet — a sheet on a phone, a
  /// dialog on a wide window, as the person's *Speak* sheet is.
  static Future<void> show(
    BuildContext context, {
    required String agentId,
    required String goalTitle,
    GoalCheckInStart start = GoalCheckInStart.idle,
    String? preparedLine,
    String? personaName,
    String? categoryId,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await DsActionModal.show<void>(
        context: context,
        title: context.messages.goalCheckInComposerTitle,
        builder: (_) => GoalCheckInComposer(
          agentId: agentId,
          goalTitle: goalTitle,
          start: start,
          preparedLine: preparedLine,
          personaName: personaName,
          categoryId: categoryId,
        ),
      );
    } finally {
      // The recorder hides the floating indicator while it is up; a sheet
      // gone mid-take must hand it back, for the take to be stopped there.
      // Only where a recorder exists: a written check-in never made one.
      if (container.read(audioRecorderControllerProvider.exists)) {
        container
            .read(audioRecorderControllerProvider.notifier)
            .setModalVisible(modalVisible: false);
      }
    }
  }

  @override
  ConsumerState<GoalCheckInComposer> createState() =>
      _GoalCheckInComposerState();
}

enum _Mode { speaking, idle, writing }

class _GoalCheckInComposerState extends ConsumerState<GoalCheckInComposer> {
  final _text = TextEditingController();
  late _Mode _mode = switch (widget.start) {
    GoalCheckInStart.speaking => _Mode.speaking,
    GoalCheckInStart.writing => _Mode.writing,
    GoalCheckInStart.idle => _Mode.idle,
  };
  InlineRecordingFailure? _failure;
  var _saving = false;

  /// The writing session: when it began, the time counted before the current
  /// run, and when the current run started (null while paused). A check-in is
  /// a measurable activity, so the time the user spends writing it is what
  /// the entry stores — not the moment the sheet happened to open.
  DateTime? _sessionStart;
  Duration _counted = Duration.zero;
  DateTime? _runningSince;

  /// A time the user set by hand. It replaces the counted time outright: the
  /// user knows better than the clock how long they were really reflecting.
  Duration? _override;

  /// Repaints the running clock. It drives nothing else.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (_mode == _Mode.writing) _startWriting();
  }

  Duration get _timeSpent {
    if (_override case final override?) return override;
    final since = _runningSince;
    return since == null ? _counted : _counted + clock.now().difference(since);
  }

  bool get _running => _override == null && _runningSince != null;

  void _startWriting() {
    final now = clock.now();
    _sessionStart ??= now;
    if (_override == null && _runningSince == null) _resume(now);
  }

  void _resume([DateTime? at]) {
    _runningSince = at ?? clock.now();
    _ticker ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  void _pause() {
    final since = _runningSince;
    if (since != null) _counted += clock.now().difference(since);
    _runningSince = null;
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _editTime() async {
    final chosen = await widget.pickDuration(
      context: context,
      initialDuration: _timeSpent,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _pause();
      _override = chosen;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _speak() => setState(() {
    _pause();
    _failure = null;
    _mode = _Mode.speaking;
  });

  void _write() => setState(() {
    _failure = null;
    _mode = _Mode.writing;
    _startWriting();
  });

  /// The take is saved and linked the moment the recorder stops, and its
  /// words follow from the recorder's own automation — which also covers a
  /// take stopped from the floating indicator after this sheet is gone. So
  /// the sheet's job is done: it says so and closes.
  void _onRecorded(String _, Duration _) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = context.messages.goalCheckInSaved;
    Navigator.of(context).pop();
    messenger?.showDesignSystemToast(
      tone: DesignSystemToastTone.success,
      title: saved,
    );
  }

  Future<void> _saveText(String goalEntryId, String? categoryId) async {
    final text = _text.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final created = await widget.saveText(
        text: text,
        goalEntryId: goalEntryId,
        started: _sessionStart ?? clock.now(),
        timeSpent: _timeSpent,
        categoryId: categoryId,
      );
      if (created && mounted) Navigator.of(context).pop();
    } finally {
      // Reset whatever happened: a throw used to leave the button spinning
      // forever with nothing telling the user the save had failed.
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // The capture target, not the derived id: linking to a row that does not
    // exist yet saves the recording and silently drops the link.
    final target = ref.watch(goalCaptureTargetProvider(widget.agentId));
    final goalEntryId = target.value;
    // The category a check-in is filed in: the host's, or the goal row's. A
    // composer opened while that lookup is still loading waits for it, or
    // the check-in would be filed uncategorized.
    final category = ref.watch(goalCategoryIdProvider(widget.agentId));
    final categoryId = widget.categoryId ?? category.value;
    final ready =
        target.hasValue && (widget.categoryId != null || category.hasValue);
    final failure = _failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // What the check-in is about: the sheet's title says *Check in*, and
        // this names the goal, so the recorder is never anonymous.
        Text(
          widget.goalTitle,
          key: const ValueKey('goal-checkin-goal-title'),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        if (widget.preparedLine case final line?) ...[
          SizedBox(height: tokens.spacing.step4),
          _PreparedCard(line: line, personaName: widget.personaName),
        ],
        if (failure != null) ...[
          SizedBox(height: tokens.spacing.step4),
          _FailureCallout(
            failure: failure,
            onOpenSettings: () => ref.read(appSettingsOpenerProvider)(),
            onWrite: _write,
          ),
        ],
        SizedBox(height: tokens.spacing.step5),
        switch (_mode) {
          _Mode.speaking when !ready => Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
            child: Center(
              child: DesignSystemSpinner(
                semanticsLabel: messages.commonLoading,
              ),
            ),
          ),
          // No goal row to record into: the sheet rests, its Speak disabled.
          _Mode.speaking when goalEntryId == null => const _SpeakButton(
            onPressed: null,
          ),
          _Mode.speaking => InlineRecorder(
            linkedId: goalEntryId!,
            categoryId: categoryId,
            // The recorder's own automation transcribes a goal's take, under
            // the goal's automatic-updates switch.
            transcriptionHandledByCaller: false,
            // The sheet has no status line of its own.
            showStatus: true,
            onRecorded: _onRecorded,
            onDiscarded: () => setState(() => _mode = _Mode.idle),
            onFailed: (failure) => setState(() {
              _failure = failure;
              _mode = _Mode.idle;
            }),
          ),
          _Mode.idle => _SpeakButton(
            onPressed: goalEntryId == null ? null : _speak,
          ),
          _Mode.writing => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SessionRow(
                timeSpent: _timeSpent,
                running: _running,
                edited: _override != null,
                onPause: () => setState(_pause),
                onResume: () => setState(_resume),
                onEdit: _editTime,
              ),
              SizedBox(height: tokens.spacing.step3),
              DesignSystemTextarea(
                controller: _text,
                label: messages.goalCheckInWritePlaceholder,
                growWithContent: true,
              ),
            ],
          ),
        },
        // While a take is running the recorder's own row is the only set of
        // controls: Discard, Stop, Pause. Everything else waits.
        if (_mode != _Mode.speaking || !ready || goalEntryId == null) ...[
          SizedBox(height: tokens.spacing.step5),
          Row(
            children: [
              // A failure's callout already offers *Write instead*; a second
              // copy under it would be the same button twice.
              if (failure == null || _mode == _Mode.writing) ...[
                Expanded(
                  child: DesignSystemButton(
                    key: const ValueKey('goal-checkin-mode-toggle'),
                    label: _mode == _Mode.writing
                        ? messages.goalCheckInSpeakInstead
                        : messages.goalCheckInWriteInstead,
                    leadingIcon: _mode == _Mode.writing
                        ? LottiIcons.mic
                        : LottiIcons.edit,
                    variant: DesignSystemButtonVariant.secondary,
                    onPressed: _mode == _Mode.writing
                        ? (goalEntryId == null ? null : _speak)
                        : _write,
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
              ],
              Expanded(
                // One label, one meaning: writing, the sole primary commits;
                // at rest Speak is the only primary and this is a plain way
                // out.
                child: _mode == _Mode.writing
                    ? DesignSystemButton(
                        key: const ValueKey('goal-checkin-save'),
                        label: messages.goalCheckInSave,
                        isLoading: _saving,
                        // Never save without a capture target: with none
                        // resolved, popping discarded what the user had just
                        // typed without a word.
                        onPressed: goalEntryId == null
                            ? null
                            : () => _saveText(goalEntryId, categoryId),
                      )
                    : DesignSystemButton(
                        label: messages.goalCheckInClose,
                        variant: DesignSystemButtonVariant.tertiary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The agent's opening question, in the agent's own voice: its violet card
/// and its name, so the user is never answering a prompt without knowing
/// where it came from (the Two Voices rule — it used to wear the user's
/// teal).
class _PreparedCard extends StatelessWidget {
  const _PreparedCard({required this.line, this.personaName});

  final String line;
  final String? personaName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      key: const ValueKey('goal-checkin-prepared'),
      decoration: aiCardDecoration(context),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.goalCheckInPreparedBy(
                personaName ?? context.messages.agentsPageTitle,
              ),
              style: calmEyebrowStyle(
                tokens,
                color: tokens.colors.aiCard.accent,
              ),
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              line,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the recorder has nothing to hand back, and what to do about it: the
/// reason in plain words, writing as the way that always works, and *Open
/// settings* where a refused microphone is the reason. Trying again is the
/// sheet's *Speak* button beneath it.
class _FailureCallout extends StatelessWidget {
  const _FailureCallout({
    required this.failure,
    required this.onOpenSettings,
    required this.onWrite,
  });

  final InlineRecordingFailure failure;
  final VoidCallback onOpenSettings;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final alert = tokens.colors.alert;
    final denied = failure == InlineRecordingFailure.microphoneDenied;
    final (tone, icon, title, body) = switch (failure) {
      InlineRecordingFailure.microphoneDenied => (
        alert.error.defaultColor,
        LottiIcons.micIdle,
        messages.checkInMicrophoneDeniedCalloutTitle,
        messages.goalCheckInMicrophoneDeniedBody,
      ),
      InlineRecordingFailure.startFailed => (
        alert.error.defaultColor,
        LottiIcons.micIdle,
        messages.checkInRecordingFailedTitle,
        messages.checkInRecordingFailedBody,
      ),
      InlineRecordingFailure.recorderBusy => (
        alert.warning.defaultColor,
        LottiIcons.mic,
        messages.checkInRecorderBusyTitle,
        messages.checkInRecorderBusyBody,
      ),
      InlineRecordingFailure.notSaved => (
        alert.error.defaultColor,
        LottiIcons.micIdle,
        messages.checkInRecordingNotSavedTitle,
        messages.checkInRecordingNotSavedBody,
      ),
    };
    return DesignSystemInlineCallout(
      key: ValueKey('goal-checkin-failure-${failure.name}'),
      icon: icon,
      tone: tone,
      title: title,
      text: body,
      announce: true,
      actions: [
        DesignSystemButton(
          key: const ValueKey('goal-checkin-failure-write'),
          label: messages.goalCheckInWriteInstead,
          variant: DesignSystemButtonVariant.quiet,
          size: DesignSystemButtonSize.medium,
          tapTargetSize: MaterialTapTargetSize.padded,
          onPressed: onWrite,
        ),
        // Trying again is the sheet's own Speak button, right under this
        // callout; only a refused microphone needs a door of its own.
        if (denied)
          DesignSystemButton(
            key: const ValueKey('goal-checkin-open-settings'),
            label: messages.checkInOpenSettingsButton,
            leadingIcon: LottiIcons.settings,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.medium,
            tapTargetSize: MaterialTapTargetSize.padded,
            onPressed: onOpenSettings,
          ),
      ],
    );
  }
}

/// The writing session's read-out: the time this check-in will count for,
/// running or paused, with the controls to pause it or set it by hand.
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.timeSpent,
    required this.running,
    required this.edited,
    required this.onPause,
    required this.onResume,
    required this.onEdit,
  });

  final Duration timeSpent;
  final bool running;
  final bool edited;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final clockText = _clockText(timeSpent);
    final label = edited
        // A time set by hand is the user's answer, zero included — so it
        // reads "0 min", not an offer to add time.
        ? messages.goalCheckInTimeSpentValue(
            goalCheckInDurationLabel(context, timeSpent) ??
                messages.goalCheckInMinutes(0),
          )
        : running
        ? messages.goalCheckInSessionRunning(clockText)
        : messages.goalCheckInSessionPaused(clockText);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            key: const ValueKey('goal-checkin-session-label'),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (!edited)
          DesignSystemButton(
            key: const ValueKey('goal-checkin-session-toggle'),
            label: running
                ? messages.goalCheckInSessionPause
                : messages.goalCheckInSessionResume,
            leadingIcon: running ? LottiIcons.pause : LottiIcons.play,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.dense,
            onPressed: running ? onPause : onResume,
          ),
        DesignSystemButton(
          key: const ValueKey('goal-checkin-session-edit'),
          label: messages.goalCheckInSessionEdit,
          leadingIcon: LottiIcons.timer,
          variant: DesignSystemButtonVariant.tertiary,
          size: DesignSystemButtonSize.dense,
          onPressed: onEdit,
        ),
      ],
    );
  }

  /// `m:ss` — digits only, so it needs no translation.
  static String _clockText(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// The sheet's primary action at rest: the app's one voice verb, on the
/// design system's large button.
class _SpeakButton extends StatelessWidget {
  const _SpeakButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DesignSystemButton(
      key: const ValueKey('goal-checkin-record'),
      label: context.messages.goalSpeak,
      leadingIcon: LottiIcons.mic,
      onPressed: onPressed,
      fullWidth: true,
      size: DesignSystemButtonSize.large,
    );
  }
}

/// The real saver. Exposed for test because it is the one place the static
/// `JournalRepository.createTextEntry` is called from — the seam exists so the
/// composer is testable, and this keeps the adapter itself honest too.
@visibleForTesting
Future<bool> saveCheckInText({
  required String text,
  required String goalEntryId,
  required DateTime started,
  required Duration timeSpent,
  String? categoryId,
}) async {
  final created = await JournalRepository.createTextEntry(
    EntryText(plainText: text),
    started: started,
    ended: started.add(timeSpent),
    linkedId: goalEntryId,
    categoryId: categoryId,
  );
  return created != null;
}
