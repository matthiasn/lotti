import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/audio/audio_recorder.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecorderWidget Widget Tests - ', () {
    setUp(() {
      getIt.registerSingleton<ThemesService>(ThemesService(watch: false));
    });
    tearDown(getIt.reset);

    final mockAudioRecorderCubit = MockAudioRecorderCubit();

    testWidgets('controls are are displayed, stop is tappable', (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: Duration.zero,
      );

      when(() => mockAudioRecorderCubit.stream).thenAnswer(
        (_) => Stream<AudioRecorderState>.fromIterable([recordingState]),
      );

      when(() => mockAudioRecorderCubit.state).thenAnswer(
        (_) => recordingState,
      );

      when(mockAudioRecorderCubit.close).thenAnswer((_) async {});

      when(mockAudioRecorderCubit.stop).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockAudioRecorderCubit,
            lazy: false,
            child: const AudioRecorderWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final micIconFinder = find.byIcon(Icons.mic_rounded);
      expect(micIconFinder, findsOneWidget);

      final stopIconFinder = find.byIcon(Icons.stop);
      expect(stopIconFinder, findsOneWidget);

      await tester.tap(stopIconFinder);
      verify(mockAudioRecorderCubit.stop).called(1);
    });

    testWidgets('controls are are displayed, stop is tappable (loud)',
        (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 140,
        progress: Duration.zero,
      );

      when(() => mockAudioRecorderCubit.stream).thenAnswer(
        (_) => Stream<AudioRecorderState>.fromIterable([recordingState]),
      );

      when(() => mockAudioRecorderCubit.state).thenAnswer(
        (_) => recordingState,
      );

      when(mockAudioRecorderCubit.close).thenAnswer((_) async {});

      when(mockAudioRecorderCubit.stop).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockAudioRecorderCubit,
            lazy: false,
            child: const AudioRecorderWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final micIconFinder = find.byIcon(Icons.mic_rounded);
      expect(micIconFinder, findsOneWidget);

      final stopIconFinder = find.byIcon(Icons.stop);
      expect(stopIconFinder, findsOneWidget);

      await tester.tap(stopIconFinder);
      verify(mockAudioRecorderCubit.stop).called(1);
    });

    testWidgets('controls are are displayed, stop is tappable (semi-loud)',
        (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 110,
        progress: Duration.zero,
      );

      when(() => mockAudioRecorderCubit.stream).thenAnswer(
        (_) => Stream<AudioRecorderState>.fromIterable([recordingState]),
      );

      when(() => mockAudioRecorderCubit.state).thenAnswer(
        (_) => recordingState,
      );

      when(mockAudioRecorderCubit.close).thenAnswer((_) async {});

      when(mockAudioRecorderCubit.stop).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockAudioRecorderCubit,
            lazy: false,
            child: const AudioRecorderWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final micIconFinder = find.byIcon(Icons.mic_rounded);
      expect(micIconFinder, findsOneWidget);

      final stopIconFinder = find.byIcon(Icons.stop);
      expect(stopIconFinder, findsOneWidget);

      await tester.tap(stopIconFinder);
      verify(mockAudioRecorderCubit.stop).called(1);
    });

    testWidgets('controls are are displayed, record is tappable',
        (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        decibels: 110,
        progress: Duration.zero,
      );

      when(() => mockAudioRecorderCubit.stream).thenAnswer(
        (_) => Stream<AudioRecorderState>.fromIterable([recordingState]),
      );

      when(() => mockAudioRecorderCubit.state).thenAnswer(
        (_) => recordingState,
      );

      when(mockAudioRecorderCubit.close).thenAnswer((_) async {});

      when(mockAudioRecorderCubit.record).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockAudioRecorderCubit,
            lazy: false,
            child: const AudioRecorderWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final micIconFinder = find.byIcon(Icons.mic_rounded);
      expect(micIconFinder, findsOneWidget);

      final stopIconFinder = find.byIcon(Icons.stop);
      expect(stopIconFinder, findsOneWidget);

      await tester.tap(micIconFinder);
      verify(mockAudioRecorderCubit.record).called(1);
    });
  });
}
