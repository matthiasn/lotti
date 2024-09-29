import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/recorder_cubit.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/audio_recording_indicator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecordingIndicator Widget Tests - ', () {
    setUp(() {});
    tearDown(getIt.reset);

    final mockAudioRecorderCubit = MockAudioRecorderCubit();
    final mockNavService = MockNavService();

    getIt
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<SettingsDb>(SettingsDb());

    when(mockNavService.isTasksTabActive).thenAnswer(
      (_) => false,
    );

    testWidgets('widget is displayed, tapping stops recorder', (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: Duration.zero,
        showIndicator: true,
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
            child: const Row(
              children: [
                Expanded(child: AudioRecordingIndicator()),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final indicatorFinder =
          find.byKey(const Key('audio_recording_indicator'));
      expect(indicatorFinder, findsOneWidget);

      await tester.tap(indicatorFinder);
      verify(() => mockNavService.beamToNamed(any())).called(1);
    });
  });
}
