import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(FakeJournalAudio());

  group('AudioPlayerWidget Widget Tests - ', () {
    setUp(() {});
    tearDown(getIt.reset);

    final mockAudioPlayerCubit = MockAudioPlayerCubit();

    final pausedState = AudioPlayerState(
      status: AudioPlayerStatus.paused,
      progress: Duration.zero,
      totalDuration: const Duration(minutes: 1),
      pausedAt: Duration.zero,
      speed: 1,
      audioNote: testAudioEntry,
      showTranscriptsList: false,
    );

    testWidgets('controls are are displayed, paused state', skip: true,
        (tester) async {
      when(() => mockAudioPlayerCubit.stream).thenAnswer(
        (_) => Stream<AudioPlayerState>.fromIterable([pausedState]),
      );

      when(() => mockAudioPlayerCubit.state).thenAnswer(
        (_) => pausedState,
      );

      when(() => mockAudioPlayerCubit.setAudioNote(any()))
          .thenAnswer((_) async {});

      when(mockAudioPlayerCubit.play).thenAnswer((_) async {});

      when(mockAudioPlayerCubit.close).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (_) => mockAudioPlayerCubit,
            lazy: false,
            child: AudioPlayerWidget(pausedState.audioNote!),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final playIconFinder = find.byIcon(Icons.play_arrow_rounded);
      final pauseIconFinder = find.byIcon(Icons.pause_rounded);

      final normalSpeedIcon = find.text('1x');

      expect(playIconFinder, findsOneWidget);
      expect(pauseIconFinder, findsOneWidget);
      expect(normalSpeedIcon, findsOneWidget);

      await tester.tap(playIconFinder);
      verify(mockAudioPlayerCubit.play).called(1);
    });

    testWidgets('controls are are displayed, playing state', skip: true,
        (tester) async {
      final playingState = AudioPlayerState(
        status: AudioPlayerStatus.playing,
        progress: const Duration(seconds: 15),
        totalDuration: const Duration(minutes: 1),
        pausedAt: Duration.zero,
        speed: 1,
        showTranscriptsList: false,
        audioNote: testAudioEntry,
      );

      when(() => mockAudioPlayerCubit.stream).thenAnswer(
        (_) => Stream<AudioPlayerState>.fromIterable([playingState]),
      );

      when(() => mockAudioPlayerCubit.state).thenAnswer(
        (_) => playingState,
      );

      when(() => mockAudioPlayerCubit.setAudioNote(any()))
          .thenAnswer((_) async {});

      when(mockAudioPlayerCubit.close).thenAnswer((_) async {});
      when(mockAudioPlayerCubit.pause).thenAnswer((_) async {});

      when(() => mockAudioPlayerCubit.setSpeed(1.25)).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (_) => mockAudioPlayerCubit,
            lazy: false,
            child: AudioPlayerWidget(playingState.audioNote!),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final playIconFinder = find.byIcon(Icons.play_arrow_rounded);
      final pauseIconFinder = find.byIcon(Icons.pause_rounded);

      final normalSpeedIcon = find.text('1x');
      final fasterSpeedIcon = find.text('1.25x');

      expect(playIconFinder, findsOneWidget);
      expect(pauseIconFinder, findsOneWidget);

      expect(normalSpeedIcon, findsOneWidget);
      expect(fasterSpeedIcon, findsNothing);

      await tester.tap(normalSpeedIcon);

      verify(() => mockAudioPlayerCubit.setSpeed(1.25)).called(1);

      await tester.pumpAndSettle();

      await tester.tap(pauseIconFinder);
      verify(mockAudioPlayerCubit.pause).called(1);

      await tester.tap(playIconFinder);
      verify(mockAudioPlayerCubit.play).called(1);
    });

    testWidgets('controls are are displayed, playing state', skip: true,
        (tester) async {
      final playingState = AudioPlayerState(
        status: AudioPlayerStatus.playing,
        progress: const Duration(seconds: 15),
        totalDuration: const Duration(minutes: 1),
        pausedAt: Duration.zero,
        speed: 1,
        showTranscriptsList: true,
        audioNote: testAudioEntryWithTranscripts,
      );

      when(() => mockAudioPlayerCubit.stream).thenAnswer(
        (_) => Stream<AudioPlayerState>.fromIterable([playingState]),
      );

      when(() => mockAudioPlayerCubit.state).thenAnswer(
        (_) => playingState,
      );

      when(() => mockAudioPlayerCubit.setAudioNote(any()))
          .thenAnswer((_) async {});

      when(mockAudioPlayerCubit.close).thenAnswer((_) async {});
      when(mockAudioPlayerCubit.pause).thenAnswer((_) async {});

      when(() => mockAudioPlayerCubit.setSpeed(1.25)).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (_) => mockAudioPlayerCubit,
            lazy: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: AudioPlayerWidget(playingState.audioNote!),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final showIcon = find.byIcon(Icons.keyboard_double_arrow_down_outlined);
      final hideIcon = find.byIcon(Icons.keyboard_double_arrow_up_outlined);

      expect(find.text('whisper-v1.4.0,  ggml-small.bin'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('transcript'), findsNothing);

      expect(showIcon, findsOneWidget);

      await tester.tap(showIcon);
      await tester.pumpAndSettle();

      expect(find.text('transcript'), findsOneWidget);

      await tester.tap(hideIcon);
      await tester.pumpAndSettle();

      expect(find.text('transcript'), findsNothing);
    });
  });
}
