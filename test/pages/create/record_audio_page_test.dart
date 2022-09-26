import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/create/record_audio_page.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecorderWidget Widget Tests - ', () {
    setUp(() {
      getIt.registerSingleton<ThemesService>(ThemesService(watch: false));
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
            child: const RecordAudioPage(),
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
  });
}
