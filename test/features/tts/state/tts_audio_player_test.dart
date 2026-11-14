import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/state/tts_audio_focus.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:media_kit/media_kit.dart';
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
    when(() => player.platform).thenReturn(null);
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

  test('a clip is opened from its start, or from where an earlier open '
      'of it stopped', () async {
    final opened = <Media>[];
    when(() => player.open(any(), play: any(named: 'play'))).thenAnswer((
      invocation,
    ) async {
      opened.add(invocation.positionalArguments.single as Media);
    });
    final audio = build();

    await audio.play(File('/tmp/clip.wav'), speed: 1);
    await audio.play(
      File('/tmp/clip.wav'),
      speed: 1,
      from: const Duration(milliseconds: 1900),
    );

    expect(opened.first.start, isNull);
    expect(opened.last.start, const Duration(milliseconds: 1900));
    expect(opened.last.uri, endsWith('/tmp/clip.wav'));
  });

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

  test('every clip reaches the output resampled to 48 kHz, so a 24 kHz '
      'cloud voice is never played at twice its speed', () async {
    final native = MockNativePlayer();
    when(() => player.platform).thenReturn(native);
    when(() => native.setProperty(any(), any())).thenAnswer((_) async {});

    await build().play(File('/tmp/tts.wav'), speed: 1);

    verifyInOrder([
      () => native.setProperty('audio-samplerate', '48000'),
      () => player.open(any(), play: false),
      () => player.play(),
    ]);
  });

  test('a stop while the output rate is set prevents late playback', () async {
    final native = MockNativePlayer();
    final pending = Completer<void>();
    when(() => player.platform).thenReturn(native);
    when(() => native.setProperty(any(), any())).thenAnswer(
      (_) => pending.future,
    );
    final audio = build();

    final play = audio.play(File('/tmp/tts.wav'), speed: 1);
    await audio.stop();
    pending.complete();
    await play;

    verifyNever(() => player.open(any(), play: any(named: 'play')));
    verifyNever(() => player.play());
  });

  test('setSpeed changes the rate of the clip that is playing', () async {
    await build().setSpeed(1.75);
    verify(() => player.setRate(1.75)).called(1);
    verifyNever(() => player.open(any(), play: any(named: 'play')));
  });

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

    test('settled is the focus letting go', () async {
      final letting = Completer<void>();
      focus.settling = letting.future;
      var settled = false;
      unawaited(withFocus().settled.then((_) => settled = true));
      await pumpEventQueue();
      expect(settled, isFalse);
      letting.complete();
      await pumpEventQueue();
      expect(settled, isTrue);
    });

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

    test('a stop while the focus is being taken never plays, and its own '
        'release gives the claim back', () async {
      final taking = Completer<void>();
      focus.acquiring = taking.future;
      final audio = withFocus();
      final play = audio.play(File('/tmp/tts.wav'), speed: 1);
      await pumpEventQueue();
      await audio.stop();
      taking.complete();
      await play;
      verifyNever(() => player.play());
      expect(focus.calls, ['acquire', 'release']);
    });

    // The regression: the stop queued its release only after the native stop
    // returned, so a play started meanwhile claimed first, and the stale
    // release then deactivated the new clip's session.
    test("a stop's release is queued before a play started during the native "
        'stop claims', () async {
      final stopping = Completer<void>();
      when(() => player.stop()).thenAnswer((_) => stopping.future);
      final audio = withFocus();
      final stop = audio.stop();
      final play = audio.play(File('/tmp/b.wav'), speed: 1);
      await pumpEventQueue();
      stopping.complete();
      await Future.wait([stop, play]);
      expect(focus.calls, ['release', 'acquire']);
    });

    // The regression: a play cancelled while taking the focus released it
    // once more when the claim came back — after a newer play had claimed
    // it, deactivating the newer play's session.
    test(
      'a cancelled play never releases the focus a newer play holds',
      () async {
        final taking = Completer<void>();
        focus.acquiring = taking.future;
        final audio = withFocus();
        final first = audio.play(File('/tmp/a.wav'), speed: 1);
        await pumpEventQueue();
        await audio.stop();
        focus.acquiring = null;
        await audio.play(File('/tmp/b.wav'), speed: 1);
        taking.complete();
        await first;
        expect(focus.calls, ['acquire', 'release', 'acquire']);
        verify(() => player.play()).called(1);
      },
    );

    test('is given back, and the error passed on, when the clip cannot '
        'start', () async {
      when(() => player.play()).thenThrow(StateError('no output'));
      await expectLater(
        withFocus().play(File('/tmp/tts.wav'), speed: 1),
        throwsStateError,
      );
      expect(focus.calls, ['acquire', 'release']);
    });

    test(
      'is given back even when the player fails to stop or dispose',
      () async {
        when(() => player.stop()).thenThrow(StateError('stuck'));
        when(() => player.dispose()).thenThrow(StateError('gone'));
        final audio = withFocus();
        await expectLater(audio.stop(), throwsStateError);
        await expectLater(audio.dispose(), throwsStateError);
        expect(focus.calls, ['release', 'release']);
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
  Future<void>? settling;

  @override
  Future<void> get settled => settling ?? Future<void>.value();

  @override
  Future<void> acquire() async {
    calls.add('acquire');
    await acquiring;
  }

  @override
  Future<void> release() async => calls.add('release');
}
