import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/audio_player_controller.dart';
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';

/// A recording in a history row, kept light: until it plays, only a play
/// glyph and its length — on a goal's rail and a person's timeline alike. A
/// history is for reading, and a waveform card under every recording made
/// each one the heaviest thing on the page.
///
/// Tapping plays it, and the row opens the app's waveform player
/// ([AudioPlayerWidget]) for as long as this recording is the one the
/// player holds; when another recording starts, this one folds back to its
/// glyph. One player for the app, so only one row is ever open.
class RecordingPlayback extends ConsumerWidget {
  const RecordingPlayback(this.audio, {super.key});

  final JournalAudio audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = audio.meta.id;
    final isActive = ref.watch(
      audioPlayerControllerProvider.select(
        (state) => state.audioNote?.meta.id == id,
      ),
    );
    if (isActive) {
      return AudioPlayerWidget(audio, key: ValueKey('recording-player-$id'));
    }

    // The time chip's own shape: a glyph and a figure in the action ink,
    // ending on the row's leading edge, so the recording reads as one quiet
    // action rather than a control panel.
    final length = formatElapsed(audio.data.duration);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DesignSystemButton(
        key: ValueKey('recording-playback-play-$id'),
        label: length,
        leadingIcon: LottiIcons.playCircled,
        variant: DesignSystemButtonVariant.tertiary,
        size: DesignSystemButtonSize.dense,
        tabularFigures: true,
        alignsLabelToLeadingEdge: true,
        semanticsLabel: '${context.messages.audioPlayerPlay}, $length',
        onPressed: () => unawaited(
          ref.read(audioPlayerControllerProvider.notifier).playAudioNote(audio),
        ),
      ),
    );
  }
}
