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
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/ui/lotti_animated_checkbox.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../../mocks/mocks.dart';

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockPlayer extends Mock implements Player {}

class MockPlayerState extends Mock implements PlayerState {}

class MockPlayerStream extends Mock implements PlayerStream {}

class FakePlayable extends Fake implements Playable {}

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
  Future<EntryState?> build({required String id}) {
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
    ).thenAnswer((_) async => false);
    when(
      () => mockAudioRecorderRepository.isPaused(),
    ).thenAnswer((_) async => false);
    when(
      () => mockAudioRecorderRepository.isRecording(),
    ).thenAnswer((_) async => false);
    when(
      () => mockAudioRecorderRepository.stopRecording(),
    ).thenAnswer((_) async {});
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
        entryControllerProvider(id: linkedTaskId).overrideWith(
          () => FakeEntryController(mockEntry: mockTask),
        ),
      );
    }

    // Override checkbox visibility when speech checkbox should be shown
    if (showSpeechCheckbox) {
      overrides.add(
        checkboxVisibilityProvider(
          categoryId: provideCategory ? 'test-category' : null,
          linkedId: linkedTaskId,
        ).overrideWithValue(
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
          entryControllerProvider(id: linkedId).overrideWith(
            () => FakeEntryController(
              mockEntry: linkedEntry,
              shouldError: shouldError,
            ),
          ),
          if (showSpeechCheckbox)
            checkboxVisibilityProvider(
              categoryId: 'test-category',
              linkedId: linkedId,
            ).overrideWithValue(
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
            entryControllerProvider(id: 'event-123').overrideWith(
              () => FakeEntryController(mockEntry: mockEvent),
            ),
            checkboxVisibilityProvider(
              categoryId: 'test-category',
              linkedId: 'event-123',
            ).overrideWithValue(
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
            entryControllerProvider(id: 'journal-123').overrideWith(
              () => FakeEntryController(mockEntry: mockJournalEntry),
            ),
            checkboxVisibilityProvider(
              categoryId: 'test-category',
              linkedId: 'journal-123',
            ).overrideWithValue(
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
            entryControllerProvider(id: 'nonexistent-123').overrideWith(
              () => FakeEntryController(mockEntry: null),
            ),
            checkboxVisibilityProvider(
              categoryId: 'test-category',
              linkedId: 'nonexistent-123',
            ).overrideWithValue(
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
              entryControllerProvider(id: 'null-value-123').overrideWith(
                () => FakeEntryController(mockEntry: null),
              ),
              checkboxVisibilityProvider(
                categoryId: 'test-category',
                linkedId: 'null-value-123',
              ).overrideWithValue(
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
            entryControllerProvider(id: 'loading-123').overrideWith(
              () => FakeEntryController(isLoading: true),
            ),
            checkboxVisibilityProvider(
              categoryId: 'test-category',
              linkedId: 'loading-123',
            ).overrideWithValue(
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
            checkboxVisibilityProvider(
              categoryId: 'test-category',
              linkedId: 'error-123',
            ).overrideWithValue(
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
              entryControllerProvider(id: 'task-123').overrideWith(
                () => FakeEntryController(mockEntry: mockTask),
              ),
              checkboxVisibilityProvider(
                categoryId: 'test-category',
                linkedId: 'task-123',
              ).overrideWithValue(
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
