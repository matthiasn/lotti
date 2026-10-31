import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_charter_providers.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_recording.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_sheet.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/transcript/recording_transcript.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

/// *About this goal*: the goal's charter (ADR 0140) — what the user wrote
/// or said the goal is for and how its agent should coach, which the agent
/// reads on every wake.
///
/// A written entry opens its sheet to edit; a recorded one plays, and its
/// transcript opens the sheet to correct. The header writes another or
/// records another. With no charter yet, the card invites one, since a goal
/// with soft criteria has nowhere else to say what it is about. A charter
/// longer than one wake can carry says so, because the agent would otherwise
/// silently read half of it.
class GoalCharterCard extends ConsumerWidget {
  const GoalCharterCard({
    required this.agentId,
    required this.editable,
    super.key,
  });

  final String agentId;

  /// False on a dormant goal: its charter still reads and plays, but nothing
  /// is added or changed — the same gate the check-ins card applies.
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // `.value` keeps the last charter on screen while a background re-read
    // runs, so an edit synced in never flashes the card empty.
    final entries = ref.watch(goalCharterEntriesProvider(agentId)).value;
    if (entries == null || (entries.isEmpty && !editable)) {
      return const SizedBox.shrink();
    }
    void write([JournalEntity? entry]) => showGoalCharterSheet(
      context: context,
      agentId: agentId,
      entry: entry,
    );
    void record() => recordGoalCharterEntry(context, agentId: agentId);
    final interactive = tokens.colors.interactive.enabled;

    // The card owns the gap above it, so a card that renders nothing leaves
    // no hole in the page's otherwise even stack.
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.cardItemSpacing),
      child: DesignSystemSectionCard(
        key: const ValueKey('goal-charter-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    messages.goalCharterTitle,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                if (editable && entries.isNotEmpty) ...[
                  IconButton(
                    key: const ValueKey('goal-charter-record'),
                    onPressed: record,
                    tooltip: messages.goalCharterRecord,
                    icon: Icon(LottiIcons.mic, color: interactive),
                  ),
                  IconButton(
                    key: const ValueKey('goal-charter-add'),
                    onPressed: write,
                    tooltip: messages.goalCharterAdd,
                    icon: Icon(LottiIcons.addCircled, color: interactive),
                  ),
                ],
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
            if (entries.isEmpty) ...[
              Text(
                messages.goalCharterEmpty,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              Wrap(
                spacing: tokens.spacing.step3,
                runSpacing: tokens.spacing.step2,
                children: [
                  DesignSystemButton(
                    key: const ValueKey('goal-charter-empty-cta'),
                    label: messages.goalCharterAdd,
                    leadingIcon: LottiIcons.edit,
                    variant: DesignSystemButtonVariant.secondary,
                    onPressed: write,
                  ),
                  DesignSystemButton(
                    key: const ValueKey('goal-charter-empty-record'),
                    label: messages.goalCharterRecord,
                    leadingIcon: LottiIcons.mic,
                    variant: DesignSystemButtonVariant.secondary,
                    onPressed: record,
                  ),
                ],
              ),
            ] else ...[
              for (final (index, entry) in entries.indexed) ...[
                // A rule between entries, with more air around it than any
                // gap inside one: a recording's transcript must read as its
                // own, not as the caption of the player below it.
                if (index > 0)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: tokens.spacing.step4,
                    ),
                    child: const DesignSystemDivider(),
                  ),
                if (entry is JournalAudio)
                  _GoalCharterRecordingTile(
                    recording: entry,
                    onEdit: editable ? () => write(entry) : null,
                  )
                else
                  _GoalCharterNoteTile(
                    entry: entry,
                    onTap: editable ? () => write(entry) : null,
                  ),
              ],
              if (!goalCharterFitsBudget(entries)) ...[
                SizedBox(height: tokens.spacing.step3),
                Row(
                  key: const ValueKey('goal-charter-over-budget'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LottiIcons.warning,
                      size: IconSizes.s,
                      color: tokens.colors.alert.warning.defaultColor,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Expanded(
                      child: Text(
                        messages.goalCharterOverBudget,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The words of a charter entry, in full: the user wrote them — or said
/// them — for the agent to read word for word, so the page shows them the
/// same way. Tapping them edits them when [onTap] is given.
class _GoalCharterWords extends StatelessWidget {
  const _GoalCharterWords({
    required this.entryId,
    required this.text,
    required this.onTap,
  });

  final String entryId;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final words = Text(
      text,
      style: tokens.typography.styles.body.bodyMedium.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
    final tap = onTap;
    if (tap == null) return words;
    return DsQuietInk(
      key: ValueKey('goal-charter-entry-$entryId'),
      onTap: tap,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      builder: (context, highlighted) => Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
        child: words,
      ),
    );
  }
}

/// A written charter entry.
class _GoalCharterNoteTile extends StatelessWidget {
  const _GoalCharterNoteTile({required this.entry, required this.onTap});

  final JournalEntity entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _GoalCharterWords(
    entryId: entry.meta.id,
    text: entry.entryText?.plainText.trim() ?? '',
    onTap: onTap,
  );
}

/// A spoken charter entry: the recording, then its transcript — or, until
/// there is one, the same honest account the check-in rail gives
/// ([RecordingTranscript]), with Retry where nothing is coming. It
/// wakes itself when its grace window closes, as the rail does.
class _GoalCharterRecordingTile extends ConsumerStatefulWidget {
  const _GoalCharterRecordingTile({
    required this.recording,
    required this.onEdit,
  });

  final JournalAudio recording;
  final VoidCallback? onEdit;

  @override
  ConsumerState<_GoalCharterRecordingTile> createState() =>
      _GoalCharterRecordingTileState();
}

class _GoalCharterRecordingTileState
    extends ConsumerState<_GoalCharterRecordingTile>
    with TranscriptGraceRebuild {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final recording = widget.recording;
    final onEdit = widget.onEdit;
    final id = recording.meta.id;
    final transcript = recording.entryText?.plainText.trim() ?? '';
    final hasTranscript = transcript.isNotEmpty;
    final inference = ref.watch(
      inferenceStatusControllerProvider((
        id: id,
        aiResponseType: AiResponseType.audioTranscription,
      )),
    );
    final durableFailure =
        !hasTranscript &&
        (ref.watch(goalAudioTranscriptionFailedProvider(id)).value ?? false);
    final graceExpiry = recording.meta.dateFrom.add(kTranscriptGrace);
    final now = clock.now();
    final status = transcriptStatusOf(
      hasTranscript: hasTranscript,
      running: inference == InferenceStatus.running,
      failed: inference == InferenceStatus.error || durableFailure,
      graceExpiry: graceExpiry,
      now: now,
    );
    // Waiting with nothing running is the one state no other rebuild ends.
    armGraceRebuild(
      status == TranscriptStatus.transcribing &&
              inference == InferenceStatus.idle &&
              graceExpiry.isAfter(now)
          ? graceExpiry
          : null,
    );
    return Column(
      key: ValueKey('goal-charter-recording-$id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AudioPlayerWidget(recording),
        SizedBox(height: tokens.spacing.step2),
        // The charter's words stay editable in place; until there are any,
        // the recording says why the way every check-in recording does.
        if (status == TranscriptStatus.heard)
          _GoalCharterWords(entryId: id, text: transcript, onTap: onEdit)
        else
          RecordingTranscript(
            id: id,
            status: status,
            onRetry: () => ref.read(
              triggerSkillProvider((
                entityId: id,
                skillId: skillTranscribeContextId,
                linkedTaskId: null,
                referenceImages: null,
                overrideModelId: null,
                geminiThinkingMode: null,
              )).future,
            ),
          ),
      ],
    );
  }
}
