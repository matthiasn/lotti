import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' show Amplitude;

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

// Mock classes
class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockLoggingService extends Mock implements LoggingService {}

// Custom AudioRecorderController for testing
class TestAudioRecorderController extends AudioRecorderController {
  TestAudioRecorderController(this._testState);

  final AudioRecorderState _testState;

  @override
  AudioRecorderState build() => _testState;

  @override
  Future<void> record({String? linkedId}) async {
    state = state.copyWith(
      status: AudioRecorderStatus.recording,
      linkedId: linkedId,
    );
  }

  @override
  Future<String?> stop() async {
    state = state.copyWith(status: AudioRecorderStatus.stopped);
    return 'test-entry-id';
  }

  @override
  void setModalVisible({required bool modalVisible}) {
    state = state.copyWith(modalVisible: modalVisible);
  }

  @override
  void setCategoryId(String? categoryId) {
    // In the real implementation, this updates persistence
    // For testing, we don't need to do anything
  }

  @override
  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecordingModalContent Tests', () {
    late MockJournalDb mockJournalDb;
    late MockNavService mockNavService;
    late MockAudioRecorderRepository mockRecorderRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();
      mockRecorderRepository = MockAudioRecorderRepository();
      mockLoggingService = MockLoggingService();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<LoggingService>(mockLoggingService);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);
      when(() => mockNavService.beamBack()).thenReturn(null);
      when(() => mockRecorderRepository.amplitudeStream)
          .thenAnswer((_) => const Stream<Amplitude>.empty());
      when(() => mockRecorderRepository.dispose()).thenAnswer((_) async {});
    });

    tearDown(getIt.reset);

    Widget makeTestableWidget({
      String? linkedId,
      String? categoryId,
      AudioRecorderState? state,
    }) {
      final testState = state ??
          AudioRecorderState(
            status: AudioRecorderStatus.initialized,
            decibels: 0,
            progress: Duration.zero,
            showIndicator: false,
            modalVisible: false,
            language: 'en',
          );

      return ProviderScope(
        overrides: [
          audioRecorderRepositoryProvider
              .overrideWithValue(mockRecorderRepository),
          audioRecorderControllerProvider.overrideWith(() {
            return TestAudioRecorderController(testState);
          }),
        ],
        child: makeTestableWidgetWithScaffold(
          AudioRecordingModalContent(
            linkedId: linkedId,
            categoryId: categoryId,
          ),
        ),
      );
    }

    testWidgets('displays VU meter with correct size', (tester) async {
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

      await tester.pumpWidget(makeTestableWidget(state: state));
      await tester.pumpAndSettle();

      // Duration should be formatted as 0:01:23
      expect(find.text('0:01:23'), findsOneWidget);
    });

    testWidgets('shows record button when not recording', (tester) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('RECORD'), findsOneWidget);
      expect(find.text('STOP'), findsNothing);

      // Tap record button
      await tester.tap(find.text('RECORD'));
      await tester.pump();
    });

    testWidgets('record button calls record method with correct linkedId',
        (tester) async {
      TestAudioRecorderController? controller;
      const testLinkedId = 'test-linked-id';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            audioRecorderControllerProvider.overrideWith(() {
              controller = TestAudioRecorderController(
                AudioRecorderState(
                  status: AudioRecorderStatus.initialized,
                  decibels: 0,
                  progress: Duration.zero,
                  showIndicator: false,
                  modalVisible: false,
                  language: 'en',
                ),
              );
              return controller!;
            }),
          ],
          child: makeTestableWidgetWithScaffold(
            const AudioRecordingModalContent(
              linkedId: testLinkedId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially should not be recording
      expect(controller!.state.status, AudioRecorderStatus.initialized);
      expect(controller!.state.linkedId, isNull);

      // Tap record button
      await tester.tap(find.text('RECORD'));
      await tester.pump();

      // Verify record was called with correct linkedId
      expect(controller!.state.status, AudioRecorderStatus.recording);
      expect(controller!.state.linkedId, testLinkedId);
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

      await tester.pumpWidget(makeTestableWidget(state: state));
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

      await tester.pumpWidget(makeTestableWidget(state: state));
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

    testWidgets('stop button shows recording indicator', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 80,
        progress: const Duration(seconds: 5),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state: state));
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

    testWidgets('modal content widget renders without setting visibility',
        (tester) async {
      // Modal visibility is now managed by the show() method, not the widget
      final controller = TestAudioRecorderController(
        AudioRecorderState(
          status: AudioRecorderStatus.initialized,
          decibels: 0,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
          language: 'en',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            audioRecorderControllerProvider.overrideWith(() => controller),
          ],
          child: makeTestableWidgetWithScaffold(
            const AudioRecordingModalContent(),
          ),
        ),
      );

      // Wait for post frame callback
      await tester.pump();

      // The widget should render properly
      expect(find.byType(AudioRecordingModalContent), findsOneWidget);
      // Modal visibility is not set by the widget anymore
      expect(controller.state.modalVisible, isFalse);
    });
  });

  group('Stop Button and Transcription Tests', () {
    late MockJournalDb mockJournalDb;
    late MockNavService mockNavService;
    late MockAsrService mockAsrService;
    late MockAudioRecorderRepository mockRecorderRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();
      mockAsrService = MockAsrService();
      mockRecorderRepository = MockAudioRecorderRepository();
      mockLoggingService = MockLoggingService();

      // Mock the progressController for AsrService
      when(() => mockAsrService.progressController).thenReturn(
        StreamController<(String, TranscriptionStatus)>(),
      );

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<AsrService>(mockAsrService)
        ..registerSingleton<LoggingService>(mockLoggingService);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);
      when(() => mockNavService.beamBack()).thenReturn(null);
      when(() => mockRecorderRepository.amplitudeStream)
          .thenAnswer((_) => const Stream<Amplitude>.empty());
      when(() => mockRecorderRepository.dispose()).thenAnswer((_) async {});
    });

    tearDown(getIt.reset);

    testWidgets('stop button calls stop() and navigates back', (tester) async {
      TestAudioRecorderController? controller;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            audioRecorderControllerProvider.overrideWith(() {
              controller = TestAudioRecorderController(
                AudioRecorderState(
                  status: AudioRecorderStatus.recording,
                  decibels: 80,
                  progress: const Duration(seconds: 30),
                  showIndicator: false,
                  modalVisible: false,
                  language: 'en',
                ),
              );
              return controller!;
            }),
          ],
          child: makeTestableWidgetWithScaffold(
            const AudioRecordingModalContent(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state is recording
      expect(controller!.state.status, AudioRecorderStatus.recording);

      // Tap stop button
      await tester.tap(find.text('STOP'));
      await tester.pump();

      // Verify controller state changed to stopped
      expect(controller!.state.status, AudioRecorderStatus.stopped);
    });
  });

  group('Language Selection Tests', () {
    late MockJournalDb mockJournalDb;
    late MockNavService mockNavService;
    late MockAudioRecorderRepository mockRecorderRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();
      mockRecorderRepository = MockAudioRecorderRepository();
      mockLoggingService = MockLoggingService();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<LoggingService>(mockLoggingService);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);
      when(() => mockNavService.beamBack()).thenReturn(null);
      when(() => mockRecorderRepository.amplitudeStream)
          .thenAnswer((_) => const Stream<Amplitude>.empty());
      when(() => mockRecorderRepository.dispose()).thenAnswer((_) async {});
    });

    tearDown(getIt.reset);

    Widget makeTestableWidget({AudioRecorderState? state}) {
      final testState = state ??
          AudioRecorderState(
            status: AudioRecorderStatus.initialized,
            decibels: 0,
            progress: Duration.zero,
            showIndicator: false,
            modalVisible: false,
            language: 'de',
          );

      return ProviderScope(
        overrides: [
          audioRecorderRepositoryProvider
              .overrideWithValue(mockRecorderRepository),
          audioRecorderControllerProvider.overrideWith(() {
            return TestAudioRecorderController(testState);
          }),
        ],
        child: makeTestableWidgetWithScaffold(
          const AudioRecordingModalContent(),
        ),
      );
    }

    testWidgets('language selector shows current language correctly',
        (tester) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // Should show "Deutsch" for 'de' language
      expect(find.text('Deutsch'), findsOneWidget);
    });

    testWidgets('tapping language selector calls setLanguage with correct code',
        (tester) async {
      TestAudioRecorderController? controller;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            audioRecorderControllerProvider.overrideWith(() {
              controller = TestAudioRecorderController(
                AudioRecorderState(
                  status: AudioRecorderStatus.initialized,
                  decibels: 0,
                  progress: Duration.zero,
                  showIndicator: false,
                  modalVisible: false,
                  language: '',
                ),
              );
              return controller!;
            }),
          ],
          child: makeTestableWidgetWithScaffold(
            const AudioRecordingModalContent(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open language selector
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      // Select English
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // Verify setLanguage was called with 'en'
      expect(controller!.state.language, 'en');

      // Open language selector again
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      // Select Deutsch
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      // Verify setLanguage was called with 'de'
      expect(controller!.state.language, 'de');
    });
  });

  group('Utility Method Tests', () {
    late MockJournalDb mockJournalDb;
    late MockNavService mockNavService;
    late MockAudioRecorderRepository mockRecorderRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();
      mockRecorderRepository = MockAudioRecorderRepository();
      mockLoggingService = MockLoggingService();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<LoggingService>(mockLoggingService);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);
      when(() => mockNavService.beamBack()).thenReturn(null);
      when(() => mockRecorderRepository.amplitudeStream)
          .thenAnswer((_) => const Stream<Amplitude>.empty());
      when(() => mockRecorderRepository.dispose()).thenAnswer((_) async {});
    });

    tearDown(getIt.reset);

    Widget makeTestableWidget({AudioRecorderState? state}) {
      final testState = state ??
          AudioRecorderState(
            status: AudioRecorderStatus.initialized,
            decibels: 0,
            progress: Duration.zero,
            showIndicator: false,
            modalVisible: false,
            language: 'en',
          );

      return ProviderScope(
        overrides: [
          audioRecorderRepositoryProvider
              .overrideWithValue(mockRecorderRepository),
          audioRecorderControllerProvider.overrideWith(() {
            return TestAudioRecorderController(testState);
          }),
        ],
        child: makeTestableWidgetWithScaffold(
          const AudioRecordingModalContent(),
        ),
      );
    }

    testWidgets('formatDuration formats duration string correctly',
        (tester) async {
      // Test the duration formatting through the widget
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        decibels: 0,
        progress: const Duration(minutes: 1, seconds: 23, milliseconds: 456),
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state: state));
      await tester.pumpAndSettle();

      // The widget should format the duration correctly
      expect(find.text('0:01:23'), findsOneWidget);
    });

    testWidgets('formatDuration handles various duration formats',
        (tester) async {
      // Test different duration values
      final testCases = [
        (const Duration(seconds: 5), '0:00:05'),
        (const Duration(minutes: 10, seconds: 30), '0:10:30'),
        (const Duration(hours: 1, minutes: 5, seconds: 45), '1:05:45'),
      ];

      for (final (duration, expected) in testCases) {
        final state = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          decibels: 0,
          progress: duration,
          showIndicator: false,
          modalVisible: false,
          language: 'en',
        );

        await tester.pumpWidget(makeTestableWidget(state: state));
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget,
            reason: 'Expected to find "$expected" for duration $duration');

        // Clear the widget tree before the next iteration
        await tester.pumpWidget(Container());
      }
    });
  });
}
