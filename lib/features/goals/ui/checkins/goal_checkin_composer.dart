import 'package:flutter/material.dart';
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
class GoalCheckInComposer extends ConsumerStatefulWidget {
  const GoalCheckInComposer({
    required this.agentId,
    required this.goalTitle,
    this.preparedLine,
    this.personaName,
    this.categoryId,
    super.key,
  });

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
  Future<void> _record(String goalEntryId) async {
    await AudioRecordingModal.show(
      context,
      linkedId: goalEntryId,
      categoryId: widget.categoryId,
      useRootNavigator: false,
    );
  }

  Future<void> _saveText(String goalEntryId) async {
    final text = _text.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    final created = await JournalRepository.createTextEntry(
      EntryText(plainText: text),
      started: DateTime.now(),
      id: const Uuid().v1(),
      linkedId: goalEntryId,
      categoryId: widget.categoryId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (created != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final goalEntryId = ref.watch(goalEntryIdProvider(widget.agentId));

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
                DateFormat.yMMMMEEEEd(locale).add_Hm().format(DateTime.now()),
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
                      leadingIcon: _writing
                          ? Icons.mic_rounded
                          : Icons.edit_outlined,
                      variant: DesignSystemButtonVariant.secondary,
                      onPressed: () => setState(() => _writing = !_writing),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: DesignSystemButton(
                      label: context.messages.goalCheckInDone,
                      isLoading: _saving,
                      onPressed: () {
                        if (_writing && goalEntryId != null) {
                          _saveText(goalEntryId);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
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

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.onPressed});

  final VoidCallback? onPressed;

  static const double _diameter = 68;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Column(
      children: [
        Semantics(
          button: true,
          label: context.messages.goalCheckInRecordCta,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: _diameter,
              height: _diameter,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: accent),
              ),
              child: Icon(Icons.mic_rounded, size: IconSizes.l, color: accent),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          context.messages.goalCheckInRecordCta,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}
