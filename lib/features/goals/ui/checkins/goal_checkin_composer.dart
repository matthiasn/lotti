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
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

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
/// Saves a written check-in. Returns whether it landed.
typedef GoalCheckInTextSaver =
    Future<bool> Function({
      required String text,
      required String goalEntryId,
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
    super.key,
  });

  /// Seams for the two side effects, defaulted to the real ones. Injected
  /// rather than called statically so the composer's save and record paths are
  /// testable without standing up the journal and audio stacks.
  final GoalCheckInTextSaver saveText;
  final GoalCheckInRecorderOpener openRecorder;

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

  @override
  void dispose() {
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
              if (_writing)
                DesignSystemTextarea(
                  controller: _text,
                  label: context.messages.goalCheckInWritePlaceholder,
                  growWithContent: true,
                )
              else
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
                      onPressed: () => setState(() => _writing = !_writing),
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
  String? categoryId,
}) async {
  final created = await JournalRepository.createTextEntry(
    EntryText(plainText: text),
    started: clock.now(),
    id: const Uuid().v1(),
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
