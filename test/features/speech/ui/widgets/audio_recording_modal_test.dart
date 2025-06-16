import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech/state/recorder_cubit.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/audio_recording_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecordingModalContent Tests', () {
    late MockAudioRecorderCubit mockRecorderCubit;
    late MockJournalDb mockJournalDb;
    late MockNavService mockNavService;

    setUp(() {
      mockRecorderCubit = MockAudioRecorderCubit();
      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);
      when(() => mockNavService.beamBack()).thenReturn(null);
      when(() => mockRecorderCubit.close()).thenAnswer((_) async {});
    });

    tearDown(getIt.reset);

    Widget makeTestableWidget({
      String? linkedId,
      String? categoryId,
    }) {
      return ProviderScope(
        child: makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockRecorderCubit,
            child: AudioRecordingModalContent(
              linkedId: linkedId,
              categoryId: categoryId,
            ),
          ),
        ),
      );
    }

    testWidgets('displays VU meter with correct size', (tester) async {
      final initialState = AudioRecorderState(
        status: AudioRecorderStatus.initialized,
        decibels: 0,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(initialState);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(initialState),
      );

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AnalogVuMeter), findsOneWidget);

      final vuMeter = tester.widget<AnalogVuMeter>(
        find.byType(AnalogVuMeter),
      );
      expect(vuMeter.size, 400);
    });

    testWidgets('displays duration in correct format', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: const Duration(minutes: 1, seconds: 23),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(state);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(state),
      );

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Duration should be formatted as 0:01:23
      expect(find.text('0:01:23'), findsOneWidget);
    });

    testWidgets('shows record button when not recording', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.initialized,
        decibels: 0,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(state);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(state),
      );
      when(() => mockRecorderCubit.record(linkedId: any(named: 'linkedId')))
          .thenAnswer((_) async {});

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('RECORD'), findsOneWidget);
      expect(find.text('STOP'), findsNothing);

      // Tap record button
      await tester.tap(find.text('RECORD'));
      await tester.pump();

      verify(() => mockRecorderCubit.record()).called(1);
    });

    testWidgets('shows stop button when recording', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: const Duration(seconds: 5),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(state);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(state),
      );
      when(() => mockRecorderCubit.stop()).thenAnswer((_) async => 'test-id');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('STOP'), findsOneWidget);
      expect(find.text('RECORD'), findsNothing);
    });

    testWidgets('displays language selector with correct options',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.initialized,
        decibels: 0,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: '',
      );

      when(() => mockRecorderCubit.state).thenReturn(state);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(state),
      );

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Should show "Auto" for empty language
      expect(find.text('Auto'), findsOneWidget);

      // Tap language selector
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      // Should show language options
      expect(find.text('Auto-detect'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Deutsch'), findsOneWidget);
    });

    testWidgets('language selector has same height as record button',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.initialized,
        decibels: 0,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(state);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(state),
      );

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Find the language selector container
      final languageSelector = find
          .ancestor(
            of: find.byIcon(Icons.language),
            matching: find.byType(Container),
          )
          .first;

      final recordButton = find
          .ancestor(
            of: find.text('RECORD'),
            matching: find.byType(Container),
          )
          .first;

      final languageSelectorBox = tester.getSize(languageSelector);
      final recordButtonBox = tester.getSize(recordButton);

      // Both should have height of 48
      expect(languageSelectorBox.height, 48);
      expect(recordButtonBox.height, 48);
    });

    testWidgets('passes linkedId and categoryId correctly', (tester) async {
      const testLinkedId = 'test-linked-id';
      const testCategoryId = 'test-category-id';

      final state = AudioRecorderState(
        status: AudioRecorderStatus.initialized,
        decibels: 0,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(state);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(state),
      );
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);
      when(() => mockRecorderCubit.record(linkedId: any(named: 'linkedId')))
          .thenAnswer((_) async {});

      await tester.pumpWidget(makeTestableWidget(
        linkedId: testLinkedId,
        categoryId: testCategoryId,
      ));
      await tester.pumpAndSettle();

      verify(() => mockRecorderCubit.setCategoryId(testCategoryId))
          .called(greaterThanOrEqualTo(1));

      // Tap record button
      await tester.tap(find.text('RECORD'));
      await tester.pump();

      verify(() => mockRecorderCubit.record(linkedId: testLinkedId)).called(1);
    });

    testWidgets('stop button shows recording indicator', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: const Duration(seconds: 5),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(state);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(state),
      );

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Should have red recording indicator dot
      final redDot = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration?)?.color == Colors.red &&
            (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      );

      expect(redDot, findsOneWidget);
    });
  });
}
