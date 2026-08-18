import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
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
    required this.day,
    this.enabled = true,
    this.openRecorder = openReflectionRecorder,
    super.key,
  });

  /// The recorder, defaulted to the real one and injected for the same reason
  /// the composer's is: the tap is behaviour worth testing without standing up
  /// the audio stack.
  final GoalCheckInRecorderOpener openRecorder;

  final String agentId;

  /// The day being reflected on — not necessarily today. Reopening
  /// yesterday's reflection must show yesterday's voice notes; showing
  /// today's instead would hide the one the user is looking for and display
  /// unrelated recordings under it.
  final DateTime day;

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final goalEntryId = ref.watch(goalCaptureTargetProvider(agentId)).value;
    final reflectedDay = day.toLocal();
    final recordings = [
      for (final entity in ref.watch(goalCheckInEntriesProvider(agentId)))
        if (entity is JournalAudio &&
            !entity.isDeleted &&
            DateUtils.isSameDay(entity.meta.dateFrom.toLocal(), reflectedDay))
          entity,
    ]..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

    // Recording always lands on the moment it happens, so offering it under a
    // past day would file today's words as yesterday's. Past reflections stay
    // readable; only capture is withheld.
    final canRecord =
        enabled &&
        goalEntryId != null &&
        DateUtils.isSameDay(reflectedDay, clock.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final audio in recordings) ...[
          AudioPlayerWidget(audio),
          SizedBox(height: tokens.spacing.step2),
        ],
        if (canRecord)
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              key: const ValueKey('goal-reflection-add-voice-note'),
              onTap: () => openRecorder(context, goalEntryId: goalEntryId),
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

/// The real recorder opener, exposed for test for the same reason the
/// composer's is.
@visibleForTesting
Future<void> openReflectionRecorder(
  BuildContext context, {
  required String goalEntryId,
  String? categoryId,
}) => AudioRecordingModal.show(
  context,
  linkedId: goalEntryId,
  categoryId: categoryId,
  useRootNavigator: false,
);
