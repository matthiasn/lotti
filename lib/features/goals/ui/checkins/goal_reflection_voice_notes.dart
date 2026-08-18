import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The voice half of the reflection sheet's Note block.
///
/// Recordings are created and linked the moment they exist — the recorder
/// already deletes a discarded partial — so dismissing the sheet can never
/// orphan audio. That is the deliberate trade: a stray recording the user can
/// see and delete beats a saved one that silently vanished.
///
/// The recordings shown here are the goal's own check-ins from today, because
/// that is what they are: a voice note attached to a reflection is a check-in,
/// and giving it a second home would put the same recording on the rail twice.
class GoalReflectionVoiceNotes extends ConsumerWidget {
  const GoalReflectionVoiceNotes({
    required this.agentId,
    this.enabled = true,
    super.key,
  });

  final String agentId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final goalEntryId = ref.watch(goalEntryIdProvider(agentId));
    final today = DateTime.now();
    final recordings = [
      for (final entity in ref.watch(goalCheckInEntriesProvider(agentId)))
        if (entity is JournalAudio &&
            DateUtils.isSameDay(entity.meta.dateFrom.toLocal(), today))
          entity,
    ]..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final audio in recordings) ...[
          AudioPlayerWidget(audio),
          SizedBox(height: tokens.spacing.step2),
        ],
        if (enabled && goalEntryId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              key: const ValueKey('goal-reflection-add-voice-note'),
              onTap: () => AudioRecordingModal.show(
                context,
                linkedId: goalEntryId,
                useRootNavigator: false,
              ),
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mic_rounded,
                      size: IconSizes.xs,
                      color: tokens.colors.interactive.enabled,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Text(
                      context.messages.goalCheckInAddVoiceNote,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.interactive.enabled,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Flexible(
                      child: Text(
                        context.messages.goalCheckInNoteKeptSeparate,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
