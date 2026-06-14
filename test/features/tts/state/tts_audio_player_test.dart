import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockPlayer player;
  late MockPlayerStream stream;
  late StreamController<Duration> positionController;
  late StreamController<Duration> durationController;
  late StreamController<bool> completedController;

  setUpAll(() => registerFallbackValue(FakePlayable()));

  setUp(() {
    player = MockPlayer();
    stream = MockPlayerStream();
    positionController = StreamController<Duration>.broadcast();
    durationController = StreamController<Duration>.broadcast();
    completedController = StreamController<bool>.broadcast();

    when(() => player.stream).thenReturn(stream);
    when(() => stream.position).thenAnswer((_) => positionController.stream);
    when(() => stream.duration).thenAnswer((_) => durationController.stream);
    when(() => stream.completed).thenAnswer((_) => completedController.stream);
    when(
      () => player.open(any(), play: any(named: 'play')),
    ).thenAnswer((_) async {});
    when(() => player.setRate(any())).thenAnswer((_) async {});
    when(() => player.play()).thenAnswer((_) async {});
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await positionController.close();
    await durationController.close();
    await completedController.close();
  });

  MediaKitTtsAudioPlayer build() => MediaKitTtsAudioPlayer(player);

  test(
    'play opens the file without autoplay, sets the rate, then plays',
    () async {
      await build().play(File('/tmp/tts.wav'), speed: 1.5);

      verifyInOrder([
        () => player.open(any(), play: false),
        () => player.setRate(1.5),
        () => player.play(),
      ]);
    },
  );

  test('stop stops the underlying player', () async {
    await build().stop();
    verify(() => player.stop()).called(1);
  });

  test('position and duration streams forward the player streams', () async {
    final audio = build();
    final position = expectLater(
      audio.positionStream,
      emits(const Duration(seconds: 2)),
    );
    final duration = expectLater(
      audio.durationStream,
      emits(const Duration(seconds: 9)),
    );
    positionController.add(const Duration(seconds: 2));
    durationController.add(const Duration(seconds: 9));
    await position;
    await duration;
  });

  test('completedStream emits only when playback actually completes', () async {
    final audio = build();
    // `false` updates are filtered out; only a real completion surfaces (void).
    final completed = expectLater(audio.completedStream, emits(null));
    completedController
      ..add(false)
      ..add(true);
    await completed;
  });

  test('dispose disposes the underlying player', () async {
    await build().dispose();
    verify(() => player.dispose()).called(1);
  });
}
