// Coverage tests for AudioRecordingModal to reach 80-100% coverage
// This file focuses on testing uncovered code paths:
// - AudioRecordingModal.show() static method
// - Stop button interaction and navigation
// - Record button interaction
// - Checkbox onChange callbacks

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
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
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../../mocks/mocks.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockEditorStateService extends Mock implements EditorStateService {}

class MockNavService extends Mock implements NavService {}

class MockPlayer extends Mock implements Player {}

class MockPlayerState extends Mock implements PlayerState {}

class MockPlayerStream extends Mock implements PlayerStream {}

class FakePlayable extends Fake implements Playable {}

// Fake implementations for testing
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

  @override
  List<ChecklistCorrectionExample>? get correctionExamples => null;
}

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
    if (shouldError) {
      throw Exception('Test error');
    }

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

Task createMockTask(String id) {
  final now = DateTime(2024);
  const uuid = Uuid();
  final openStatus = TaskStatus.open(
    id: uuid.v1(),
    createdAt: now,
    utcOffset: 0,
  );

  return Task(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      categoryId: 'test-category',
    ),
    data: TaskData(
      title: 'Test Task',
      status: openStatus,
      dateFrom: now,
      dateTo: now,
      statusHistory: [openStatus],
    ),
  );
}

// Test helper controller that returns a fixed state
class TestAudioRecorderController extends AudioRecorderController {
  TestAudioRecorderController(this.fixedState);

  final AudioRecorderState fixedState;

  @override
  AudioRecorderState build() => fixedState;
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Returns the three provider overrides common to nearly every test.
List<Override> _baseOverrides({
  required MockAudioRecorderRepository audioRecorderRepo,
  required MockCategoryRepository categoryRepo,
  required MockPlayer player,
}) =>
    [
      audioRecorderRepositoryProvider.overrideWithValue(audioRecorderRepo),
      categoryRepositoryProvider.overrideWithValue(categoryRepo),
      playerFactoryProvider.overrideWithValue(() => player),
    ];

/// Pumps an [AudioRecordingModalContent] widget with localization and the
/// standard provider overrides.  Pass [extraOverrides] for per-test extras
/// (e.g. [audioRecorderControllerProvider], [realtimeAvailableProvider]).
Future<void> _pumpModalContent(
  WidgetTester tester, {
  required MockAudioRecorderRepository audioRecorderRepo,
  required MockCategoryRepository categoryRepo,
  required MockPlayer player,
  String categoryId = 'test-category',
  String? linkedId,
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ..._baseOverrides(
          audioRecorderRepo: audioRecorderRepo,
          categoryRepo: categoryRepo,
          player: player,
        ),
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

/// Pumps a widget that shows the modal via `AudioRecordingModal.show()`.
/// Returns after `pumpWidget` — caller should tap "Show Modal" and settle.
Future<void> _pumpShowModalTrigger(
  WidgetTester tester, {
  required MockAudioRecorderRepository audioRecorderRepo,
  required MockCategoryRepository categoryRepo,
  required MockPlayer player,
  String? categoryId,
  String? linkedId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _baseOverrides(
        audioRecorderRepo: audioRecorderRepo,
        categoryRepo: categoryRepo,
        player: player,
      ),
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

/// Stubs `mockCategoryRepo.watchCategory` for the given [categoryId].
void _stubCategory(
  MockCategoryRepository mockCategoryRepo, {
  String categoryId = 'test-category',
  FakeCategoryDefinition? category,
}) {
  when(() => mockCategoryRepo.watchCategory(categoryId))
      .thenAnswer((_) => Stream.value(category ?? FakeCategoryDefinition()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    when(() => mockPlayerStream.position)
        .thenAnswer((_) => positionController.stream);
    when(() => mockPlayerStream.buffer)
        .thenAnswer((_) => bufferController.stream);
    when(() => mockPlayerStream.completed)
        .thenAnswer((_) => completedController.stream);
    when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    when(() => mockPlayer.open(any(), play: any(named: 'play')))
        .thenAnswer((_) async {});
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
    when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});

    // Setup default mock behavior for AudioRecorderRepository
    when(() => mockAudioRecorderRepository.amplitudeStream).thenAnswer(
      (_) => const Stream<Amplitude>.empty(),
    );
    when(() => mockAudioRecorderRepository.hasPermission())
        .thenAnswer((_) async => true);
    when(() => mockAudioRecorderRepository.isPaused())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.isRecording())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.stopRecording())
        .thenAnswer((_) async => 'test-audio-path.m4a');
    when(() => mockAudioRecorderRepository.startRecording())
        .thenAnswer((_) async => null);
    when(() => mockAudioRecorderRepository.pauseRecording())
        .thenAnswer((_) async {});
    when(() => mockAudioRecorderRepository.resumeRecording())
        .thenAnswer((_) async {});

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

  group('AudioRecordingModal.show() - Static Method Coverage', () {
    testWidgets('should set modal visible and category when show() is called',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      await _pumpShowModalTrigger(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
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
      await tester.pumpAndSettle();

      // Verify modal is shown and state is updated
      state = container.read(audioRecorderControllerProvider);
      expect(state.modalVisible, isTrue);

      // Find modal content
      expect(find.byType(AudioRecordingModalContent), findsOneWidget);
    });

    testWidgets('should set modal invisible when modal is dismissed',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      await _pumpShowModalTrigger(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        categoryId: 'test-category',
      );

      // Show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ElevatedButton)),
      );

      // Modal should be visible
      var state = container.read(audioRecorderControllerProvider);
      expect(state.modalVisible, isTrue);

      // Dismiss modal by tapping outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Modal should be invisible after dismissal
      state = container.read(audioRecorderControllerProvider);
      expect(state.modalVisible, isFalse);
    });

    testWidgets('should handle show() without categoryId', (tester) async {
      await _pumpShowModalTrigger(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

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
        '(recording state)', (tester) async {
      _stubCategory(mockCategoryRepository);

      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        progress: const Duration(seconds: 5),
        vu: 80,
        dBFS: -20,
        showIndicator: false,
        modalVisible: true,
      );

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        extraOverrides: [
          realtimeAvailableProvider.overrideWith((_) async => false),
          audioRecorderControllerProvider
              .overrideWith(() => TestAudioRecorderController(recordingState)),
        ],
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));

      final stopControlsFinder = find.byKey(const ValueKey('stop_controls'));
      expect(stopControlsFinder, findsOneWidget);
      expect(find.text('STOP'), findsOneWidget);
      expect(
        find.descendant(
          of: stopControlsFinder,
          matching: find.byType(Container),
        ),
        findsWidgets,
      );
    });

    testWidgets(
        'should render stop button when _isRecording returns true '
        '(paused state)', (tester) async {
      _stubCategory(mockCategoryRepository);

      final pausedState = AudioRecorderState(
        status: AudioRecorderStatus.paused,
        progress: const Duration(seconds: 10),
        vu: 0,
        dBFS: -60,
        showIndicator: false,
        modalVisible: true,
      );

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        extraOverrides: [
          realtimeAvailableProvider.overrideWith((_) async => false),
          audioRecorderControllerProvider
              .overrideWith(() => TestAudioRecorderController(pausedState)),
        ],
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));

      final stopControlsFinder = find.byKey(const ValueKey('stop_controls'));
      expect(stopControlsFinder, findsOneWidget);
      expect(find.text('STOP'), findsOneWidget);
    });
  });

  group('Record Button Coverage', () {
    testWidgets('should call record when record button is tapped',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        linkedId: 'test-linked-id',
      );

      await tester.pumpAndSettle();

      final recordButton = find.byKey(const ValueKey('record'));
      expect(recordButton, findsOneWidget);
      expect(find.text('RECORD'), findsOneWidget);

      await tester.tap(recordButton);
      await tester.pumpAndSettle();

      verify(() => mockAudioRecorderRepository.startRecording()).called(1);
    });
  });

  group('Checkbox onChange Callbacks Coverage', () {
    testWidgets(
        'should call setEnableSpeechRecognition when speech checkbox toggled',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
      );

      await tester.pumpAndSettle();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );

      final speechCheckbox =
          find.byKey(const Key('speech_recognition_checkbox'));
      expect(speechCheckbox, findsOneWidget);

      var state = container.read(audioRecorderControllerProvider);
      final initialValue = state.enableSpeechRecognition ?? true;

      await tester.tap(speechCheckbox);
      await tester.pumpAndSettle();

      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, !initialValue);
    });

    testWidgets(
        'should call setEnableChecklistUpdates when checklist checkbox toggled',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        linkedId: 'task-123',
        extraOverrides: [
          entryControllerProvider(id: 'task-123').overrideWith(
            () => FakeEntryController(
              mockEntry: createMockTask('task-123'),
            ),
          ),
        ],
      );

      await tester.pumpAndSettle();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );

      // Enable speech recognition to reveal checklist checkbox
      container
          .read(audioRecorderControllerProvider.notifier)
          .setEnableSpeechRecognition(enable: true);
      await tester.pumpAndSettle();

      final checklistCheckbox =
          find.byKey(const Key('checklist_updates_checkbox'));
      expect(checklistCheckbox, findsOneWidget);

      var state = container.read(audioRecorderControllerProvider);
      final initialValue = state.enableChecklistUpdates ?? true;

      await tester.tap(checklistCheckbox);
      await tester.pumpAndSettle();

      state = container.read(audioRecorderControllerProvider);
      expect(state.enableChecklistUpdates, !initialValue);
    });

    testWidgets(
        'should call setEnableTaskSummary when task summary checkbox toggled',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        linkedId: 'task-456',
        extraOverrides: [
          entryControllerProvider(id: 'task-456').overrideWith(
            () => FakeEntryController(
              mockEntry: createMockTask('task-456'),
            ),
          ),
        ],
      );

      await tester.pumpAndSettle();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );

      // Enable speech recognition to reveal task summary checkbox
      container
          .read(audioRecorderControllerProvider.notifier)
          .setEnableSpeechRecognition(enable: true);
      await tester.pumpAndSettle();

      final summaryCheckbox = find.byKey(const Key('task_summary_checkbox'));
      expect(summaryCheckbox, findsOneWidget);

      var state = container.read(audioRecorderControllerProvider);
      final initialValue = state.enableTaskSummary ?? true;

      await tester.tap(summaryCheckbox);
      await tester.pumpAndSettle();

      state = container.read(audioRecorderControllerProvider);
      expect(state.enableTaskSummary, !initialValue);
    });
  });

  group('Realtime Mode UI Coverage', () {
    testWidgets('should render mode toggle when realtime is available',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        extraOverrides: [
          realtimeAvailableProvider.overrideWith((_) async => true),
        ],
      );

      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('should toggle between standard and realtime mode',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        extraOverrides: [
          realtimeAvailableProvider.overrideWith((_) async => true),
        ],
      );

      await tester.pumpAndSettle();

      final switchWidget = find.byType(Switch);
      expect(switchWidget, findsOneWidget);

      await tester.tap(switchWidget);
      await tester.pumpAndSettle();

      final switchState = tester.widget<Switch>(switchWidget);
      expect(switchState.value, isTrue);
    });

    testWidgets('should render cancel button in realtime recording mode',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      final realtimeRecordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        progress: const Duration(seconds: 5),
        vu: 80,
        dBFS: -20,
        showIndicator: false,
        modalVisible: true,
        isRealtimeMode: true,
      );

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
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
    });

    testWidgets('should render live transcript area with listening spinner',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      final realtimeRecordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        progress: const Duration(seconds: 3),
        vu: 60,
        dBFS: -30,
        showIndicator: false,
        modalVisible: true,
        isRealtimeMode: true,
      );

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
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
    });

    testWidgets('should render live transcript text when available',
        (tester) async {
      _stubCategory(mockCategoryRepository);

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

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        extraOverrides: [
          realtimeAvailableProvider.overrideWith((_) async => true),
          audioRecorderControllerProvider.overrideWith(
            () => TestAudioRecorderController(realtimeRecordingState),
          ),
        ],
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Hello this is a test transcription'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tapping STOP in realtime mode calls stopRealtime',
        (tester) async {
      _stubCategory(mockCategoryRepository);

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

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
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
      await tester.pumpAndSettle();

      expect(stopRealtimeCalled, isTrue);
    });

    testWidgets('tapping CANCEL in realtime mode calls cancelRealtime',
        (tester) async {
      _stubCategory(mockCategoryRepository);

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

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
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
      await tester.pumpAndSettle();

      expect(cancelRealtimeCalled, isTrue);
    });

    testWidgets('tapping RECORD in realtime mode calls recordRealtime',
        (tester) async {
      _stubCategory(mockCategoryRepository);

      var recordRealtimeCalled = false;
      final idleState = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        vu: 0,
        dBFS: -160,
        showIndicator: false,
        modalVisible: true,
      );

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
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

      await tester.pumpAndSettle();

      // Toggle to realtime mode first
      final switchWidget = find.byType(Switch);
      expect(switchWidget, findsOneWidget);
      await tester.tap(switchWidget);
      await tester.pumpAndSettle();

      // Tap the RECORD button (now in realtime mode)
      expect(find.text('RECORD'), findsOneWidget);
      await tester.tap(find.text('RECORD'));
      await tester.pumpAndSettle();

      expect(recordRealtimeCalled, isTrue);
    });

    testWidgets('should not show mode toggle when recording', (tester) async {
      _stubCategory(mockCategoryRepository);

      final recordingState = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        progress: const Duration(seconds: 5),
        vu: 80,
        dBFS: -20,
        showIndicator: false,
        modalVisible: true,
      );

      await _pumpModalContent(
        tester,
        audioRecorderRepo: mockAudioRecorderRepository,
        categoryRepo: mockCategoryRepository,
        player: mockPlayer,
        extraOverrides: [
          realtimeAvailableProvider.overrideWith((_) async => true),
          audioRecorderControllerProvider
              .overrideWith(() => TestAudioRecorderController(recordingState)),
        ],
      );

      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNothing);
    });
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
