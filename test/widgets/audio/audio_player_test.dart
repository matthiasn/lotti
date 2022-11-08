import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlayerWidget Widget Tests - ', () {
    setUp(() {
      getIt.registerSingleton<ThemesService>(ThemesService(watch: false));
    });
    tearDown(getIt.reset);

    final mockAudioPlayerCubit = MockAudioPlayerCubit();

    final pausedState = AudioPlayerState(
      status: AudioPlayerStatus.paused,
      progress: Duration.zero,
      totalDuration: const Duration(minutes: 1),
      pausedAt: Duration.zero,
      speed: 1,
    );

    testWidgets('controls are are displayed, paused state', (tester) async {
      when(() => mockAudioPlayerCubit.stream).thenAnswer(
        (_) => Stream<AudioPlayerState>.fromIterable([pausedState]),
      );

      when(() => mockAudioPlayerCubit.state).thenAnswer(
        (_) => pausedState,
      );

      when(mockAudioPlayerCubit.play).thenAnswer((_) async {});

      when(mockAudioPlayerCubit.fwd).thenAnswer((_) async {});

      when(mockAudioPlayerCubit.rew).thenAnswer((_) async {});

      when(mockAudioPlayerCubit.close).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (_) => mockAudioPlayerCubit,
            lazy: false,
            child: const AudioPlayerWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final stopIconFinder = find.byIcon(Icons.stop);
      final playIconFinder = find.byIcon(Icons.play_arrow);
      final rewindIconFinder = find.byIcon(Icons.fast_rewind);
      final pauseIconFinder = find.byIcon(Icons.pause);
      final fwdIconFinder = find.byIcon(Icons.fast_forward);

      final normalSpeedIcon = find.text('1x');

      expect(stopIconFinder, findsOneWidget);
      expect(playIconFinder, findsOneWidget);
      expect(pauseIconFinder, findsOneWidget);
      expect(rewindIconFinder, findsOneWidget);
      expect(fwdIconFinder, findsOneWidget);
      expect(normalSpeedIcon, findsOneWidget);

      await tester.tap(playIconFinder);
      verify(mockAudioPlayerCubit.play).called(1);

      await tester.tap(fwdIconFinder);
      verify(mockAudioPlayerCubit.fwd).called(1);

      await tester.tap(rewindIconFinder);
      verify(mockAudioPlayerCubit.rew).called(1);
    });

    testWidgets('controls are are displayed, playing state', (tester) async {
      final playingState = AudioPlayerState(
        status: AudioPlayerStatus.playing,
        progress: const Duration(seconds: 15),
        totalDuration: const Duration(minutes: 1),
        pausedAt: Duration.zero,
        speed: 1,
      );

      when(() => mockAudioPlayerCubit.stream).thenAnswer(
        (_) => Stream<AudioPlayerState>.fromIterable([playingState]),
      );

      when(() => mockAudioPlayerCubit.state).thenAnswer(
        (_) => playingState,
      );

      when(mockAudioPlayerCubit.close).thenAnswer((_) async {});
      when(mockAudioPlayerCubit.stopPlay).thenAnswer((_) async {});
      when(mockAudioPlayerCubit.pause).thenAnswer((_) async {});

      when(() => mockAudioPlayerCubit.setSpeed(1.25)).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (_) => mockAudioPlayerCubit,
            lazy: false,
            child: const AudioPlayerWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final stopIconFinder = find.byIcon(Icons.stop);
      final playIconFinder = find.byIcon(Icons.play_arrow);
      final rewindIconFinder = find.byIcon(Icons.fast_rewind);
      final pauseIconFinder = find.byIcon(Icons.pause);
      final fwdIconFinder = find.byIcon(Icons.fast_forward);

      final normalSpeedIcon = find.text('1x');
      final fasterSpeedIcon = find.text('1.25x');

      expect(stopIconFinder, findsOneWidget);
      expect(playIconFinder, findsOneWidget);
      expect(pauseIconFinder, findsOneWidget);
      expect(rewindIconFinder, findsOneWidget);
      expect(fwdIconFinder, findsOneWidget);

      expect(normalSpeedIcon, findsOneWidget);
      expect(fasterSpeedIcon, findsNothing);

      await tester.tap(normalSpeedIcon);

      verify(() => mockAudioPlayerCubit.setSpeed(1.25)).called(1);

      await tester.pumpAndSettle();

      await tester.tap(pauseIconFinder);
      verify(mockAudioPlayerCubit.pause).called(1);

      await tester.tap(playIconFinder);
      verify(mockAudioPlayerCubit.play).called(1);

      await tester.tap(stopIconFinder);
      verify(mockAudioPlayerCubit.stopPlay).called(1);
    });
  });
}
