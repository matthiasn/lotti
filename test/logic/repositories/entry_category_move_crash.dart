part of 'entry_category_move_test.dart';

// The move against real databases: a task with a project, a linked time
// entry and a checklist with an item, all in one category, moved to another
// — whole, and after an app that died right after the task's write
// (`specs/tla/TaskCategoryMove.tla`).
void _registerDbTests() {
  group('against a real database', () {
    final mockNotificationService = MockNotificationService();
    final mockUpdateNotifications = MockUpdateNotifications();
    final mockFts5Db = MockFts5Db();
    final mockOutboxService = MockOutboxService();
    final mockTimeService = MockTimeService();

    const from = 'cat_from';
    const to = 'cat_to';

    late JournalDb db;
    late SettingsDb settings;
    late ProjectRepository projects;
    late Task task;
    late String entryId;
    late String checklistId;
    late String itemId;

    EntryCategoryMove realMove() => EntryCategoryMove(
      journalRepository: JournalRepository(),
      journalDb: db,
      projectRepository: projects,
      intents: CategoryMoveIntents(settingsDb: settings),
      domainLogger: getIt<DomainLogger>(),
    );

    Future<String?> categoryOf(String id) async =>
        (await db.journalEntityById(id))?.meta.categoryId;

    Future<void> expectMovedWhole() async {
      expect(
        [
          for (final id in [task.meta.id, entryId, checklistId, itemId])
            await categoryOf(id),
        ],
        [to, to, to, to],
      );
      // The project stays in the category the task left.
      expect(await projects.getLinkedProjectForTask(task.meta.id), isNull);
    }

    setUp(() async {
      setFakeDocumentsPath();
      settings = SettingsDb(inMemoryDatabase: true);
      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db, inMemoryDatabase: true);
      when(mockNotificationService.updateBadge).thenAnswer((_) async {});
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));
      when(
        () => mockFts5Db.insertText(any(), removePrevious: true),
      ).thenAnswer((_) async {});
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});
      when(mockTimeService.getCurrent).thenReturn(null);

      final documents = await getApplicationDocumentsDirectory();
      await setUpTestGetIt(
        additionalSetup: () {
          void put<T extends Object>(T instance) {
            if (getIt.isRegistered<T>()) getIt.unregister<T>();
            getIt.registerSingleton<T>(instance);
          }

          put<UpdateNotifications>(mockUpdateNotifications);
          put<Directory>(documents);
          put<SettingsDb>(settings);
          put<Fts5Db>(mockFts5Db);
          put<JournalDb>(db);
          put<OutboxService>(mockOutboxService);
          put<NotificationService>(mockNotificationService);
          put<VectorClockService>(buildVectorClockService());
          put<TimeService>(mockTimeService);
          put<EntitiesCacheService>(MockEntitiesCacheService());
          put<DomainLogger>(DomainLogger(loggingService: LoggingService()));
          put<MetadataService>(
            MetadataService(vectorClockService: getIt<VectorClockService>()),
          );
          put<GeolocationService>(MockGeolocationService());
          put<PersistenceLogic>(buildPersistenceLogic());
        },
      );
      projects = ProjectRepository(
        journalDb: db,
        entitiesCacheService: getIt<EntitiesCacheService>(),
        persistenceLogic: getIt<PersistenceLogic>(),
        updateNotifications: getIt<UpdateNotifications>(),
        vectorClockService: getIt<VectorClockService>(),
      );

      final logic = getIt<PersistenceLogic>();
      task = testTask.copyWith(
        meta: testTask.meta.copyWith(id: 'moving-task', categoryId: from),
      );
      await logic.createDbEntity(task);
      final project = makeTestProject(id: 'project-1', categoryId: from);
      await logic.createDbEntity(project);
      expect(
        await projects.linkTaskToProject(
          projectId: project.meta.id,
          taskId: task.meta.id,
        ),
        isTrue,
      );
      final entry = testTextEntryNoGeo.copyWith(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: 'time-entry',
          categoryId: from,
        ),
      );
      await logic.createDbEntity(entry, linkedId: task.meta.id);
      entryId = entry.meta.id;
      final created = await ChecklistRepository().createChecklist(
        taskId: task.meta.id,
        items: [
          const ChecklistItemData(
            title: 'Rotate the key',
            isChecked: false,
            linkedChecklists: [],
          ),
        ],
        title: 'Launch checks',
      );
      checklistId = created.checklist!.meta.id;
      itemId = created.createdItems.single.id;
      expect(await categoryOf(checklistId), from);
      expect(await categoryOf(itemId), from);
    });

    tearDown(() async {
      await tearDownTestGetIt();
      await db.close();
      await settings.close();
    });

    test('a move takes the linked entry, the checklist and its item along, '
        'and leaves the project', () async {
      expect(await realMove().move(task.meta.id, to), isTrue);

      await expectMovedWhole();
    });

    test('a move the app died in after the task write is finished at the '
        'next start', () async {
      // What the move had written when the app died: its record and the
      // task's own category.
      await CategoryMoveIntents(settingsDb: settings).record(task.meta.id, to);
      expect(
        await JournalRepository().updateCategoryId(
          task.meta.id,
          categoryId: to,
        ),
        isTrue,
      );
      expect(await categoryOf(entryId), from);

      await realMove().replay();

      await expectMovedWhole();
      expect(
        await CategoryMoveIntents(settingsDb: settings).pending(),
        isEmpty,
      );
    });
  });
}
