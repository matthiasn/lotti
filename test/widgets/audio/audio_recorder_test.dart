import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech/state/recorder_cubit.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/audio_recorder.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecorderWidget Widget Tests - ', () {
    final mockJournalDb = MockJournalDb();

    setUp(() async {
      getIt.registerSingleton<JournalDb>(mockJournalDb);

      when(
        () => mockJournalDb.getConfigFlag(any()),
      ).thenAnswer((_) async => true);
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
    });
    tearDown(getIt.reset);

    final mockAudioRecorderCubit = MockAudioRecorderCubit();

    testWidgets('controls are are displayed, stop is tappable', (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: Duration.zero,
        showIndicator: false,
        language: 'en',
      );

      when(() => mockAudioRecorderCubit.stream).thenAnswer(
        (_) => Stream<AudioRecorderState>.fromIterable([recordingState]),
      );

      when(() => mockAudioRecorderCubit.state).thenAnswer(
        (_) => recordingState,
      );

      when(mockAudioRecorderCubit.close).thenAnswer((_) async {});

      when(mockAudioRecorderCubit.stop).thenAnswer((_) async => 'entry-id');

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

      final micIconFinder = find.byKey(const Key('micIcon'));
      expect(micIconFinder, findsOneWidget);

      final stopIconFinder = find.byKey(const Key('stopIcon'));
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
        showIndicator: false,
        language: 'en',
      );

      when(() => mockAudioRecorderCubit.stream).thenAnswer(
        (_) => Stream<AudioRecorderState>.fromIterable([recordingState]),
      );

      when(() => mockAudioRecorderCubit.state).thenAnswer(
        (_) => recordingState,
      );

      when(mockAudioRecorderCubit.close).thenAnswer((_) async {});

      when(mockAudioRecorderCubit.stop).thenAnswer((_) async => 'entry-id');

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

      final micIconFinder = find.byKey(const Key('micIcon'));
      expect(micIconFinder, findsOneWidget);

      final stopIconFinder = find.byKey(const Key('stopIcon'));
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
        showIndicator: false,
        language: 'en',
      );

      when(() => mockAudioRecorderCubit.stream).thenAnswer(
        (_) => Stream<AudioRecorderState>.fromIterable([recordingState]),
      );

      when(() => mockAudioRecorderCubit.state).thenAnswer(
        (_) => recordingState,
      );

      when(mockAudioRecorderCubit.close).thenAnswer((_) async {});

      when(mockAudioRecorderCubit.stop).thenAnswer((_) async => 'entry-id');

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

      final micIconFinder = find.byKey(const Key('micIcon'));
      expect(micIconFinder, findsOneWidget);

      final stopIconFinder = find.byKey(const Key('stopIcon'));
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
        showIndicator: false,
        language: 'en',
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

      final micIconFinder = find.byKey(const Key('micIcon'));
      expect(micIconFinder, findsOneWidget);

      final stopIconFinder = find.byKey(const Key('stopIcon'));
      expect(stopIconFinder, findsOneWidget);

      await tester.tap(micIconFinder);
      verify(mockAudioRecorderCubit.record).called(1);
    });
  });
}
