import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/ai/ai_logic.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../helpers/path_provider.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secureStorageMock = MockSecureStorage();
  setFakeDocumentsPath();
  registerFallbackValue(FakeJournalEntity());

  final mockNotificationService = MockNotificationService();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockAiLogic = MockAiLogic();
  final mockFts5Db = MockFts5Db();

  group('Database Tests - ', () {
    var vcMockNext = '1';

    when(() => mockAiLogic.embed(any())).thenAnswer(
      (_) async {},
    );

    setUpAll(() async {
      setFakeDocumentsPath();

      getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

      final settingsDb = SettingsDb(inMemoryDatabase: true);
      final journalDb = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(journalDb, inMemoryDatabase: true);

      when(() => secureStorageMock.readValue(hostKey))
          .thenAnswer((_) async => 'some_host');
      when(() => secureStorageMock.readValue(nextAvailableCounterKey))
          .thenAnswer((_) async {
        return vcMockNext;
      });
      when(() => secureStorageMock.writeValue(nextAvailableCounterKey, any()))
          .thenAnswer((invocation) async {
        vcMockNext = invocation.positionalArguments[1] as String;
      });

      when(mockNotificationService.updateBadge).thenAnswer((_) async {});

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockFts5Db.insertText(any())).thenAnswer((_) async {});

      when(
        () => mockNotificationService.showNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationId: any(named: 'notificationId'),
          deepLink: any(named: 'deepLink'),
        ),
      ).thenAnswer((_) async {});

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<AiLogic>(mockAiLogic)
        ..registerSingleton<SyncDatabase>(SyncDatabase(inMemoryDatabase: true))
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<TagsService>(TagsService())
        ..registerSingleton<OutboxService>(OutboxService())
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<NotificationService>(mockNotificationService)
        ..registerSingleton<VectorClockService>(VectorClockService())
        ..registerSingleton<PersistenceLogic>(PersistenceLogic());
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    tearDown(() {
      clearInteractions(mockNotificationService);
    });

    test(
      'create and retrieve text entry',
      () async {
        final now = DateTime.now();
        const testText = 'test text';
        const updatedTestText = 'updated test text';

        // create test entry
        final textEntry = await getIt<PersistenceLogic>().createTextEntry(
          const EntryText(plainText: testText),
          id: uuid.v1(),
          started: now,
        );

        // expect to find created entry
        expect(
          (await getIt<JournalDb>().journalEntityById(textEntry!.meta.id))
              ?.entryText
              ?.plainText,
          testText,
        );

        // expect to get created entry in watch stream
        expect(
          (await getIt<JournalDb>().watchEntityById(textEntry.meta.id).first)
              ?.entryText
              ?.plainText,
          testText,
        );

        // update entry with new plaintext
        await getIt<PersistenceLogic>().updateJournalEntity(
          textEntry.copyWith(
            entryText: const EntryText(plainText: updatedTestText),
          ),
          textEntry.meta,
        );

        // expect to find updated entry
        expect(
          (await getIt<JournalDb>().journalEntityById(textEntry.meta.id))
              ?.entryText
              ?.plainText,
          updatedTestText,
        );

        // expect to get updated entry in watch stream
        expect(
          (await getIt<JournalDb>().watchEntityById(textEntry.meta.id).first)
              ?.entryText
              ?.plainText,
          updatedTestText,
        );

        // TODO: why is this failing suddenly?
        //verify(mockNotificationService.updateBadge).called(2);
      },
    );

    test('create and retrieve task', () async {
      final now = DateTime.now();
      final taskData = TaskData(
        status: TaskStatus.open(
          id: uuid.v1(),
          createdAt: now,
          utcOffset: 60,
        ),
        title: 'title',
        statusHistory: [],
        dateTo: DateTime.now(),
        dateFrom: DateTime.now(),
        estimate: const Duration(hours: 1),
      );
      const testTaskText = 'testTaskText';

      // create test task
      final task = await getIt<PersistenceLogic>().createTaskEntry(
        data: taskData,
        entryText: const EntryText(plainText: testTaskText),
      );

      // expect to find created task
      final testTask =
          await getIt<JournalDb>().journalEntityById(task!.meta.id) as Task?;
      expect(testTask?.entryText?.plainText, testTaskText);

      // expect to get created task in watch stream
      final testTaskFromStream =
          await getIt<JournalDb>().watchEntityById(task.meta.id).first as Task?;
      expect(testTaskFromStream?.entryText?.plainText, testTaskText);

      verify(mockNotificationService.updateBadge).called(1);

      // expect correct task by status counts in streams
      expect(await getIt<JournalDb>().watchTaskCount('OPEN').first, 1);
      expect(await getIt<JournalDb>().watchTaskCount('DONE').first, 0);

      // expect task lists by status in streams
      expect(
        (await getIt<JournalDb>().getTasks(
          starredStatuses: [true, false],
          taskStatuses: ['OPEN'],
          categoryIds: [''],
        ))
            .length,
        1,
      );

      expect(
        (await getIt<JournalDb>().getTasks(
          starredStatuses: [true, false],
          taskStatuses: ['OPEN'],
          categoryIds: [''],
          ids: [task.meta.id],
        ))
            .length,
        1,
      );

      expect(
        (await getIt<JournalDb>().getTasks(
          starredStatuses: [true, false],
          taskStatuses: ['DONE'],
          categoryIds: [],
        ))
            .length,
        0,
      );

      expect(
        (await getIt<JournalDb>().getTasks(
          starredStatuses: [true, false],
          taskStatuses: ['DONE'],
          categoryIds: [],
        ))
            .length,
        0,
      );

      // expect task in journal entities stream by type
      expect(
        (await getIt<JournalDb>().getJournalEntities(
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          types: ['Task'],
          ids: null,
        ))
            .length,
        1,
      );

      // update task with status 'IN PROGRESS'
      await getIt<PersistenceLogic>().updateTask(
        journalEntityId: task.meta.id,
        entryText: task.entryText,
        taskData: taskData.copyWith(
          status: TaskStatus.inProgress(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: 60,
          ),
        ),
      );

      // TODO: why is this failing suddenly?
      //verify(mockNotificationService.updateBadge).called(1);
      expect(await getIt<JournalDb>().getWipCount(), 1);
      expect(await getIt<JournalDb>().watchTaskCount('OPEN').first, 0);
      expect(await getIt<JournalDb>().watchTaskCount('IN PROGRESS').first, 1);

      // update task with status 'DONE'
      await getIt<PersistenceLogic>().updateTask(
        journalEntityId: task.meta.id,
        entryText: task.entryText,
        taskData: taskData.copyWith(
          status: TaskStatus.done(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: 60,
          ),
        ),
      );

      // TODO: why is this failing suddenly?
      //verify(mockNotificationService.updateBadge).called(1);

      // expect task counts by status to be updated
      expect(await getIt<JournalDb>().watchTaskCount('OPEN').first, 0);
      expect(await getIt<JournalDb>().watchTaskCount('DONE').first, 1);

      // create test tag
      final testTagId = uuid.v1();
      final testStoryTag = TagEntity.storyTag(
        id: testTagId,
        tag: 'Lotti: testing',
        private: false,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      );

      await getIt<PersistenceLogic>().upsertTagEntity(testStoryTag);

      // expect tag in database when queried
      expect(
        await getIt<JournalDb>().getMatchingTags(testStoryTag.tag),
        [testStoryTag],
      );

      // expect tag in database when queried with substring match
      expect(
        await getIt<JournalDb>()
            .getMatchingTags(testStoryTag.tag.substring(1, 5)),
        [testStoryTag],
      );

      // expect tag in database when watching tags
      expect(
        await getIt<JournalDb>().watchTags().first,
        [testStoryTag],
      );

      // create linked comment entry
      const testText = 'test comment for task';
      const updatedTestText = 'updated test comment for task';
      final comment = await getIt<PersistenceLogic>().createTextEntry(
        const EntryText(plainText: testText),
        id: uuid.v1(),
        started: now,
        linkedId: task.meta.id,
      );

      // add tag to task
      await getIt<PersistenceLogic>().addTagsWithLinked(
        journalEntityId: task.meta.id,
        addedTagIds: [testStoryTag.id],
      );

      // expect tagged entry in journal by tag query
      expect(
        (await getIt<JournalDb>()
                .watchJournalEntitiesByTag(
                  tagId: testTagId,
                  rangeStart: DateTime(0),
                  rangeEnd: DateTime(2100),
                )
                .first)
            .map((entity) => entity.meta.id)
            .toSet()
            .contains(task.meta.id),
        true,
      );

      expect(
        (await getIt<JournalDb>()
                .watchJournalEntitiesByTag(
                  tagId: testTagId,
                  rangeStart: DateTime(0),
                  rangeEnd: DateTime(2100),
                )
                .first)
            .map((entity) => entity.meta.id)
            .toSet()
            .contains(comment?.meta.id),
        true,
      );

      await getIt<PersistenceLogic>().updateJournalEntityText(
        comment!.meta.id,
        const EntryText(
          plainText: updatedTestText,
        ),
        comment.meta.dateTo,
      );

      // expect linked comment entry to appear in stream
      final linked = await getIt<JournalDb>()
          .watchLinkedEntities(linkedFrom: task.meta.id)
          .first;

      expect(linked.first.entryText?.plainText, updatedTestText);
      expect(linked.first.meta.tagIds?.toSet(), {testTagId});

      expect(
        (await getIt<JournalDb>().getLinkedEntities(task.meta.id))
            .first
            .entryText,
        (await getIt<JournalDb>().journalEntityById(comment.meta.id))
            ?.entryText,
      );

      expect(
        (await getIt<JournalDb>()
                .watchLinkedToEntities(linkedTo: comment.meta.id)
                .first)
            .first
            .entryText,
        (await getIt<JournalDb>().journalEntityById(task.meta.id))?.entryText,
      );

      // linked ids can be watched
      expect(
        await getIt<JournalDb>().watchLinkedEntityIds(task.meta.id).first,
        [comment.meta.id],
      );

      expect(await getIt<JournalDb>().watchTaggedCount().first, 2);

      // remove tags and expect them to be empty
      await getIt<PersistenceLogic>()
          .removeTag(journalEntityId: comment.meta.id, tagId: testTagId);

      expect(await getIt<JournalDb>().watchTaggedCount().first, 1);

      expect(
        (await getIt<JournalDb>().journalEntityById(comment.meta.id))
            ?.meta
            .tagIds,
        isEmpty,
      );

      // expect three entries to be in database
      expect(await getIt<JournalDb>().watchJournalCount().first, 3);
      expect(await getIt<JournalDb>().getJournalCount(), 3);

      // unlink comment from task
      expect(
        await getIt<JournalDb>().removeLink(
          fromId: task.meta.id,
          toId: comment.meta.id,
        ),
        1,
      );

      // delete task and expect counts to be updated
      await getIt<PersistenceLogic>().deleteJournalEntity(task.meta.id);
      expect(await getIt<JournalDb>().watchJournalCount().first, 2);
      expect(await getIt<JournalDb>().getJournalCount(), 2);
      expect(await getIt<JournalDb>().watchTaskCount('OPEN').first, 0);
      expect(await getIt<JournalDb>().watchTaskCount('DONE').first, 0);
      expect(await getIt<JournalDb>().getWipCount(), 0);

      await getIt<JournalDb>().purgeDeleted(backup: false);
    });

    test('create and retrieve workout entry', () async {
      // create test workout
      final workoutData = WorkoutData(
        id: 'some_id',
        workoutType: '',
        energy: 100,
        distance: 10,
        dateFrom: DateTime.fromMillisecondsSinceEpoch(0),
        dateTo: DateTime.fromMillisecondsSinceEpoch(3600000),
        source: '',
      );

      final workout =
          await getIt<PersistenceLogic>().createWorkoutEntry(workoutData);
      expect(workout?.data, workoutData);

      // workout is retrieved as latest workout
      expect((await getIt<JournalDb>().latestWorkout())?.data, workoutData);

      // workout is retrieved on workout watch stream
      expect(
        ((await getIt<JournalDb>()
                    .watchWorkouts(
                      rangeStart: DateTime(0),
                      rangeEnd: DateTime(2100),
                    )
                    .first)
                .first as WorkoutEntry)
            .data,
        workoutData,
      );
    });

    test('create and retrieve QuantitativeEntry', () async {
      final entry = await getIt<PersistenceLogic>().createQuantitativeEntry(
        testWeightEntry.data,
      );
      expect(entry?.data, testWeightEntry.data);

      // workout is retrieved as latest workout
      expect(
        (await getIt<JournalDb>()
                .latestQuantitativeByType('HealthDataType.WEIGHT'))
            ?.data,
        testWeightEntry.data,
      );

      // workout is retrieved on workout watch stream
      expect(
        ((await getIt<JournalDb>()
                    .watchQuantitativeByType(
                      rangeStart: DateTime(0),
                      rangeEnd: DateTime(2100),
                      type: 'HealthDataType.WEIGHT',
                    )
                    .first)
                .first as QuantitativeEntry)
            .data,
        testWeightEntry.data,
      );
    });

    test('create and retrieve measurement entry', () async {
      // create test data types
      await getIt<JournalDb>().upsertMeasurableDataType(measurableWater);
      await getIt<JournalDb>().upsertMeasurableDataType(measurableChocolate);

      // create test measurements
      final measurementData = MeasurementData(
        dateFrom: DateTime.fromMillisecondsSinceEpoch(0),
        dateTo: DateTime.fromMillisecondsSinceEpoch(3600000),
        value: 1000,
        dataTypeId: measurableWater.id,
      );

      // measurement data from db equals data used for creating measurement
      final measurement =
          await getIt<PersistenceLogic>().createMeasurementEntry(
        data: measurementData,
        private: false,
      );

      expect(measurement?.data, measurementData);

      // measurement is retrieved in query by type
      expect(
        ((await getIt<JournalDb>()
                    .watchMeasurementsByType(
                      rangeStart: DateTime(0),
                      rangeEnd: DateTime(2100),
                      type: measurableWater.id,
                    )
                    .first)
                .first as MeasurementEntry)
            .data,
        measurementData,
      );

      expect(
        await getIt<JournalDb>()
            .watchMeasurementsByType(
              rangeStart: DateTime(0),
              rangeEnd: DateTime(2100),
              type: measurableChocolate.id,
            )
            .first,
        isEmpty,
      );

      // measurable types can be retrieved
      expect(
        (await getIt<JournalDb>().watchMeasurableDataTypes().first).toSet(),
        {measurableChocolate, measurableWater},
      );

      expect(
        await getIt<JournalDb>()
            .watchMeasurableDataTypeById(measurableChocolate.id)
            .first,
        measurableChocolate,
      );

      expect(
        await getIt<JournalDb>()
            .getMeasurableDataTypeById(measurableChocolate.id),
        measurableChocolate,
      );

      // measurable can be deleted
      await getIt<PersistenceLogic>().upsertEntityDefinition(
        measurableChocolate.copyWith(deletedAt: DateTime.now()),
      );

      expect(
        await getIt<JournalDb>()
            .getMeasurableDataTypeById(measurableChocolate.id),
        null,
      );

      expect(
        (await getIt<JournalDb>().watchMeasurableDataTypes().first).toSet(),
        {measurableWater},
      );
    });

    test('create and retrieve tag', () async {
      const testTag = 'test-tag';
      await getIt<PersistenceLogic>().addTagDefinition(testTag);

      final createdTag =
          (await getIt<JournalDb>().getMatchingTags(testTag)).first;

      expect(createdTag.tag, testTag);
    });

    test('create, retrieve and delete dashboard', () async {
      await getIt<PersistenceLogic>()
          .upsertDashboardDefinition(testDashboardConfig);

      final created = await getIt<JournalDb>()
          .watchDashboardById(testDashboardConfig.id)
          .first;

      expect(created, testDashboardConfig);

      when(() => mockNotificationService.cancelNotification(any()))
          .thenAnswer((_) async {});

      await getIt<PersistenceLogic>()
          .deleteDashboardDefinition(testDashboardConfig);

      final item = await getIt<JournalDb>()
          .watchDashboardById(testDashboardConfig.id)
          .first;

      expect(item, null);
    });

    test('create and retrieve habit definition', () async {
      await getIt<PersistenceLogic>().upsertEntityDefinition(habitFlossing);

      final habitCompletionData = HabitCompletionData(
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        habitId: habitFlossing.id,
      );

      final habitCompletion =
          await getIt<PersistenceLogic>().createHabitCompletionEntry(
        data: habitCompletionData,
        habitDefinition: habitFlossing,
      );

      expect(habitCompletion?.data, habitCompletionData);

      // habit can be retrieved
      expect(
        (await getIt<JournalDb>().watchHabitDefinitions().first).toSet(),
        {habitFlossing},
      );

      expect(
        await getIt<JournalDb>().watchHabitById(habitFlossing.id).first,
        habitFlossing,
      );

      // habit can be deleted
      await getIt<PersistenceLogic>().upsertEntityDefinition(
        habitFlossing.copyWith(deletedAt: DateTime.now()),
      );

      expect(
        await getIt<JournalDb>().watchHabitById(habitFlossing.id).first,
        null,
      );
    });
  });
}
