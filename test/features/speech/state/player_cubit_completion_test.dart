import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockLoggingService extends Mock implements LoggingService {}

class _TestAudioPlayerCubit extends AudioPlayerCubit {
  _TestAudioPlayerCubit({
    required Player super.player,
    required LoggingService super.loggingService,
    required super.completionDelay,
  });

  void emitForTest(AudioPlayerState state) {
    emit(state);
  }
}

void main() {
  late _MockPlayer mockPlayer;
  late _MockLoggingService loggingService;
  late StreamController<Duration> positionController;
  late StreamController<Duration> bufferController;
  late StreamController<bool> completedController;
  late PlayerStream playerStream;
  late PlayerState playerState;
  const completionDelay = Duration(milliseconds: 50);

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockPlayer = _MockPlayer();
    loggingService = _MockLoggingService();
    positionController = StreamController<Duration>.broadcast();
    bufferController = StreamController<Duration>.broadcast();
    completedController = StreamController<bool>.broadcast();

    playerStream = PlayerStream(
      const Stream<Playlist>.empty(),
      const Stream<bool>.empty(),
      completedController.stream,
      positionController.stream,
      const Stream<Duration>.empty(),
      const Stream<double>.empty(),
      const Stream<double>.empty(),
      const Stream<double>.empty(),
      const Stream<bool>.empty(),
      const Stream<double>.empty(),
      bufferController.stream,
      const Stream<PlaylistMode>.empty(),
      const Stream<bool>.empty(),
      const Stream<AudioParams>.empty(),
      const Stream<VideoParams>.empty(),
      const Stream<double?>.empty(),
      const Stream<AudioDevice>.empty(),
      const Stream<List<AudioDevice>>.empty(),
      const Stream<Track>.empty(),
      const Stream<Tracks>.empty(),
      const Stream<int?>.empty(),
      const Stream<int?>.empty(),
      const Stream<List<String>>.empty(),
      const Stream<PlayerLog>.empty(),
      const Stream<String>.empty(),
    );

    playerState = const PlayerState(
      duration: Duration(minutes: 1),
    );

    when(() => mockPlayer.stream).thenReturn(playerStream);
    when(() => mockPlayer.state).thenReturn(playerState);
    when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
    when(() => mockPlayer.dispose()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await positionController.close();
    await bufferController.close();
    await completedController.close();
  });

  JournalAudio createAudio({Duration duration = const Duration(seconds: 30)}) {
    final recordedAt = DateTime(2024, 1, 1, 8);
    return JournalAudio(
      meta: Metadata(
        id: 'audio-123',
        createdAt: recordedAt,
        updatedAt: recordedAt,
        dateFrom: recordedAt,
        dateTo: recordedAt.add(duration),
      ),
      data: AudioData(
        dateFrom: recordedAt,
        dateTo: recordedAt.add(duration),
        audioFile: 'clip.m4a',
        audioDirectory:
            '/audio/${recordedAt.year}-${recordedAt.month.toString().padLeft(2, '0')}-${recordedAt.day.toString().padLeft(2, '0')}/',
        duration: duration,
      ),
      entryText: const EntryText(plainText: 'Sample'),
    );
  }

  _TestAudioPlayerCubit createCubit() {
    final cubit = _TestAudioPlayerCubit(
      player: mockPlayer,
      loggingService: loggingService,
      completionDelay: completionDelay,
    );
    addTearDown(() async {
      if (!cubit.isClosed) {
        await cubit.close();
      }
    });
    return cubit;
  }

  group('AudioPlayerCubit completion handling', () {
    test('creates completion subscription in constructor', () {
      final cubit = createCubit();

      expect(cubit.completedSubscription, isNotNull);
      expect(completedController.hasListener, isTrue);
    });

    test('cancels completion subscription on close', () async {
      final cubit = createCubit();

      await cubit.close();

      expect(completedController.hasListener, isFalse);
      verify(() => mockPlayer.dispose()).called(1);
    });

    test('does not duplicate completion subscription on multiple play calls',
        () async {
      final cubit = createCubit();
      final initialSubscription = cubit.completedSubscription;

      await cubit.play();
      await cubit.play();

      expect(cubit.completedSubscription, same(initialSubscription));
      verify(() => mockPlayer.setRate(1)).called(2);
      verify(() => mockPlayer.play()).called(2);
    });

    test('ignores completion when audioNote is null', () {
      fakeAsync((async) {
        final cubit = createCubit();
        const total = Duration(seconds: 10);
        cubit
          ..emitForTest(
            AudioPlayerState(
              status: AudioPlayerStatus.playing,
              totalDuration: total,
              progress: const Duration(seconds: 3),
              pausedAt: const Duration(seconds: 3),
              speed: 1,
              showTranscriptsList: false,
            ),
          )
          ..handleCompletedForTest(isCompleted: true);
        async.elapse(completionDelay);

        expect(cubit.state.progress, const Duration(seconds: 3));
      });
    });

    test('completion updates progress after configured delay', () {
      fakeAsync((async) {
        final cubit = createCubit();
        final audio = createAudio(duration: const Duration(seconds: 12));

        cubit
          ..emitForTest(
            AudioPlayerState(
              status: AudioPlayerStatus.playing,
              totalDuration: audio.data.duration,
              progress: Duration.zero,
              pausedAt: Duration.zero,
              speed: 1,
              showTranscriptsList: false,
              audioNote: audio,
            ),
          )
          ..handleCompletedForTest(isCompleted: true);
        async.elapse(const Duration(milliseconds: 49));
        expect(cubit.state.progress, Duration.zero);

        async.elapse(const Duration(milliseconds: 1));
        expect(cubit.state.progress, audio.data.duration);
      });
    });

    test('completion delay respects progress update order', () {
      fakeAsync((async) {
        final cubit = createCubit();
        final audio = createAudio(duration: const Duration(seconds: 20));
        cubit
          ..emitForTest(
            AudioPlayerState(
              status: AudioPlayerStatus.playing,
              totalDuration: audio.data.duration,
              progress: const Duration(seconds: 5),
              pausedAt: const Duration(seconds: 5),
              speed: 1,
              showTranscriptsList: false,
              audioNote: audio,
            ),
          )
          ..handleCompletedForTest(isCompleted: true);
        async.elapse(completionDelay);

        expect(cubit.state.progress, audio.data.duration);
      });
    });

    test('completion false does not emit progress update', () {
      final cubit = createCubit();
      final audio = createAudio();
      cubit
        ..emitForTest(
          AudioPlayerState(
            status: AudioPlayerStatus.playing,
            totalDuration: audio.data.duration,
            progress: const Duration(seconds: 4),
            pausedAt: const Duration(seconds: 4),
            speed: 1,
            showTranscriptsList: false,
            audioNote: audio,
          ),
        )
        ..handleCompletedForTest(isCompleted: false);

      expect(cubit.state.progress, const Duration(seconds: 4));
    });
  });
}
