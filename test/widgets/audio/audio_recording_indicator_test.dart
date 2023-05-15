import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/audio/audio_recording_indicator.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecordingIndicator Widget Tests - ', () {
    setUp(() {
      getIt.registerSingleton<ThemesService>(ThemesService(watch: false));
    });
    tearDown(getIt.reset);

    final mockAudioRecorderCubit = MockAudioRecorderCubit();

    testWidgets('widget is displayed, tapping stops recoder', (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: Duration.zero,
        showIndicator: true,
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
            child: const Row(
              children: [
                Expanded(child: AudioRecordingIndicator()),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final stopIconFinder = find.byKey(const Key('audio_recording_indicator'));
      expect(stopIconFinder, findsOneWidget);

      await tester.tap(stopIconFinder);
      verify(mockAudioRecorderCubit.stop).called(1);
    });
  });
}
