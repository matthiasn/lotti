import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_duration.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:material_ui/material_ui.dart';

/// The anytime check-in: one tap into the recorder, no typing required.
///
/// Deliberately a third, lighter sheet rather than a mode of the day
/// reflection. The reflection is a judgement about a finished day; a check-in
/// is a moment. Folding them together would produce a modal with a mode
/// switch, which makes both worse.
///
/// The agent's prepared line is read from what the last wake already authored,
/// so opening this costs no inference — it is a casual surface and must stay
/// free to open.
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

/// Opens the recorder against a goal. Resolves with the created audio
/// entry's id, or null when the recording was discarded.
typedef GoalCheckInRecorderOpener =
    Future<String?> Function(
      BuildContext context, {
      required String goalEntryId,
      String? categoryId,
    });

class GoalCheckInComposer extends ConsumerStatefulWidget {
  const GoalCheckInComposer({
    required this.agentId,
    required this.goalTitle,
    this.preparedLine,
    this.personaName,
    this.categoryId,
    this.saveText = saveCheckInText,
    this.openRecorder = openCheckInRecorder,
    this.pickDuration = showGoalCheckInDurationPicker,
    super.key,
  });

  /// Seams for the two side effects, defaulted to the real ones. Injected
  /// rather than called statically so the composer's save and record paths are
  /// testable without standing up the journal and audio stacks.
  final GoalCheckInTextSaver saveText;
  final GoalCheckInRecorderOpener openRecorder;
  final Future<Duration?> Function({
    required BuildContext context,
    required Duration initialDuration,
  })
  pickDuration;

  final String agentId;
  final String goalTitle;

  /// One agent-authored sentence to reflect on. Absent is normal and fine —
  /// the composer's job is capture, and the prompt is additive.
  final String? preparedLine;
  final String? personaName;
  final String? categoryId;

  /// Opens the composer as a bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String agentId,
    required String goalTitle,
    String? preparedLine,
    String? personaName,
    String? categoryId,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => GoalCheckInComposer(
      agentId: agentId,
      goalTitle: goalTitle,
      preparedLine: preparedLine,
      personaName: personaName,
      categoryId: categoryId,
    ),
  );

  @override
  ConsumerState<GoalCheckInComposer> createState() =>
      _GoalCheckInComposerState();
}

class _GoalCheckInComposerState extends ConsumerState<GoalCheckInComposer> {
  final _text = TextEditingController();
  var _writing = false;
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

  /// Records straight into the goal. The recorder owns save-versus-discard, so
  /// a discarded recording creates nothing and a saved one is linked the
  /// moment it exists — a dismissed sheet can never orphan audio.
  ///
  /// When the recorder saved something the composer's job is done, so it
  /// closes itself instead of leaving a sheet whose only remaining action is
  /// dismissal. A discarded recording returns to the sheet — the user may
  /// still want to write instead.
  Future<void> _record(String goalEntryId) async {
    final createdId = await widget.openRecorder(
      context,
      goalEntryId: goalEntryId,
      categoryId: widget.categoryId,
    );
    if (createdId == null) return;
    // Transcription is not asked for here: the recorder's stop path runs the
    // shared post-recording automation, which recognises a goal-linked
    // recording and transcribes it under the goal's automatic-updates switch.
    // Asking from the composer would miss every recording stopped from the
    // sidebar or the floating indicator after this sheet was dismissed.
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveText(String goalEntryId) async {
    final text = _text.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final created = await widget.saveText(
        text: text,
        goalEntryId: goalEntryId,
        started: _sessionStart ?? clock.now(),
        timeSpent: _timeSpent,
        categoryId: widget.categoryId,
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    // The capture target, not the derived id: linking to a row that does not
    // exist yet saves the recording and silently drops the link.
    final goalEntryId = ref
        .watch(goalCaptureTargetProvider(widget.agentId))
        .value;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step5,
          tokens.spacing.step4,
          tokens.spacing.step5,
          tokens.spacing.step5,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${context.messages.goalCheckInComposerTitle} · '
                '${widget.goalTitle}',
                style: tokens.typography.styles.heading.heading3,
              ),
              SizedBox(height: tokens.spacing.step1),
              Text(
                DateFormat.yMMMMEEEEd(locale).add_Hm().format(clock.now()),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
              if (widget.preparedLine case final line?) ...[
                SizedBox(height: tokens.spacing.step4),
                _PreparedCard(line: line, personaName: widget.personaName),
              ],
              SizedBox(height: tokens.spacing.step5),
              if (_writing) ...[
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
                  label: context.messages.goalCheckInWritePlaceholder,
                  growWithContent: true,
                ),
              ] else
                _RecordButton(
                  onPressed: goalEntryId == null
                      ? null
                      : () => _record(goalEntryId),
                ),
              SizedBox(height: tokens.spacing.step5),
              Row(
                children: [
                  Expanded(
                    child: DesignSystemButton(
                      label: _writing
                          ? context.messages.goalCheckInRecordCta
                          : context.messages.goalCheckInWriteInstead,
                      leadingIcon: _writing ? LottiIcons.mic : LottiIcons.edit,
                      variant: DesignSystemButtonVariant.secondary,
                      onPressed: () => setState(() {
                        _writing = !_writing;
                        // Recording is its own session — the recorder's span
                        // is the voice check-in's time — so leaving write
                        // mode stops the writing clock rather than letting
                        // it count time spent recording.
                        _writing ? _startWriting() : _pause();
                      }),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    // One label, one meaning: in write mode the sole primary
                    // commits; in record mode the hero record button is the
                    // only primary and this slot is a plain dismissal.
                    child: _writing
                        ? DesignSystemButton(
                            label: context.messages.goalCheckInSave,
                            isLoading: _saving,
                            // Never save without a capture target: with none
                            // resolved, popping discarded what the user had
                            // just typed without a word — the same silent
                            // drop the capture gate exists to prevent for
                            // audio.
                            onPressed: goalEntryId == null
                                ? null
                                : () => _saveText(goalEntryId),
                          )
                        : DesignSystemButton(
                            label: context.messages.goalCheckInClose,
                            variant: DesignSystemButtonVariant.tertiary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The agent's opening question, labelled as the agent's — the same provenance
/// contract the verdict suggestion keeps on the reflection sheet. The user is
/// never answering a prompt without knowing where it came from.
class _PreparedCard extends StatelessWidget {
  const _PreparedCard({required this.line, this.personaName});

  final String line;
  final String? personaName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.goalCheckInPreparedBy(
              personaName ?? context.messages.agentsPageTitle,
            ),
            style: calmEyebrowStyle(tokens, color: accent),
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

/// The composer's primary action.
///
/// The design canvas draws a 68px orb here, but the recorder this opens is the
/// app-wide `AudioRecordingModal` — which owns the real capture UI, the level
/// meter and the discard rules. A bespoke orb would therefore be a large
/// button wearing a one-off dimension the design system has no token for, so
/// this uses the system's own button instead. A dedicated recorder-control
/// token is the thing to add if the orb is wanted; it needs a decision, not an
/// invented constant.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DesignSystemButton(
      key: const ValueKey('goal-checkin-record'),
      label: context.messages.goalCheckInRecordCta,
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

/// The real recorder opener.
///
/// Pure delegation to the app-wide recording modal, which owns the capture UI,
/// the level meter, the discard rules and its own tests. Exercising it here
/// would mean driving that modal's timers to assert nothing this function
/// decides, so it is excluded rather than covered by a test that proves
/// nothing.
// coverage:ignore-start
Future<String?> openCheckInRecorder(
  BuildContext context, {
  required String goalEntryId,
  String? categoryId,
}) => AudioRecordingModal.show(
  context,
  linkedId: goalEntryId,
  categoryId: categoryId,
  // The composer is itself a sheet; the recorder must open inside the same
  // navigator or it tears the composer down beneath it.
  useRootNavigator: false,
);
// coverage:ignore-end
