import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
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

import '../../features/agents/test_utils.dart';
import '../../helpers/fallbacks.dart';
import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
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
      clearInteractions(mockGeolocationService);
      await tearDownTestGetIt();
      await journalDb.close();
      await settingsDb.close();
    });

    test(
      'createScreenshot persists captured data and requests geolocation',
      () async {
        final entry = await createScreenshot(
          capture: () async => testImageEntry.data,
        );
        expect(entry, isA<JournalImage>());
        final image = entry! as JournalImage;
        expect(image.data, testImageEntry.data);
        expect(image.meta.dateFrom, testImageEntry.data.capturedAt);
        expect(image.meta.dateTo, testImageEntry.data.capturedAt);
        expect(await journalDb.journalEntityById(image.meta.id), image);
        verify(
          () => mockGeolocationService.addGeolocation(
            image.meta.id,
            getIt<PersistenceLogic>().updateDbEntity,
          ),
        ).called(1);
      },
    );

    test('createScreenshot persists the link to its parent', () async {
      final parent = await createTextEntry();
      expect(parent, isNotNull);
      final screenshot = await createScreenshot(
        linkedId: parent!.meta.id,
        capture: () async => testImageEntry.data,
      );
      expect(screenshot, isA<JournalImage>());
      final linked = await journalDb.getLinkedEntities(parent.meta.id);
      expect(linked.map((e) => e.meta.id), [screenshot!.meta.id]);
      expect((linked.single as JournalImage).data, testImageEntry.data);
    });

    test('createScreenshot persists the selected category', () async {
      const categoryId = 'screenshot-category-123';
      final screenshot = await createScreenshot(
        categoryId: categoryId,
        capture: () async => testImageEntry.data,
      );
      expect(screenshot?.categoryId, categoryId);
      final saved = await journalDb.journalEntityById(screenshot!.meta.id);
      expect(saved?.categoryId, categoryId);
      expect((saved! as JournalImage).data, testImageEntry.data);
    });

    test('a capture failure creates no entry or geolocation request', () async {
      final error = StateError('capture failed');
      final before = await journalDb.select(journalDb.journal).get();
      await expectLater(
        createScreenshot(capture: () async => throw error),
        throwsA(same(error)),
      );
      expect(await journalDb.select(journalDb.journal).get(), before);
      verifyZeroInteractions(mockGeolocationService);
    });

    test('createTask inherits defaultProfileId from category', () async {
      const categoryId = 'cat-with-profile';
      const profileId = 'profile-abc';
      final mockCache =
          getIt<EntitiesCacheService>() as MockEntitiesCacheService;

      final category = CategoryDefinition(
        id: categoryId,
        name: 'Test',
        private: false,
        active: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        defaultProfileId: profileId,
      );
      when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

      final task = await createTask(categoryId: categoryId);

      expect(task, isNotNull);
      expect(task!.data.profileId, equals(profileId));
    });

    test(
      'createTask has null profileId when category has no default',
      () async {
        const categoryId = 'cat-no-profile';
        final mockCache =
            getIt<EntitiesCacheService>() as MockEntitiesCacheService;

        final category = CategoryDefinition(
          id: categoryId,
          name: 'Plain',
          private: false,
          active: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );
        when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

        final task = await createTask(categoryId: categoryId);

        expect(task, isNotNull);
        expect(task!.data.profileId, isNull);
      },
    );

    test('createTask has null profileId when no categoryId', () async {
      final task = await createTask();
      expect(task, isNotNull);
      expect(task!.data.profileId, isNull);
    });

    test(
      'autoAssignCategoryAgentWith creates agent for category with template',
      () async {
        const categoryId = 'cat-with-template';
        const templateId = 'template-xyz';
        const profileId = 'profile-xyz';
        final mockCache =
            getIt<EntitiesCacheService>() as MockEntitiesCacheService;

        final category = CategoryDefinition(
          id: categoryId,
          name: 'AI Cat',
          private: false,
          active: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          defaultTemplateId: templateId,
          defaultProfileId: profileId,
        );
        when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

        final task = await createTask(categoryId: categoryId);
        expect(task, isNotNull);

        final mockService = MockTaskAgentService();
        when(
          () => mockService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            setupOrigin: any(named: 'setupOrigin'),
            setupOriginEntityId: any(named: 'setupOriginEntityId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        ).thenAnswer(
          (_) async => makeTestIdentity(id: 'agent-1'),
        );

        await autoAssignCategoryAgentWith(mockService, task!);

        verify(
          () => mockService.createTaskAgent(
            taskId: task.meta.id,
            templateId: templateId,
            profileId: profileId,
            setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
            setupOriginEntityId: categoryId,
            allowedCategoryIds: {categoryId},
            awaitContent: true,
          ),
        ).called(1);
      },
    );

    test(
      'autoAssignCategoryAgentWith does nothing when no categoryId',
      () async {
        final task = await createTask();
        expect(task, isNotNull);

        final mockService = MockTaskAgentService();
        await autoAssignCategoryAgentWith(mockService, task!);

        verifyNever(
          () => mockService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    test(
      'autoAssignCategoryAgentWith does nothing when no defaultTemplateId',
      () async {
        const categoryId = 'cat-no-template';
        final mockCache =
            getIt<EntitiesCacheService>() as MockEntitiesCacheService;

        final category = CategoryDefinition(
          id: categoryId,
          name: 'No Template',
          private: false,
          active: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );
        when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

        final task = await createTask(categoryId: categoryId);
        expect(task, isNotNull);

        final mockService = MockTaskAgentService();
        await autoAssignCategoryAgentWith(mockService, task!);

        verifyNever(
          () => mockService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    test(
      'autoAssignCategoryAgentWith catches errors gracefully',
      () async {
        const categoryId = 'cat-error';
        const templateId = 'template-err';
        final mockCache =
            getIt<EntitiesCacheService>() as MockEntitiesCacheService;

        final category = CategoryDefinition(
          id: categoryId,
          name: 'Error Cat',
          private: false,
          active: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          defaultTemplateId: templateId,
        );
        when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

        final task = await createTask(categoryId: categoryId);
        expect(task, isNotNull);

        final mockService = MockTaskAgentService();
        when(
          () => mockService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            setupOrigin: any(named: 'setupOrigin'),
            setupOriginEntityId: any(named: 'setupOriginEntityId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        ).thenThrow(Exception('Service unavailable'));

        // Should not throw — errors are caught and logged.
        await autoAssignCategoryAgentWith(mockService, task!);
      },
    );

    test(
      'autoAssignCategoryAgentWith catches StateError without propagating',
      () async {
        const categoryId = 'cat-state-error';
        const templateId = 'template-state-err';
        final mockCache =
            getIt<EntitiesCacheService>() as MockEntitiesCacheService;

        final category = CategoryDefinition(
          id: categoryId,
          name: 'State Error Cat',
          private: false,
          active: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          defaultTemplateId: templateId,
        );
        when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

        final task = await createTask(categoryId: categoryId);
        expect(task, isNotNull);

        final mockService = MockTaskAgentService();
        when(
          () => mockService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            setupOrigin: any(named: 'setupOrigin'),
            setupOriginEntityId: any(named: 'setupOriginEntityId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        ).thenThrow(StateError('Bad state'));

        // Should not throw — the catch block handles all error types.
        await autoAssignCategoryAgentWith(mockService, task!);

        // Verify the service was indeed called (the error was thrown and caught).
        verify(
          () => mockService.createTaskAgent(
            taskId: task.meta.id,
            templateId: templateId,
            setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
            setupOriginEntityId: categoryId,
            allowedCategoryIds: {categoryId},
            awaitContent: true,
          ),
        ).called(1);
      },
    );

    test(
      'autoAssignCategoryEventAgentWith creates event agent for category '
      'with defaultEventTemplateId',
      () async {
        const categoryId = 'cat-event-template';
        const templateId = 'event-template-xyz';
        const profileId = 'profile-xyz';
        final mockCache =
            getIt<EntitiesCacheService>() as MockEntitiesCacheService;

        final category = CategoryDefinition(
          id: categoryId,
          name: 'Event Cat',
          private: false,
          active: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          defaultEventTemplateId: templateId,
          defaultProfileId: profileId,
        );
        when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

        final event = await createEvent(categoryId: categoryId);
        expect(event, isNotNull);

        final mockService = MockEventAgentService();
        when(
          () => mockService.createEventAgent(
            eventId: any(named: 'eventId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        ).thenAnswer((_) async => makeTestIdentity(id: 'event-agent-1'));

        await autoAssignCategoryEventAgentWith(mockService, event!);

        verify(
          () => mockService.createEventAgent(
            eventId: event.meta.id,
            templateId: templateId,
            profileId: profileId,
            allowedCategoryIds: {categoryId},
            // Event agents attach in content-awaiting mode (the default).
            // ignore: avoid_redundant_argument_values
            awaitContent: true,
          ),
        ).called(1);
      },
    );

    test(
      'autoAssignCategoryEventAgentWith does nothing when no categoryId',
      () async {
        final event = await createEvent();
        expect(event, isNotNull);

        final mockService = MockEventAgentService();
        await autoAssignCategoryEventAgentWith(mockService, event!);

        verifyNever(
          () => mockService.createEventAgent(
            eventId: any(named: 'eventId'),
            templateId: any(named: 'templateId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    test(
      'autoAssignCategoryEventAgentWith does nothing without '
      'defaultEventTemplateId',
      () async {
        const categoryId = 'cat-no-event-template';
        final mockCache =
            getIt<EntitiesCacheService>() as MockEntitiesCacheService;

        final category = CategoryDefinition(
          id: categoryId,
          name: 'No Event Template',
          private: false,
          active: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          // A task template alone must NOT spawn an event agent.
          defaultTemplateId: 'task-template-only',
        );
        when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

        final event = await createEvent(categoryId: categoryId);
        expect(event, isNotNull);

        final mockService = MockEventAgentService();
        await autoAssignCategoryEventAgentWith(mockService, event!);

        verifyNever(
          () => mockService.createEventAgent(
            eventId: any(named: 'eventId'),
            templateId: any(named: 'templateId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    test(
      'autoAssignCategoryEventAgentWith catches errors gracefully',
      () async {
        const categoryId = 'cat-event-error';
        const templateId = 'event-template-err';
        final mockCache =
            getIt<EntitiesCacheService>() as MockEntitiesCacheService;

        final category = CategoryDefinition(
          id: categoryId,
          name: 'Event Error Cat',
          private: false,
          active: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          defaultEventTemplateId: templateId,
        );
        when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

        final event = await createEvent(categoryId: categoryId);
        expect(event, isNotNull);

        final mockService = MockEventAgentService();
        when(
          () => mockService.createEventAgent(
            eventId: any(named: 'eventId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        ).thenThrow(StateError('already exists'));

        // Should not throw — errors are caught and logged.
        await autoAssignCategoryEventAgentWith(mockService, event!);
      },
    );
  });
}
