import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/state/tts_audio_focus.dart';
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

  for (final pauseAt in ['open', 'rate']) {
    test('stop during $pauseAt prevents late native playback', () async {
      final pending = Completer<void>();
      final entered = Completer<void>();
      if (pauseAt == 'open') {
        when(() => player.open(any(), play: any(named: 'play'))).thenAnswer((
          _,
        ) {
          entered.complete();
          return pending.future;
        });
      } else {
        when(() => player.setRate(any())).thenAnswer((_) {
          entered.complete();
          return pending.future;
        });
      }
      final audio = build();
      final play = audio.play(File('/tmp/private-chat.wav'), speed: 1);
      await entered.future;
      await audio.stop();
      pending.complete();
      await play;
      verifyNever(() => player.play());
      verify(() => player.stop()).called(1);
    });
  }

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

  group('the audio focus', () {
    late _RecordingFocus focus;

    setUp(() => focus = _RecordingFocus());

    MediaKitTtsAudioPlayer withFocus() => MediaKitTtsAudioPlayer(player, focus);

    test('is taken after the clip is ready and before it plays', () async {
      when(() => player.play()).thenAnswer((_) async {
        focus.calls.add('play');
      });
      await withFocus().play(File('/tmp/tts.wav'), speed: 1);
      expect(focus.calls, ['acquire', 'play']);
    });

    test('is given back when the voice is stopped', () async {
      final audio = withFocus();
      await audio.play(File('/tmp/tts.wav'), speed: 1);
      await audio.stop();
      expect(focus.calls, ['acquire', 'release']);
    });

    test('is given back when the clip plays to its end, not before', () async {
      withFocus();
      completedController.add(false);
      await pumpEventQueue();
      expect(focus.calls, isEmpty);
      completedController.add(true);
      await pumpEventQueue();
      expect(focus.calls, ['release']);
    });

    test(
      'a stop while the focus is being taken gives it back, never plays',
      () async {
        final taking = Completer<void>();
        focus.acquiring = taking.future;
        final audio = withFocus();
        final play = audio.play(File('/tmp/tts.wav'), speed: 1);
        await pumpEventQueue();
        await audio.stop();
        taking.complete();
        await play;
        verifyNever(() => player.play());
        expect(focus.calls, ['acquire', 'release', 'release']);
      },
    );

    test('is given back on dispose, and the end of a clip after it is not '
        'heard', () async {
      final audio = withFocus();
      await audio.dispose();
      completedController.add(true);
      await pumpEventQueue();
      expect(focus.calls, ['release']);
    });
  });
}

/// Records when the player takes and gives back the focus; [acquiring]
/// holds the taking open when a test needs it to.
class _RecordingFocus implements TtsAudioFocus {
  final calls = <String>[];
  Future<void>? acquiring;

  @override
  Future<void> acquire() async {
    calls.add('acquire');
    await acquiring;
  }

  @override
  Future<void> release() async => calls.add('release');
}
