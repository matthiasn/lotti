import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_player_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/features/speech/ui/widgets/recording_playback.dart';
import 'package:lotti/providers/audio_player_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// Holds a fixed state and records what the widget asked it to play.
class _FixedPlayer extends AudioPlayerController {
  _FixedPlayer(this._fixed);

  final AudioPlayerState _fixed;
  final played = <String>[];

  @override
  AudioPlayerState build() => _fixed;

  @override
  Future<void> playAudioNote(JournalAudio audioNote) async {
    played.add(audioNote.meta.id);
  }
}

void main() {
  final at = DateTime(2026, 8, 5, 9);
  JournalAudio recording(String id) => JournalAudio(
    meta: Metadata(
      id: id,
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at.add(const Duration(seconds: 38)),
    ),
    data: AudioData(
      dateFrom: at,
      dateTo: at.add(const Duration(seconds: 38)),
      audioFile: '$id.m4a',
      audioDirectory: '/audio/',
      duration: const Duration(seconds: 38),
    ),
  );

  Future<_FixedPlayer> pump(
    WidgetTester tester,
    AudioPlayerState state,
  ) async {
    final player = _FixedPlayer(state);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        RecordingPlayback(recording('a1')),
        overrides: [audioPlayerControllerProvider.overrideWith(() => player)],
      ),
    );
    await tester.pump();
    return player;
  }

  testWidgets('closed, a recording offers one light action — Play audio, '
      'its length in what a screen reader hears — and no player', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const AudioPlayerState());

    final play = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('recording-playback-play-a1')),
    );
    expect(play.label, 'Play audio');
    expect(play.leadingIcon, LottiIcons.playCircled);
    expect(play.variant, DesignSystemButtonVariant.tertiary);
    expect(play.size, DesignSystemButtonSize.small);
    expect(play.semanticsLabel, 'Play audio, 00:38');
    expect(find.byType(AudioPlayerWidget), findsNothing);
    semantics.dispose();
  });

  testWidgets('tapping plays this recording', (tester) async {
    final player = await pump(tester, const AudioPlayerState());

    await tester.tap(find.byKey(const ValueKey('recording-playback-play-a1')));
    await tester.pump();

    expect(player.played, ['a1']);
  });

  testWidgets('while it is the recording the player holds, the row opens to '
      'the waveform player', (tester) async {
    for (final status in [
      AudioPlayerStatus.playing,
      AudioPlayerStatus.paused,
    ]) {
      await pump(
        tester,
        AudioPlayerState(status: status, audioNote: recording('a1')),
      );
      expect(
        find.byKey(const ValueKey('recording-player-a1')),
        findsOneWidget,
        reason: '$status',
      );
      expect(
        find.byKey(const ValueKey('recording-playback-play-a1')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a finished recording, or another one playing, folds back to '
      'the play action', (tester) async {
    for (final state in [
      AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        audioNote: recording('a1'),
      ),
      AudioPlayerState(
        status: AudioPlayerStatus.playing,
        audioNote: recording('other'),
      ),
    ]) {
      await pump(tester, state);
      expect(find.byType(AudioPlayerWidget), findsNothing);
      expect(
        find.byKey(const ValueKey('recording-playback-play-a1')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
