import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/audio_player_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/audio_player_controller.dart';
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';

/// A recording in a history row, kept light: until it plays, only *Play
/// audio* — on a goal's rail and a person's timeline alike. A history is
/// for reading, and a waveform card under every recording made each one the
/// heaviest thing on the page (design panel 2026-10-31, unanimous).
///
/// Tapping plays it, and the row eases open to the app's waveform player
/// ([AudioPlayerWidget]) while this recording is the one the player holds
/// and has not finished; when it finishes, or another recording starts, it
/// folds back. One player for the app, so only one row is ever open.
class RecordingPlayback extends ConsumerWidget {
  const RecordingPlayback(this.audio, {super.key});

  final JournalAudio audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = audio.meta.id;
    // Open while this recording is the one the player holds and has not run
    // to its end: a finished recording folds back to its glyph.
    final isOpen = ref.watch(
      audioPlayerControllerProvider.select(
        (state) =>
            state.audioNote?.meta.id == id &&
            state.status != AudioPlayerStatus.stopped,
      ),
    );
    final tokens = context.designTokens;
    // Eased, not snapped: the rows below move down with the player rather
    // than jumping, so a reader keeps their place.
    return AnimatedSize(
      duration: MotionDurations.medium1,
      curve: MotionCurves.standard,
      alignment: AlignmentDirectional.topStart,
      child: isOpen
          ? Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.step2),
              child: AudioPlayerWidget(
                audio,
                key: ValueKey('recording-player-$id'),
              ),
            )
          : _PlayAction(audio: audio),
    );
  }
}

/// The closed row's one action: *Play audio*, its own shape — a play glyph
/// and a word — so it never reads as the time a check-in counts for beside
/// it. The row already says how long it ran.
class _PlayAction extends ConsumerWidget {
  const _PlayAction({required this.audio});

  final JournalAudio audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = audio.meta.id;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DesignSystemButton(
        key: ValueKey('recording-playback-play-$id'),
        label: context.messages.audioPlayerPlay,
        leadingIcon: LottiIcons.playCircled,
        variant: DesignSystemButtonVariant.tertiary,
        // The caption tier of the row's other actions: visually light, the
        // owner's ask — the words stay the loudest thing in the row.
        size: DesignSystemButtonSize.dense,
        alignsLabelToLeadingEdge: true,
        semanticsLabel:
            '${context.messages.audioPlayerPlay}, '
            '${formatElapsed(audio.data.duration)}',
        onPressed: () async {
          await ref
              .read(audioPlayerControllerProvider.notifier)
              .playAudioNote(audio);
        },
      ),
    );
  }
}
