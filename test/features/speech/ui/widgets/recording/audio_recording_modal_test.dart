// ignore_for_file: avoid_redundant_argument_values
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/speech/state/checkbox_visibility_provider.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/ui/lotti_animated_checkbox.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

// Mock EntryController for testing
class FakeEntryController extends EntryController {
  FakeEntryController({
    this.mockEntry,
    this.shouldError = false,
    this.isLoading = false,
  });

  final JournalEntity? mockEntry;
  final bool shouldError;
  final bool isLoading;

  @override
  Future<EntryState?> build() {
    // Return synchronously using SynchronousFuture for immediate resolution in tests
    if (shouldError) {
      // Return a Future.error for error propagation
      return Future<EntryState?>.error(Exception('Test error'));
    }

    // If simulating loading, return a future that never completes
    if (isLoading) {
      return Completer<EntryState?>().future;
    }

    if (mockEntry == null) {
      return SynchronousFuture(null);
    }

    return SynchronousFuture(
      EntryState.saved(
        entryId: mockEntry!.meta.id,
        entry: mockEntry,
        showMap: false,
        isFocused: false,
        shouldShowEditorToolBar: false,
      ),
    );
  }
}

class FakeCategoryDefinition extends Fake implements CategoryDefinition {
  @override
  String get id => 'test-category';

  @override
  String get name => 'Test Category';

  @override
  DateTime get createdAt => DateTime(2024);

  @override
  DateTime get updatedAt => DateTime(2024);

  @override
  bool get private => false;

  @override
  String? get color => '#000000';

  @override
  bool get active => true;

  @override
  bool get favorite => false;

  @override
  String? get defaultLanguageCode => null;

  @override
  List<String>? get speechDictionary => null;

  @override
  CategoryIcon? get icon => null;

  @override
  List<ChecklistCorrectionExample>? get correctionExamples => null;
}

// Test helper controller that returns a fixed state (from coverage tests)
class TestAudioRecorderController extends AudioRecorderController {
  TestAudioRecorderController(this.fixedState);

  final AudioRecorderState fixedState;

  @override
  AudioRecorderState build() => fixedState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Font downloads are centrally configured in test/flutter_test_config.dart

  late MockLoggingService mockLoggingService;
  late MockAudioRecorderRepository mockAudioRecorderRepository;
  late MockCategoryRepository mockCategoryRepository;
  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockTimeService mockTimeService;
  late MockNavService mockNavService;
  late MockPlayer mockPlayer;
  late MockPlayerState mockPlayerState;
  late MockPlayerStream mockPlayerStream;
  late StreamController<Duration> positionController;
  late StreamController<Duration> bufferController;
  late StreamController<bool> completedController;

  setUpAll(() {
    registerFallbackValue(FakePlayable());
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockAudioRecorderRepository = MockAudioRecorderRepository();
    mockCategoryRepository = MockCategoryRepository();
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockUpdateNotifications = MockUpdateNotifications();
    mockTimeService = MockTimeService();
    mockNavService = MockNavService();
    mockPlayer = MockPlayer();
    mockPlayerState = MockPlayerState();
    mockPlayerStream = MockPlayerStream();
    positionController = StreamController<Duration>.broadcast();
    bufferController = StreamController<Duration>.broadcast();
    completedController = StreamController<bool>.broadcast();

    // Setup mock player
    when(() => mockPlayer.state).thenReturn(mockPlayerState);
    when(() => mockPlayerState.duration).thenReturn(const Duration(minutes: 5));
    when(() => mockPlayer.stream).thenReturn(mockPlayerStream);
    when(
      () => mockPlayerStream.position,
    ).thenAnswer((_) => positionController.stream);
    when(
      () => mockPlayerStream.buffer,
    ).thenAnswer((_) => bufferController.stream);
    when(
      () => mockPlayerStream.completed,
    ).thenAnswer((_) => completedController.stream);
    when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    when(
      () => mockPlayer.open(any(), play: any(named: 'play')),
    ).thenAnswer((_) async {});
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
    when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});

    // Setup default mock behavior for AudioRecorderRepository
    when(() => mockAudioRecorderRepository.amplitudeStream).thenAnswer(
      (_) => const Stream<Amplitude>.empty(),
    );
    when(
      () => mockAudioRecorderRepository.hasPermission(),
    ).thenAnswer((_) async => true);
    when(
      () => mockAudioRecorderRepository.isPaused(),
    ).thenAnswer((_) async => false);
    when(
      () => mockAudioRecorderRepository.isRecording(),
    ).thenAnswer((_) async => false);
    when(
      () => mockAudioRecorderRepository.stopRecording(),
    ).thenAnswer((_) async => 'test-audio-path.m4a');
    when(
      () => mockAudioRecorderRepository.startRecording(),
    ).thenAnswer((_) async => null);
    when(
      () => mockAudioRecorderRepository.pauseRecording(),
    ).thenAnswer((_) async {});
    when(
      () => mockAudioRecorderRepository.resumeRecording(),
    ).thenAnswer((_) async {});

    // Register mocks with GetIt
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService);
    ensureDomainLoggerRegistered();
  });

  tearDown(() async {
    await positionController.close();
    await bufferController.close();
    await completedController.close();
    await getIt.reset();
  });

  Widget createTestWidget({
    AudioRecorderState? state,
    CategoryDefinition? category,
    String? linkedTaskId,
    bool provideCategory = true,
    bool showSpeechCheckbox = false,
  }) {
    final categoryToUse = category ?? FakeCategoryDefinition();

    // Set up category mock BEFORE creating widget (critical for synchronous resolution)
    if (provideCategory) {
      when(
        () => mockCategoryRepository.watchCategory('test-category'),
      ).thenAnswer((_) => Stream.value(categoryToUse));
    }

    // Create a mock Task entity when linkedTaskId is provided
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final mockTask = linkedTaskId != null
        ? Task(
            meta: Metadata(
              id: linkedTaskId,
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              categoryId: 'test-category',
            ),
            data: TaskData(
              title: 'Test Task',
              status: TaskStatus.open(
                id: const Uuid().v1(),
                createdAt: testDate,
                utcOffset: 0,
              ),
              dateFrom: testDate,
              dateTo: testDate,
              statusHistory: [
                TaskStatus.open(
                  id: const Uuid().v1(),
                  createdAt: testDate,
                  utcOffset: 0,
                ),
              ],
            ),
          )
        : null;

    // Create a provider container with the mocked dependencies
    final overrides = <Override>[
      audioRecorderRepositoryProvider.overrideWithValue(
        mockAudioRecorderRepository,
      ),
      categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
      playerFactoryProvider.overrideWithValue(() => mockPlayer),
    ];

    // Override the entryControllerProvider if linkedTaskId is provided
    if (linkedTaskId != null && mockTask != null) {
      overrides.add(
        entryControllerProvider(linkedTaskId).overrideWith(
          () => FakeEntryController(mockEntry: mockTask),
        ),
      );
    }

    // Override checkbox visibility when speech checkbox should be shown
    if (showSpeechCheckbox) {
      overrides.add(
        checkboxVisibilityProvider((
          categoryId: provideCategory ? 'test-category' : null,
          linkedId: linkedTaskId,
        )).overrideWithValue(
          const AutomaticPromptVisibility(speech: true),
        ),
      );
    }

    return ProviderScope(
      overrides: overrides,
      child: Builder(
        builder: (context) {
          // If we have a specific state to set, update the controller
          if (state != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ProviderScope.containerOf(context)
                  .read(audioRecorderControllerProvider.notifier)
                  .setEnableSpeechRecognition(
                    enable: state.enableSpeechRecognition,
                  );
            });
          }

          return MaterialApp(
            home: Scaffold(
              body: AudioRecordingModalContent(
                categoryId: provideCategory ? 'test-category' : null,
                linkedId: linkedTaskId,
              ),
            ),
          );
        },
      ),
    );
  }

  group('AudioRecordingModal - Speech Recognition Checkbox', () {
    testWidgets('shows checkbox when profile transcription available', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          linkedTaskId: 'task-1',
          showSpeechCheckbox: true,
        ),
      );
      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
    });

    testWidgets('hides checkbox when transcription prompts are absent', (
      tester,
    ) async {
      final category = FakeCategoryDefinition();

      await tester.pumpWidget(createTestWidget(category: category));
      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsNothing,
      );
    });
  });

  group('AudioRecordingModal - Visibility Integration', () {
    testWidgets('hides entire section when no categoryId provided', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(provideCategory: false));
      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.byKey(const Key('speech_recognition_checkbox')),
        findsNothing,
      );
      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });

    testWidgets('hides when category stream returns null', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          provideCategory: false,
          linkedTaskId: 'task-1',
        ),
      );
      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });

    testWidgets('shows speech recognition checkbox when configured', (
      tester,
    ) async {
      final category = FakeCategoryDefinition();
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        linkedId: 'task-1',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(
        createTestWidget(
          state: state,
          category: category,
          linkedTaskId: 'task-1',
          showSpeechCheckbox: true,
        ),
      );
      await tester.pump(); // Build initial frame
      await tester.pump(); // Execute postFrameCallback
      await tester.pump(); // Process state update from postFrameCallback
      await tester.pump(); // Allow async providers to resolve
      await tester.pump(); // Rebuild with resolved provider data

      // Speech checkbox should be present
      expect(
        find.byKey(const Key('speech_recognition_checkbox')),
        findsOneWidget,
      );
    });

    testWidgets('hides section when no profile transcription', (tester) async {
      final category = FakeCategoryDefinition();

      await tester.pumpWidget(
        createTestWidget(
          category: category,
          linkedTaskId: 'task-1',
        ),
      );
      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });
  });

  group('AudioRecordingModal - Coverage', () {
    // ---------------------------------------------------------------------------
    // Shared helpers (from coverage tests)
    // ---------------------------------------------------------------------------

    List<Override> baseOverrides() => [
      audioRecorderRepositoryProvider.overrideWithValue(
        mockAudioRecorderRepository,
      ),
      categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
      playerFactoryProvider.overrideWithValue(() => mockPlayer),
    ];

    Future<void> pumpModalContent(
      WidgetTester tester, {
      String categoryId = 'test-category',
      String? linkedId,
      List<Override> extraOverrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(),
            ...extraOverrides,
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AudioRecordingModalContent(
                categoryId: categoryId,
                linkedId: linkedId,
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pumpShowModalTrigger(
      WidgetTester tester, {
      String? categoryId,
      String? linkedId,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      AudioRecordingModal.show(
                        context,
                        categoryId: categoryId,
                        linkedId: linkedId,
                      );
                    },
                    child: const Text('Show Modal'),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    void stubCategory({
      String categoryId = 'test-category',
      FakeCategoryDefinition? category,
    }) {
      when(
        () => mockCategoryRepository.watchCategory(categoryId),
      ).thenAnswer(
        (_) => Stream.value(category ?? FakeCategoryDefinition()),
      );
    }

    group('AudioRecordingModal.show() - Static Method Coverage', () {
      testWidgets(
        'should set modal visible and category when show() is called',
        (tester) async {
          stubCategory();

          await pumpShowModalTrigger(
            tester,
            categoryId: 'test-category',
            linkedId: 'test-linked-id',
          );

          // Initial state - modal not visible
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ElevatedButton)),
          );
          var state = container.read(audioRecorderControllerProvider);
          expect(state.modalVisible, isFalse);

          // Tap button to show modal
          await tester.tap(find.text('Show Modal'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Verify modal is shown and state is updated
          state = container.read(audioRecorderControllerProvider);
          expect(state.modalVisible, isTrue);

          // Find modal content
          expect(find.byType(AudioRecordingModalContent), findsOneWidget);
        },
      );

      testWidgets('should set modal invisible when modal is dismissed', (
        tester,
      ) async {
        stubCategory();

        await pumpShowModalTrigger(
          tester,
          categoryId: 'test-category',
        );

        // Show modal
        await tester.tap(find.text('Show Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ElevatedButton)),
        );

        // Modal should be visible
        var state = container.read(audioRecorderControllerProvider);
        expect(state.modalVisible, isTrue);

        // Dismiss modal by tapping outside
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();

        // Modal should be invisible after dismissal
        state = container.read(audioRecorderControllerProvider);
        expect(state.modalVisible, isFalse);
      });

      testWidgets('should handle show() without categoryId', (tester) async {
        await pumpShowModalTrigger(tester);

        await tester.tap(find.text('Show Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ElevatedButton)),
        );
        final state = container.read(audioRecorderControllerProvider);

        expect(state.modalVisible, isTrue);
        expect(find.byType(AudioRecordingModalContent), findsOneWidget);
      });
    });

    group('Stop Button Rendering and _isRecording Coverage', () {
      testWidgets(
        'should render stop button UI when _isRecording returns true '
        '(recording state)',
        (tester) async {
          stubCategory();

          final recordingState = AudioRecorderState(
            status: AudioRecorderStatus.recording,
            progress: const Duration(seconds: 5),
            vu: 80,
            dBFS: -20,
            showIndicator: false,
            modalVisible: true,
          );

          await pumpModalContent(
            tester,
            extraOverrides: [
              realtimeAvailableProvider.overrideWith((_) async => false),
              audioRecorderControllerProvider.overrideWith(
                () => TestAudioRecorderController(recordingState),
              ),
            ],
          );

          await tester.pump();

          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 250));

          final stopControlsFinder = find.byKey(
            const ValueKey('stop_controls'),
          );
          expect(stopControlsFinder, findsOneWidget);
          expect(find.text('STOP'), findsOneWidget);
          expect(
            find.descendant(
              of: stopControlsFinder,
              matching: find.byType(Container),
            ),
            findsWidgets,
          );
        },
      );

      testWidgets(
        'should render stop button when _isRecording returns true '
        '(paused state)',
        (tester) async {
          stubCategory();

          final pausedState = AudioRecorderState(
            status: AudioRecorderStatus.paused,
            progress: const Duration(seconds: 10),
            vu: 0,
            dBFS: -60,
            showIndicator: false,
            modalVisible: true,
          );

          await pumpModalContent(
            tester,
            extraOverrides: [
              realtimeAvailableProvider.overrideWith((_) async => false),
              audioRecorderControllerProvider.overrideWith(
                () => TestAudioRecorderController(pausedState),
              ),
            ],
          );

          await tester.pump();

          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 250));

          final stopControlsFinder = find.byKey(
            const ValueKey('stop_controls'),
          );
          expect(stopControlsFinder, findsOneWidget);
          expect(find.text('STOP'), findsOneWidget);
        },
      );
    });

    group('Record Button Coverage', () {
      testWidgets('should call record when record button is tapped', (
        tester,
      ) async {
        stubCategory();

        await pumpModalContent(
          tester,
          linkedId: 'test-linked-id',
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        final recordButton = find.byKey(const ValueKey('record'));
        expect(recordButton, findsOneWidget);
        expect(find.text('RECORD'), findsOneWidget);

        await tester.tap(recordButton);
        await tester.pump();

        verify(
          () => mockAudioRecorderRepository.startRecording(),
        ).called(1);
      });
    });

    group('Checkbox onChange Callbacks Coverage', () {
      testWidgets(
        'should call setEnableSpeechRecognition when speech checkbox toggled',
        (tester) async {
          stubCategory();

          await pumpModalContent(
            tester,
            linkedId: 'task-1',
            extraOverrides: [
              checkboxVisibilityProvider((
                categoryId: 'test-category',
                linkedId: 'task-1',
              )).overrideWithValue(
                const AutomaticPromptVisibility(speech: true),
              ),
            ],
          );

          await tester.pump();

          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();

          final container = ProviderScope.containerOf(
            tester.element(find.byType(Scaffold)),
          );

          final speechCheckbox = find.byKey(
            const Key('speech_recognition_checkbox'),
          );
          expect(speechCheckbox, findsOneWidget);

          var state = container.read(audioRecorderControllerProvider);
          final initialValue = state.enableSpeechRecognition ?? true;

          await tester.tap(speechCheckbox);
          await tester.pump();

          state = container.read(audioRecorderControllerProvider);
          expect(state.enableSpeechRecognition, !initialValue);
        },
      );
    });

    group('Realtime Mode UI Coverage', () {
      testWidgets(
        'should render mode toggle when realtime is available',
        (tester) async {
          stubCategory();

          await pumpModalContent(
            tester,
            extraOverrides: [
              realtimeAvailableProvider.overrideWith((_) async => true),
            ],
          );

          await tester.pump();

          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(Switch), findsOneWidget);
        },
      );

      testWidgets(
        'should toggle between standard and realtime mode',
        (tester) async {
          stubCategory();

          await pumpModalContent(
            tester,
            extraOverrides: [
              realtimeAvailableProvider.overrideWith((_) async => true),
            ],
          );

          await tester.pump();

          await tester.pump(const Duration(milliseconds: 300));

          final switchWidget = find.byType(Switch);
          expect(switchWidget, findsOneWidget);

          await tester.tap(switchWidget);
          await tester.pump();

          final switchState = tester.widget<Switch>(switchWidget);
          expect(switchState.value, isTrue);
        },
      );

      testWidgets(
        'should render cancel button in realtime recording mode',
        (tester) async {
          stubCategory();

          final realtimeRecordingState = AudioRecorderState(
            status: AudioRecorderStatus.recording,
            progress: const Duration(seconds: 5),
            vu: 80,
            dBFS: -20,
            showIndicator: false,
            modalVisible: true,
            isRealtimeMode: true,
          );

          await pumpModalContent(
            tester,
            extraOverrides: [
              realtimeAvailableProvider.overrideWith((_) async => true),
              audioRecorderControllerProvider.overrideWith(
                () => TestAudioRecorderController(realtimeRecordingState),
              ),
            ],
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          expect(find.text('CANCEL'), findsOneWidget);
          expect(find.text('STOP'), findsOneWidget);
        },
      );

      testWidgets(
        'should render live transcript area with listening spinner',
        (tester) async {
          stubCategory();

          final realtimeRecordingState = AudioRecorderState(
            status: AudioRecorderStatus.recording,
            progress: const Duration(seconds: 3),
            vu: 60,
            dBFS: -30,
            showIndicator: false,
            modalVisible: true,
            isRealtimeMode: true,
          );

          await pumpModalContent(
            tester,
            extraOverrides: [
              realtimeAvailableProvider.overrideWith((_) async => true),
              audioRecorderControllerProvider.overrideWith(
                () => TestAudioRecorderController(realtimeRecordingState),
              ),
            ],
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );

      testWidgets(
        'should render live transcript text when available',
        (tester) async {
          stubCategory();

          final realtimeRecordingState = AudioRecorderState(
            status: AudioRecorderStatus.recording,
            progress: const Duration(seconds: 5),
            vu: 60,
            dBFS: -30,
            showIndicator: false,
            modalVisible: true,
            isRealtimeMode: true,
            partialTranscript: 'Hello this is a test transcription',
          );

          await pumpModalContent(
            tester,
            extraOverrides: [
              realtimeAvailableProvider.overrideWith((_) async => true),
              audioRecorderControllerProvider.overrideWith(
                () => TestAudioRecorderController(realtimeRecordingState),
              ),
            ],
          );

          await tester.pump();

          await tester.pump(const Duration(milliseconds: 300));

          expect(
            find.text('Hello this is a test transcription'),
            findsOneWidget,
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );

      testWidgets('tapping STOP in realtime mode calls stopRealtime', (
        tester,
      ) async {
        stubCategory();

        var stopRealtimeCalled = false;
        final realtimeRecordingState = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          progress: const Duration(seconds: 5),
          vu: 80,
          dBFS: -20,
          showIndicator: false,
          modalVisible: true,
          isRealtimeMode: true,
        );

        await pumpModalContent(
          tester,
          extraOverrides: [
            realtimeAvailableProvider.overrideWith((_) async => true),
            audioRecorderControllerProvider.overrideWith(
              () => _CallbackTrackingController(
                fixedState: realtimeRecordingState,
                onStopRealtimeCalled: () => stopRealtimeCalled = true,
              ),
            ),
          ],
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('STOP'), findsOneWidget);
        await tester.tap(find.text('STOP'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(stopRealtimeCalled, isTrue);
      });

      testWidgets('tapping CANCEL in realtime mode calls cancelRealtime', (
        tester,
      ) async {
        stubCategory();

        var cancelRealtimeCalled = false;
        final realtimeRecordingState = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          progress: const Duration(seconds: 5),
          vu: 80,
          dBFS: -20,
          showIndicator: false,
          modalVisible: true,
          isRealtimeMode: true,
        );

        await pumpModalContent(
          tester,
          extraOverrides: [
            realtimeAvailableProvider.overrideWith((_) async => true),
            audioRecorderControllerProvider.overrideWith(
              () => _CallbackTrackingController(
                fixedState: realtimeRecordingState,
                onCancelRealtimeCalled: () => cancelRealtimeCalled = true,
              ),
            ),
          ],
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('CANCEL'), findsOneWidget);
        await tester.tap(find.text('CANCEL'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(cancelRealtimeCalled, isTrue);
      });

      testWidgets('tapping RECORD in realtime mode calls recordRealtime', (
        tester,
      ) async {
        stubCategory();

        var recordRealtimeCalled = false;
        final idleState = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          progress: Duration.zero,
          vu: 0,
          dBFS: -160,
          showIndicator: false,
          modalVisible: true,
        );

        await pumpModalContent(
          tester,
          extraOverrides: [
            realtimeAvailableProvider.overrideWith((_) async => true),
            audioRecorderControllerProvider.overrideWith(
              () => _CallbackTrackingController(
                fixedState: idleState,
                onRecordRealtimeCalled: () => recordRealtimeCalled = true,
              ),
            ),
          ],
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        // Toggle to realtime mode first
        final switchWidget = find.byType(Switch);
        expect(switchWidget, findsOneWidget);
        await tester.tap(switchWidget);
        await tester.pump();

        // Tap the RECORD button (now in realtime mode)
        expect(find.text('RECORD'), findsOneWidget);
        await tester.tap(find.text('RECORD'));
        await tester.pump();

        expect(recordRealtimeCalled, isTrue);
      });

      testWidgets('should not show mode toggle when recording', (
        tester,
      ) async {
        stubCategory();

        final recordingState = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          progress: const Duration(seconds: 5),
          vu: 80,
          dBFS: -20,
          showIndicator: false,
          modalVisible: true,
        );

        await pumpModalContent(
          tester,
          extraOverrides: [
            realtimeAvailableProvider.overrideWith((_) async => true),
            audioRecorderControllerProvider.overrideWith(
              () => TestAudioRecorderController(recordingState),
            ),
          ],
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(Switch), findsNothing);
      });
    });
  });

  group('AudioRecordingModal - Task Type Detection', () {
    Metadata createMockMetadata(String id) {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      return Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        categoryId: 'test-category',
      );
    }

    Widget createTestWidgetWithEntry({
      required String linkedId,
      JournalEntity? linkedEntry,
      CategoryDefinition? category,
      bool shouldError = false,
      bool showSpeechCheckbox = false,
    }) {
      final categoryToUse = category ?? FakeCategoryDefinition();

      when(
        () => mockCategoryRepository.watchCategory('test-category'),
      ).thenAnswer((_) => Stream.value(categoryToUse));

      return ProviderScope(
        overrides: [
          audioRecorderRepositoryProvider.overrideWithValue(
            mockAudioRecorderRepository,
          ),
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          playerFactoryProvider.overrideWithValue(() => mockPlayer),
          entryControllerProvider(linkedId).overrideWith(
            () => FakeEntryController(
              mockEntry: linkedEntry,
              shouldError: shouldError,
            ),
          ),
          if (showSpeechCheckbox)
            checkboxVisibilityProvider((
              categoryId: 'test-category',
              linkedId: linkedId,
            )).overrideWithValue(
              const AutomaticPromptVisibility(speech: true),
            ),
        ],
        child: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ProviderScope.containerOf(context)
                  .read(audioRecorderControllerProvider.notifier)
                  .setEnableSpeechRecognition(enable: true);
            });

            return MaterialApp(
              home: Scaffold(
                body: AudioRecordingModalContent(
                  categoryId: 'test-category',
                  linkedId: linkedId,
                ),
              ),
            );
          },
        ),
      );
    }

    testWidgets('shows checkboxes when linked entry is a Task', (tester) async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      const uuid = Uuid();
      final openStatus = TaskStatus.open(
        id: uuid.v1(),
        createdAt: testDate,
        utcOffset: 0,
      );
      final mockTask = Task(
        meta: createMockMetadata('task-123'),
        data: TaskData(
          title: 'Test Task',
          status: openStatus,
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [openStatus],
        ),
      );

      await tester.pumpWidget(
        createTestWidgetWithEntry(
          linkedId: 'task-123',
          linkedEntry: mockTask,
          showSpeechCheckbox: true,
        ),
      );
      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Speech recognition checkbox should be visible for a Task
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
    });

    testWidgets('hides task checkboxes when linked entry is an Event', (
      tester,
    ) async {
      final mockEvent = JournalEvent(
        meta: createMockMetadata('event-123'),
        data: const EventData(
          title: 'Test Event',
          stars: 0,
          status: EventStatus.completed,
        ),
      );

      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        linkedId: 'event-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(
        () => mockCategoryRepository.watchCategory('test-category'),
      ).thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            playerFactoryProvider.overrideWithValue(() => mockPlayer),
            // Override entryControllerProvider to return an Event
            entryControllerProvider('event-123').overrideWith(
              () => FakeEntryController(mockEntry: mockEvent),
            ),
            checkboxVisibilityProvider((
              categoryId: 'test-category',
              linkedId: 'event-123',
            )).overrideWithValue(
              const AutomaticPromptVisibility(speech: true),
            ),
          ],
          child: Builder(
            builder: (context) {
              if (state.enableSpeechRecognition != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ProviderScope.containerOf(context)
                      .read(audioRecorderControllerProvider.notifier)
                      .setEnableSpeechRecognition(
                        enable: state.enableSpeechRecognition,
                      );
                });
              }

              return const MaterialApp(
                home: Scaffold(
                  body: AudioRecordingModalContent(
                    categoryId: 'test-category',
                    linkedId: 'event-123',
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Only speech recognition checkbox should be visible, not task-specific ones
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
    });

    testWidgets('hides task checkboxes when linked entry is a JournalEntry', (
      tester,
    ) async {
      final mockJournalEntry = JournalEntry(
        meta: createMockMetadata('journal-123'),
      );

      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        linkedId: 'journal-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(
        () => mockCategoryRepository.watchCategory('test-category'),
      ).thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            playerFactoryProvider.overrideWithValue(() => mockPlayer),
            entryControllerProvider('journal-123').overrideWith(
              () => FakeEntryController(mockEntry: mockJournalEntry),
            ),
            checkboxVisibilityProvider((
              categoryId: 'test-category',
              linkedId: 'journal-123',
            )).overrideWithValue(
              const AutomaticPromptVisibility(speech: true),
            ),
          ],
          child: Builder(
            builder: (context) {
              if (state.enableSpeechRecognition != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ProviderScope.containerOf(context)
                      .read(audioRecorderControllerProvider.notifier)
                      .setEnableSpeechRecognition(
                        enable: state.enableSpeechRecognition,
                      );
                });
              }

              return const MaterialApp(
                home: Scaffold(
                  body: AudioRecordingModalContent(
                    categoryId: 'test-category',
                    linkedId: 'journal-123',
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Only speech recognition should be visible
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
    });

    testWidgets('hides task checkboxes when entry is null', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        linkedId: 'nonexistent-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(
        () => mockCategoryRepository.watchCategory('test-category'),
      ).thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            playerFactoryProvider.overrideWithValue(() => mockPlayer),
            // Return null entry
            entryControllerProvider('nonexistent-123').overrideWith(
              () => FakeEntryController(mockEntry: null),
            ),
            checkboxVisibilityProvider((
              categoryId: 'test-category',
              linkedId: 'nonexistent-123',
            )).overrideWithValue(
              const AutomaticPromptVisibility(speech: true),
            ),
          ],
          child: Builder(
            builder: (context) {
              if (state.enableSpeechRecognition != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ProviderScope.containerOf(context)
                      .read(audioRecorderControllerProvider.notifier)
                      .setEnableSpeechRecognition(
                        enable: state.enableSpeechRecognition,
                      );
                });
              }

              return const MaterialApp(
                home: Scaffold(
                  body: AudioRecordingModalContent(
                    categoryId: 'test-category',
                    linkedId: 'nonexistent-123',
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Only speech recognition visible, task checkboxes hidden
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
    });

    testWidgets(
      'hides task checkboxes when entryController returns null value',
      (tester) async {
        final state = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: true,
          linkedId: 'null-value-123',
          enableSpeechRecognition: true,
        );

        // Set up category mock BEFORE creating widget
        when(
          () => mockCategoryRepository.watchCategory('test-category'),
        ).thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              audioRecorderRepositoryProvider.overrideWithValue(
                mockAudioRecorderRepository,
              ),
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
              playerFactoryProvider.overrideWithValue(() => mockPlayer),
              // Return AsyncValue with null value
              entryControllerProvider('null-value-123').overrideWith(
                () => FakeEntryController(mockEntry: null),
              ),
              checkboxVisibilityProvider((
                categoryId: 'test-category',
                linkedId: 'null-value-123',
              )).overrideWithValue(
                const AutomaticPromptVisibility(speech: true),
              ),
            ],
            child: Builder(
              builder: (context) {
                if (state.enableSpeechRecognition != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ProviderScope.containerOf(context)
                        .read(audioRecorderControllerProvider.notifier)
                        .setEnableSpeechRecognition(
                          enable: state.enableSpeechRecognition,
                        );
                  });
                }

                return const MaterialApp(
                  home: Scaffold(
                    body: AudioRecordingModalContent(
                      categoryId: 'test-category',
                      linkedId: 'null-value-123',
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pump();
        // Extra pump for Riverpod async provider resolution
        await tester.pump();

        // Only speech recognition visible
        expect(
          find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows task checkboxes optimistically during loading state', (
      tester,
    ) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        linkedId: 'loading-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(
        () => mockCategoryRepository.watchCategory('test-category'),
      ).thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            playerFactoryProvider.overrideWithValue(() => mockPlayer),
            // Return loading state
            entryControllerProvider('loading-123').overrideWith(
              () => FakeEntryController(isLoading: true),
            ),
            checkboxVisibilityProvider((
              categoryId: 'test-category',
              linkedId: 'loading-123',
            )).overrideWithValue(
              const AutomaticPromptVisibility(speech: true),
            ),
          ],
          child: Builder(
            builder: (context) {
              if (state.enableSpeechRecognition != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ProviderScope.containerOf(context)
                      .read(audioRecorderControllerProvider.notifier)
                      .setEnableSpeechRecognition(
                        enable: state.enableSpeechRecognition,
                      );
                });
              }

              return const MaterialApp(
                home: Scaffold(
                  body: AudioRecordingModalContent(
                    categoryId: 'test-category',
                    linkedId: 'loading-123',
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // All checkboxes visible optimistically during loading
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
    });

    testWidgets('hides task checkboxes on error state', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        linkedId: 'error-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(
        () => mockCategoryRepository.watchCategory('test-category'),
      ).thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            playerFactoryProvider.overrideWithValue(() => mockPlayer),
            // Override checkboxVisibilityProvider to simulate error state behavior
            // When entryController is in error state, isLinkedToTask should be false,
            // so only speech checkbox is visible
            checkboxVisibilityProvider((
              categoryId: 'test-category',
              linkedId: 'error-123',
            )).overrideWithValue(
              const AutomaticPromptVisibility(
                speech: true,
              ),
            ),
          ],
          child: Builder(
            builder: (context) {
              if (state.enableSpeechRecognition != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ProviderScope.containerOf(context)
                      .read(audioRecorderControllerProvider.notifier)
                      .setEnableSpeechRecognition(
                        enable: state.enableSpeechRecognition,
                      );
                });
              }

              return const MaterialApp(
                home: Scaffold(
                  body: AudioRecordingModalContent(
                    categoryId: 'test-category',
                    linkedId: 'error-123',
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      // Extra pumps for Riverpod async provider error state propagation
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Only speech recognition visible on error
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows Task checkboxes even with Task + no category prompts still respects category config',
      (tester) async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        const uuid = Uuid();
        final openStatus = TaskStatus.open(
          id: uuid.v1(),
          createdAt: testDate,
          utcOffset: 0,
        );
        final mockTask = Task(
          meta: createMockMetadata('task-123'),
          data: TaskData(
            title: 'Test Task',
            status: openStatus,
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [openStatus],
          ),
        );

        final categoryWithoutPrompts = FakeCategoryDefinition();

        // Set up category mock BEFORE creating widget
        when(
          () => mockCategoryRepository.watchCategory('test-category'),
        ).thenAnswer((_) => Stream.value(categoryWithoutPrompts));

        final state = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: true,
          linkedId: 'task-123',
          enableSpeechRecognition: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              audioRecorderRepositoryProvider.overrideWithValue(
                mockAudioRecorderRepository,
              ),
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
              playerFactoryProvider.overrideWithValue(() => mockPlayer),
              entryControllerProvider('task-123').overrideWith(
                () => FakeEntryController(mockEntry: mockTask),
              ),
              checkboxVisibilityProvider((
                categoryId: 'test-category',
                linkedId: 'task-123',
              )).overrideWithValue(
                const AutomaticPromptVisibility(speech: true),
              ),
            ],
            child: Builder(
              builder: (context) {
                if (state.enableSpeechRecognition != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ProviderScope.containerOf(context)
                        .read(audioRecorderControllerProvider.notifier)
                        .setEnableSpeechRecognition(
                          enable: state.enableSpeechRecognition,
                        );
                  });
                }

                return const MaterialApp(
                  home: Scaffold(
                    body: AudioRecordingModalContent(
                      categoryId: 'test-category',
                      linkedId: 'task-123',
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pump();
        // Extra pump for Riverpod async provider resolution
        await tester.pump();

        // Speech checkbox visible via profile-driven transcription
        expect(
          find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
          findsOneWidget,
        );
      },
    );
  });
}

/// Controller that tracks method calls for interaction tests
class _CallbackTrackingController extends AudioRecorderController {
  _CallbackTrackingController({
    required this.fixedState,
    this.onStopRealtimeCalled,
    this.onCancelRealtimeCalled,
    this.onRecordRealtimeCalled,
  });

  final AudioRecorderState fixedState;
  final VoidCallback? onStopRealtimeCalled;
  final VoidCallback? onCancelRealtimeCalled;
  final VoidCallback? onRecordRealtimeCalled;

  @override
  AudioRecorderState build() => fixedState;

  @override
  Future<String?> stopRealtime() async {
    onStopRealtimeCalled?.call();
    state = fixedState.copyWith(
      status: AudioRecorderStatus.stopped,
      modalVisible: false,
    );
    return null;
  }

  @override
  Future<void> cancelRealtime() async {
    onCancelRealtimeCalled?.call();
    state = fixedState.copyWith(
      status: AudioRecorderStatus.stopped,
      modalVisible: false,
    );
  }

  @override
  Future<void> recordRealtime({String? linkedId}) async {
    onRecordRealtimeCalled?.call();
  }

  @override
  Future<void> record({String? linkedId}) async {}

  @override
  Future<String?> stop() async => null;
}
