import 'dart:async';

import 'package:flutter_quill/flutter_quill.dart'; // Import for QuillController
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/features/sync/vector_clock.dart'; // Added import for VectorClock
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../utils/utils.dart';
import '../../../utils/wait.dart';

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

// Create a Fake class for EntryText to use with registerFallbackValue
class FakeEntryText extends Fake implements EntryText {}

// Mock for EditorStateService
class MockEditorStateService extends Mock implements EditorStateService {}

// Fake for QuillController
class FakeQuillController extends Fake implements QuillController {}

// Added FakeTaskData
class FakeTaskData extends Fake implements TaskData {}

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
    starred: false, private: false,
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
  var vcMockNext =
      '1'; // This was used by secureStorageMock for vector clock testing

  ProviderContainer makeProviderContainer({
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: overrides,
    );
    addTearDown(container.dispose);
    return container;
  }

  // setUpAll at main scope
  setUpAll(() {
    registerFallbackValue(FakeJournalEntity());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(FakeEntryText());
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(FakeEventData());
    registerFallbackValue(const AsyncLoading<EntryState?>());
    registerFallbackValue(DateTime.now());
    registerFallbackValue(FakeQuillController());

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
    when(() => mockEditorStateService.getUnsavedStream(any(), any()))
        .thenAnswer((_) => Stream<bool>.fromIterable([false]));
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

    when(() => secureStorageMock.readValue(hostKey))
        .thenAnswer((_) async => 'some_host');
    when(() => secureStorageMock.readValue(nextAvailableCounterKey))
        .thenAnswer((_) async => vcMockNext);
    when(() => secureStorageMock.writeValue(nextAvailableCounterKey, any()))
        .thenAnswer((invocation) async {
      vcMockNext = invocation.positionalArguments[1] as String;
    });

    getIt
      ..registerSingleton<SettingsDb>(settingsDb)
      ..registerSingleton<NotificationService>(mockNotificationService)
      ..registerSingleton<SyncDatabase>(SyncDatabase(inMemoryDatabase: true))
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
      ..registerSingleton<LoggingService>(LoggingService())
      ..registerSingleton<SecureStorage>(secureStorageMock)
      ..registerSingleton<OutboxService>(OutboxService())
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<VectorClockService>(VectorClockService())
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
      ..registerSingleton<EditorStateService>(mockEditorStateService);

    when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
        .thenAnswer((_) async => testTextEntry);
    when(() => mockJournalDb.journalEntityById(testTextEntryNoGeo.meta.id))
        .thenAnswer((_) async => testTextEntryNoGeo);
    when(() => mockJournalDb.journalEntityById(testTask.meta.id))
        .thenAnswer((_) async => testTask);
    when(() => mockJournalDb.journalEntityById(testEventEntry.meta.id))
        .thenAnswer((_) async => testEventEntry);
    // For addTextToImage tests - ensure these are also available if not overridden in group's setUp
    when(() => mockJournalDb.journalEntityById(testImageEntryNoText.meta.id))
        .thenAnswer((_) async => testImageEntryNoText);
    when(
      () => mockJournalDb.journalEntityById(testImageEntryWithMarkdown.meta.id),
    ).thenAnswer((_) async => testImageEntryWithMarkdown);

    when(() => mockPersistenceLogic.updateJournalEntity(any(), any()))
        .thenAnswer((_) async => true);
    when(mockNotificationService.updateBadge).thenAnswer((_) async {});

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
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);
      when(() => mockJournalDb.journalEntityById(testTextEntryNoGeo.meta.id))
          .thenAnswer((_) async => testTextEntryNoGeo);
      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);
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
          journalRepositoryProvider
              .overrideWithValue(localMockJournalRepository),
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
      when(() => localMockJournalRepository.deleteJournalEntity(entryId))
          .thenAnswer((_) async => true);
      // If getLinkedEntities is called by the controller during this flow, stub it too.
      when(
        () => localMockJournalRepository.getLinkedEntities(
          linkedTo: any(named: 'linkedTo'),
        ),
      ).thenAnswer((_) async => []);

      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider
              .overrideWithValue(localMockJournalRepository),
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
        (_) async => testTextEntry.meta.copyWith(deletedAt: DateTime.now()),
      );

      await notifier.delete(beamBack: false);
      verify(() => localMockJournalRepository.deleteJournalEntity(entryId))
          .called(1);
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
      when(() => localMockJournalRepository.deleteJournalEntity(entryId))
          .thenAnswer((_) async => true);
      when(
        () => localMockJournalRepository.getLinkedEntities(
          linkedTo: any(named: 'linkedTo'),
        ),
      ).thenAnswer((_) async => []);

      final container = makeProviderContainer(
        overrides: [
          journalRepositoryProvider
              .overrideWithValue(localMockJournalRepository),
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
        (_) async => testTextEntry.meta.copyWith(deletedAt: DateTime.now()),
      );

      await notifier.delete(beamBack: true);
      verify(() => localMockJournalRepository.deleteJournalEntity(entryId))
          .called(1);

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

        // wait until state change, not sure why waitUntilAsync alone not working
        await waitMilliseconds(100);
        await waitUntilAsync(
          () async => (await container.read(testEntryProvider.future)) != null,
        );

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

        final plainText =
            entryTextFromController(notifier.controller).plainText;
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

    test('focus node listener - no change when focus state unchanged',
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
      final stateBeforeSecondCall =
          await container.read(testEntryProvider.future);
      notifier.focusNodeListener(); // Should return early
      final stateAfterSecondCall =
          await container.read(testEntryProvider.future);

      expect(stateBeforeSecondCall, equals(stateAfterSecondCall));
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
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
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

      test('propagates categoryId to linked entries with null categoryId',
          () async {
        final localMockJournalRepository = MockJournalRepository();

        final linkedEntry1 = testTask.copyWith(
          meta: testTask.meta.copyWith(id: 'linked_1', categoryId: null),
        );
        final linkedEntry2 = testTextEntryNoGeo.copyWith(
          meta: testTextEntryNoGeo.meta
              .copyWith(id: 'linked_2', categoryId: null),
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
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
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

      test(
          'does not propagate categoryId to linked entries that already have a categoryId',
          () async {
        final localMockJournalRepository = MockJournalRepository();

        final linkedEntryWithCategory = testTask.copyWith(
          meta: testTask.meta
              .copyWith(id: 'linked_with_cat', categoryId: 'existing_cat_id'),
        );
        final linkedEntryNullCategory = testTextEntryNoGeo.copyWith(
          meta: testTextEntryNoGeo.meta
              .copyWith(id: 'linked_null_cat', categoryId: null),
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
        ).thenAnswer(
          (_) async => [linkedEntryWithCategory, linkedEntryNullCategory],
        );
        when(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntryNullCategory.id,
            categoryId: testCategoryId,
          ),
        ).thenAnswer((_) async => true);

        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
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
            linkedEntryNullCategory.id,
            categoryId: testCategoryId,
          ),
        ).called(1);
        verifyNever(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntryWithCategory.id,
            categoryId: testCategoryId,
          ),
        );
      });

      test('handles null categoryId update (clearing category)', () async {
        final localMockJournalRepository = MockJournalRepository();

        final linkedEntryNullCategory = testTextEntryNoGeo.copyWith(
          meta: testTextEntryNoGeo.meta.copyWith(
            id: 'linked_null_cat_clear',
            categoryId: null,
          ), // This one should be updated to null
        );
        final linkedEntryWithCategory = testTask.copyWith(
          meta: testTask.meta.copyWith(
            id: 'linked_with_cat_clear',
            categoryId: 'existing_cat_id',
          ), // This one should NOT be updated to null
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
          (_) async => [linkedEntryNullCategory, linkedEntryWithCategory],
        );
        when(
          () => localMockJournalRepository.updateCategoryId(
            linkedEntryNullCategory.id,
            categoryId: null,
          ),
        ).thenAnswer((_) async => true);

        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
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
            linkedEntryNullCategory.id,
            categoryId: null,
          ),
        ).called(1);
        verifyNever(
          () => localMockJournalRepository
              .updateCategoryId(linkedEntryWithCategory.id, categoryId: null),
        );
      });

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
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
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
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
        await container
            .read(entryControllerProvider(id: entryId).future); // Ensure loaded

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
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
        await container
            .read(entryControllerProvider(id: entryId).future); // Ensure loaded

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
      test('emits AsyncError when _journalDb.journalEntityById throws',
          () async {
        const entryId = 'error-id';
        final exception = Exception('Database error');

        when(() => mockJournalDb.journalEntityById(entryId))
            .thenThrow(exception);

        final localMockJournalRepository = MockJournalRepository();
        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
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
            verify(() => listener(captureAny(), captureAny())).captured.last;
        expect(lastEmittedValue, isA<AsyncError<EntryState?>>());
        expect((lastEmittedValue as AsyncError).error, exception);
      });

      test(
          'emits EntryState.saved with null entry when _journalDb.journalEntityById returns null',
          () async {
        const entryId = 'not-found-id';

        when(() => mockJournalDb.journalEntityById(entryId))
            .thenAnswer((_) async => null);

        final localMockJournalRepository = MockJournalRepository();
        when(
          () => localMockJournalRepository.getLinkedEntities(
            linkedTo: any(named: 'linkedTo'),
          ),
        ).thenAnswer((_) async => []);

        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );

        final initialState =
            await container.read(entryControllerProvider(id: entryId).future);

        expect(initialState, isNotNull);
        expect(initialState, isNot(isA<EntryStateDirty>()));
        expect(initialState?.entry, isNull);
        expect(initialState?.entryId, entryId);
      });
    });

    group('save method - JournalEntry (text)', () {
      final entryId = testTextEntry.meta.id;

      test('successful save updates state and calls dependencies', () async {
        final localMockJournalRepository = MockJournalRepository();
        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
        await container.read(entryControllerProvider(id: entryId).future);

        notifier.controller.document.insert(0, 'New text');
        notifier.setDirty(value: true);
        final dirtyState =
            await container.read(entryControllerProvider(id: entryId).future);
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

        final savedState =
            await container.read(entryControllerProvider(id: entryId).future);
        expect(savedState, isNot(isA<EntryStateDirty>()));
        expect(savedState?.shouldShowEditorToolBar, isFalse);
      });

      test('save with stopRecording calls TimeService.stop', () async {
        final localMockJournalRepository = MockJournalRepository();
        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
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

        verify(mockTimeService.stop).called(1);
      });

      test('save propagates exception from updateJournalEntityText', () async {
        final localMockJournalRepository = MockJournalRepository();
        final exception = Exception('Persistence error');
        final container = makeProviderContainer(
          overrides: [
            journalRepositoryProvider
                .overrideWithValue(localMockJournalRepository),
          ],
        );
        final notifier =
            container.read(entryControllerProvider(id: entryId).notifier);
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
  });

  // Add tests for updateChecklistOrder
  group('updateChecklistOrder method', () {
    const entryId = _testTaskId; // ID of the main Task entry

    setUp(() {
      reset(mockPersistenceLogic);
      reset(mockJournalDb);

      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => testTaskEntry);
      when(() => mockJournalDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => [testChecklistItem1, testChecklistItem2]);

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
      when(() => mockJournalDb.journalEntityById(nonTaskEntryId))
          .thenAnswer((_) async => testImageEntryNoText);

      final container = makeProviderContainer();
      final notifier =
          container.read(entryControllerProvider(id: nonTaskEntryId).notifier);
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

    test('updates with an empty list, clearing existing checklistIds',
        () async {
      final container = makeProviderContainer();
      final notifier =
          container.read(entryControllerProvider(id: entryId).notifier);
      await container.read(entryControllerProvider(id: entryId).future);

      notifier.controller.document
          .insert(0, 'Task description from controller');
      final expectedEntryText = entryTextFromController(notifier.controller);

      when(() => mockJournalDb.getJournalEntitiesForIds(const <String>{}))
          .thenAnswer((_) async => []);

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
    });

    test('updates with a new order of existing checklistIds', () async {
      final container = makeProviderContainer();
      final notifier =
          container.read(entryControllerProvider(id: entryId).notifier);
      await container.read(entryControllerProvider(id: entryId).future);
      notifier.controller.document.insert(0, 'Reordering checklist');
      final expectedEntryText = entryTextFromController(notifier.controller);

      final newOrder = [testChecklistItem2.id, testChecklistItem1.id];
      when(
        () => mockJournalDb.getJournalEntitiesForIds(
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
      final notifier =
          container.read(entryControllerProvider(id: entryId).notifier);
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
        () => mockJournalDb.getJournalEntitiesForIds({
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
      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);
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

  group('updateRating method', () {
    setUp(() {
      reset(mockPersistenceLogic);
      // Ensure mocks are set up for this group
      when(() => mockJournalDb.journalEntityById(testEventEntry.meta.id))
          .thenAnswer((_) async => testEventEntry);
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);
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
      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);
    });

    test('registers hotkey on focus and unregisters on unfocus', () async {
      final container = makeProviderContainer();
      final entryId = testTask.meta.id;
      final testEntryProvider = entryControllerProvider(id: entryId);
      final notifier = container.read(testEntryProvider.notifier);

      await container.read(testEntryProvider.future);

      // Simulate focus
      notifier.taskTitleFocusNode.requestFocus();
      notifier.taskTitleFocusNodeListener();

      // On desktop, hotkey would be registered here
      // We can't directly test hotKeyManager without mocking it

      // Simulate unfocus
      notifier.taskTitleFocusNode.unfocus();
      notifier.taskTitleFocusNodeListener();

      // On desktop, hotkey would be unregistered here
    });
  });

  group('save method - JournalEvent', () {
    setUp(() {
      reset(mockPersistenceLogic);
      // Ensure mocks are set up for this group
      when(() => mockJournalDb.journalEntityById(testEventEntry.meta.id))
          .thenAnswer((_) async => testEventEntry);
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
      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);
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
  });
}

class MockJournalRepository extends Mock implements JournalRepository {}
