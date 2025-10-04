import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/ui/lotti_animated_checkbox.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' show Amplitude;

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

// Register fake for navigation
class FakeRoute extends Fake implements Route<dynamic> {}

// Mock classes
class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

// Custom AudioRecorderController for testing
class TestAudioRecorderController extends AudioRecorderController {
  TestAudioRecorderController(
    this._testState, {
    this.stopResult = 'test-entry-id',
  });

  final AudioRecorderState _testState;
  final String? stopResult;

  final modalVisibleValues = <bool>[];
  final recordLinkedIds = <String?>[];
  String? lastCategoryId;

  @override
  AudioRecorderState build() => _testState;

  @override
  Future<void> record({String? linkedId}) async {
    recordLinkedIds.add(linkedId);
    state = state.copyWith(
      status: AudioRecorderStatus.recording,
      linkedId: linkedId,
    );
  }

  @override
  Future<String?> stop() async {
    state = state.copyWith(status: AudioRecorderStatus.stopped);
    return stopResult;
  }

  @override
  void setModalVisible({required bool modalVisible}) {
    modalVisibleValues.add(modalVisible);
    state = state.copyWith(modalVisible: modalVisible);
  }

  @override
  void setCategoryId(String? categoryId) {
    lastCategoryId = categoryId;
  }

  @override
  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Register fake for Route
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  group('AudioRecordingModalContent Tests', () {
    late MockJournalDb mockJournalDb;
    late MockNavService mockNavService;
    late MockAudioRecorderRepository mockRecorderRepository;
    late MockLoggingService mockLoggingService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();
      mockRecorderRepository = MockAudioRecorderRepository();
      mockLoggingService = MockLoggingService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockEntitiesCacheService = MockEntitiesCacheService();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<LoggingService>(mockLoggingService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);
      when(() => mockNavService.beamBack()).thenReturn(null);
      when(() => mockRecorderRepository.amplitudeStream)
          .thenAnswer((_) => const Stream<Amplitude>.empty());
      when(() => mockRecorderRepository.dispose()).thenAnswer((_) async {});

      // Mock category related methods
      when(() => mockJournalDb.watchCategoryById(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => mockEntitiesCacheService.getCategoryById(any()))
          .thenReturn(null);
    });

    tearDown(getIt.reset);

    Widget makeTestableWidget({
      String? linkedId,
      String? categoryId,
      AudioRecorderState? state,
    }) {
      final testState = state ??
          AudioRecorderState(
            status: AudioRecorderStatus.initializing,
            vu: 0,
            dBFS: -60,
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
        vu: -10,
        dBFS: -20,
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
      late TestAudioRecorderController controller;
      const testLinkedId = 'test-linked-id';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            audioRecorderControllerProvider.overrideWith(
              () => controller = TestAudioRecorderController(
                AudioRecorderState(
                  status: AudioRecorderStatus.initializing,
                  vu: 0,
                  dBFS: -60,
                  progress: Duration.zero,
                  showIndicator: false,
                  modalVisible: false,
                  language: 'en',
                ),
              ),
            ),
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
      expect(controller.state.status, AudioRecorderStatus.initializing);
      expect(controller.state.linkedId, isNull);

      // Tap record button
      await tester.tap(find.text('RECORD'));
      await tester.pump();

      // Verify record was called with correct linkedId
      expect(controller.state.status, AudioRecorderStatus.recording);
      expect(controller.state.linkedId, testLinkedId);
    });

    testWidgets('shows stop button when recording', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: -10,
        dBFS: -20,
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

    testWidgets('stop button shows recording indicator', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: -10,
        dBFS: -20,
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
          status: AudioRecorderStatus.initializing,
          vu: 0,
          dBFS: -60,
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

    testWidgets('passes categoryId correctly to the modal', (tester) async {
      const testCategoryId = 'test-category-id';

      await tester.pumpWidget(
        makeTestableWidget(categoryId: testCategoryId),
      );

      // The widget itself doesn't call setCategoryId, it's called by the show method
      // So we verify that the categoryId is passed to the widget
      final modalContent = tester.widget<AudioRecordingModalContent>(
        find.byType(AudioRecordingModalContent),
      );
      expect(modalContent.categoryId, testCategoryId);
    });
  });

  group('AudioRecordingModal.show', () {
    late MockJournalDb mockJournalDb;
    late MockNavService mockNavService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockCategoryRepository mockCategoryRepository;
    late MockAudioRecorderRepository mockRecorderRepository;

    setUp(() {
      getIt.reset();

      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockCategoryRepository = MockCategoryRepository();
      mockRecorderRepository = MockAudioRecorderRepository();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);
      when(() => mockRecorderRepository.amplitudeStream)
          .thenAnswer((_) => const Stream<Amplitude>.empty());
      when(() => mockRecorderRepository.dispose()).thenAnswer((_) async {});

      // Mock category repository to return a stream with a category that has automatic prompts
      final now = DateTime(2024);
      final category = CategoryDefinition(
        id: 'cat-id',
        createdAt: now,
        updatedAt: now,
        name: 'Test Category',
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: {
          AiResponseType.audioTranscription: ['prompt-1'],
        },
      );
      when(() => mockCategoryRepository.watchCategory('cat-id'))
          .thenAnswer((_) => Stream.value(category));
    });

    tearDown(getIt.reset);

    testWidgets('sets modal visibility around modal lifecycle', (tester) async {
      late TestAudioRecorderController controller;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            audioRecorderControllerProvider.overrideWith(
              () => controller = TestAudioRecorderController(
                AudioRecorderState(
                  status: AudioRecorderStatus.stopped,
                  vu: 0,
                  dBFS: -60,
                  progress: Duration.zero,
                  showIndicator: false,
                  modalVisible: false,
                  language: 'en',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await AudioRecordingModal.show(
                        context,
                        categoryId: 'cat-id',
                        useRootNavigator: false,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(controller.modalVisibleValues.first, isTrue);
      expect(controller.lastCategoryId, 'cat-id');

      final modalContext =
          tester.element(find.byType(AudioRecordingModalContent));
      Navigator.of(modalContext).pop();
      await tester.pumpAndSettle();

      expect(controller.modalVisibleValues, [true, false]);
    });
  });

  group('Stop Button and Transcription Tests', () {
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

    testWidgets('stop button calls stop() and navigates back', (tester) async {
      late TestAudioRecorderController controller;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            audioRecorderControllerProvider.overrideWith(
              () => controller = TestAudioRecorderController(
                AudioRecorderState(
                  status: AudioRecorderStatus.recording,
                  vu: -10,
                  dBFS: -20,
                  progress: const Duration(seconds: 30),
                  showIndicator: false,
                  modalVisible: false,
                  language: 'en',
                ),
              ),
            ),
          ],
          child: makeTestableWidgetWithScaffold(
            const AudioRecordingModalContent(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state is recording
      expect(controller.state.status, AudioRecorderStatus.recording);

      // Tap stop button
      await tester.tap(find.text('STOP'));
      await tester.pump();

      // Verify controller state changed to stopped
      expect(controller.state.status, AudioRecorderStatus.stopped);
    });

    testWidgets('navigates to entry when linkedId is null after recording',
        (tester) async {
      String? capturedNavigationPath;

      // Mock navigation to capture the path
      when(() => mockNavService.beamToNamed(any())).thenAnswer((invocation) {
        capturedNavigationPath = invocation.positionalArguments[0] as String;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            audioRecorderControllerProvider.overrideWith(
              () => TestAudioRecorderController(
                AudioRecorderState(
                  status: AudioRecorderStatus.recording,
                  vu: -10,
                  dBFS: -20,
                  progress: const Duration(seconds: 30),
                  showIndicator: false,
                  modalVisible: false,
                  language: 'en',
                ),
              ),
            ),
          ],
          child: makeTestableWidgetWithScaffold(
            const AudioRecordingModalContent(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap stop button
      await tester.tap(find.text('STOP'));
      await tester.pump();

      // Verify navigation happened to the created entry
      expect(capturedNavigationPath, '/journal/test-entry-id');
    });

    testWidgets('does not navigate when linkedId is provided', (tester) async {
      var navigationCalled = false;

      // Mock navigation to detect if it's called
      when(() => mockNavService.beamToNamed(any())).thenAnswer((_) {
        navigationCalled = true;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            audioRecorderControllerProvider.overrideWith(
              () => TestAudioRecorderController(
                AudioRecorderState(
                  status: AudioRecorderStatus.recording,
                  vu: -10,
                  dBFS: -20,
                  progress: const Duration(seconds: 30),
                  showIndicator: false,
                  modalVisible: false,
                  language: 'en',
                ),
              ),
            ),
          ],
          child: makeTestableWidgetWithScaffold(
            const AudioRecordingModalContent(
              linkedId: 'existing-entry-id', // Has linked ID
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap stop button
      await tester.tap(find.text('STOP'));
      await tester.pump();

      // Verify navigation was NOT called
      expect(navigationCalled, false);
    });
  });

  group('Checkbox Controls Tests', () {
    late MockJournalDb mockJournalDb;
    late MockNavService mockNavService;
    late MockAudioRecorderRepository mockRecorderRepository;
    late MockLoggingService mockLoggingService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();
      mockRecorderRepository = MockAudioRecorderRepository();
      mockLoggingService = MockLoggingService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockEntitiesCacheService = MockEntitiesCacheService();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<LoggingService>(mockLoggingService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);
      when(() => mockRecorderRepository.amplitudeStream)
          .thenAnswer((_) => const Stream<Amplitude>.empty());
      when(() => mockRecorderRepository.dispose()).thenAnswer((_) async {});
      when(() => mockNavService.beamBack()).thenReturn(null);
    });

    tearDown(getIt.reset);

    Future<ExtendedTestAudioRecorderController> pumpModal(
      WidgetTester tester, {
      String? linkedId,
      String? categoryId,
      CategoryDefinition? category,
      AudioRecorderState? state,
    }) async {
      late ExtendedTestAudioRecorderController controller;
      final testState = state ??
          AudioRecorderState(
            status: AudioRecorderStatus.initializing,
            vu: 0,
            dBFS: -60,
            progress: Duration.zero,
            showIndicator: false,
            modalVisible: false,
            language: 'en',
          );

      // Create a local mock for category repository
      final localMockCategoryRepository = MockCategoryRepository();

      final overrides = <Override>[
        audioRecorderRepositoryProvider.overrideWithValue(
          mockRecorderRepository,
        ),
        categoryRepositoryProvider
            .overrideWithValue(localMockCategoryRepository),
        audioRecorderControllerProvider.overrideWith(
          () => controller = ExtendedTestAudioRecorderController(testState),
        ),
      ];

      if (categoryId != null && category != null) {
        when(() => localMockCategoryRepository.watchCategory(categoryId))
            .thenAnswer((_) => Stream.value(category));
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: makeTestableWidgetWithScaffold(
            AudioRecordingModalContent(
              linkedId: linkedId,
              categoryId: categoryId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      return controller;
    }

    CategoryDefinition categoryDefinitionWithPrompts({
      bool transcription = false,
      bool checklist = false,
      bool summary = false,
    }) {
      final prompts = <AiResponseType, List<String>>{};

      if (transcription) {
        prompts[AiResponseType.audioTranscription] = ['prompt-transcription'];
      }
      if (checklist) {
        prompts[AiResponseType.checklistUpdates] = ['prompt-checklist'];
      }
      if (summary) {
        prompts[AiResponseType.taskSummary] = ['prompt-summary'];
      }

      final now = DateTime(2024);
      return CategoryDefinition(
        id: 'cat-id',
        createdAt: now,
        updatedAt: now,
        name: 'Audio Category',
        vectorClock: null,
        private: false,
        active: true,
        automaticPrompts: prompts.isEmpty ? null : prompts,
      );
    }

    testWidgets('does not show checkboxes when categoryId is null',
        (tester) async {
      await pumpModal(tester);

      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });

    testWidgets('hides checkboxes when category has no automatic prompts',
        (tester) async {
      await pumpModal(
        tester,
        categoryId: 'cat-id',
        category: categoryDefinitionWithPrompts(),
      );

      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });

    testWidgets(
        'shows only speech recognition option when transcription prompts exist and entry is not linked to a task',
        (tester) async {
      final controller = await pumpModal(
        tester,
        categoryId: 'cat-id',
        category: categoryDefinitionWithPrompts(transcription: true),
      );

      expect(find.text('Speech Recognition'), findsOneWidget);
      expect(find.text('Checklist Updates'), findsNothing);
      expect(find.text('Task Summary'), findsNothing);

      await tester.tap(find.text('Speech Recognition'));
      await tester.pump();

      expect(controller.speechRecognitionValues, contains(false));
    });

    testWidgets(
        'hides checklist and task summary when speech recognition is disabled',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
        enableSpeechRecognition: false,
        enableChecklistUpdates: true,
        enableTaskSummary: true,
      );

      await pumpModal(
        tester,
        linkedId: 'task-1',
        categoryId: 'cat-id',
        category: categoryDefinitionWithPrompts(
          transcription: true,
          checklist: true,
          summary: true,
        ),
        state: state,
      );

      expect(find.text('Speech Recognition'), findsOneWidget);
      expect(find.text('Checklist Updates'), findsNothing);
      expect(find.text('Task Summary'), findsNothing);
    });

    testWidgets(
        'shows and toggles all automatic prompt checkboxes when prerequisites are met',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
        enableSpeechRecognition: true,
        enableChecklistUpdates: true,
        enableTaskSummary: true,
      );

      final controller = await pumpModal(
        tester,
        linkedId: 'task-1',
        categoryId: 'cat-id',
        category: categoryDefinitionWithPrompts(
          transcription: true,
          checklist: true,
          summary: true,
        ),
        state: state,
      );

      expect(find.text('Speech Recognition'), findsOneWidget);
      expect(find.text('Checklist Updates'), findsOneWidget);
      expect(find.text('Task Summary'), findsOneWidget);

      await tester.tap(find.text('Checklist Updates'));
      await tester.pump();
      await tester.tap(find.text('Task Summary'));
      await tester.pump();
      await tester.tap(find.text('Speech Recognition'));
      await tester.pumpAndSettle();

      expect(controller.checklistValues, contains(false));
      expect(controller.taskSummaryValues, contains(false));
      expect(controller.speechRecognitionValues, contains(false));
      expect(find.text('Checklist Updates'), findsNothing);
      expect(find.text('Task Summary'), findsNothing);
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
            status: AudioRecorderStatus.initializing,
            vu: 0,
            dBFS: -60,
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
        vu: 0,
        dBFS: -60,
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
          vu: 0,
          dBFS: -60,
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

// Extended TestAudioRecorderController for checkbox tests
class ExtendedTestAudioRecorderController extends TestAudioRecorderController {
  ExtendedTestAudioRecorderController(super._testState);

  final speechRecognitionValues = <bool?>[];
  final checklistValues = <bool?>[];
  final taskSummaryValues = <bool?>[];

  @override
  void setEnableSpeechRecognition({required bool? enable}) {
    speechRecognitionValues.add(enable);
    state = state.copyWith(enableSpeechRecognition: enable);
  }

  @override
  void setEnableChecklistUpdates({required bool? enable}) {
    checklistValues.add(enable);
    state = state.copyWith(enableChecklistUpdates: enable);
  }

  @override
  void setEnableTaskSummary({required bool? enable}) {
    taskSummaryValues.add(enable);
    state = state.copyWith(enableTaskSummary: enable);
  }
}
