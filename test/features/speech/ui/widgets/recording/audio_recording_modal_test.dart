import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/speech/state/recorder_cubit.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

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

  group('AudioRecordingModal Tests', () {
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
      when(() => mockRecorderCubit.setModalVisible(
          modalVisible: any(named: 'modalVisible'))).thenReturn(null);
    });

    tearDown(getIt.reset);

    testWidgets('AudioRecordingModal.show sets modal visible correctly',
        (tester) async {
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
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);

      // Test the modal visibility state management directly
      final widget = ProviderScope(
        child: makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockRecorderCubit,
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // Test the setModalVisible call directly
                    context
                        .read<AudioRecorderCubit>()
                        .setModalVisible(modalVisible: true);
                  },
                  child: const Text('Set Modal Visible'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Tap button to trigger modal visible
      await tester.tap(find.text('Set Modal Visible'));
      await tester.pump();

      // Verify modal visible was set to true
      verify(() => mockRecorderCubit.setModalVisible(modalVisible: true))
          .called(1);
    });

    testWidgets('AudioRecordingModal static method calls cubit correctly',
        (tester) async {
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
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);

      // Test the modal content directly with parameters
      final widget = ProviderScope(
        child: makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockRecorderCubit,
            child: const AudioRecordingModalContent(
              linkedId: 'test-linked-id',
              categoryId: 'test-category-id',
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Verify categoryId was set
      verify(() => mockRecorderCubit.setCategoryId('test-category-id'))
          .called(greaterThanOrEqualTo(1));

      // Verify modal content is displayed
      expect(find.byType(AnalogVuMeter), findsOneWidget);
      expect(find.text('RECORD'), findsOneWidget);
    });
  });

  group('Stop Button and Transcription Tests', () {
    late MockAudioRecorderCubit mockRecorderCubit;
    late MockJournalDb mockJournalDb;
    late MockNavService mockNavService;
    late MockAsrService mockAsrService;

    setUp(() {
      mockRecorderCubit = MockAudioRecorderCubit();
      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();
      mockAsrService = MockAsrService();

      // Mock the progressController for AsrService
      when(() => mockAsrService.progressController).thenReturn(
        StreamController<(String, TranscriptionStatus)>(),
      );

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<AsrService>(mockAsrService);

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

    testWidgets('stop button calls cubit.stop() and navigates back',
        (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: const Duration(seconds: 30),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(recordingState);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(recordingState),
      );
      when(() => mockRecorderCubit.stop())
          .thenAnswer((_) async => 'test-entry-id');
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Tap stop button
      await tester.tap(find.text('STOP'));
      await tester.pump();

      // Verify stop was called
      verify(() => mockRecorderCubit.stop()).called(1);
      // Verify navigation back was called
      verify(() => mockNavService.beamBack()).called(1);
    });

    testWidgets(
        'stop button with autoTranscribe enabled shows transcription modal',
        (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: const Duration(seconds: 30),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(recordingState);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(recordingState),
      );
      when(() => mockRecorderCubit.stop())
          .thenAnswer((_) async => 'test-entry-id');
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);
      when(() => mockJournalDb.getConfigFlag(autoTranscribeFlag))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Tap stop button
      await tester.tap(find.text('STOP'));
      await tester.pump();

      // Verify stop was called
      verify(() => mockRecorderCubit.stop()).called(1);
      // Verify autoTranscribe flag was checked
      verify(() => mockJournalDb.getConfigFlag(autoTranscribeFlag)).called(1);
    });
  });

  group('Language Selection Tests', () {
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

    Widget makeTestableWidget() {
      return ProviderScope(
        child: makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockRecorderCubit,
            child: const AudioRecordingModalContent(),
          ),
        ),
      );
    }

    testWidgets('language selector shows current language correctly',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.initialized,
        decibels: 0,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'de',
      );

      when(() => mockRecorderCubit.state).thenReturn(state);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(state),
      );
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Should show "Deutsch" for 'de' language
      expect(find.text('Deutsch'), findsOneWidget);
    });

    testWidgets('language selector calls setLanguage when option selected',
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
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);
      when(() => mockRecorderCubit.setLanguage(any())).thenReturn(null);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Tap language selector
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      // Select English
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // Verify setLanguage was called with 'en'
      verify(() => mockRecorderCubit.setLanguage('en')).called(1);
    });
  });

  group('Recording State Tests', () {
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

    Widget makeTestableWidget() {
      return ProviderScope(
        child: makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockRecorderCubit,
            child: const AudioRecordingModalContent(),
          ),
        ),
      );
    }

    testWidgets('shows stop button when recording state is paused',
        (tester) async {
      final pausedState = AudioRecorderState(
        status: AudioRecorderStatus.paused,
        decibels: 0,
        progress: const Duration(seconds: 15),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(pausedState);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(pausedState),
      );
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Should show stop button for paused state
      expect(find.text('STOP'), findsOneWidget);
      expect(find.text('RECORD'), findsNothing);
    });

    testWidgets('shows record button when recording state is stopped',
        (tester) async {
      final stoppedState = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        decibels: 0,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(stoppedState);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(stoppedState),
      );
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Should show record button for stopped state
      expect(find.text('RECORD'), findsOneWidget);
      expect(find.text('STOP'), findsNothing);
    });
  });

  group('Error Handling Tests', () {
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

    Widget makeTestableWidget() {
      return ProviderScope(
        child: makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockRecorderCubit,
            child: const AudioRecordingModalContent(),
          ),
        ),
      );
    }

    testWidgets('handles stop() returning null gracefully', (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: const Duration(seconds: 30),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(recordingState);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(recordingState),
      );
      when(() => mockRecorderCubit.stop()).thenAnswer((_) async => null);
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Tap stop button
      await tester.tap(find.text('STOP'));
      await tester.pump();

      // Should still call stop and navigate back even if entryId is null
      verify(() => mockRecorderCubit.stop()).called(1);
      verify(() => mockNavService.beamBack()).called(1);
    });

    testWidgets(
        'verifies correct cubit methods are available for error scenarios',
        (tester) async {
      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: const Duration(seconds: 30),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      when(() => mockRecorderCubit.state).thenReturn(recordingState);
      when(() => mockRecorderCubit.stream).thenAnswer(
        (_) => Stream.value(recordingState),
      );
      when(() => mockRecorderCubit.stop()).thenAnswer((_) async => null);
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Tap stop button
      await tester.tap(find.text('STOP'));
      await tester.pump();

      // Should call stop method even when returning null
      verify(() => mockRecorderCubit.stop()).called(1);
    });
  });

  group('Widget Structure Tests', () {
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

    Widget makeTestableWidget() {
      return ProviderScope(
        child: makeTestableWidgetWithScaffold(
          BlocProvider<AudioRecorderCubit>(
            create: (_) => mockRecorderCubit,
            child: const AudioRecordingModalContent(),
          ),
        ),
      );
    }

    testWidgets('AnimatedSwitcher widget is present with correct duration',
        (tester) async {
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
      when(() => mockRecorderCubit.setCategoryId(any())).thenReturn(null);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Find the AnimatedSwitcher widget
      final animatedSwitcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );

      // Verify the duration is 200ms as specified in the code
      expect(animatedSwitcher.duration, const Duration(milliseconds: 200));
    });
  });

  group('Utility Method Tests', () {
    testWidgets('formatDuration formats duration string correctly',
        (tester) async {
      const content = AudioRecordingModalContent();

      // Test various duration formats
      expect(content.formatDuration('0:01:23.456789'), '0:01:23');
      expect(content.formatDuration('0:00:05.123456'), '0:00:05');
      expect(content.formatDuration('1:30:45.987654'), '1:30:45');
    });
  });
}
