import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

// Added FakeEventData
class FakeEventData extends Fake implements EventData {}

// Definitions for sample JournalImage for testing addTextToImage
const _testImageEntryId = 'image_id_001';
final _testImageDateFrom = DateTime(2023, 10, 26, 10);
final _testImageCreatedAt = DateTime(2023, 10, 26, 9);
final _testImageUpdatedAt = DateTime(2023, 10, 26, 9, 30);
final _testImageCapturedAt = DateTime(2023, 10, 26, 9, 55);

final _testImageData = ImageData(
  capturedAt: _testImageCapturedAt,
  imageId:
      _testImageEntryId, // Assuming imageId within ImageData can be same as entry id
  imageFile: 'image.jpg',
  imageDirectory: '/path/to/image',
);

final JournalImage testImageEntryNoText = JournalImage(
  meta: Metadata(
    id: _testImageEntryId,
    createdAt: _testImageCreatedAt,
    updatedAt: _testImageUpdatedAt,
    dateFrom: _testImageDateFrom,
    dateTo:
        _testImageDateFrom, // Consistent with how dateTo is used in addTextToImage context
    vectorClock: const VectorClock({'device': 1}),
    starred: false,
    private: false,
  ),
  data: _testImageData,
);

final JournalImage testImageEntryWithMarkdown = testImageEntryNoText.copyWith(
  entryText: const EntryText(
    plainText: 'Initial Markdown Text',
    markdown: 'Initial Markdown Text',
  ),
);

// Definitions for sample Task and ChecklistItems for testing updateChecklistOrder
const _testTaskId = 'task_id_001';
final _testTaskDateFrom = DateTime(2023, 11, 1, 10);
final _testTaskCreatedAt = DateTime(2023, 11, 1, 9);
final _testTaskUpdatedAt = DateTime(2023, 11, 1, 9, 30);

// Helper for creating TaskStatus for test data
final _testTaskOpenStatus = TaskStatus.open(
  id: 'status_open_id',
  createdAt: _testTaskCreatedAt,
  utcOffset: 0,
);

final ChecklistItem testChecklistItem1 = ChecklistItem(
  meta: Metadata(
    id: 'cl_item_1',
    createdAt: _testTaskCreatedAt,
    updatedAt: _testTaskUpdatedAt,
    dateFrom: _testTaskDateFrom,
    dateTo: _testTaskDateFrom,
    vectorClock: const VectorClock({'device': 1}),
    starred: false,
    private: false,
  ),
  data: const ChecklistItemData(
    title: 'Item 1',
    isChecked: false,
    linkedChecklists: [],
  ),
);

final ChecklistItem testChecklistItem2 = ChecklistItem(
  meta: Metadata(
    id: 'cl_item_2',
    createdAt: _testTaskCreatedAt,
    updatedAt: _testTaskUpdatedAt,
    dateFrom: _testTaskDateFrom,
    dateTo: _testTaskDateFrom,
    vectorClock: const VectorClock({'device': 1}),
    starred: false,
    private: false,
  ),
  data: const ChecklistItemData(
    title: 'Item 2',
    isChecked: false,
    linkedChecklists: [],
  ),
);

final ChecklistItem testChecklistItem3Deleted = ChecklistItem(
  meta: Metadata(
    id: 'cl_item_3_deleted',
    createdAt: _testTaskCreatedAt,
    updatedAt: _testTaskUpdatedAt,
    dateFrom: _testTaskDateFrom,
    dateTo: _testTaskDateFrom,
    vectorClock: const VectorClock({'device': 1}),
    deletedAt: _testTaskUpdatedAt, // Mark as deleted
    starred: false,
    private: false,
  ),
  data: const ChecklistItemData(
    title: 'Item 3',
    isChecked: true,
    linkedChecklists: [],
  ),
);

final Task testTaskEntry = Task(
  meta: Metadata(
    id: _testTaskId,
    createdAt: _testTaskCreatedAt,
    updatedAt: _testTaskUpdatedAt,
    dateFrom: _testTaskDateFrom,
    dateTo: _testTaskDateFrom,
    vectorClock: const VectorClock({'device': 1}),
    starred: false,
    private: false,
  ),
  data: TaskData(
    title: 'Test Task with Checklists',
    status: _testTaskOpenStatus, // Use helper
    dateFrom: _testTaskDateFrom, // TaskData also has dateFrom/dateTo
    dateTo: _testTaskDateFrom,
    statusHistory: [_testTaskOpenStatus], // Provide history
    checklistIds: [testChecklistItem1.id, testChecklistItem2.id],
  ),
  entryText: const EntryText(plainText: 'Initial task description'),
);

// Test data for JournalEvent
const _testEventId = 'event_id_001';
final _testEventDateFrom = DateTime(2023, 11, 10, 14);
final _testEventCreatedAt = DateTime(2023, 11, 10, 13);
final _testEventUpdatedAt = DateTime(2023, 11, 10, 13, 30);

final JournalEvent testEventEntry = JournalEvent(
  meta: Metadata(
    id: _testEventId,
    createdAt: _testEventCreatedAt,
    updatedAt: _testEventUpdatedAt,
    dateFrom: _testEventDateFrom,
    dateTo: _testEventDateFrom,
    vectorClock: const VectorClock({'device': 1}),
    starred: false,
    private: false,
  ),
  data: const EventData(
    title: 'Test Event',
    status: EventStatus.planned,
    stars: 3.5,
  ),
  entryText: const EntryText(plainText: 'Initial event description'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mocks defined at main scope
  final mockUpdateNotifications = MockUpdateNotifications();
  final secureStorageMock = MockSecureStorage();
  final settingsDb = SettingsDb(inMemoryDatabase: true);
  final mockTimeService = MockTimeService();
  final mockJournalDb = MockJournalDb();
  final mockPersistenceLogic = MockPersistenceLogic();
  final mockNavService = MockNavService();
  final mockNotificationService = MockNotificationService();
  final mockEditorStateService = MockEditorStateService();
  final mockOutboxService = MockOutboxService();
  var vcMockNext =
      '1'; // This was used by secureStorageMock for vector clock testing

  ProviderContainer makeProviderContainer({
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        agentInitializationProvider.overrideWith((ref) async {}),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // setUpAll at main scope
  setUpAll(() {
    stopRecordingDelay = Duration.zero;

    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(FakeEntryText());
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(FakeEventData());
    registerFallbackValue(const AsyncLoading<EntryState?>());
    registerFallbackValue(DateTime(2024, 3, 15, 10, 30));
    registerFallbackValue(FakeQuillController());

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
    when(
      () => mockEditorStateService.getUnsavedStream(any(), any()),
    ).thenAnswer((_) => Stream<bool>.fromIterable([false]));
    when(
      () => mockEditorStateService.entryWasSaved(
        id: any(named: 'id'),
        lastSaved: any(named: 'lastSaved'),
        controller: any(named: 'controller'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockEditorStateService.getDelta(any())).thenReturn(null);
    when(() => mockEditorStateService.getSelection(any())).thenReturn(null);
    when(() => mockEditorStateService.entryIsUnsaved(any())).thenReturn(false);

    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    when(
      () => secureStorageMock.readValue(hostKey),
    ).thenAnswer((_) async => 'some_host');
    when(
      () => secureStorageMock.readValue(nextAvailableCounterKey),
    ).thenAnswer((_) async => vcMockNext);
    when(
      () => secureStorageMock.writeValue(nextAvailableCounterKey, any()),
    ).thenAnswer((invocation) async {
      vcMockNext = invocation.positionalArguments[1] as String;
    });

    getIt
      ..registerSingleton<SettingsDb>(settingsDb)
      ..registerSingleton<NotificationService>(mockNotificationService)
      ..registerSingleton<SyncDatabase>(SyncDatabase(inMemoryDatabase: true))
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<LoggingService>(LoggingService())
      ..registerSingleton<SecureStorage>(secureStorageMock)
      ..registerSingleton<OutboxService>(mockOutboxService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<VectorClockService>(VectorClockService())
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
      ..registerSingleton<EditorStateService>(mockEditorStateService);

    when(
      () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
    ).thenAnswer((_) async => testTextEntry);
    when(
      () => mockJournalDb.journalEntityById(testTextEntryNoGeo.meta.id),
    ).thenAnswer((_) async => testTextEntryNoGeo);
    when(
      () => mockJournalDb.journalEntityById(testTask.meta.id),
    ).thenAnswer((_) async => testTask);
    when(
      () => mockJournalDb.journalEntityById(testEventEntry.meta.id),
    ).thenAnswer((_) async => testEventEntry);
    // For addTextToImage tests - ensure these are also available if not overridden in group's setUp
    when(
      () => mockJournalDb.journalEntityById(testImageEntryNoText.meta.id),
    ).thenAnswer((_) async => testImageEntryNoText);
    when(
      () => mockJournalDb.journalEntityById(testImageEntryWithMarkdown.meta.id),
    ).thenAnswer((_) async => testImageEntryWithMarkdown);

    when(
      () => mockPersistenceLogic.updateJournalEntity(any(), any()),
    ).thenAnswer((_) async => true);
    when(mockNotificationService.updateBadge).thenAnswer((_) async {});

    // Default stub for session ratings config flag check
    when(
      () => mockJournalDb.getConfigFlagByName(any()),
    ).thenAnswer((_) async => null);

    // Default stub for updateJournalEntityText
    when(
      () => mockPersistenceLogic.updateJournalEntityText(
        any(),
        any(),
        any(),
      ),
    ).thenAnswer((_) async => true);

    // Default stub for persistence logic updateTask, must return Future<bool>
    when(
      () => mockPersistenceLogic.updateTask(
        entryText: any(named: 'entryText'),
        journalEntityId: any(named: 'journalEntityId'),
        taskData: any(named: 'taskData'),
      ),
    ).thenAnswer((_) async => true);

    // Default stub for persistence logic updateEvent
    when(
      () => mockPersistenceLogic.updateEvent(
        entryText: any(named: 'entryText'),
        journalEntityId: any(named: 'journalEntityId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDownAll(getIt.reset);

  group('EntryController Tests - ', () {
    // Specific setUp for this group if needed (e.g., vcMockNext reset)
    setUp(() {
      reset(
        mockPersistenceLogic,
      ); // Still good to reset per group if tests modify its state
      vcMockNext = '1';

      // JournalDb mocks specific to this group, ensure they don't conflict if IDs overlap
      // with addTextToImage test data, or make IDs unique.
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
      when(
        () => mockJournalDb.journalEntityById(testTextEntryNoGeo.meta.id),
      ).thenAnswer((_) async => testTextEntryNoGeo);
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
    });

    test('entry loads', () async {
      final localMockJournalRepository = MockJournalRepository();
      // Stub getLinkedEntities if it's called during load/build by the controller for this test
      when(
        () => localMockJournalRepository.getLinkedEntities(
          linkedTo: any(named: 'linkedTo'),
        ),
      ).thenAnswer((_) async => []);

      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(
            localMockJournalRepository,
          ),
        ],
      );
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );
    });

    test('toggle map visibility', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      notifier.toggleMapVisible();

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: true,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      notifier.toggleMapVisible();

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );
    });

    test('toggle map does nothing for entry without geolocation', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntryNoGeo.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntryNoGeo,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      notifier.toggleMapVisible();

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntryNoGeo,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );
    });

    test('set dirty', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      notifier.setDirty(value: true);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.dirty(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );
    });

    test('delete entry', () async {
      final localMockJournalRepository = MockJournalRepository();
      final entryId = testTextEntry.meta.id;

      // Specific stub for this test
      when(
        () => localMockJournalRepository.deleteJournalEntity(entryId),
      ).thenAnswer((_) async => true);
      // If getLinkedEntities is called by the controller during this flow, stub it too.
      when(
        () => localMockJournalRepository.getLinkedEntities(
          linkedTo: any(named: 'linkedTo'),
        ),
      ).thenAnswer((_) async => []);

      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(
            localMockJournalRepository,
          ),
        ],
      );
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      when(
        () => mockPersistenceLogic.updateMetadata(
          testTextEntry.meta,
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenAnswer(
        (_) async => testTextEntry.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 10, 30),
        ),
      );

      await notifier.delete(beamBack: false);
      verify(
        () => localMockJournalRepository.deleteJournalEntity(entryId),
      ).called(1);
      await expectLater(
        container.read(testEntryProvider.future),
        completion(null),
      );
    });

    test('delete entry & beam back', () async {
      reset(mockPersistenceLogic);
      final localMockJournalRepository = MockJournalRepository();
      final entryId = testTextEntry.meta.id;

      // Specific stub for this test
      when(
        () => localMockJournalRepository.deleteJournalEntity(entryId),
      ).thenAnswer((_) async => true);
      when(
        () => localMockJournalRepository.getLinkedEntities(
          linkedTo: any(named: 'linkedTo'),
        ),
      ).thenAnswer((_) async => []);

      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(
            localMockJournalRepository,
          ),
        ],
      );
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      when(
        () => mockPersistenceLogic.updateMetadata(
          testTextEntry.meta,
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenAnswer(
        (_) async => testTextEntry.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 10, 30),
        ),
      );

      await notifier.delete(beamBack: true);
      verify(
        () => localMockJournalRepository.deleteJournalEntity(entryId),
      ).called(1);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(null),
      );
    });

    test('toggle starred', () async {
      reset(mockPersistenceLogic);
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      Future<bool> testFn() => mockPersistenceLogic.updateJournalEntity(
        testTextEntry,
        testTextEntry.meta.copyWith(starred: false),
      );
      when(testFn).thenAnswer((invocation) async => true);
      await notifier.toggleStarred();
      verify(testFn).called(1);
    });

    test('toggle private', () async {
      reset(mockPersistenceLogic);
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      Future<bool> testFn() => mockPersistenceLogic.updateJournalEntity(
        testTextEntry,
        testTextEntry.meta.copyWith(private: true),
      );
      when(testFn).thenAnswer((invocation) async => true);
      await notifier.togglePrivate();
      verify(testFn).called(1);
    });

    test('toggle flagged', () async {
      reset(mockPersistenceLogic);
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      Future<bool> testFn() => mockPersistenceLogic.updateJournalEntity(
        testTextEntry,
        testTextEntry.meta.copyWith(flag: EntryFlag.import),
      );
      when(testFn).thenAnswer((invocation) async => true);
      await notifier.toggleFlagged();
      verify(testFn).called(1);
    });

    test('set dirty & save text', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.saved(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      notifier.setDirty(value: true);

      await expectLater(
        container.read(testEntryProvider.future),
        completion(
          EntryState.dirty(
            entryId: entryId,
            entry: testTextEntry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
            formKey: notifier.formKey,
          ),
        ),
      );

      Future<bool> testFn() => mockPersistenceLogic.updateJournalEntityText(
        entryId,
        entryTextFromController(notifier.controller),
        testTextEntry.meta.dateTo,
      );
      when(testFn).thenAnswer((invocation) async => true);

      await notifier.save();
      await container.pump(); // Revert to container.pump for consistency

      verify(testFn).called(1);
    });

    test(
      'insert & save text',
      () async {
        final container = makeProviderContainer();
        final entryId = testTextEntry.meta.id;
        final testEntryProvider = entryControllerProvider(id: entryId);
        final notifier = container.read(testEntryProvider.notifier);
        await expectLater(
          container.read(testEntryProvider.future),
          completion(
            EntryState.saved(
              entryId: entryId,
              entry: testTextEntry,
              showMap: false,
              isFocused: false,
              shouldShowEditorToolBar: false,
              formKey: notifier.formKey,
            ),
          ),
        );

        // inserting text changes to dirty state
        notifier.controller.document.insert(0, 'PREFIXED: ');

        // Yield to allow state change to propagate
        await container.pump();

        await expectLater(
          container.read(testEntryProvider.future),
          completion(
            EntryState.dirty(
              entryId: entryId,
              entry: testTextEntry,
              showMap: false,
              isFocused: false,
              shouldShowEditorToolBar: false,
              formKey: notifier.formKey,
            ),
          ),
        );

        Future<bool> testFn() => mockPersistenceLogic.updateJournalEntityText(
          entryId,
          entryTextFromController(notifier.controller),
          testTextEntry.meta.dateTo,
        );
        when(testFn).thenAnswer((invocation) async => true);

        await notifier.save();
        await container
            .pump(); // Add pump to allow async focus changes to settle

        verify(testFn).called(1);

        final plainText = entryTextFromController(
          notifier.controller,
        ).plainText;
        expect(plainText, 'PREFIXED: test entry text\n');
      },
    );

    test('focusNodeListener maintains editor toolbar visibility', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);

      // Initial state - not focused, toolbar not visible
      final initialState = await container.read(testEntryProvider.future);
      expect(initialState?.isFocused, false);
      expect(initialState?.shouldShowEditorToolBar, false);

      // The specific behavior change is tested indirectly through save method
      // When entry is saved and focus is lost, toolbar should remain visible
      // This is now tested in the save test where after save,
      // shouldShowEditorToolBar remains false (not automatically hidden)
    });

    test(
      'focus node listener - no change when focus state unchanged',
      () async {
        final container = makeProviderContainer();
        final entryId = testTextEntry.meta.id;
        final testEntryProvider = entryControllerProvider(id: entryId);
        final notifier = container.read(testEntryProvider.notifier);

        await container.read(testEntryProvider.future);

        // Focus the node
        notifier.focusNode.requestFocus();
        notifier.focusNodeListener();

        // Call listener again with same focus state - should return early
        final stateBeforeSecondCall = await container.read(
          testEntryProvider.future,
        );
        notifier.focusNodeListener(); // Should return early
        final stateAfterSecondCall = await container.read(
          testEntryProvider.future,
        );

        expect(stateBeforeSecondCall, equals(stateAfterSecondCall));
      },
    );

    test('focus node listener updates isFocused state', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      // Get initial state - should not be focused
      var state = await container.read(testEntryProvider.future);
      final initialFocusState = state?.isFocused;

      // Call listener - this reads focusNode.hasFocus and updates _isFocused
      // Even though focusNode.hasFocus is false in tests, the listener
      // executes all its code including the isDesktop hotkey block
      notifier.focusNodeListener();
      state = await container.read(testEntryProvider.future);

      // Verify that isFocused reflects the focusNode's state
      // In test environment without widget tree, hasFocus stays false
      expect(state?.isFocused, initialFocusState);

      // Call listener again to exercise the code path multiple times
      // This ensures both the if and else branches in the isDesktop block are hit
      notifier
        ..focusNodeListener()
        ..focusNodeListener();

      // Verify state is still consistent
      state = await container.read(testEntryProvider.future);
      expect(state?.isFocused, isFalse);
    });

    group('updateCategoryId', () {
      const testCategoryId = 'cat_123';
      final entryId = testTextEntry.meta.id;

      test('successfully updates categoryId for the main entry', () async {
        final localMockJournalRepository = MockJournalRepository();
        // Specific stub for this test
        when(
          () => localMockJournalRepository.updateCategoryId(
            entryId,
            categoryId: testCategoryId,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => localMockJournalRepository.getLinkedEntities(linkedTo: entryId),
        ).thenAnswer((_) async => []);

        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              localMockJournalRepository,
            ),
          ],
        );
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        // Ensure the initial state is loaded AFTER container is created and notifier is obtained
        await container.read(entryControllerProvider(id: entryId).future);

        final result = await notifier.updateCategoryId(testCategoryId);

        expect(result, isTrue);
        verify(
          () => localMockJournalRepository.updateCategoryId(
            entryId,
            categoryId: testCategoryId,
          ),
        ).called(1);
      });

      test('propagates categoryId to all linked entries', () async {
        final localMockJournalRepository = MockJournalRepository();

        final linkedEntry1 = testTask.copyWith(
          meta: testTask.meta.copyWith(id: 'linked_1', categoryId: null),
        );
        final linkedEntry2 = testTextEntryNoGeo.copyWith(
          meta: testTextEntryNoGeo.meta.copyWith(
            id: 'linked_2',
            categoryId: 'old_category',
          ),
        );

        // Specific stubs for this test
        when(
          () => localMockJournalRepository.updateCategoryId(
            entryId,
            categoryId: testCategoryId,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => localMockJournalRepository.getLinkedEntities(linkedTo: entryId),
        ).thenAnswer((_) async => [linkedEntry1, linkedEntry2]);
        when(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntry1.id,
            categoryId: testCategoryId,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntry2.id,
            categoryId: testCategoryId,
          ),
        ).thenAnswer((_) async => true);

        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              localMockJournalRepository,
            ),
          ],
        );
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        await container.read(entryControllerProvider(id: entryId).future);

        final result = await notifier.updateCategoryId(testCategoryId);

        expect(result, isTrue);
        verify(
          () => localMockJournalRepository.updateCategoryId(
            entryId,
            categoryId: testCategoryId,
          ),
        ).called(1);
        verify(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntry1.id,
            categoryId: testCategoryId,
          ),
        ).called(1);
        verify(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntry2.id,
            categoryId: testCategoryId,
          ),
        ).called(1);
      });

      test('handles null categoryId update (clearing category)', () async {
        final localMockJournalRepository = MockJournalRepository();

        final linkedEntry1 = testTextEntryNoGeo.copyWith(
          meta: testTextEntryNoGeo.meta.copyWith(
            id: 'linked_1_clear',
            categoryId: null,
          ),
        );
        final linkedEntry2 = testTask.copyWith(
          meta: testTask.meta.copyWith(
            id: 'linked_2_clear',
            categoryId: 'existing_cat_id',
          ),
        );

        // Specific stubs for this test
        when(
          () => localMockJournalRepository.updateCategoryId(
            entryId,
            categoryId: null,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => localMockJournalRepository.getLinkedEntities(linkedTo: entryId),
        ).thenAnswer(
          (_) async => [linkedEntry1, linkedEntry2],
        );
        when(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntry1.id,
            categoryId: null,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntry2.id,
            categoryId: null,
          ),
        ).thenAnswer((_) async => true);

        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              localMockJournalRepository,
            ),
          ],
        );
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        await container.read(entryControllerProvider(id: entryId).future);

        final result = await notifier.updateCategoryId(null);

        expect(result, isTrue);
        verify(
          () => localMockJournalRepository.updateCategoryId(
            entryId,
            categoryId: null,
          ),
        ).called(1);
        verify(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntry1.id,
            categoryId: null,
          ),
        ).called(1);
        verify(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntry2.id,
            categoryId: null,
          ),
        ).called(1);
      });

      test(
        'updates linked entries categories when task category changes',
        () async {
          final localMockJournalRepository = MockJournalRepository();
          const oldCategoryId = 'old_cat_123';
          const newCategoryId = 'new_cat_456';

          // Create a task with old category and linked entries with same old category
          final mainTask = testTask.copyWith(
            meta: testTask.meta.copyWith(categoryId: oldCategoryId),
          );
          final linkedEntry1 = testTextEntry.copyWith(
            meta: testTextEntry.meta.copyWith(
              id: 'linked_entry_1',
              categoryId: oldCategoryId,
            ),
          );
          final linkedEntry2 = testTextEntryNoGeo.copyWith(
            meta: testTextEntryNoGeo.meta.copyWith(
              id: 'linked_entry_2',
              categoryId: oldCategoryId,
            ),
          );

          // Setup mocks
          when(
            () => mockJournalDb.journalEntityById(mainTask.meta.id),
          ).thenAnswer((_) async => mainTask);
          when(
            () => localMockJournalRepository.updateCategoryId(
              mainTask.meta.id,
              categoryId: newCategoryId,
            ),
          ).thenAnswer((_) async => true);
          when(
            () => localMockJournalRepository.getLinkedEntities(
              linkedTo: mainTask.meta.id,
            ),
          ).thenAnswer((_) async => [linkedEntry1, linkedEntry2]);
          when(
            () => localMockJournalRepository.updateCategoryId(
              linkedEntry1.id,
              categoryId: newCategoryId,
            ),
          ).thenAnswer((_) async => true);
          when(
            () => localMockJournalRepository.updateCategoryId(
              linkedEntry2.id,
              categoryId: newCategoryId,
            ),
          ).thenAnswer((_) async => true);

          final container = makeProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                localMockJournalRepository,
              ),
            ],
          );
          final notifier = container.read(
            entryControllerProvider(id: mainTask.meta.id).notifier,
          );
          await container.read(
            entryControllerProvider(id: mainTask.meta.id).future,
          );

          final result = await notifier.updateCategoryId(newCategoryId);

          expect(result, isTrue);
          // Verify all entries (main and linked) are updated to new category
          verify(
            () => localMockJournalRepository.updateCategoryId(
              mainTask.meta.id,
              categoryId: newCategoryId,
            ),
          ).called(1);
          verify(
            () => localMockJournalRepository.updateCategoryId(
              linkedEntry1.id,
              categoryId: newCategoryId,
            ),
          ).called(1);
          verify(
            () => localMockJournalRepository.updateCategoryId(
              linkedEntry2.id,
              categoryId: newCategoryId,
            ),
          ).called(1);
        },
      );

      test('returns false if main entry update fails', () async {
        final localMockJournalRepository = MockJournalRepository();

        // Specific stub for this test - this one returns false
        when(
          () => localMockJournalRepository.updateCategoryId(
            entryId,
            categoryId: testCategoryId,
          ),
        ).thenAnswer((_) async => false); // Simulate failure
        when(
          () => localMockJournalRepository.getLinkedEntities(linkedTo: entryId),
        ).thenAnswer((_) async => []);

        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              localMockJournalRepository,
            ),
          ],
        );
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        await container.read(entryControllerProvider(id: entryId).future);

        final result = await notifier.updateCategoryId(testCategoryId);

        expect(result, isFalse);
        verify(
          () => localMockJournalRepository.updateCategoryId(
            entryId,
            categoryId: testCategoryId,
          ),
        ).called(1);
        verify(
          () => localMockJournalRepository.getLinkedEntities(linkedTo: entryId),
        ).called(
          1,
        ); // Should be called even if updateCategoryId returns false
      });
    });

    group('updateFromTo', () {
      final entryId = testTextEntry.meta.id;
      final initialDateFrom = testTextEntry.meta.dateFrom;
      final initialDateTo = testTextEntry.meta.dateTo;
      final newDateFrom = initialDateFrom.subtract(const Duration(days: 1));
      final newDateTo = initialDateTo.add(const Duration(days: 1));

      test('successfully updates dates and returns true', () async {
        final localMockJournalRepository = MockJournalRepository();
        when(
          () => localMockJournalRepository.updateJournalEntityDate(
            entryId,
            dateFrom: newDateFrom,
            dateTo: newDateTo,
          ),
        ).thenAnswer((_) async {
          return true;
        });
        // If getLinkedEntities is called by the controller during this flow, stub it too.
        // Based on controller code, it's not directly called by updateFromTo itself.

        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              localMockJournalRepository,
            ),
          ],
        );
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        await container.read(
          entryControllerProvider(id: entryId).future,
        ); // Ensure loaded

        final result = await notifier.updateFromTo(
          dateFrom: newDateFrom,
          dateTo: newDateTo,
        );

        expect(result, isTrue);
        verify(
          () => localMockJournalRepository.updateJournalEntityDate(
            entryId,
            dateFrom: newDateFrom,
            dateTo: newDateTo,
          ),
        ).called(1);
      });

      test('returns false when repository update fails', () async {
        final localMockJournalRepository = MockJournalRepository();
        when(
          () => localMockJournalRepository.updateJournalEntityDate(
            entryId,
            dateFrom: newDateFrom,
            dateTo: newDateTo,
          ),
        ).thenAnswer((_) async {
          return false;
        });

        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              localMockJournalRepository,
            ),
          ],
        );
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        await container.read(
          entryControllerProvider(id: entryId).future,
        ); // Ensure loaded

        final result = await notifier.updateFromTo(
          dateFrom: newDateFrom,
          dateTo: newDateTo,
        );

        expect(result, isFalse);
        verify(
          () => localMockJournalRepository.updateJournalEntityDate(
            entryId,
            dateFrom: newDateFrom,
            dateTo: newDateTo,
          ),
        ).called(1);
      });
    });

    group('build method', () {
      test(
        'emits AsyncError when _journalDb.journalEntityById throws',
        () async {
          const entryId = 'error-id';
          final exception = Exception('Database error');

          when(
            () => mockJournalDb.journalEntityById(entryId),
          ).thenThrow(exception);

          final localMockJournalRepository = MockJournalRepository();
          final container = makeProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                localMockJournalRepository,
              ),
            ],
          );

          final listener = Listener<AsyncValue<EntryState?>>();
          container.listen<AsyncValue<EntryState?>>(
            entryControllerProvider(id: entryId),
            listener.call,
            fireImmediately: true,
          );

          await container.pump();

          final lastEmittedValue =
              verify(() => listener(captureAny(), captureAny())).captured.last
                  as AsyncValue<EntryState?>;
          // In Riverpod 3, async errors may be in AsyncLoading (retrying) state
          expect(lastEmittedValue.hasError, isTrue);
          expect(lastEmittedValue.error, exception);
        },
      );

      test(
        'emits EntryState.saved with null entry when _journalDb.journalEntityById returns null',
        () async {
          const entryId = 'not-found-id';

          when(
            () => mockJournalDb.journalEntityById(entryId),
          ).thenAnswer((_) async => null);

          final localMockJournalRepository = MockJournalRepository();
          when(
            () => localMockJournalRepository.getLinkedEntities(
              linkedTo: any(named: 'linkedTo'),
            ),
          ).thenAnswer((_) async => []);

          final container = makeProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                localMockJournalRepository,
              ),
            ],
          );

          final initialState = await container.read(
            entryControllerProvider(id: entryId).future,
          );

          expect(initialState, isNotNull);
          expect(initialState, isNot(isA<EntryStateDirty>()));
          expect(initialState?.entry, isNull);
          expect(initialState?.entryId, entryId);
        },
      );
    });

    group('save method - JournalEntry (text)', () {
      final entryId = testTextEntry.meta.id;

      test('successful save updates state and calls dependencies', () async {
        final localMockJournalRepository = MockJournalRepository();
        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              localMockJournalRepository,
            ),
          ],
        );
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        await container.read(entryControllerProvider(id: entryId).future);

        notifier.controller.document.insert(0, 'New text');
        notifier.setDirty(value: true);
        final dirtyState = await container.read(
          entryControllerProvider(id: entryId).future,
        );
        expect(dirtyState, isA<EntryStateDirty>());

        when(
          () => mockPersistenceLogic.updateJournalEntityText(
            entryId,
            any(),
            any(),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockEditorStateService.entryWasSaved(
            id: entryId,
            lastSaved: any(named: 'lastSaved'),
            controller: notifier.controller,
          ),
        ).thenAnswer((_) async {});

        notifier.focusNode.requestFocus();

        await notifier.save();
        await container.pump(); // Revert to container.pump for consistency

        verify(
          () => mockPersistenceLogic.updateJournalEntityText(
            entryId,
            any(),
            any(),
          ),
        ).called(1);
        verify(
          () => mockEditorStateService.entryWasSaved(
            id: entryId,
            lastSaved: any(named: 'lastSaved'),
            controller: notifier.controller,
          ),
        ).called(1);

        final savedState = await container.read(
          entryControllerProvider(id: entryId).future,
        );
        expect(savedState, isNot(isA<EntryStateDirty>()));
        expect(savedState?.shouldShowEditorToolBar, isFalse);
      });

      test('save with stopRecording calls TimeService.stop', () async {
        final localMockJournalRepository = MockJournalRepository();
        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              localMockJournalRepository,
            ),
          ],
        );
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        await container.read(entryControllerProvider(id: entryId).future);
        notifier.setDirty(value: true);

        when(
          () => mockPersistenceLogic.updateJournalEntityText(
            entryId,
            any(),
            any(),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockEditorStateService.entryWasSaved(
            id: entryId,
            lastSaved: any(named: 'lastSaved'),
            controller: notifier.controller,
          ),
        ).thenAnswer((_) async {});
        when(mockTimeService.stop).thenAnswer((_) async {});

        await notifier.save(stopRecording: true);
        await container.pump();

        verify(mockTimeService.stop).called(1);

        // The full post-save transition: dirty cleared and the editor
        // toolbar hidden — not just the timer side effect.
        final savedState = await container.read(
          entryControllerProvider(id: entryId).future,
        );
        expect(savedState, isNot(isA<EntryStateDirty>()));
        expect(savedState?.shouldShowEditorToolBar, isFalse);
      });

      test('save propagates exception from updateJournalEntityText', () async {
        final localMockJournalRepository = MockJournalRepository();
        final exception = Exception('Persistence error');
        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              localMockJournalRepository,
            ),
          ],
        );
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        await container.read(entryControllerProvider(id: entryId).future);
        notifier.setDirty(value: true);

        when(
          () => mockPersistenceLogic.updateJournalEntityText(
            entryId,
            any(),
            any(),
          ),
        ).thenThrow(exception);

        expect(notifier.save, throwsA(exception));
      });
    });

    group('save method - JournalEvent', () {
      final entryId = testEventEntry.meta.id;

      test(
        'save routes through updateEvent preserving title and status',
        () async {
          final container = makeProviderContainer();
          final notifier = container.read(
            entryControllerProvider(id: entryId).notifier,
          );
          await container.read(entryControllerProvider(id: entryId).future);

          notifier.setDirty(value: true);

          when(
            () => mockPersistenceLogic.updateEvent(
              entryText: any(named: 'entryText'),
              journalEntityId: entryId,
              data: any(named: 'data'),
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockEditorStateService.entryWasSaved(
              id: entryId,
              lastSaved: any(named: 'lastSaved'),
              controller: notifier.controller,
            ),
          ).thenAnswer((_) async {});

          await notifier.save();
          await container.pump();

          // With no form mounted, the saved data falls back to the event's
          // existing title and status.
          final captured = verify(
            () => mockPersistenceLogic.updateEvent(
              entryText: any(named: 'entryText'),
              journalEntityId: entryId,
              data: captureAny(named: 'data'),
            ),
          ).captured;
          final capturedData = captured.single as EventData;
          expect(capturedData.title, testEventEntry.data.title);
          expect(capturedData.status, testEventEntry.data.status);

          // The text-entry save path must not run for events.
          verifyNever(
            () => mockPersistenceLogic.updateJournalEntityText(
              entryId,
              any(),
              any(),
            ),
          );

          final savedState = await container.read(
            entryControllerProvider(id: entryId).future,
          );
          expect(savedState, isNot(isA<EntryStateDirty>()));
        },
      );
    });
  });

  // Add tests for updateChecklistOrder
  group('updateChecklistOrder method', () {
    const entryId = _testTaskId; // ID of the main Task entry

    setUp(() {
      reset(mockPersistenceLogic);
      reset(mockJournalDb);

      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => testTaskEntry);
      when(
        () => mockJournalDb.getJournalEntitiesForIdsUnordered(any()),
      ).thenAnswer((_) async => [testChecklistItem1, testChecklistItem2]);

      // Corrected when call for updateTask
      when(
        () => mockPersistenceLogic.updateTask(
          entryText: any(named: 'entryText'),
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);
    });

    test('does nothing if current entry is not a Task', () async {
      final nonTaskEntryId = testImageEntryNoText.meta.id;
      when(
        () => mockJournalDb.journalEntityById(nonTaskEntryId),
      ).thenAnswer((_) async => testImageEntryNoText);

      final container = makeProviderContainer();
      final notifier = container.read(
        entryControllerProvider(id: nonTaskEntryId).notifier,
      );
      await container.read(entryControllerProvider(id: nonTaskEntryId).future);

      await notifier.updateChecklistOrder(['any_id']);

      // Corrected verifyNever call
      verifyNever(
        () => mockPersistenceLogic.updateTask(
          entryText: any(named: 'entryText'),
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      );
    });

    test(
      'updates with an empty list, clearing existing checklistIds',
      () async {
        final container = makeProviderContainer();
        final notifier = container.read(
          entryControllerProvider(id: entryId).notifier,
        );
        await container.read(entryControllerProvider(id: entryId).future);

        notifier.controller.document.insert(
          0,
          'Task description from controller',
        );
        final expectedEntryText = entryTextFromController(notifier.controller);

        when(
          () =>
              mockJournalDb.getJournalEntitiesForIdsUnordered(const <String>{}),
        ).thenAnswer((_) async => []);

        await notifier.updateChecklistOrder([]);

        final captured = verify(
          () => mockPersistenceLogic.updateTask(
            entryText: captureAny(named: 'entryText'),
            journalEntityId: captureAny(named: 'journalEntityId'),
            taskData: captureAny(named: 'taskData'),
          ),
        ).captured;

        expect(captured[0], entryId);
        final capturedTaskData = captured[1] as TaskData;
        final capturedEntryText = captured[2] as EntryText;
        expect(capturedTaskData.checklistIds, isEmpty);
        expect(capturedEntryText.plainText, expectedEntryText.plainText);
      },
    );

    test('updates with a new order of existing checklistIds', () async {
      final container = makeProviderContainer();
      final notifier = container.read(
        entryControllerProvider(id: entryId).notifier,
      );
      await container.read(entryControllerProvider(id: entryId).future);
      notifier.controller.document.insert(0, 'Reordering checklist');
      final expectedEntryText = entryTextFromController(notifier.controller);

      final newOrder = [testChecklistItem2.id, testChecklistItem1.id];
      when(
        () => mockJournalDb.getJournalEntitiesForIdsUnordered(
          {testChecklistItem1.id, testChecklistItem2.id},
        ),
      ).thenAnswer((_) async => [testChecklistItem1, testChecklistItem2]);

      await notifier.updateChecklistOrder(newOrder);

      final captured = verify(
        () => mockPersistenceLogic.updateTask(
          entryText: captureAny(named: 'entryText'),
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;

      expect(captured[0], entryId);
      final capturedTaskData = captured[1] as TaskData;
      final capturedEntryText = captured[2] as EntryText;
      expect(capturedTaskData.checklistIds, newOrder);
      expect(capturedEntryText.plainText, expectedEntryText.plainText);
    });

    test('filters out non-existent or deleted checklistIds', () async {
      final container = makeProviderContainer();
      final notifier = container.read(
        entryControllerProvider(id: entryId).notifier,
      );
      await container.read(entryControllerProvider(id: entryId).future);
      notifier.controller.document.insert(0, 'Filtering checklist');
      final expectedEntryText = entryTextFromController(notifier.controller);

      final idsWithInvalid = [
        testChecklistItem1.id,
        'non_existent_id',
        testChecklistItem3Deleted.id,
        testChecklistItem2.id,
      ];
      final expectedFilteredOrder = [
        testChecklistItem1.id,
        testChecklistItem2.id,
      ];

      when(
        () => mockJournalDb.getJournalEntitiesForIdsUnordered({
          testChecklistItem1.id,
          'non_existent_id',
          testChecklistItem3Deleted.id,
          testChecklistItem2.id,
        }),
      ).thenAnswer(
        (_) async => [
          testChecklistItem1,
          testChecklistItem2,
          testChecklistItem3Deleted,
        ],
      );

      await notifier.updateChecklistOrder(idsWithInvalid);

      final captured = verify(
        () => mockPersistenceLogic.updateTask(
          entryText: captureAny(named: 'entryText'),
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;

      expect(captured[0], entryId);
      final capturedTaskData = captured[1] as TaskData;
      final capturedEntryText = captured[2] as EntryText;
      expect(capturedTaskData.checklistIds, expectedFilteredOrder);
      expect(capturedEntryText.plainText, expectedEntryText.plainText);
    });
  });

  group('updateTaskStatus method', () {
    setUp(() {
      reset(mockPersistenceLogic);
      // Ensure mocks are set up for this group
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
    });

    test('updates task status when status changes', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      await notifier.updateTaskStatus('DONE');

      verify(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).called(1);
    });

    test('does nothing when task status is unchanged', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      await notifier.updateTaskStatus(testTask.data.status.toDbString);

      verifyNever(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      );
    });

    test('does nothing when entry is not a task', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      await notifier.updateTaskStatus('DONE');

      verifyNever(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      );
    });

    test('does nothing when status is null', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      await notifier.updateTaskStatus(null);

      verifyNever(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      );
    });
  });

  group('updateTaskLanguage method', () {
    setUp(() {
      reset(mockPersistenceLogic);
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
    });

    test('persists a new language code with ChangeSource.user', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final provider = entryControllerProvider(id: entryId);
      final notifier = container.read(provider.notifier);

      await container.read(provider.future);

      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      await notifier.updateTaskLanguage('en');

      final captured =
          verify(
                () => mockPersistenceLogic.updateTask(
                  journalEntityId: entryId,
                  taskData: captureAny(named: 'taskData'),
                ),
              ).captured.single
              as TaskData;
      expect(captured.languageCode, 'en');
      expect(captured.languageSource, ChangeSource.user);
    });

    test(
      'persists user override even when language code matches a default source',
      () async {
        // Seed a task whose current language came from an agent / default
        // source, not an explicit user pick.
        final seeded = testTask.copyWith(
          data: testTask.data.copyWith(
            languageCode: 'en',
            languageSource: ChangeSource.agent,
          ),
        );
        when(
          () => mockJournalDb.journalEntityById(seeded.meta.id),
        ).thenAnswer((_) async => seeded);

        final container = makeProviderContainer();
        final provider = entryControllerProvider(id: seeded.meta.id);
        final notifier = container.read(provider.notifier);
        await container.read(provider.future);

        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: seeded.meta.id,
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => true);

        await notifier.updateTaskLanguage('en');

        final captured =
            verify(
                  () => mockPersistenceLogic.updateTask(
                    journalEntityId: seeded.meta.id,
                    taskData: captureAny(named: 'taskData'),
                  ),
                ).captured.single
                as TaskData;
        expect(captured.languageCode, 'en');
        expect(captured.languageSource, ChangeSource.user);
      },
    );

    test(
      'skips the write when code and source are already user-set',
      () async {
        final seeded = testTask.copyWith(
          data: testTask.data.copyWith(
            languageCode: 'en',
            languageSource: ChangeSource.user,
          ),
        );
        when(
          () => mockJournalDb.journalEntityById(seeded.meta.id),
        ).thenAnswer((_) async => seeded);

        final container = makeProviderContainer();
        final provider = entryControllerProvider(id: seeded.meta.id);
        final notifier = container.read(provider.notifier);
        await container.read(provider.future);

        await notifier.updateTaskLanguage('en');

        verifyNever(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
          ),
        );
      },
    );

    test('clearing the language code (null) is persisted', () async {
      final seeded = testTask.copyWith(
        data: testTask.data.copyWith(
          languageCode: 'en',
          languageSource: ChangeSource.user,
        ),
      );
      when(
        () => mockJournalDb.journalEntityById(seeded.meta.id),
      ).thenAnswer((_) async => seeded);

      final container = makeProviderContainer();
      final provider = entryControllerProvider(id: seeded.meta.id);
      final notifier = container.read(provider.notifier);
      await container.read(provider.future);

      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: seeded.meta.id,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      await notifier.updateTaskLanguage(null);

      final captured =
          verify(
                () => mockPersistenceLogic.updateTask(
                  journalEntityId: seeded.meta.id,
                  taskData: captureAny(named: 'taskData'),
                ),
              ).captured.single
              as TaskData;
      expect(captured.languageCode, isNull);
      expect(captured.languageSource, ChangeSource.user);
    });

    test('does nothing when entry is not a task', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final provider = entryControllerProvider(id: entryId);
      final notifier = container.read(provider.notifier);
      await container.read(provider.future);

      await notifier.updateTaskLanguage('en');

      verifyNever(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      );
    });
  });

  group('updateRating method', () {
    setUp(() {
      reset(mockPersistenceLogic);
      // Ensure mocks are set up for this group
      when(
        () => mockJournalDb.journalEntityById(testEventEntry.meta.id),
      ).thenAnswer((_) async => testEventEntry);
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
    });

    test('updates rating for JournalEvent', () async {
      final container = makeProviderContainer();
      final entryId = testEventEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      when(
        () => mockPersistenceLogic.updateEvent(
          entryText: any(named: 'entryText'),
          journalEntityId: entryId,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => true);

      const newRating = 4.5;
      await notifier.updateRating(newRating);

      final captured = verify(
        () => mockPersistenceLogic.updateEvent(
          entryText: captureAny(named: 'entryText'),
          journalEntityId: captureAny(named: 'journalEntityId'),
          data: captureAny(named: 'data'),
        ),
      ).captured;

      expect(captured[0], entryId);
      expect(captured[1], isA<EventData>());
      expect(captured[2], isA<EntryText>());
      final capturedData = captured[1] as EventData;
      expect(capturedData.stars, newRating);
      expect(capturedData.title, testEventEntry.data.title);
      expect(capturedData.status, testEventEntry.data.status);
    });

    test('does nothing when entry is not a JournalEvent', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      await notifier.updateRating(5);

      verifyNever(
        () => mockPersistenceLogic.updateEvent(
          entryText: any(named: 'entryText'),
          journalEntityId: any(named: 'journalEntityId'),
          data: any(named: 'data'),
        ),
      );
    });
  });

  group('taskTitleFocusNodeListener method', () {
    setUp(() {
      // Ensure mocks are set up for this group
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
    });

    test('taskTitleFocusNodeListener executes without errors', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      final stateBefore = await container.read(testEntryProvider.future);

      // Call listener multiple times to exercise all code paths
      // This executes:
      // - if (isDesktop) check
      // - if (taskTitleFocusNode.hasFocus) check and else branch
      // - hotKeyManager.register(...) and unregister(...) calls on desktop
      notifier
        ..taskTitleFocusNodeListener()
        ..taskTitleFocusNodeListener()
        ..taskTitleFocusNodeListener();

      // Verify that the state hasn't changed (taskTitleFocusNodeListener
      // doesn't modify EntryState, it only manages hotkeys)
      final stateAfter = await container.read(testEntryProvider.future);
      expect(stateAfter, stateBefore);

      // Verify that the entry is still accessible and valid
      expect(stateAfter?.entry, isA<Task>());
    });
  });

  group('save method - JournalEvent', () {
    setUp(() {
      reset(mockPersistenceLogic);
      // Ensure mocks are set up for this group
      when(
        () => mockJournalDb.journalEntityById(testEventEntry.meta.id),
      ).thenAnswer((_) async => testEventEntry);
    });

    test('saves event', () async {
      final container = makeProviderContainer();
      final entryId = testEventEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      when(
        () => mockPersistenceLogic.updateEvent(
          entryText: any(named: 'entryText'),
          journalEntityId: entryId,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockEditorStateService.entryWasSaved(
          id: entryId,
          lastSaved: any(named: 'lastSaved'),
          controller: notifier.controller,
        ),
      ).thenAnswer((_) async {});

      await notifier.save();

      verify(
        () => mockPersistenceLogic.updateEvent(
          entryText: any(named: 'entryText'),
          journalEntityId: entryId,
          data: any(named: 'data'),
        ),
      ).called(1);
    });
  });

  group('save method - Task', () {
    setUp(() {
      reset(mockPersistenceLogic);
      // Ensure mocks are set up for this group
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
    });

    test('saves task with title and estimate', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      // Mock both updateTask and updateJournalEntityText
      when(
        () => mockPersistenceLogic.updateJournalEntityText(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockPersistenceLogic.updateTask(
          entryText: any(named: 'entryText'),
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockEditorStateService.entryWasSaved(
          id: entryId,
          lastSaved: any(named: 'lastSaved'),
          controller: notifier.controller,
        ),
      ).thenAnswer((_) async {});

      const newTitle = 'Updated Task Title';
      const newEstimate = Duration(hours: 2);
      await notifier.save(title: newTitle, estimate: newEstimate);

      final captured = verify(
        () => mockPersistenceLogic.updateTask(
          entryText: captureAny(named: 'entryText'),
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;

      expect(captured[0], entryId);
      expect(captured[1], isA<TaskData>());
      expect(captured[2], isA<EntryText>());
      final capturedTaskData = captured[1] as TaskData;
      expect(capturedTaskData.title, newTitle);
      expect(capturedTaskData.estimate, newEstimate);
    });

    test('saves task with dueDate', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      when(
        () => mockPersistenceLogic.updateJournalEntityText(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockPersistenceLogic.updateTask(
          entryText: any(named: 'entryText'),
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockEditorStateService.entryWasSaved(
          id: entryId,
          lastSaved: any(named: 'lastSaved'),
          controller: notifier.controller,
        ),
      ).thenAnswer((_) async {});

      final newDueDate = DateTime(2025, 12, 31);
      await notifier.save(dueDate: newDueDate);

      final captured = verify(
        () => mockPersistenceLogic.updateTask(
          entryText: captureAny(named: 'entryText'),
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;

      final capturedTaskData = captured[1] as TaskData;
      expect(capturedTaskData.due, newDueDate);
    });

    test('clears dueDate when clearDueDate is true', () async {
      // Create a task with an existing due date
      final taskWithDueDate = testTask.copyWith(
        data: testTask.data.copyWith(due: DateTime(2025, 6, 15)),
      );

      when(
        () => mockJournalDb.journalEntityById(taskWithDueDate.meta.id),
      ).thenAnswer((_) async => taskWithDueDate);

      final container = makeProviderContainer();
      final entryId = taskWithDueDate.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      when(
        () => mockPersistenceLogic.updateJournalEntityText(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockPersistenceLogic.updateTask(
          entryText: any(named: 'entryText'),
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockEditorStateService.entryWasSaved(
          id: entryId,
          lastSaved: any(named: 'lastSaved'),
          controller: notifier.controller,
        ),
      ).thenAnswer((_) async {});

      await notifier.save(clearDueDate: true);

      final captured = verify(
        () => mockPersistenceLogic.updateTask(
          entryText: captureAny(named: 'entryText'),
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;

      final capturedTaskData = captured[1] as TaskData;
      expect(capturedTaskData.due, isNull);
    });

    test(
      'preserves existing dueDate when neither dueDate nor clearDueDate provided',
      () async {
        final existingDueDate = DateTime(2025, 6, 15);
        final taskWithDueDate = testTask.copyWith(
          data: testTask.data.copyWith(due: existingDueDate),
        );

        when(
          () => mockJournalDb.journalEntityById(taskWithDueDate.meta.id),
        ).thenAnswer((_) async => taskWithDueDate);

        final container = makeProviderContainer();
        final entryId = taskWithDueDate.meta.id;
        final testEntryProvider = entryControllerProvider(id: entryId);
        final notifier = container.read(testEntryProvider.notifier);

        await container.read(testEntryProvider.future);

        when(
          () => mockPersistenceLogic.updateJournalEntityText(
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockPersistenceLogic.updateTask(
            entryText: any(named: 'entryText'),
            journalEntityId: entryId,
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockEditorStateService.entryWasSaved(
            id: entryId,
            lastSaved: any(named: 'lastSaved'),
            controller: notifier.controller,
          ),
        ).thenAnswer((_) async {});

        // Save with just a title change, dueDate should be preserved
        await notifier.save(title: 'New Title');

        final captured = verify(
          () => mockPersistenceLogic.updateTask(
            entryText: captureAny(named: 'entryText'),
            journalEntityId: captureAny(named: 'journalEntityId'),
            taskData: captureAny(named: 'taskData'),
          ),
        ).captured;

        final capturedTaskData = captured[1] as TaskData;
        expect(capturedTaskData.due, existingDueDate);
      },
    );
  });

  group('setCoverArt method', () {
    setUp(() {
      reset(mockPersistenceLogic);
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
    });

    test('sets cover art on a task', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      await notifier.setCoverArt('image-123');

      final captured = verify(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;

      expect(captured[0], entryId);
      final capturedTaskData = captured[1] as TaskData;
      expect(capturedTaskData.coverArtId, 'image-123');
    });

    test('removes cover art when null is passed', () async {
      // Use a task that has cover art set
      final taskWithCover = testTask.copyWith(
        data: testTask.data.copyWith(coverArtId: 'existing-image'),
      );
      when(
        () => mockJournalDb.journalEntityById(taskWithCover.meta.id),
      ).thenAnswer((_) async => taskWithCover);

      final container = makeProviderContainer();
      final entryId = taskWithCover.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      await notifier.setCoverArt(null);

      final captured = verify(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;

      expect(captured[0], entryId);
      final capturedTaskData = captured[1] as TaskData;
      expect(capturedTaskData.coverArtId, isNull);
    });

    test('does nothing when entry is not a task', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      await notifier.setCoverArt('image-123');

      verifyNever(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      );
    });

    test('updates local state optimistically', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      await notifier.setCoverArt('new-image');

      // Verify the state was updated optimistically
      final state = container.read(testEntryProvider).value;
      expect(state?.entry, isA<Task>());
      final task = state!.entry! as Task;
      expect(task.data.coverArtId, 'new-image');
    });
  });

  group('updateTaskPriority method', () {
    setUp(() {
      reset(mockPersistenceLogic);
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
    });

    test('does nothing when entry is not a task', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final provider = entryControllerProvider(id: entryId);
      final notifier = container.read(provider.notifier);

      await container.read(provider.future);

      await notifier.updateTaskPriority('P1');

      verifyNever(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      );
    });

    test('does nothing when priority is already the same', () async {
      // testTask has default priority p2Medium; 'P2' resolves to that.
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final provider = entryControllerProvider(id: entryId);
      final notifier = container.read(provider.notifier);

      await container.read(provider.future);

      await notifier.updateTaskPriority('P2');

      verifyNever(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      );
    });

    test('persists new priority and optimistically updates state', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final provider = entryControllerProvider(id: entryId);
      final notifier = container.read(provider.notifier);

      await container.read(provider.future);

      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      await notifier.updateTaskPriority('P0');

      final captured = verify(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;

      expect(captured[0], entryId);
      final capturedTaskData = captured[1] as TaskData;
      expect(capturedTaskData.priority, TaskPriority.p0Urgent);

      // Verify local state was optimistically updated
      final currentState = container.read(provider).value;
      final currentTask = currentState?.entry as Task?;
      expect(currentTask?.data.priority, TaskPriority.p0Urgent);
    });

    test('persists P1 (high) priority correctly', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final provider = entryControllerProvider(id: entryId);
      final notifier = container.read(provider.notifier);

      await container.read(provider.future);

      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: entryId,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      await notifier.updateTaskPriority('P1');

      final captured = verify(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;

      final capturedTaskData = captured[1] as TaskData;
      expect(capturedTaskData.priority, TaskPriority.p1High);
    });
  });

  group('listen() updateStream callback', () {
    setUp(() {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
    });

    test(
      'updates state and resets controller when stream emits matching id '
      'with changed entry',
      () async {
        final streamController = StreamController<Set<String>>.broadcast();
        when(
          () => mockUpdateNotifications.updateStream,
        ).thenAnswer((_) => streamController.stream);

        final updatedEntry = testTextEntry.copyWith(
          entryText: const EntryText(plainText: 'updated text'),
        );
        // After the stream fires we fetch the updated entry
        var fetchCount = 0;
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async {
          fetchCount++;
          return fetchCount == 1 ? testTextEntry : updatedEntry;
        });

        final container = makeProviderContainer();
        final entryId = testTextEntry.meta.id;
        final provider = entryControllerProvider(id: entryId);
        container.read(provider.notifier);

        await container.read(provider.future);

        // Emit the matching id to trigger the callback
        streamController.add({entryId});
        await container.pump();
        // Allow the listener's async re-fetch to complete.
        await container.read(provider.future);

        // The state entry should now reflect the updated entry
        final currentState = container.read(provider).value;
        expect(currentState?.entry, updatedEntry);

        await streamController.close();

        // Restore default stub
        when(
          () => mockUpdateNotifications.updateStream,
        ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
      },
    );

    test(
      'does not update state when stream emits unrelated id',
      () async {
        final streamController = StreamController<Set<String>>.broadcast();
        when(
          () => mockUpdateNotifications.updateStream,
        ).thenAnswer((_) => streamController.stream);

        final container = makeProviderContainer();
        final entryId = testTextEntry.meta.id;
        final provider = entryControllerProvider(id: entryId);
        container.read(provider.notifier);

        await container.read(provider.future);
        final stateBefore = container.read(provider).value;

        // Emit a different id - should not trigger update
        streamController.add({'some-other-id'});
        await container.pump();

        final stateAfter = container.read(provider).value;
        expect(stateAfter, stateBefore);

        await streamController.close();

        // Restore default stub
        when(
          () => mockUpdateNotifications.updateStream,
        ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
      },
    );
  });

  group('setLanguage method', () {
    setUp(() {
      reset(mockPersistenceLogic);
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
      when(
        () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
      ).thenAnswer((_) async => testAudioEntry);
    });

    test('completes without calling SpeechRepository.updateLanguage for '
        'non-audio entry', () async {
      if (!getIt.isRegistered<DomainLogger>()) {
        getIt.registerSingleton<DomainLogger>(
          DomainLogger(loggingService: getIt<LoggingService>()),
        );
      }

      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final provider = entryControllerProvider(id: entryId);
      final notifier = container.read(provider.notifier);

      await container.read(provider.future);

      // Should complete without throwing; for non-audio entries the logger
      // records an error but no exception is raised.
      await expectLater(notifier.setLanguage('de'), completes);
    });
  });

  group('copyImage method', () {
    setUp(() {
      when(
        () => mockJournalDb.journalEntityById(testImageEntryNoText.meta.id),
      ).thenAnswer((_) async => testImageEntryNoText);
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
    });

    test('does nothing when entry is not a JournalImage', () async {
      final container = makeProviderContainer();
      final entryId = testTextEntry.meta.id;
      final provider = entryControllerProvider(id: entryId);
      final notifier = container.read(provider.notifier);

      await container.read(provider.future);

      // No exception thrown, no state changes – just completes silently.
      await expectLater(notifier.copyImage(), completes);

      // State is unchanged
      final state = container.read(provider).value;
      expect(state?.entry, testTextEntry);
    });
  });

  group('focusNodeListener – state-change branch', () {
    setUp(() {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
    });

    test(
      'focusNodeListener leaves toolbar hidden when focus state is unchanged',
      () async {
        final container = makeProviderContainer();
        final entryId = testTextEntry.meta.id;
        final provider = entryControllerProvider(id: entryId);
        final notifier = container.read(provider.notifier);

        await container.read(provider.future);

        // Force _isFocused=false (initial) while making hasFocus appear true
        // by setting the dirty flag first so we have a valid entry state,
        // then directly exercise the listener with a manually-driven focus
        // state change.  We drive the state by temporarily overriding the
        // internal flag via setDirty (which does not change _isFocused) and
        // then simulating the transition through focusNodeListener.

        // Prime: set internal _isFocused to true by calling the listener
        // after forcing hasFocus mismatch.  The easiest approach in a
        // headless test is to manipulate _isFocused indirectly: call
        // focusNodeListener() while _isFocused is currently false and
        // focusNode.hasFocus is also false → the guard triggers and it
        // returns early.  To break the symmetry, we flip _isFocused to
        // true internally by calling setDirty to put the notifier in a
        // known state, then directly call emitState to verify that the
        // _shouldShowEditorToolBar field isn't yet set.

        // Verify initial toolbar state
        final stateBeforeFocus = container.read(provider).value;
        expect(stateBeforeFocus?.shouldShowEditorToolBar, isFalse);

        // Calling focusNodeListener when both hasFocus and _isFocused are
        // false causes the guard to fire (return early).  That path is
        // already exercised by existing tests.  Here we want the BODY of the
        // function (lines 48–65) to run, which requires hasFocus != _isFocused.

        // After build(), _isFocused == false.  We manipulate the internal
        // boolean by calling focusNodeListener() after setting _isFocused to
        // true indirectly.  The only public way to set _isFocused is through
        // focusNodeListener itself.  In a widget-less test hasFocus is always
        // false.  So we set _isFocused to true by temporarily forking the
        // listener call:
        //   1. Set _dirty to mark a state to assert on.
        //   2. Call notifier.focusNodeListener() once – it returns early
        //      because hasFocus==false == _isFocused==false.
        //   3. We reach into the focusNode and simulate a focus event by
        //      calling the listener directly after patching the private bool
        //      through the public setDirty/emitState cycle (no direct access).

        // The most reliable approach in a provider test without a widget tree:
        // verify that calling setDirty(value:false, requestFocus:false) does
        // NOT call focusNode.requestFocus, and that calling
        // setDirty(value:true) with requestFocus:true does.  This at least
        // exercises emitState() transitioning between saved/dirty – the
        // focusNodeListener body itself requires a widget binding with a real
        // focus scope to change hasFocus.  We call it repeatedly to at least
        // drive the desktop hotkey block.
        notifier
          ..focusNodeListener()
          ..focusNodeListener();

        // The early-return guard must leave the toolbar flag untouched.
        final stateAfter = container.read(provider).value;
        expect(stateAfter, isNotNull);
        expect(stateAfter?.shouldShowEditorToolBar, isFalse);
      },
    );
  });

  group('focusNodeListener – widget-focus branch (lines 48-65)', () {
    setUp(() {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);
    });

    // Use testWidgets so the FocusNode is attached to a real widget tree,
    // allowing hasFocus to actually flip between true/false.
    // The container is disposed inside the test body, followed by
    // tester.pump(2 min) to drain the cacheFor(1 min) timer before the
    // framework's pending-timer invariant check.
    testWidgets(
      'sets _isFocused and _shouldShowEditorToolBar true when focus is gained',
      (tester) async {
        final container = ProviderContainer(
          overrides: [agentInitializationProvider.overrideWith((ref) async {})],
        );
        final entryId = testTextEntry.meta.id;
        final provider = entryControllerProvider(id: entryId);
        final notifier = container.read(provider.notifier);

        await container.read(provider.future);

        // Attach the notifier's focusNode to a real widget tree so
        // focusNode.hasFocus can become true.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Focus(
                focusNode: notifier.focusNode,
                child: const SizedBox(),
              ),
            ),
          ),
        );

        // Verify initial state: not focused, toolbar hidden.
        expect(container.read(provider).value?.isFocused, isFalse);
        expect(
          container.read(provider).value?.shouldShowEditorToolBar,
          isFalse,
        );

        // Request focus → hasFocus becomes true → listener fires
        // (_isFocused=false → hasFocus=true → guard fails → body runs)
        notifier.focusNode.requestFocus();
        await tester.pump();

        // Listener is also called manually to be explicit about coverage.
        notifier.focusNodeListener();

        // After gaining focus: isFocused=true and toolbar should be shown.
        final stateAfterFocus = container.read(provider).value;
        expect(stateAfterFocus?.isFocused, isTrue);
        expect(stateAfterFocus?.shouldShowEditorToolBar, isTrue);

        // Dispose the container now and drain the cacheFor(1 min) timer so
        // the testWidgets pending-timer invariant check passes.
        container.dispose();
        await tester.pump(const Duration(minutes: 2));
      },
    );

    testWidgets(
      'clears _isFocused when focus is lost after it was gained',
      (tester) async {
        final container = ProviderContainer(
          overrides: [agentInitializationProvider.overrideWith((ref) async {})],
        );
        final entryId = testTextEntry.meta.id;
        final provider = entryControllerProvider(id: entryId);
        final notifier = container.read(provider.notifier);

        await container.read(provider.future);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Focus(
                focusNode: notifier.focusNode,
                child: const SizedBox(),
              ),
            ),
          ),
        );

        // Gain focus first so _isFocused becomes true.
        notifier.focusNode.requestFocus();
        await tester.pump();
        notifier.focusNodeListener();

        expect(container.read(provider).value?.isFocused, isTrue);

        // Lose focus: unfocus the node so hasFocus becomes false.
        notifier.focusNode.unfocus();
        await tester.pump();

        // Now hasFocus=false != _isFocused=true → body runs again,
        // _isFocused is reset to false (covers line 63 unregister path).
        notifier.focusNodeListener();

        final stateAfterBlur = container.read(provider).value;
        expect(stateAfterBlur?.isFocused, isFalse);
        // Toolbar visibility is retained after blur (not cleared by the listener).
        expect(stateAfterBlur?.shouldShowEditorToolBar, isTrue);

        // Dispose and drain the cacheFor timer.
        container.dispose();
        await tester.pump(const Duration(minutes: 2));
      },
    );
  });

  group('taskTitleFocusNodeListener – widget-focus branch (lines 71-74)', () {
    setUp(() {
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);
    });

    testWidgets(
      'registers hotkey when taskTitleFocusNode gains focus on desktop',
      (tester) async {
        final container = ProviderContainer(
          overrides: [agentInitializationProvider.overrideWith((ref) async {})],
        );
        final entryId = testTask.meta.id;
        final provider = entryControllerProvider(id: entryId);
        final notifier = container.read(provider.notifier);

        await container.read(provider.future);

        // Attach taskTitleFocusNode to a real widget tree.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Focus(
                focusNode: notifier.taskTitleFocusNode,
                child: const SizedBox(),
              ),
            ),
          ),
        );

        // Request focus → hasFocus becomes true → listener covers
        // the register branch (lines 71-74).
        notifier.taskTitleFocusNode.requestFocus();
        await tester.pump();

        // Calling the listener manually exercises lines 70-74.
        // No exception should be thrown.
        notifier.taskTitleFocusNodeListener();

        // Lose focus → covers the unregister else branch (line 78).
        notifier.taskTitleFocusNode.unfocus();
        await tester.pump();

        // Called again with hasFocus=false; should not throw.
        notifier.taskTitleFocusNodeListener();

        // State is not modified by taskTitleFocusNodeListener.
        expect(container.read(provider).value?.entry, isA<Task>());

        // Dispose and drain the cacheFor timer.
        container.dispose();
        await tester.pump(const Duration(minutes: 2));
      },
    );
  });

  group('copyImage – JournalImage entry (lines 498-509)', () {
    late Directory tempDir;
    late JournalImage testImageForCopy;

    setUp(() async {
      // Create a temporary directory and a real image file so that
      // copyImage can proceed past the file-read on platforms where
      // SystemClipboard.instance is non-null.
      tempDir = await Directory.systemTemp.createTemp('lotti_copy_test_');
      const imageDir = '/img/';
      const imageFile = 'test.jpg';
      final imgFile = File('${tempDir.path}$imageDir$imageFile');
      await imgFile.parent.create(recursive: true);
      // Write a minimal 1×1 PNG so the read succeeds.
      await imgFile.writeAsBytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
        0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82, // IEND
      ]);

      testImageForCopy = JournalImage(
        meta: Metadata(
          id: 'copy_image_test_id',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'device': 1}),
          starred: false,
          private: false,
        ),
        data: ImageData(
          capturedAt: DateTime(2024, 3, 15),
          imageId: 'copy_image_test_id',
          imageFile: imageFile,
          imageDirectory: imageDir,
        ),
      );

      when(
        () => mockJournalDb.journalEntityById(testImageForCopy.meta.id),
      ).thenAnswer((_) async => testImageForCopy);

      // getFullImagePath calls getDocumentsDirectory() which reads Directory
      // from GetIt.  Register our temp directory for this group.
      if (!getIt.isRegistered<Directory>()) {
        getIt.registerSingleton<Directory>(tempDir);
      }
    });

    tearDown(() async {
      if (getIt.isRegistered<Directory>()) {
        getIt.unregister<Directory>();
      }
      await tempDir.delete(recursive: true);
    });

    test(
      'enters JournalImage branch, reads the file, and completes or throws '
      'native clipboard error',
      () async {
        // copyImage calls getFullImagePath (line 498), gets the clipboard
        // instance (line 500), and – whether clipboard is null or not –
        // must enter the JournalImage branch.
        //
        // When SystemClipboard.instance is non-null (desktop/Linux environment
        // in CI), lines 506-509 run.  clipboard.write may then throw a
        // "DataProviderManager channel not found" native error because the
        // super_clipboard platform channel is not set up in tests.
        // We handle both outcomes so the test is environment-agnostic.
        final container = makeProviderContainer();
        final provider = entryControllerProvider(id: testImageForCopy.meta.id);
        final notifier = container.read(provider.notifier);

        await container.read(provider.future);

        // Verify the entry is a JournalImage before calling copyImage.
        expect(container.read(provider).value?.entry, isA<JournalImage>());

        // copyImage either completes (clipboard null) or throws a native
        // channel error (clipboard non-null but write channel absent).
        // Either path exercises lines 498 and 500.
        Object? caughtError;
        try {
          await notifier.copyImage();
        } catch (e) {
          caughtError = e;
        }

        // If an error was thrown it must be the native channel error, not
        // a logic bug in copyImage itself.
        if (caughtError != null) {
          expect(
            caughtError.toString(),
            contains('DataProviderManager'),
          );
        }

        // State is not mutated by copyImage.
        expect(container.read(provider).value?.entry, testImageForCopy);
      },
    );
  });
}
