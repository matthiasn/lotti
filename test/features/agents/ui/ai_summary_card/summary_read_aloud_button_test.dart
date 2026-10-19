import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';

import '../../../../widget_test_utils.dart';

/// The app-wide playback state, set by the test, recording what the button
/// asks of the voice.
class _Playback extends TtsPlaybackController {
  _Playback(this.initial);

  final TtsPlaybackState initial;
  final spoken = <({String sourceId, String text})>[];
  TtsModelDownloadConsent? confirmModelDownload;
  int stops = 0;

  @override
  TtsPlaybackState build() => initial;

  @override
  Future<void> speak({
    required String sourceId,
    required String text,
    String language = 'en',
    Future<bool> Function()? canPlay,
    TtsModelDownloadConsent? confirmModelDownload,
  }) async {
    spoken.add((sourceId: sourceId, text: text));
    this.confirmModelDownload = confirmModelDownload;
  }

  @override
  Future<void> stop({String? sourceId}) async => stops++;
}

void main() {
  late _Playback playback;

  Future<TtsPlayButton> pump(
    WidgetTester tester,
    TtsPlaybackState state,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const SummaryReadAloudButton(sourceId: 'task-1', text: 'Two left.'),
        overrides: [
          ttsPlaybackControllerProvider.overrideWith(
            () => playback = _Playback(state),
          ),
        ],
      ),
    );
    return tester.widget<TtsPlayButton>(find.byType(TtsPlayButton));
  }

  testWidgets('idle, it plays its own words under its own source', (
    tester,
  ) async {
    final button = await pump(tester, const TtsPlaybackState());

    expect(button.mode, TtsButtonMode.idle);
    expect(button.progress, isNull);
    button.onPlay();
    expect(playback.spoken, [(sourceId: 'task-1', text: 'Two left.')]);
  });

  testWidgets('a play asks before the voice model downloads, showing its '
      'size', (tester) async {
    final button = await pump(tester, const TtsPlaybackState());
    button.onPlay();
    final consent = playback.confirmModelDownload;
    expect(consent, isNotNull, reason: 'the model must never download unasked');

    final agreed = consent!(ttsModelByIdOrDefault(kDefaultTtsModelId));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Download the voice model?'), findsOneWidget);
    await tester.tap(find.text('Download (398.4 MB)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await agreed, isTrue);
  });

  testWidgets('another source playing leaves it idle', (tester) async {
    final button = await pump(
      tester,
      const TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'task-2',
        duration: Duration(seconds: 10),
        position: Duration(seconds: 5),
      ),
    );

    expect(button.mode, TtsButtonMode.idle);
    expect(button.progress, isNull);
  });

  for (final status in [
    TtsPlaybackStatus.downloadingModel,
    TtsPlaybackStatus.synthesizing,
  ]) {
    testWidgets('its source ${status.name} reads as preparing', (
      tester,
    ) async {
      final button = await pump(
        tester,
        TtsPlaybackState(status: status, sourceId: 'task-1'),
      );

      expect(button.mode, TtsButtonMode.preparing);
      expect(button.progress, isNull);
    });
  }

  testWidgets('its source playing reports how far it has read, and stops', (
    tester,
  ) async {
    final button = await pump(
      tester,
      const TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'task-1',
        duration: Duration(seconds: 10),
        position: Duration(seconds: 4),
      ),
    );

    expect(button.mode, TtsButtonMode.playing);
    expect(button.progress, closeTo(0.4, 1e-9));
    button.onStop();
    expect(playback.stops, 1);
  });

  testWidgets('playing before the duration is known shows no progress', (
    tester,
  ) async {
    final button = await pump(
      tester,
      const TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'task-1',
      ),
    );

    expect(button.mode, TtsButtonMode.playing);
    expect(button.progress, isNull);
  });
}
