import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';
import 'package:lotti/features/tts/ui/widgets/tts_source_play_button.dart';

import '../../../../widget_test_utils.dart';

class _Playback extends TtsPlaybackController {
  _Playback(this.initial);

  final TtsPlaybackState initial;
  int stops = 0;

  @override
  TtsPlaybackState build() => initial;

  @override
  Future<void> stop({String? sourceId}) async => stops++;
}

void main() {
  late _Playback playback;
  late List<TtsPlaybackController> played;

  Future<TtsPlayButton> pump(
    WidgetTester tester,
    TtsPlaybackState state,
  ) async {
    played = [];
    await tester.pumpWidget(
      makeTestableWidget(
        TtsSourcePlayButton(sourceId: 'mine', onPlay: played.add),
        overrides: [
          ttsPlaybackControllerProvider.overrideWith(
            () => playback = _Playback(state),
          ),
        ],
      ),
    );
    return tester.widget<TtsPlayButton>(find.byType(TtsPlayButton));
  }

  testWidgets('idle, a tap hands the playback controller to onPlay', (
    tester,
  ) async {
    final button = await pump(tester, const TtsPlaybackState());
    expect(button.mode, TtsButtonMode.idle);
    button.onPlay();
    expect(played, [playback]);
  });

  testWidgets('its own utterance shows progress and a tap stops it', (
    tester,
  ) async {
    final button = await pump(
      tester,
      const TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'mine',
        duration: Duration(seconds: 8),
        position: Duration(seconds: 2),
      ),
    );
    expect(button.mode, TtsButtonMode.playing);
    expect(button.progress, 0.25);
    button.onStop();
    expect(playback.stops, 1);
  });

  testWidgets("another source's utterance leaves it idle", (tester) async {
    final button = await pump(
      tester,
      const TtsPlaybackState(
        status: TtsPlaybackStatus.synthesizing,
        sourceId: 'theirs',
      ),
    );
    expect(button.mode, TtsButtonMode.idle);
    expect(button.progress, isNull);
  });

  testWidgets('preparing its own utterance has no progress yet', (
    tester,
  ) async {
    final button = await pump(
      tester,
      const TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'mine',
      ),
    );
    // Playing before the duration is known: no arc to draw.
    expect(button.progress, isNull);
  });
}
