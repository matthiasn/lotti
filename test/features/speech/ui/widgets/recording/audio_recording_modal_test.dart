// ignore_for_file: avoid_redundant_argument_values
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
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
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../../mocks/mocks.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockAudioPlayerCubit extends Mock implements AudioPlayerCubit {}

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockEditorStateService extends Mock implements EditorStateService {}

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
      throw Exception('Test error');
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
  FakeCategoryDefinition({
    this.includeTranscriptionPrompts = true,
    this.includeChecklistPrompts = true,
    this.includeTaskSummaryPrompts = true,
  });

  final bool includeTranscriptionPrompts;
  final bool includeChecklistPrompts;
  final bool includeTaskSummaryPrompts;

  @override
  String get id => 'test-category';

  @override
  String get name => 'Test Category';

  @override
  DateTime get createdAt => DateTime.now();

  @override
  DateTime get updatedAt => DateTime.now();

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
  List<String>? get allowedPromptIds => null;

  @override
  List<String>? get speechDictionary => null;

  @override
  Map<AiResponseType, List<String>>? get automaticPrompts {
    final prompts = <AiResponseType, List<String>>{};

    if (includeTranscriptionPrompts) {
      prompts[AiResponseType.audioTranscription] = ['transcription-prompt'];
    }

    if (includeTaskSummaryPrompts) {
      prompts[AiResponseType.taskSummary] = ['summary-prompt'];
    }

    if (includeChecklistPrompts) {
      prompts[AiResponseType.checklistUpdates] = ['checklist-prompt'];
    }

    return prompts.isEmpty ? null : prompts;
  }

  @override
  CategoryIcon? get icon => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Font downloads are centrally configured in test/flutter_test_config.dart

  late MockLoggingService mockLoggingService;
  late MockAudioPlayerCubit mockAudioPlayerCubit;
  late MockAudioRecorderRepository mockAudioRecorderRepository;
  late MockCategoryRepository mockCategoryRepository;
  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockTimeService mockTimeService;
  late MockNavService mockNavService;

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockAudioPlayerCubit = MockAudioPlayerCubit();
    mockAudioRecorderRepository = MockAudioRecorderRepository();
    mockCategoryRepository = MockCategoryRepository();
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockUpdateNotifications = MockUpdateNotifications();
    mockTimeService = MockTimeService();
    mockNavService = MockNavService();

    // Setup default mock behavior for AudioPlayerCubit
    when(() => mockAudioPlayerCubit.state).thenReturn(
      AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        totalDuration: Duration.zero,
        progress: Duration.zero,
        pausedAt: Duration.zero,
        speed: 1,
        showTranscriptsList: false,
      ),
    );
    when(() => mockAudioPlayerCubit.pause()).thenAnswer((_) async {});

    // Setup default mock behavior for AudioRecorderRepository
    when(() => mockAudioRecorderRepository.amplitudeStream).thenAnswer(
      (_) => const Stream<Amplitude>.empty(),
    );
    when(() => mockAudioRecorderRepository.hasPermission())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.isPaused())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.isRecording())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.stopRecording())
        .thenAnswer((_) async {});
    when(() => mockAudioRecorderRepository.startRecording())
        .thenAnswer((_) async => null);
    when(() => mockAudioRecorderRepository.pauseRecording())
        .thenAnswer((_) async {});
    when(() => mockAudioRecorderRepository.resumeRecording())
        .thenAnswer((_) async {});

    // Register mocks with GetIt
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<AudioPlayerCubit>(mockAudioPlayerCubit)
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService);
  });

  tearDown(getIt.reset);

  Widget createTestWidget({
    AudioRecorderState? state,
    CategoryDefinition? category,
    String? linkedTaskId,
    bool provideCategory = true,
  }) {
    final categoryToUse = category ?? FakeCategoryDefinition();

    // Set up category mock BEFORE creating widget (critical for synchronous resolution)
    if (provideCategory) {
      when(() => mockCategoryRepository.watchCategory('test-category'))
          .thenAnswer((_) => Stream.value(categoryToUse));
    }

    // Create a mock Task entity when linkedTaskId is provided
    final mockTask = linkedTaskId != null
        ? Task(
            meta: Metadata(
              id: linkedTaskId,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: TaskData(
              title: 'Test Task',
              status: TaskStatus.open(
                id: const Uuid().v1(),
                createdAt: DateTime.now(),
                utcOffset: 0,
              ),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              statusHistory: [
                TaskStatus.open(
                  id: const Uuid().v1(),
                  createdAt: DateTime.now(),
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
    ];

    // Override the entryControllerProvider if linkedTaskId is provided
    if (linkedTaskId != null && mockTask != null) {
      overrides.add(
        entryControllerProvider(id: linkedTaskId).overrideWith(
          () => FakeEntryController(mockEntry: mockTask),
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
                ..setEnableSpeechRecognition(
                  enable: state.enableSpeechRecognition,
                )
                ..setEnableChecklistUpdates(
                  enable: state.enableChecklistUpdates,
                )
                ..setEnableTaskSummary(
                  enable: state.enableTaskSummary,
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
    testWidgets('shows checkbox when transcription prompts exist',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
    });

    testWidgets('hides checkbox when transcription prompts are absent',
        (tester) async {
      final category =
          FakeCategoryDefinition(includeTranscriptionPrompts: false);

      await tester.pumpWidget(createTestWidget(category: category));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsNothing,
      );
    });
  });

  group('AudioRecordingModal - Checklist Updates Checkbox', () {
    testWidgets(
        'should show checklist updates checkbox when linked to task and speech recognition is enabled',
        (tester) async {
      // Enable speech recognition to make checklist updates visible
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Find the checklist updates checkbox by looking for the LottiAnimatedCheckbox
      // with the 'Checklist Updates' label
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsOneWidget);
    });

    testWidgets(
        'should NOT show checklist updates checkbox when not linked to task',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Should not find the checklist updates checkbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsNothing);
    });

    testWidgets(
        'should NOT show checklist updates checkbox when speech recognition is disabled',
        (tester) async {
      // Disable speech recognition to hide checklist updates
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: false,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Should not find the checklist updates checkbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsNothing);
    });

    testWidgets('should be enabled when category has automatic prompts',
        (tester) async {
      final category = FakeCategoryDefinition();
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Find the LottiAnimatedCheckbox for checklist updates
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsOneWidget);

      // The checkbox should be enabled
      final checkboxWidget =
          tester.widget<LottiAnimatedCheckbox>(checkboxFinder);
      expect(checkboxWidget.enabled, isTrue);
    });

    testWidgets('should be checked by default when preference is null',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Find the LottiAnimatedCheckbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      final checkboxWidget =
          tester.widget<LottiAnimatedCheckbox>(checkboxFinder);

      // Should be checked (true) when category has automatic prompts
      expect(checkboxWidget.value, isTrue);
    });

    testWidgets('should reflect user preference when set to false',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
        enableChecklistUpdates: false,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Find the LottiAnimatedCheckbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      final checkboxWidget =
          tester.widget<LottiAnimatedCheckbox>(checkboxFinder);

      // Should be unchecked
      expect(checkboxWidget.value, isFalse);
    });

    testWidgets(
        'should not render when category lacks transcription prompts despite having checklist prompts',
        (tester) async {
      final category = FakeCategoryDefinition(
        includeTranscriptionPrompts: false,
      );

      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsNothing,
      );
    });

    testWidgets('should call setEnableChecklistUpdates when toggled',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
        enableChecklistUpdates: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Find and tap the checkbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Verify the state was updated (the checkbox toggles from true to false)
      final updatedState = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(audioRecorderControllerProvider);
      expect(updatedState.enableChecklistUpdates, isFalse);
    });

    testWidgets('should not render when category has no checklist prompts',
        (tester) async {
      // Create a category without checklist prompts
      final category = FakeCategoryDefinition(includeChecklistPrompts: false);
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Checkbox should not be rendered without prompts
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsNothing);
    });

    testWidgets('should show correct label text', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Find the label
      expect(find.text('Checklist Updates'), findsOneWidget);
    });

    testWidgets('should maintain state during recording lifecycle',
        (tester) async {
      // Start with recording state
      var state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
        enableChecklistUpdates: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Verify initial state
      var checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      var checkboxWidget = tester.widget<LottiAnimatedCheckbox>(checkboxFinder);
      expect(checkboxWidget.value, isTrue);

      // Simulate state change to paused - rebuild widget with new state
      state = state.copyWith(status: AudioRecorderStatus.paused);
      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Checkbox should still be checked
      checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      checkboxWidget = tester.widget<LottiAnimatedCheckbox>(checkboxFinder);
      expect(checkboxWidget.value, isTrue);
    });
  });

  group('AudioRecordingModal - Task Summary Checkbox', () {
    testWidgets('shows checkbox when prompts exist and task is linked',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsOneWidget,
      );
    });

    testWidgets('hides checkbox when category has no task summary prompts',
        (tester) async {
      final category = FakeCategoryDefinition(
        includeTaskSummaryPrompts: false,
      );

      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets('hides checkbox when speech recognition is disabled',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: false,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets('hides checkbox when not linked to task', (tester) async {
      // Category has summary prompts but no linked task id provided
      final category = FakeCategoryDefinition(
        includeTaskSummaryPrompts: true,
      );

      await tester.pumpWidget(createTestWidget(
        category: category,
        linkedTaskId: null,
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets(
        'hides checkbox when summary prompts exist but no transcription',
        (tester) async {
      final category = FakeCategoryDefinition(
        includeTranscriptionPrompts: false,
        includeTaskSummaryPrompts: true,
      );
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });
  });

  group('AudioRecordingModal - Visibility Integration', () {
    testWidgets('hides entire section when no categoryId provided',
        (tester) async {
      await tester.pumpWidget(createTestWidget(provideCategory: false));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(
          find.byKey(const Key('speech_recognition_checkbox')), findsNothing);
      expect(find.byKey(const Key('checklist_updates_checkbox')), findsNothing);
      expect(find.byKey(const Key('task_summary_checkbox')), findsNothing);
      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });

    testWidgets('hides when category stream returns null', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          provideCategory: false,
          linkedTaskId: 'task-1',
        ),
      );
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });

    testWidgets('shows keys and hides dependents when Speech toggled off',
        (tester) async {
      final category = FakeCategoryDefinition();
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-1',
        enableSpeechRecognition: true,
        enableChecklistUpdates: true,
        enableTaskSummary: true,
      );

      await tester.pumpWidget(
        createTestWidget(
          state: state,
          category: category,
          linkedTaskId: 'task-1',
        ),
      );
      await tester.pump(); // Build initial frame
      await tester.pump(); // Execute postFrameCallback
      await tester.pump(); // Process state update from postFrameCallback
      await tester.pump(); // Allow async providers to resolve
      await tester.pump(); // Rebuild with resolved provider data

      // Initially all three should be present
      expect(
          find.byKey(const Key('speech_recognition_checkbox')), findsOneWidget);
      expect(
          find.byKey(const Key('checklist_updates_checkbox')), findsOneWidget);
      expect(find.byKey(const Key('task_summary_checkbox')), findsOneWidget);

      // Toggle speech off
      await tester.tap(find.byKey(const Key('speech_recognition_checkbox')));
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Speech remains (can re-enable), dependents are hidden
      expect(
          find.byKey(const Key('speech_recognition_checkbox')), findsOneWidget);
      expect(find.byKey(const Key('checklist_updates_checkbox')), findsNothing);
      expect(find.byKey(const Key('task_summary_checkbox')), findsNothing);
    });

    testWidgets('hides section when automaticPrompts is empty', (tester) async {
      final category = FakeCategoryDefinition(
        includeTranscriptionPrompts: false,
        includeChecklistPrompts: false,
        includeTaskSummaryPrompts: false,
      );

      await tester.pumpWidget(
        createTestWidget(
          category: category,
          linkedTaskId: 'task-1',
        ),
      );
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });
  });

  group('AudioRecordingModal - Task Type Detection', () {
    Metadata createMockMetadata(String id) {
      return Metadata(
        id: id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        categoryId: 'test-category',
      );
    }

    Widget createTestWidgetWithEntry({
      required String linkedId,
      JournalEntity? linkedEntry,
      CategoryDefinition? category,
      bool shouldError = false,
    }) {
      final categoryToUse = category ?? FakeCategoryDefinition();

      when(() => mockCategoryRepository.watchCategory('test-category'))
          .thenAnswer((_) => Stream.value(categoryToUse));

      return ProviderScope(
        overrides: [
          audioRecorderRepositoryProvider.overrideWithValue(
            mockAudioRecorderRepository,
          ),
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          entryControllerProvider(id: linkedId).overrideWith(
            () => FakeEntryController(
              mockEntry: linkedEntry,
              shouldError: shouldError,
            ),
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
      final now = DateTime.now();
      const uuid = Uuid();
      final openStatus = TaskStatus.open(
        id: uuid.v1(),
        createdAt: now,
        utcOffset: 0,
      );
      final mockTask = Task(
        meta: createMockMetadata('task-123'),
        data: TaskData(
          title: 'Test Task',
          status: openStatus,
          dateFrom: now,
          dateTo: now,
          statusHistory: [openStatus],
        ),
      );

      await tester.pumpWidget(
        createTestWidgetWithEntry(
          linkedId: 'task-123',
          linkedEntry: mockTask,
        ),
      );
      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // All three checkboxes should be visible for a Task
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsOneWidget,
      );
    });

    testWidgets('hides task checkboxes when linked entry is an Event',
        (tester) async {
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
        language: 'en',
        linkedId: 'event-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(() => mockCategoryRepository.watchCategory('test-category'))
          .thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            // Override entryControllerProvider to return an Event
            entryControllerProvider(id: 'event-123').overrideWith(
              () => FakeEntryController(mockEntry: mockEvent),
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

      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Only speech recognition checkbox should be visible, not task-specific ones
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsNothing,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets('hides task checkboxes when linked entry is a JournalEntry',
        (tester) async {
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
        language: 'en',
        linkedId: 'journal-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(() => mockCategoryRepository.watchCategory('test-category'))
          .thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            entryControllerProvider(id: 'journal-123').overrideWith(
              () => FakeEntryController(mockEntry: mockJournalEntry),
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

      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Only speech recognition should be visible
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsNothing,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
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
        language: 'en',
        linkedId: 'nonexistent-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(() => mockCategoryRepository.watchCategory('test-category'))
          .thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            // Return null entry
            entryControllerProvider(id: 'nonexistent-123').overrideWith(
              () => FakeEntryController(mockEntry: null),
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

      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Only speech recognition visible, task checkboxes hidden
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsNothing,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets('hides task checkboxes when entryController returns null value',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'null-value-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(() => mockCategoryRepository.watchCategory('test-category'))
          .thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            // Return AsyncValue with null value
            entryControllerProvider(id: 'null-value-123').overrideWith(
              () => FakeEntryController(mockEntry: null),
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

      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Only speech recognition visible
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsNothing,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets('shows task checkboxes optimistically during loading state',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'loading-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(() => mockCategoryRepository.watchCategory('test-category'))
          .thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            // Return loading state
            entryControllerProvider(id: 'loading-123').overrideWith(
              () => FakeEntryController(isLoading: true),
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

      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // All checkboxes visible optimistically during loading
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
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
        language: 'en',
        linkedId: 'error-123',
        enableSpeechRecognition: true,
      );

      // Set up category mock BEFORE creating widget
      when(() => mockCategoryRepository.watchCategory('test-category'))
          .thenAnswer((_) => Stream.value(FakeCategoryDefinition()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            // Return error state
            entryControllerProvider(id: 'error-123').overrideWith(
              () => FakeEntryController(shouldError: true),
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

      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Only speech recognition visible on error
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsNothing,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets(
        'shows Task checkboxes even with Task + no category prompts still respects category config',
        (tester) async {
      final now = DateTime.now();
      const uuid = Uuid();
      final openStatus = TaskStatus.open(
        id: uuid.v1(),
        createdAt: now,
        utcOffset: 0,
      );
      final mockTask = Task(
        meta: createMockMetadata('task-123'),
        data: TaskData(
          title: 'Test Task',
          status: openStatus,
          dateFrom: now,
          dateTo: now,
          statusHistory: [openStatus],
        ),
      );

      final categoryWithoutPrompts = FakeCategoryDefinition(
        includeChecklistPrompts: false,
        includeTaskSummaryPrompts: false,
      );

      // Set up category mock BEFORE creating widget
      when(() => mockCategoryRepository.watchCategory('test-category'))
          .thenAnswer((_) => Stream.value(categoryWithoutPrompts));

      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            entryControllerProvider(id: 'task-123').overrideWith(
              () => FakeEntryController(mockEntry: mockTask),
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

      await tester.pumpAndSettle();
      // Extra pump for Riverpod async provider resolution
      await tester.pump();

      // Task type detected but category config prevents checkboxes
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsNothing,
      );
      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });
  });
}
