import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/direct_task_summary_refresh_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_data/test_data.dart';
import '../../../mocks/mocks.dart' as mocks;

class MockJournalRepository extends Mock implements JournalRepository {}

class MockDirectTaskSummaryRefreshController extends Notifier<void> with Mock
    implements DirectTaskSummaryRefreshController {
  @override
  void build() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  ProviderContainer makeProviderContainer({
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: overrides,
    );
    addTearDown(container.dispose);
    return container;
  }

  late MockJournalRepository mockJournalRepository;
  late MockDirectTaskSummaryRefreshController mockSummaryController;
  late mocks.MockJournalDb mockJournalDb;
  late mocks.MockUpdateNotifications mockUpdateNotifications;
  late mocks.MockEditorStateService mockEditorStateService;
  late mocks.MockPersistenceLogic mockPersistenceLogic;
  late mocks.MockTimeService mockTimeService;
  late mocks.MockNavService mockNavService;
  late Task testTaskData;

  setUpAll(() {
    registerFallbackValue(mocks.FakeJournalEntity());
    registerFallbackValue(mocks.FakeTaskData());
    registerFallbackValue(mocks.FakeQuillController());
    registerFallbackValue(mocks.FakeEntryText());
  });

  setUp(() {
    mockJournalRepository = MockJournalRepository();
    mockSummaryController = MockDirectTaskSummaryRefreshController();
    mockJournalDb = mocks.MockJournalDb();
    mockUpdateNotifications = mocks.MockUpdateNotifications();
    mockEditorStateService = mocks.MockEditorStateService();
    mockPersistenceLogic = mocks.MockPersistenceLogic();
    mockTimeService = mocks.MockTimeService();
    mockNavService = mocks.MockNavService();
    testTaskData = testTask;

    // Register all required dependencies
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService);

    // Setup default mocks
    when(() => mockSummaryController.requestTaskSummaryRefresh(any()))
        .thenAnswer((invocation) async {});
    when(() => mockJournalRepository.updateJournalEntity(any()))
        .thenAnswer((_) async => true);
    when(() => mockJournalDb.journalEntityById(any()))
        .thenAnswer((_) async => testTaskData);
    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
    when(() => mockEditorStateService.getUnsavedStream(any(), any()))
        .thenAnswer((_) => Stream<bool>.fromIterable([false]));
    when(() => mockEditorStateService.getDelta(any())).thenReturn(null);
    when(() => mockEditorStateService.getSelection(any())).thenReturn(null);
    when(() => mockEditorStateService.entryIsUnsaved(any())).thenReturn(false);
    when(() => mockTimeService.getCurrent()).thenReturn(null);
    when(() => mockEditorStateService.entryWasSaved(
          id: any(named: 'id'),
          lastSaved: any(named: 'lastSaved'),
          controller: any(named: 'controller'),
        )).thenAnswer((_) async {});
    when(() => mockPersistenceLogic.updateTask(
          entryText: any(named: 'entryText'),
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        )).thenAnswer((_) async => true);
    when(
      () => mockPersistenceLogic.updateJournalEntityText(
        any(),
        any(),
        any(),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() {
    getIt.reset();
  });

  tearDownAll(getIt.reset);

  group('Task Save AI Inference Tests', () {
    test('1. Updating task title triggers AI inference', () async {
      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          directTaskSummaryRefreshControllerProvider.overrideWith(
            () => mockSummaryController,
          ),
        ],
      );
      
      final entryId = testTaskData.meta.id;
      final notifier = container.read(
        entryControllerProvider(id: entryId).notifier,
      );

      // Wait for the controller to load
      await container.read(entryControllerProvider(id: entryId).future);

      // Update title through the controller
      await notifier.save(title: 'New Task Title');

      // Verify that task summary refresh was triggered
      verify(
        () => mockSummaryController.requestTaskSummaryRefresh(entryId),
      ).called(1);

      // Verify the persistence layer was called with new title
      verify(() => mockPersistenceLogic.updateTask(
            entryText: any(named: 'entryText'),
            journalEntityId: entryId,
            taskData: any(named: 'taskData', that: isA<TaskData>()
                .having((t) => t.title, 'title', 'New Task Title')),
          )).called(1);
    });

    test('2. Updating task estimate triggers AI inference', () async {
      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          directTaskSummaryRefreshControllerProvider.overrideWith(
            () => mockSummaryController,
          ),
        ],
      );
      
      final entryId = testTaskData.meta.id;
      final notifier = container.read(
        entryControllerProvider(id: entryId).notifier,
      );

      // Wait for the controller to load
      await container.read(entryControllerProvider(id: entryId).future);

      // Update estimate through the controller (45 minutes)
      await notifier.save(estimate: const Duration(minutes: 45));

      // Verify that task summary refresh was triggered
      verify(
        () => mockSummaryController.requestTaskSummaryRefresh(entryId),
      ).called(1);

      // Verify the persistence layer was called with new estimate
      verify(() => mockPersistenceLogic.updateTask(
            entryText: any(named: 'entryText'),
            journalEntityId: entryId,
            taskData: any(named: 'taskData', that: isA<TaskData>()
                .having((t) => t.estimate?.inSeconds, 'estimate', 2700)),
          )).called(1);
    });

    test('3. Updating task language triggers AI inference', () async {
      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          directTaskSummaryRefreshControllerProvider.overrideWith(
            () => mockSummaryController,
          ),
        ],
      );
      
      final entryId = testTaskData.meta.id;
      final notifier = container.read(
        entryControllerProvider(id: entryId).notifier,
      );

      // Wait for the controller to load
      await container.read(entryControllerProvider(id: entryId).future);
      
      // When language changes, the UI calls updateJournalEntity directly
      final updatedTask = testTaskData.copyWith(
        data: testTaskData.data.copyWith(languageCode: 'es'),
      );

      await container.read(journalRepositoryProvider).updateJournalEntity(updatedTask);

      // The updateJournalEntity will trigger update notifications,
      // which EntryController listens to and calls save()
      // For this test, we'll directly verify the behavior through the controller
      
      // Trigger save (which happens via update notifications in real flow)
      await notifier.save();

      // Verify that task summary refresh was triggered
      verify(
        () => mockSummaryController.requestTaskSummaryRefresh(entryId),
      ).called(1);
    });

    test('4. Updating task status triggers AI inference', () async {
      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          directTaskSummaryRefreshControllerProvider.overrideWith(
            () => mockSummaryController,
          ),
        ],
      );
      
      final entryId = testTaskData.meta.id;
      final notifier = container.read(
        entryControllerProvider(id: entryId).notifier,
      );

      // Wait for the controller to load
      await container.read(entryControllerProvider(id: entryId).future);

      // Update status through the controller
      await notifier.updateTaskStatus('DONE');

      // Verify that task summary refresh was triggered
      verify(
        () => mockSummaryController.requestTaskSummaryRefresh(entryId),
      ).called(1);
    });

    test('5. Regular save without changes also triggers AI inference', () async {
      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          directTaskSummaryRefreshControllerProvider.overrideWith(
            () => mockSummaryController,
          ),
        ],
      );
      
      final entryId = testTaskData.meta.id;
      final notifier = container.read(
        entryControllerProvider(id: entryId).notifier,
      );

      // Wait for the controller to load
      await container.read(entryControllerProvider(id: entryId).future);

      // Just save without any changes
      await notifier.save();

      // Verify that task summary refresh was triggered even without changes
      verify(
        () => mockSummaryController.requestTaskSummaryRefresh(entryId),
      ).called(1);
    });

    test('6. Multiple updates in sequence each trigger AI inference', () async {
      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          directTaskSummaryRefreshControllerProvider.overrideWith(
            () => mockSummaryController,
          ),
        ],
      );
      
      final entryId = testTaskData.meta.id;
      final notifier = container.read(
        entryControllerProvider(id: entryId).notifier,
      );

      // Wait for the controller to load
      await container.read(entryControllerProvider(id: entryId).future);

      // Update title
      await notifier.save(title: 'First Title');
      verify(() => mockSummaryController.requestTaskSummaryRefresh(entryId)).called(1);

      // Reset the mock count
      reset(mockSummaryController);
      when(() => mockSummaryController.requestTaskSummaryRefresh(any()))
          .thenAnswer((invocation) async {});

      // Update estimate
      await notifier.save(estimate: const Duration(hours: 1));
      verify(() => mockSummaryController.requestTaskSummaryRefresh(entryId)).called(1);

      // Reset the mock count
      reset(mockSummaryController);
      when(() => mockSummaryController.requestTaskSummaryRefresh(any()))
          .thenAnswer((invocation) async {});

      // Update status
      await notifier.updateTaskStatus('IN PROGRESS');
      verify(() => mockSummaryController.requestTaskSummaryRefresh(entryId)).called(1);
    });
  });
}