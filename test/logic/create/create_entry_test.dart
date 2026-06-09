import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../helpers/fallbacks.dart';
import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setFakeDocumentsPath();
  registerFallbackValue(fallbackJournalEntity);
  registerFallbackValue(fallbackSyncMessage);

  final mockNotificationService = MockNotificationService();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockFts5Db = MockFts5Db();
  final mockOutboxService = MockOutboxService();
  final mockTimeService = MockTimeService();
  final mockNavService = MockNavService();
  final mockGeolocationService = MockGeolocationService();

  // Note: Navigation side effects (beamToNamed calls) are intentionally not mocked/verified
  // in these tests. These are unit tests focused on entry creation and persistence logic.
  // Navigation behavior is tested separately in integration/widget tests where the full
  // navigation context is available. The NavService mock is registered to prevent errors,
  // but navigation calls are not asserted as they are implementation details of the
  // create functions, not their core responsibility.
  group('Create Entry Tests - ', () {
    late SettingsDb settingsDb;
    late JournalDb journalDb;

    // Per-test fresh databases + GetIt registrations: no state accumulates
    // across tests, so no test can depend on entries created by another.
    setUp(() async {
      setFakeDocumentsPath();

      settingsDb = SettingsDb(inMemoryDatabase: true);
      journalDb = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(journalDb, inMemoryDatabase: true);

      when(mockNotificationService.updateBadge).thenAnswer((_) async {});

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(
        () => mockFts5Db.insertText(
          any(),
          removePrevious: true,
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockNotificationService.cancelNotification(any()),
      ).thenAnswer((_) async {});

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      when(() => mockTimeService.start(any(), any())).thenAnswer((_) async {});

      final documentsDirectory = await getApplicationDocumentsDirectory();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<UpdateNotifications>()
            ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
            ..registerSingleton<Directory>(documentsDirectory)
            ..unregister<SettingsDb>()
            ..registerSingleton<SettingsDb>(settingsDb)
            ..registerSingleton<Fts5Db>(mockFts5Db)
            ..registerSingleton<UserActivityService>(UserActivityService())
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(journalDb)
            ..registerSingleton<OutboxService>(mockOutboxService)
            ..registerSingleton<NotificationService>(mockNotificationService)
            ..registerSingleton<VectorClockService>(VectorClockService())
            ..registerSingleton<MetadataService>(
              MetadataService(
                vectorClockService: getIt<VectorClockService>(),
              ),
            )
            ..registerSingleton<GeolocationService>(mockGeolocationService)
            ..registerSingleton<TimeService>(mockTimeService)
            ..registerSingleton<NavService>(mockNavService)
            ..registerSingleton<EntitiesCacheService>(
              MockEntitiesCacheService(),
            )
            ..registerSingleton<PersistenceLogic>(PersistenceLogic());
        },
      );
    });

    tearDown(() async {
      clearInteractions(mockNotificationService);
      clearInteractions(mockUpdateNotifications);
      clearInteractions(mockFts5Db);
      clearInteractions(mockTimeService);
      clearInteractions(mockOutboxService);
      clearInteractions(mockNavService);
      await tearDownTestGetIt();
      await journalDb.close();
      await settingsDb.close();
    });

    test('createTextEntry creates and stores a text entry', () async {
      // Create text entry without linkedId
      final entry = await createTextEntry();

      expect(entry, isNotNull);
      expect(entry, isA<JournalEntry>());
      expect(entry?.entryText?.plainText, '');

      // Verify entry is in database
      final retrieved = await getIt<JournalDb>().journalEntityById(
        entry!.meta.id,
      );
      expect(retrieved, isNotNull);
      expect(retrieved?.meta.id, entry.meta.id);
    });

    test('createTextEntry with linkedId creates linked entry', () async {
      // Create parent entry
      final parent = await createTextEntry();
      expect(parent, isNotNull);

      // Create linked entry
      final linked = await createTextEntry(linkedId: parent!.meta.id);
      expect(linked, isNotNull);

      // Verify link exists
      final linkedEntities = await getIt<JournalDb>().getLinkedEntities(
        parent.meta.id,
      );
      expect(linkedEntities.length, 1);
      expect(linkedEntities.first.meta.id, linked!.meta.id);
    });

    test('createTextEntry with categoryId sets category', () async {
      const testCategoryId = 'test-category-123';

      final entry = await createTextEntry(categoryId: testCategoryId);

      expect(entry, isNotNull);
      expect(entry?.categoryId, testCategoryId);
    });

    test('createTask creates and stores a task', () async {
      final task = await createTask();

      expect(task, isNotNull);
      expect(task, isA<Task>());
      expect(task?.data.title, '');
      expect(task?.data.status, isA<TaskOpen>());

      // Verify task is in database
      final retrieved = await getIt<JournalDb>().journalEntityById(
        task!.meta.id,
      );
      expect(retrieved, isNotNull);
      expect(retrieved, isA<Task>());
    });

    test('createTask with linkedId and categoryId', () async {
      const testCategoryId = 'task-category-456';
      final parent = await createTextEntry();
      expect(parent, isNotNull);

      final task = await createTask(
        linkedId: parent!.meta.id,
        categoryId: testCategoryId,
      );

      expect(task, isNotNull);
      expect(task?.categoryId, testCategoryId);

      // Verify link exists
      final linkedEntities = await getIt<JournalDb>().getLinkedEntities(
        parent.meta.id,
      );
      expect(linkedEntities.any((e) => e.meta.id == task!.meta.id), true);
    });

    test(
      'creation coordinators persist metadata invariants for every '
      'linkedId/categoryId combination',
      () async {
        final creators =
            <
              String,
              Future<JournalEntity?> Function({
                String? linkedId,
                String? categoryId,
              })
            >{
              'createTextEntry': createTextEntry,
              'createTask': createTask,
              'createEvent': createEvent,
            };

        for (final MapEntry(key: name, value: create) in creators.entries) {
          for (final withLinked in [false, true]) {
            for (final withCategory in [false, true]) {
              final parent = withLinked ? await createTextEntry() : null;
              final categoryId = withCategory
                  ? 'cat-$name-linked-$withLinked'
                  : null;

              final entity = await create(
                linkedId: parent?.meta.id,
                categoryId: categoryId,
              );
              final reason = '$name linked=$withLinked category=$withCategory';

              expect(entity, isNotNull, reason: reason);
              expect(entity!.meta.id, isNotEmpty, reason: reason);

              final persisted = await getIt<JournalDb>().journalEntityById(
                entity.meta.id,
              );
              expect(persisted, isNotNull, reason: reason);
              // Write timestamps are ordered, and the entity time range is
              // valid. (createdAt <= dateTo does NOT hold for tasks: TaskData
              // captures `now` before createMetadata stamps createdAt.)
              expect(
                persisted!.meta.createdAt.isAfter(persisted.meta.updatedAt),
                isFalse,
                reason: '$reason: createdAt must be <= updatedAt',
              );
              expect(
                persisted.meta.dateFrom.isAfter(persisted.meta.dateTo),
                isFalse,
                reason: '$reason: dateFrom must be <= dateTo',
              );
              expect(persisted.categoryId, categoryId, reason: reason);

              if (parent != null) {
                final linkedEntities = await getIt<JournalDb>()
                    .getLinkedEntities(parent.meta.id);
                expect(
                  linkedEntities.any((e) => e.meta.id == entity.meta.id),
                  isTrue,
                  reason: '$reason: link row must exist',
                );
              }
            }
          }
        }
      },
    );

    test('createTask inherits project from linked task', () async {
      const testCategoryId = 'project-inherit-cat';
      final db = getIt<JournalDb>();
      final mockCache =
          getIt<EntitiesCacheService>() as MockEntitiesCacheService;

      when(() => mockCache.getCategoryById(testCategoryId)).thenReturn(null);

      // Create a parent task.
      final parentTask = await createTask(categoryId: testCategoryId);
      expect(parentTask, isNotNull);

      // Create a project in the same category.
      final testDate = DateTime(2024, 6, 15);
      final project = ProjectEntry(
        meta: Metadata(
          id: 'project-inherit-001',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          categoryId: testCategoryId,
        ),
        data: ProjectData(
          title: 'Test Project',
          status: ProjectStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
          dateFrom: testDate,
          dateTo: testDate,
        ),
      );
      await getIt<PersistenceLogic>().createDbEntity(project);

      // Link the parent task to the project.
      final repo = ProjectRepository(
        journalDb: db,
        entitiesCacheService: getIt<EntitiesCacheService>(),
        persistenceLogic: getIt<PersistenceLogic>(),
        updateNotifications: getIt<UpdateNotifications>(),
        vectorClockService: getIt<VectorClockService>(),
      );
      final linked = await repo.linkTaskToProject(
        projectId: project.meta.id,
        taskId: parentTask!.meta.id,
      );
      expect(linked, isTrue);

      // Create a follow-up task linked to the parent.
      final followUp = await createTask(
        linkedId: parentTask.meta.id,
        categoryId: testCategoryId,
      );
      expect(followUp, isNotNull);

      // Verify the follow-up inherited the project.
      final followUpProject = await db.getProjectForTask(followUp!.meta.id);
      expect(followUpProject, isNotNull);
      expect(followUpProject!.meta.id, project.meta.id);
    });

    test('createTask without linked task does not assign project', () async {
      final task = await createTask();
      expect(task, isNotNull);

      final project = await getIt<JournalDb>().getProjectForTask(task!.meta.id);
      expect(project, isNull);
    });

    test('createEvent creates and stores an event', () async {
      final event = await createEvent();

      expect(event, isNotNull);
      expect(event, isA<JournalEvent>());
      expect(event?.data.title, '');
      expect(event?.data.status, EventStatus.tentative);
      // Events are starred by default (see PersistenceLogic.createEventEntry)
      expect(event?.meta.starred, true);

      // Verify event is in database
      final retrieved = await getIt<JournalDb>().journalEntityById(
        event!.meta.id,
      );
      expect(retrieved, isNotNull);
      expect(retrieved, isA<JournalEvent>());
    });

    test('createEvent with linkedId and categoryId', () async {
      const testCategoryId = 'event-category-789';
      final parent = await createTextEntry();
      expect(parent, isNotNull);

      final event = await createEvent(
        linkedId: parent!.meta.id,
        categoryId: testCategoryId,
      );

      expect(event, isNotNull);
      expect(event?.categoryId, testCategoryId);

      // Verify link exists
      final linkedEntities = await getIt<JournalDb>().getLinkedEntities(
        parent.meta.id,
      );
      expect(linkedEntities.any((e) => e.meta.id == event!.meta.id), true);
    });

    test('createChecklist creates checklist for valid task', () async {
      // Create a task first
      final task = await createTask();
      expect(task, isNotNull);

      // Create ProviderContainer and get a real Ref for testing
      // Note: In Riverpod 3.x, WidgetRef is sealed, so we test the repository directly
      // using a ProviderContainer instead of calling the createChecklist helper function.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Call the repository directly using the container
      // This is equivalent to what createChecklist does with ref.read(checklistRepositoryProvider)
      final result = await container
          .read(checklistRepositoryProvider)
          .createChecklist(taskId: task!.id);
      final checklist = result.checklist;

      expect(checklist, isNotNull);
      expect(checklist, isA<Checklist>());

      // Verify checklist data integrity
      final checklistEntity = checklist! as Checklist;
      expect(
        checklistEntity.data.title,
        'Todos',
      ); // Default title when none provided
      expect(
        checklistEntity.data.linkedChecklistItems,
        isEmpty,
      ); // No items yet
      expect(checklistEntity.data.linkedTasks, contains(task.id));

      // Verify metadata is properly set
      expect(checklistEntity.meta.id, isNotEmpty);
      expect(checklistEntity.meta.createdAt, isNotNull);
      expect(checklistEntity.meta.updatedAt, isNotNull);
      expect(checklistEntity.meta.vectorClock, isNotNull);

      // Verify task has checklist ID
      final updatedTask = await getIt<JournalDb>().journalEntityById(task.id);
      expect(
        (updatedTask! as Task).data.checklistIds,
        contains(checklist.meta.id),
      );

      // Verify checklist is persisted in database
      final retrievedChecklist = await getIt<JournalDb>().journalEntityById(
        checklist.meta.id,
      );
      expect(retrievedChecklist, isNotNull);
      expect(retrievedChecklist, isA<Checklist>());
    });
  });
}
