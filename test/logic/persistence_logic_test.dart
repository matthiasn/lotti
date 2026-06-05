import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:research_package/model.dart';

import '../helpers/fallbacks.dart';
import '../helpers/path_provider.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

// ---------------------------------------------------------------------------
// Helpers and scenario classes for persistence-logic update tests.
// ---------------------------------------------------------------------------

enum _GeneratedPersistenceEntityKind {
  journalEntry,
  event,
  task,
  measurement,
  habitCompletion,
  image,
  audio,
}

class _GeneratedUpdateDbEntityScenario {
  const _GeneratedUpdateDbEntityScenario({
    required this.kind,
    required this.seed,
    required this.applied,
    required this.enqueueSync,
    required this.hasLinkedId,
    required this.parentCount,
  });

  final _GeneratedPersistenceEntityKind kind;
  final int seed;
  final bool applied;
  final bool enqueueSync;
  final bool hasLinkedId;
  final int parentCount;

  String? get linkedId => hasLinkedId ? 'linked-$seed' : null;

  List<String> get parentIds => [
    for (var index = 0; index < parentCount; index++) 'parent-$seed-$index',
  ];

  JournalEntity get entity => _buildGeneratedEntity(kind, seed);

  Set<String> get expectedNotificationIds => {
    ..._expectedAffectedIds(kind, 'entity-$seed'),
    ?linkedId,
    ...parentIds,
    // Each parent ID is also emitted in propagated form so the wake
    // orchestrator can defer parent-fan-out matches to the next 06:00
    // instead of treating them as direct edits.
    for (final id in parentIds) propagatedNotification(id),
    labelUsageNotification,
  };

  bool get shouldEnqueueSync => applied && enqueueSync;

  @override
  String toString() {
    return '_GeneratedUpdateDbEntityScenario('
        'kind: $kind, '
        'seed: $seed, '
        'applied: $applied, '
        'enqueueSync: $enqueueSync, '
        'linkedId: $linkedId, '
        'parentIds: $parentIds)';
  }
}

class _GeneratedCreateDbEntityScenario {
  const _GeneratedCreateDbEntityScenario({
    required this.seed,
    required this.saved,
    required this.enqueueSync,
    required this.hasLinkedEntity,
    required this.hasExplicitCategory,
    required this.linkedPrivate,
  });

  final int seed;
  final bool saved;
  final bool enqueueSync;
  final bool hasLinkedEntity;
  final bool hasExplicitCategory;
  final bool linkedPrivate;

  String get entityId => 'created-$seed';

  String? get linkedId => hasLinkedEntity ? 'linked-$seed' : null;

  String? get explicitCategoryId =>
      hasExplicitCategory ? 'entity-category-$seed' : null;

  String? get linkedCategoryId =>
      hasLinkedEntity ? 'linked-category-$seed' : null;

  JournalEntity get entity => JournalEntity.journalEntry(
    meta: _buildMetadata(
      id: entityId,
      categoryId: explicitCategoryId,
      private: !linkedPrivate,
    ),
    entryText: EntryText(plainText: 'created text $seed'),
  );

  JournalEntity? get linkedEntity {
    if (!hasLinkedEntity) return null;
    return JournalEntity.journalEntry(
      meta: _buildMetadata(
        id: linkedId!,
        categoryId: linkedCategoryId,
        private: linkedPrivate,
      ),
      entryText: EntryText(plainText: 'linked text $seed'),
    );
  }

  String? get expectedCategoryId => explicitCategoryId ?? linkedCategoryId;

  bool? get expectedPrivate => hasLinkedEntity ? linkedPrivate : null;

  bool get shouldEnqueueSync => saved && enqueueSync;

  Set<String> get expectedCreateNotificationIds => {
    entityId,
    textEntryNotification,
    ?linkedId,
    labelUsageNotification,
  };

  @override
  String toString() {
    return '_GeneratedCreateDbEntityScenario('
        'seed: $seed, '
        'saved: $saved, '
        'enqueueSync: $enqueueSync, '
        'linkedId: $linkedId, '
        'explicitCategoryId: $explicitCategoryId, '
        'linkedPrivate: $linkedPrivate)';
  }
}

extension _AnyGeneratedPersistenceScenario on glados.Any {
  glados.Generator<_GeneratedPersistenceEntityKind> get persistenceEntityKind =>
      glados.AnyUtils(this).choose(_GeneratedPersistenceEntityKind.values);

  glados.Generator<_GeneratedUpdateDbEntityScenario>
  get updateDbEntityScenario => glados.CombinableAny(this).combine6(
    persistenceEntityKind,
    glados.IntAnys(this).intInRange(0, 10000),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(0, 4),
    (
      _GeneratedPersistenceEntityKind kind,
      int seed,
      bool applied,
      bool enqueueSync,
      bool hasLinkedId,
      int parentCount,
    ) => _GeneratedUpdateDbEntityScenario(
      kind: kind,
      seed: seed,
      applied: applied,
      enqueueSync: enqueueSync,
      hasLinkedId: hasLinkedId,
      parentCount: parentCount,
    ),
  );

  glados.Generator<_GeneratedCreateDbEntityScenario>
  get createDbEntityScenario => glados.CombinableAny(this).combine6(
    glados.IntAnys(this).intInRange(0, 10000),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    (
      int seed,
      bool saved,
      bool enqueueSync,
      bool hasLinkedEntity,
      bool hasExplicitCategory,
      bool linkedPrivate,
    ) => _GeneratedCreateDbEntityScenario(
      seed: seed,
      saved: saved,
      enqueueSync: enqueueSync,
      hasLinkedEntity: hasLinkedEntity,
      hasExplicitCategory: hasExplicitCategory,
      linkedPrivate: linkedPrivate,
    ),
  );
}

class TestPersistenceLogic extends PersistenceLogic {
  TestPersistenceLogic({this.updateDbEntityHandler});

  final Future<bool?> Function(
    JournalEntity entity, {
    String? linkedId,
    bool enqueueSync,
    bool overrideComparison,
    Future<void> Function()? beforeNotify,
  })?
  updateDbEntityHandler;
  int updateMetadataCalls = 0;
  JournalEntity? lastUpdateDbEntity;

  @override
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    List<String>? labelIds,
    bool clearLabelIds = false,
    DateTime? deletedAt,
  }) async {
    updateMetadataCalls++;
    return super.updateMetadata(
      metadata,
      dateFrom: dateFrom,
      dateTo: dateTo,
      categoryId: categoryId,
      clearCategoryId: clearCategoryId,
      labelIds: labelIds,
      clearLabelIds: clearLabelIds,
      deletedAt: deletedAt,
    );
  }

  @override
  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
    bool overrideComparison = false,
    Future<void> Function()? beforeNotify,
  }) async {
    lastUpdateDbEntity = journalEntity;
    if (updateDbEntityHandler != null) {
      return updateDbEntityHandler!(
        journalEntity,
        linkedId: linkedId,
        enqueueSync: enqueueSync,
        overrideComparison: overrideComparison,
        beforeNotify: beforeNotify,
      );
    }
    return super.updateDbEntity(
      journalEntity,
      linkedId: linkedId,
      enqueueSync: enqueueSync,
      overrideComparison: overrideComparison,
      beforeNotify: beforeNotify,
    );
  }
}

Metadata _buildMetadata({
  required String id,
  String? categoryId,
  bool? private,
}) {
  final testDate = DateTime(2024, 3, 15, 10, 30);
  return Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
    categoryId: categoryId,
    private: private,
    vectorClock: const VectorClock({'host': 1}),
  );
}

JournalEntity _buildGeneratedEntity(
  _GeneratedPersistenceEntityKind kind,
  int seed,
) {
  final id = 'entity-$seed';
  final meta = _buildMetadata(id: id);
  final testDate = DateTime(2024, 3, 15, 10, seed % 60);

  return switch (kind) {
    _GeneratedPersistenceEntityKind.journalEntry => JournalEntity.journalEntry(
      meta: meta,
      entryText: EntryText(plainText: 'generated text $seed'),
    ),
    _GeneratedPersistenceEntityKind.event => JournalEntity.event(
      meta: meta,
      data: EventData(
        status: EventStatus.tentative,
        title: 'event $seed',
        stars: seed % 5,
      ),
      entryText: EntryText(plainText: 'event text $seed'),
    ),
    _GeneratedPersistenceEntityKind.task => JournalEntity.task(
      meta: meta,
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-$seed',
          createdAt: testDate,
          utcOffset: 60,
        ),
        title: 'task $seed',
        statusHistory: const [],
        dateFrom: testDate,
        dateTo: testDate,
      ),
      entryText: EntryText(plainText: 'task text $seed'),
    ),
    _GeneratedPersistenceEntityKind.measurement => JournalEntity.measurement(
      meta: meta,
      data: MeasurementData(
        dateFrom: testDate,
        dateTo: testDate,
        value: seed,
        dataTypeId: 'measurement-type-$seed',
      ),
      entryText: EntryText(plainText: 'measurement text $seed'),
    ),
    _GeneratedPersistenceEntityKind.habitCompletion =>
      JournalEntity.habitCompletion(
        meta: meta,
        data: HabitCompletionData(
          dateFrom: testDate,
          dateTo: testDate,
          habitId: 'habit-$seed',
        ),
        entryText: EntryText(plainText: 'habit text $seed'),
      ),
    _GeneratedPersistenceEntityKind.image => JournalEntity.journalImage(
      meta: meta,
      data: ImageData(
        capturedAt: testDate,
        imageId: 'image-$seed',
        imageFile: 'image-$seed.jpg',
        imageDirectory: '/images/2024-03-15/',
      ),
      entryText: EntryText(plainText: 'image text $seed'),
    ),
    _GeneratedPersistenceEntityKind.audio => JournalEntity.journalAudio(
      meta: meta,
      data: AudioData(
        dateFrom: testDate,
        dateTo: testDate,
        audioFile: 'audio-$seed.m4a',
        audioDirectory: '/audio/2024-03-15/',
        duration: Duration(seconds: seed % 3600),
      ),
      entryText: EntryText(plainText: 'audio text $seed'),
    ),
  };
}

Set<String> _expectedAffectedIds(
  _GeneratedPersistenceEntityKind kind,
  String id,
) {
  return switch (kind) {
    _GeneratedPersistenceEntityKind.journalEntry => {
      id,
      textEntryNotification,
    },
    _GeneratedPersistenceEntityKind.event => {id, eventNotification},
    _GeneratedPersistenceEntityKind.task => {id, taskNotification},
    _GeneratedPersistenceEntityKind.measurement => {
      id,
      'measurement-type-${id.split('-').last}',
    },
    _GeneratedPersistenceEntityKind.habitCompletion => {
      id,
      'habit-${id.split('-').last}',
      habitCompletionNotification,
    },
    _GeneratedPersistenceEntityKind.image => {id, imageNotification},
    _GeneratedPersistenceEntityKind.audio => {id, audioNotification},
  };
}

// Create a FakeGeolocation class for registerFallbackValue
class FakeGeolocation extends Fake implements Geolocation {}

/// Asserts that the badge has been invalidated at least once since the
/// last reset, then clears interactions so the next assertion only
/// counts calls made after this boundary. Used at each save / status
/// transition so a regression in any single path fails its own
/// assertion instead of being masked by an earlier path's call. We use
/// `greaterThanOrEqualTo(1)` (not exactly 1) because nested writes
/// (geolocation hydration, label refresh) legitimately stack extra
/// `_savedJournalEntity` invocations; the contract this guards is
/// "badge gets invalidated on save", not exact call count.
void _verifyAndResetBadge(MockNotificationService mock) {
  verify(mock.updateBadge).called(greaterThanOrEqualTo(1));
  clearInteractions(mock);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secureStorageMock = MockSecureStorage();
  setFakeDocumentsPath();
  registerFallbackValue(fallbackJournalEntity);
  registerFallbackValue(FakeHabitDefinition());
  registerFallbackValue(FakeMetadata());
  registerFallbackValue(FakeGeolocation());
  registerFallbackValue(fallbackSyncMessage);

  final mockNotificationService = MockNotificationService();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockFts5Db = MockFts5Db();
  final mockDeviceLocation = MockDeviceLocation();
  final mockOutboxService = MockOutboxService();

  group('Database Tests - ', () {
    var vcMockNext = '1';

    setUpAll(() async {
      await getIt.reset();

      setFakeDocumentsPath();

      getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

      final settingsDb = SettingsDb(inMemoryDatabase: true);
      final journalDb = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(journalDb, inMemoryDatabase: true);

      when(
        () => secureStorageMock.readValue(hostKey),
      ).thenAnswer((_) async => 'some_host');
      when(
        () => secureStorageMock.readValue(nextAvailableCounterKey),
      ).thenAnswer((_) async {
        return vcMockNext;
      });
      when(
        () => secureStorageMock.writeValue(nextAvailableCounterKey, any()),
      ).thenAnswer((invocation) async {
        vcMockNext = invocation.positionalArguments[1] as String;
      });

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
        () => mockNotificationService.scheduleHabitNotification(
          any(),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockNotificationService.cancelNotification(any()),
      ).thenAnswer((_) async {});

      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      when(mockDeviceLocation.getCurrentGeoLocation).thenAnswer(
        (_) async => Geolocation(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 10,
          createdAt: DateTime(2024, 3, 15, 10, 30),
          geohashString: 'mock-geohash',
        ),
      );

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<SyncDatabase>(SyncDatabase(inMemoryDatabase: true))
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<DomainLogger>(
          DomainLogger(loggingService: LoggingService()),
        )
        ..registerSingleton<OutboxService>(mockOutboxService)
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<NotificationService>(mockNotificationService)
        ..registerSingleton<VectorClockService>(VectorClockService())
        ..registerSingleton<MetadataService>(
          MetadataService(
            vectorClockService: getIt<VectorClockService>(),
          ),
        )
        ..registerSingleton<GeolocationService>(
          GeolocationService(
            journalDb: journalDb,
            loggingService: getIt<DomainLogger>(),
            metadataService: getIt<MetadataService>(),
            deviceLocation: mockDeviceLocation,
          ),
        )
        ..registerSingleton<PersistenceLogic>(PersistenceLogic());
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    // Ensure Directory registration is fresh per test to avoid cross-file overrides
    setUp(() async {
      if (getIt.isRegistered<Directory>()) {
        getIt.unregister<Directory>();
      }
      getIt.registerSingleton<Directory>(
        await getApplicationDocumentsDirectory(),
      );
    });

    tearDown(() {
      clearInteractions(mockNotificationService);
      clearInteractions(mockUpdateNotifications);
      clearInteractions(mockFts5Db);
      clearInteractions(mockDeviceLocation);
    });

    test(
      'create and retrieve text entry',
      () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        const testText = 'test text';
        const updatedTestText = 'updated test text';

        // create test entry
        final textEntry = await JournalRepository.createTextEntry(
          const EntryText(plainText: testText),
          id: uuid.v1(),
          started: testDate,
        );

        // expect to find created entry
        expect(
          (await getIt<JournalDb>().journalEntityById(
            textEntry!.meta.id,
          ))?.entryText?.plainText,
          testText,
        );

        _verifyAndResetBadge(mockNotificationService);

        // update entry with new plaintext
        await getIt<PersistenceLogic>().updateJournalEntityText(
          textEntry.meta.id,
          const EntryText(plainText: updatedTestText),
          DateTime(2024, 3, 15, 10, 35),
        );

        // Yield to allow real SQLite I/O to complete
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // expect to find updated entry
        expect(
          (await getIt<JournalDb>().journalEntityById(
            textEntry.meta.id,
          ))?.entryText?.plainText,
          updatedTestText,
        );

        verify(
          () => mockFts5Db.insertText(any(), removePrevious: true),
        ).called(2);
        _verifyAndResetBadge(mockNotificationService);
      },
    );

    test('create and retrieve task', () async {
      final testDate = DateTime(2024, 3, 15, 11);
      final taskData = TaskData(
        status: TaskStatus.open(
          id: uuid.v1(),
          createdAt: testDate,
          utcOffset: 60,
        ),
        title: 'title',
        statusHistory: [],
        dateTo: DateTime(2024, 3, 15, 11),
        dateFrom: DateTime(2024, 3, 15, 11),
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

      // Simple verify without checking call count
      verify(mockNotificationService.updateBadge);

      // expect correct task by status counts in streams
      expect(await getIt<JournalDb>().getTasksCount(statuses: ['OPEN']), 1);
      expect(await getIt<JournalDb>().getTasksCount(statuses: ['DONE']), 0);

      // expect task lists by status in streams
      expect(
        (await getIt<JournalDb>().getTasks(
          starredStatuses: [true, false],
          taskStatuses: ['OPEN'],
          categoryIds: [''],
          labelIds: const [],
        )).length,
        1,
      );

      expect(
        (await getIt<JournalDb>().getTasks(
          starredStatuses: [true, false],
          taskStatuses: ['OPEN'],
          categoryIds: [''],
          labelIds: const [],
          ids: [task.meta.id],
        )).length,
        1,
      );

      expect(
        (await getIt<JournalDb>().getTasks(
          starredStatuses: [true, false],
          taskStatuses: ['DONE'],
          categoryIds: [],
          labelIds: const [],
        )).length,
        0,
      );

      expect(
        (await getIt<JournalDb>().getTasks(
          starredStatuses: [true, false],
          taskStatuses: ['DONE'],
          categoryIds: [],
          labelIds: const [],
        )).length,
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
        )).length,
        1,
      );

      // Boundary between the create call and the IN PROGRESS
      // transition below — see `_verifyAndResetBadge` for the WHY.
      clearInteractions(mockNotificationService);

      // update task with status 'IN PROGRESS'
      await getIt<PersistenceLogic>().updateTask(
        journalEntityId: task.meta.id,
        entryText: task.entryText,
        taskData: taskData.copyWith(
          status: TaskStatus.inProgress(
            id: uuid.v1(),
            createdAt: testDate,
            utcOffset: 60,
          ),
        ),
      );

      _verifyAndResetBadge(mockNotificationService);
      expect(await getIt<JournalDb>().getWipCount(), 1);
      expect(await getIt<JournalDb>().getTasksCount(statuses: ['OPEN']), 0);
      expect(
        await getIt<JournalDb>().getTasksCount(statuses: ['IN PROGRESS']),
        1,
      );

      // update task with status 'DONE'
      await getIt<PersistenceLogic>().updateTask(
        journalEntityId: task.meta.id,
        entryText: task.entryText,
        taskData: taskData.copyWith(
          status: TaskStatus.done(
            id: uuid.v1(),
            createdAt: testDate,
            utcOffset: 60,
          ),
        ),
      );

      _verifyAndResetBadge(mockNotificationService);

      // expect task counts by status to be updated
      expect(await getIt<JournalDb>().getTasksCount(statuses: ['OPEN']), 0);
      expect(await getIt<JournalDb>().getTasksCount(statuses: ['DONE']), 1);

      // create linked comment entry
      const testText = 'test comment for task';
      const updatedTestText = 'updated test comment for task';
      final comment = await JournalRepository.createTextEntry(
        const EntryText(plainText: testText),
        id: uuid.v1(),
        started: testDate,
        linkedId: task.meta.id,
      );

      await getIt<PersistenceLogic>().updateJournalEntityText(
        comment!.meta.id,
        const EntryText(
          plainText: updatedTestText,
        ),
        comment.meta.dateTo,
      );

      expect(
        (await getIt<JournalDb>().getLinkedEntities(
          task.meta.id,
        )).first.entryText,
        (await getIt<JournalDb>().journalEntityById(
          comment.meta.id,
        ))?.entryText,
      );

      // When run with other tests, we'll have 3 entries (1 from previous test + 2 from this test)
      // When run alone, we'll have 2 entries
      final countBeforeDelete = await getIt<JournalDb>().getJournalCount();
      expect(countBeforeDelete, anyOf(2, 3));

      // unlink comment from task
      expect(
        await getIt<JournalDb>().deleteLink(
          task.meta.id,
          comment.meta.id,
        ),
        1,
      );

      // delete task and expect counts to be updated
      final updatedMeta = await getIt<PersistenceLogic>().updateMetadata(
        task.meta,
        deletedAt: DateTime(2024, 3, 15, 12),
      );
      final updatedTask = task.copyWith(meta: updatedMeta);
      await getIt<PersistenceLogic>().updateDbEntity(updatedTask);

      // Yield to microtask queue to ensure database update completes
      await Future<void>.value();

      // After deleting task, we'll have one less entry
      final countAfterDelete = await getIt<JournalDb>().getJournalCount();
      expect(countAfterDelete, countBeforeDelete - 1);
      expect(await getIt<JournalDb>().getTasksCount(statuses: ['OPEN']), 0);
      expect(await getIt<JournalDb>().getTasksCount(statuses: ['DONE']), 0);
      expect(await getIt<JournalDb>().getWipCount(), 0);

      await getIt<JournalDb>()
          .purgeDeleted(backup: false, stepDelay: Duration.zero)
          .drain<void>();
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

      final workout = await getIt<PersistenceLogic>().createWorkoutEntry(
        workoutData,
      );
      expect(workout?.data, workoutData);

      // workout is retrieved as latest workout
      expect((await getIt<JournalDb>().latestWorkout())?.data, workoutData);

      // workout is retrieved on workout watch stream
      expect(
        ((await getIt<JournalDb>().getWorkouts(
                  rangeStart: DateTime(0),
                  rangeEnd: DateTime(2100),
                )).first
                as WorkoutEntry)
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
        (await getIt<JournalDb>().latestQuantitativeByType(
          'HealthDataType.WEIGHT',
        ))?.data,
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
      final measurement = await getIt<PersistenceLogic>()
          .createMeasurementEntry(
            data: measurementData,
            private: false,
          );

      expect(measurement?.data, measurementData);

      expect(
        await getIt<JournalDb>().getMeasurementsByType(
          rangeStart: DateTime(0),
          rangeEnd: DateTime(2100),
          type: measurableChocolate.id,
        ),
        isEmpty,
      );

      // measurable types can be retrieved
      expect(
        (await getIt<JournalDb>().getAllMeasurableDataTypes()).toSet(),
        {measurableChocolate, measurableWater},
      );

      expect(
        await getIt<JournalDb>().getMeasurableDataTypeById(
          measurableChocolate.id,
        ),
        measurableChocolate,
      );

      // measurable can be deleted
      await getIt<PersistenceLogic>().upsertEntityDefinition(
        measurableChocolate.copyWith(deletedAt: DateTime(2024, 3, 15, 12)),
      );

      expect(
        await getIt<JournalDb>().getMeasurableDataTypeById(
          measurableChocolate.id,
        ),
        null,
      );

      expect(
        (await getIt<JournalDb>().getAllMeasurableDataTypes()).toSet(),
        {measurableWater},
      );
    });

    test('create, retrieve and delete dashboard', () async {
      await getIt<PersistenceLogic>().upsertDashboardDefinition(
        testDashboardConfig,
      );

      final created = await getIt<JournalDb>().getDashboardById(
        testDashboardConfig.id,
      );

      expect(created, testDashboardConfig);

      // Now test the delete method directly
      await getIt<PersistenceLogic>().deleteDashboardDefinition(
        testDashboardConfig,
      );

      final item = await getIt<JournalDb>().getDashboardById(
        testDashboardConfig.id,
      );

      expect(item, null);

      // Verify notification cancellation was called
      verify(() => mockNotificationService.cancelNotification(any()));
    });

    test('create and retrieve habit definition', () async {
      await getIt<PersistenceLogic>().upsertEntityDefinition(habitFlossing);

      final habitCompletionData = HabitCompletionData(
        dateFrom: DateTime(2024, 3, 15, 11),
        dateTo: DateTime(2024, 3, 15, 11),
        habitId: habitFlossing.id,
      );

      final habitCompletion = await getIt<PersistenceLogic>()
          .createHabitCompletionEntry(
            data: habitCompletionData,
            habitDefinition: habitFlossing,
          );

      expect(habitCompletion?.data, habitCompletionData);

      // habit can be retrieved
      expect(
        (await getIt<JournalDb>().getAllHabitDefinitions()).toSet(),
        {habitFlossing},
      );

      expect(
        await getIt<JournalDb>().getHabitById(habitFlossing.id),
        habitFlossing,
      );

      // habit can be deleted
      await getIt<PersistenceLogic>().upsertEntityDefinition(
        habitFlossing.copyWith(deletedAt: DateTime(2024, 3, 15, 12)),
      );

      expect(
        await getIt<JournalDb>().getHabitById(habitFlossing.id),
        null,
      );
    });

    test('create and retrieve AI response entry', () async {
      // Create test AI response data
      const aiResponseData = AiResponseData(
        model: 'gpt-3.5-turbo',
        systemMessage: 'You are a helpful assistant',
        prompt: 'What is the meaning of life?',
        thoughts: 'Thinking about philosophical questions',
        response: '42',
      );

      // Create AI response entry
      final aiResponse = await getIt<PersistenceLogic>().createAiResponseEntry(
        data: aiResponseData,
      );

      expect(aiResponse, isNotNull);
      expect(aiResponse?.data, aiResponseData);

      // Retrieve the AI response from the database
      final retrievedResponse =
          await getIt<JournalDb>().journalEntityById(aiResponse!.meta.id)
              as AiResponseEntry?;
      expect(retrievedResponse, isNotNull);

      // Verify it's the correct type and has the right data
      expect(retrievedResponse, isA<AiResponseEntry>());
      expect(
        retrievedResponse?.data.prompt,
        'What is the meaning of life?',
      );
      expect(retrievedResponse?.data.response, '42');

      // Test creating with linked ID
      final testDate = DateTime(2024, 3, 15, 11, 30);
      final textEntry = await JournalRepository.createTextEntry(
        const EntryText(plainText: 'Parent entry'),
        id: uuid.v1(),
        started: testDate,
      );

      final linkedAiResponse = await getIt<PersistenceLogic>()
          .createAiResponseEntry(
            data: aiResponseData,
            linkedId: textEntry!.meta.id,
          );

      expect(linkedAiResponse, isNotNull);

      // Check that the link was created
      final linkedEntities = await getIt<JournalDb>().getLinkedEntities(
        textEntry.meta.id,
      );
      expect(linkedEntities.length, 1);
      expect(linkedEntities.first.meta.id, linkedAiResponse!.meta.id);

      // Verify notification was triggered
      verify(() => mockUpdateNotifications.notify(any()));
    });

    test('create and retrieve event entry', () async {
      // Create test event data
      const eventData = EventData(
        status: EventStatus.tentative,
        title: 'Test Event',
        stars: 4.5,
      );

      // Create event entry
      final event = await getIt<PersistenceLogic>().createEventEntry(
        data: eventData,
        entryText: const EntryText(plainText: 'Event details'),
      );

      expect(event, isNotNull);
      expect(event?.data, eventData);

      // Retrieve the event from the database
      final retrievedEvent =
          await getIt<JournalDb>().journalEntityById(event!.meta.id)
              as JournalEvent?;
      expect(retrievedEvent, isNotNull);

      // Verify it's the correct type and has the right data
      expect(retrievedEvent, isA<JournalEvent>());
      expect(retrievedEvent?.data.title, 'Test Event');
      expect(retrievedEvent?.data.status, EventStatus.tentative);

      // Test update event
      final updatedEventData = eventData.copyWith(
        title: 'Updated Event Title',
        status: EventStatus.planned,
      );

      await getIt<PersistenceLogic>().updateEvent(
        journalEntityId: event.meta.id,
        data: updatedEventData,
        entryText: const EntryText(plainText: 'Updated event details'),
      );

      // Retrieve the updated event
      final updatedEvent =
          await getIt<JournalDb>().journalEntityById(event.meta.id)
              as JournalEvent?;
      expect(updatedEvent?.data.title, 'Updated Event Title');
      expect(updatedEvent?.data.status, EventStatus.planned);
      expect(updatedEvent?.entryText?.plainText, 'Updated event details');
    });

    test('create link between entities', () async {
      final testDate = DateTime(2024, 3, 15, 12);
      // Create two entries to link
      final entry1 = await JournalRepository.createTextEntry(
        const EntryText(plainText: 'First entry'),
        id: uuid.v1(),
        started: testDate,
      );

      final entry2 = await JournalRepository.createTextEntry(
        const EntryText(plainText: 'Second entry'),
        id: uuid.v1(),
        started: testDate,
      );

      // Create link between entries
      final linkCreated = await getIt<PersistenceLogic>().createLink(
        fromId: entry1!.meta.id,
        toId: entry2!.meta.id,
      );

      expect(linkCreated, true);

      // Check that the link exists in the database
      final linkedEntities = await getIt<JournalDb>().getLinkedEntities(
        entry1.meta.id,
      );
      expect(linkedEntities.length, 1);
      expect(linkedEntities.first.meta.id, entry2.meta.id);

      // Verify notifications were triggered for both entities
      verify(() => mockUpdateNotifications.notify(any()));
    });

    test('add geolocation to entry', () async {
      final persistenceLogic = getIt<PersistenceLogic>();

      // Create entry WITHOUT auto-geolocation so we can test addGeolocationAsync
      final entry = JournalEntity.journalEntry(
        entryText: const EntryText(plainText: 'Entry with geolocation'),
        meta: await persistenceLogic.createMetadata(
          dateFrom: DateTime(2024, 3, 15, 12, 30),
        ),
      );
      await persistenceLogic.createDbEntity(
        entry,
        shouldAddGeolocation: false,
      );

      // Verify entry has no geolocation initially
      final beforeEntry = await getIt<JournalDb>().journalEntityById(
        entry.meta.id,
      );
      expect(beforeEntry?.geolocation, isNull);

      // Add geolocation to the entry
      await persistenceLogic.addGeolocationAsync(entry.meta.id);

      // Retrieve the entry with geolocation
      final retrievedEntry = await getIt<JournalDb>().journalEntityById(
        entry.meta.id,
      );
      expect(retrievedEntry, isNotNull);
      expect(retrievedEntry?.geolocation, isNotNull);
      expect(retrievedEntry?.geolocation?.latitude, 37.7749);
      expect(retrievedEntry?.geolocation?.longitude, -122.4194);
      expect(retrievedEntry?.geolocation?.accuracy, 10.0);

      // Verify getCurrentGeoLocation was called
      verify(mockDeviceLocation.getCurrentGeoLocation).called(1);
    });

    test('purgeDeleted should remove deleted items', () async {
      // Setup test data
      // ... existing setup code ...

      // Call purgeDeleted and collect all progress values
      final progressValues = <double>[];
      await getIt<JournalDb>()
          .purgeDeleted(backup: false, stepDelay: Duration.zero)
          .forEach(progressValues.add);

      // Verify the final progress is 1.0
      expect(progressValues.last, 1.0);

      // Verify items are deleted
      // ... existing verification code ...
    });

    test('updateMetadata with clearCategoryId=true', () async {
      // Create entry with category
      const testText = 'Entry with category';
      final testDate = DateTime(2024, 3, 15, 13);
      final entry = await JournalRepository.createTextEntry(
        const EntryText(plainText: testText),
        id: uuid.v1(),
        started: testDate,
        categoryId: categoryMindfulness.id,
      );

      expect(entry?.meta.categoryId, categoryMindfulness.id);

      // Update metadata to clear category
      final updatedMeta = await getIt<PersistenceLogic>().updateMetadata(
        entry!.meta,
        clearCategoryId: true,
      );

      expect(updatedMeta.categoryId, isNull);
    });

    test('createQuantitativeEntry handles discrete quantity data', () async {
      final testDate = DateTime(2024, 3, 15, 13, 30);
      final data = QuantitativeData.discreteQuantityData(
        dateFrom: testDate,
        dateTo: testDate,
        value: 100,
        dataType: 'test_type',
        unit: 'test_unit',
      );

      final result = await getIt<PersistenceLogic>().createQuantitativeEntry(
        data,
      );

      expect(result, isNotNull);
      expect(result?.data.value, 100);
    });

    test('createWorkoutEntry handles workout data correctly', () async {
      final testDate = DateTime(2024, 3, 15, 14);
      final workoutData = WorkoutData(
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(hours: 1)),
        id: 'workout-123',
        workoutType: 'RUNNING',
        energy: 300,
        distance: 5000,
        source: 'test',
      );

      final result = await getIt<PersistenceLogic>().createWorkoutEntry(
        workoutData,
      );

      expect(result, isNotNull);
      expect(result?.data.workoutType, 'RUNNING');
    });

    test('createSurveyEntry creates survey with proper data', () async {
      final testDate = DateTime(2024, 3, 15, 14, 30);
      final taskResult = RPTaskResult(identifier: 'test_survey')
        ..startDate = testDate
        ..endDate = testDate.add(const Duration(minutes: 5));

      final surveyData = SurveyData(
        taskResult: taskResult,
        scoreDefinitions: {
          'Score1': {'q1', 'q2'},
        },
        calculatedScores: {
          'Score1': 10,
        },
      );

      final result = await getIt<PersistenceLogic>().createSurveyEntry(
        data: surveyData,
      );

      expect(result, true);
    });

    test('createSurveyEntry with linkedId creates linked survey', () async {
      final testDate = DateTime(2024, 3, 15, 15);

      // Create parent entry first
      final parent = await JournalRepository.createTextEntry(
        const EntryText(plainText: 'Parent entry'),
        id: uuid.v1(),
        started: testDate,
      );

      final taskResult = RPTaskResult(identifier: 'linked_survey')
        ..startDate = testDate
        ..endDate = testDate.add(const Duration(minutes: 3));

      final surveyData = SurveyData(
        taskResult: taskResult,
        scoreDefinitions: {},
        calculatedScores: {},
      );

      final result = await getIt<PersistenceLogic>().createSurveyEntry(
        data: surveyData,
        linkedId: parent!.meta.id,
      );

      expect(result, true);

      // Verify link exists
      final linkedEntities = await getIt<JournalDb>().getLinkedEntities(
        parent.meta.id,
      );
      expect(linkedEntities.length, greaterThan(0));
    });

    test(
      'updateJournalEntityText returns false for non-existent entity',
      () async {
        const newText = EntryText(plainText: 'Test');
        final result = await getIt<PersistenceLogic>().updateJournalEntityText(
          'non-existent-id',
          newText,
          DateTime(2024, 3, 15, 10, 30),
        );

        expect(result, false);
      },
    );

    // Note: Additional entity type branches (Audio, Image, Measurement, HabitCompletion)
    // in updateJournalEntityText are covered by integration tests and existing
    // test coverage. Focus remains on core logic functionality.

    test(
      'Entity Type Branch Coverage: updateJournalEntityText updates JournalAudio and clears flags',
      () async {
        final audioData = AudioNote(
          createdAt: DateTime(2024, 3, 15, 10, 30),
          audioFile: 'test.m4a',
          audioDirectory: '/audio/2024-01-01/',
          duration: const Duration(seconds: 60),
        );

        final audioEntry = await SpeechRepository.createAudioEntry(audioData);

        expect(audioEntry, isNotNull);

        const newText = EntryText(plainText: 'Transcribed audio text');
        final success = await getIt<PersistenceLogic>().updateJournalEntityText(
          audioEntry!.meta.id,
          newText,
          DateTime(2024, 3, 15, 10, 35),
        );

        // Verifying the update method executes successfully covers the JournalAudio branch
        expect(success, true);
      },
    );

    test(
      'Entity Type Branch Coverage: updateJournalEntityText updates JournalImage',
      () async {
        final imageData = ImageData(
          capturedAt: DateTime(2024, 3, 15, 10, 30),
          imageId: 'test-image-id',
          imageFile: 'test.jpg',
          imageDirectory: '/images/2024-01-01/',
        );

        final imageEntry = await JournalRepository.createImageEntry(imageData);
        expect(imageEntry, isNotNull);

        const newText = EntryText(plainText: 'Image caption');
        final success = await getIt<PersistenceLogic>().updateJournalEntityText(
          imageEntry!.meta.id,
          newText,
          DateTime(2024, 3, 15, 10, 35),
        );

        // Verifying the update method executes successfully covers the JournalImage branch
        expect(success, true);
      },
    );

    test(
      'Entity Type Branch Coverage: updateJournalEntityText updates MeasurementEntry',
      () async {
        // Create measurable data type first
        await getIt<JournalDb>().upsertMeasurableDataType(measurableWater);

        final measurementData = MeasurementData(
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          value: 500,
          dataTypeId: measurableWater.id,
        );

        final measurementEntry = await getIt<PersistenceLogic>()
            .createMeasurementEntry(
              data: measurementData,
              private: false,
            );
        expect(measurementEntry, isNotNull);

        const newText = EntryText(plainText: 'Measurement notes');
        final success = await getIt<PersistenceLogic>().updateJournalEntityText(
          measurementEntry!.meta.id,
          newText,
          DateTime(2024, 3, 15, 10, 35),
        );

        // Verifying the update method executes successfully covers the MeasurementEntry branch
        expect(success, true);
      },
    );

    test(
      'Entity Type Branch Coverage: updateJournalEntityText updates HabitCompletionEntry',
      () async {
        // Create habit definition first
        await getIt<PersistenceLogic>().upsertEntityDefinition(habitFlossing);

        final habitCompletionData = HabitCompletionData(
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          habitId: habitFlossing.id,
        );

        final habitCompletion = await getIt<PersistenceLogic>()
            .createHabitCompletionEntry(
              data: habitCompletionData,
              habitDefinition: habitFlossing,
            );
        expect(habitCompletion, isNotNull);

        const newText = EntryText(plainText: 'Habit completion notes');
        final success = await getIt<PersistenceLogic>().updateJournalEntityText(
          habitCompletion!.meta.id,
          newText,
          DateTime(2024, 3, 15, 10, 35),
        );

        expect(success, true);

        // Verify the text was updated
        final updated =
            await getIt<JournalDb>().journalEntityById(habitCompletion.meta.id)
                as HabitCompletionEntry?;
        expect(updated?.entryText?.plainText, 'Habit completion notes');
      },
    );

    test('updateTask returns false for non-existent entity', () async {
      final taskData = TaskData(
        status: TaskStatus.open(
          id: uuid.v1(),
          createdAt: DateTime(2024, 3, 15, 10, 30),
          utcOffset: 60,
        ),
        title: 'test',
        statusHistory: [],
        dateTo: DateTime(2024, 3, 15, 10, 30),
        dateFrom: DateTime(2024, 3, 15, 10, 30),
      );

      final result = await getIt<PersistenceLogic>().updateTask(
        journalEntityId: 'non-existent-id',
        taskData: taskData,
      );

      expect(result, false);
    });

    test('updateEvent returns false for non-existent entity', () async {
      const eventData = EventData(
        status: EventStatus.tentative,
        title: 'Test',
        stars: 0,
      );

      final result = await getIt<PersistenceLogic>().updateEvent(
        journalEntityId: 'non-existent-id',
        data: eventData,
      );

      expect(result, false);
    });

    test('updateTask logs when entity is not a task', () async {
      final persistenceLogic = getIt<PersistenceLogic>();

      // Create a journal entry (not a task)
      final entry = JournalEntity.journalEntry(
        entryText: const EntryText(plainText: 'Not a task'),
        meta: await persistenceLogic.createMetadata(
          dateFrom: DateTime(2024, 3, 15),
        ),
      );
      await persistenceLogic.createDbEntity(entry);

      final taskData = TaskData(
        status: TaskStatus.open(
          id: uuid.v1(),
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 60,
        ),
        title: 'test',
        statusHistory: [],
        dateTo: DateTime(2024, 3, 15),
        dateFrom: DateTime(2024, 3, 15),
      );

      // Should succeed (returns true) and hit the orElse branch which logs
      final result = await persistenceLogic.updateTask(
        journalEntityId: entry.meta.id,
        taskData: taskData,
      );

      expect(result, true);

      // The entity should remain a journal entry (not converted to a task)
      final unchanged = await getIt<JournalDb>().journalEntityById(
        entry.meta.id,
      );
      expect(unchanged, isA<JournalEntry>());
    });

    test('updateEvent logs when entity is not an event', () async {
      final persistenceLogic = getIt<PersistenceLogic>();

      // Create a journal entry (not an event)
      final entry = JournalEntity.journalEntry(
        entryText: const EntryText(plainText: 'Not an event'),
        meta: await persistenceLogic.createMetadata(
          dateFrom: DateTime(2024, 3, 15),
        ),
      );
      await persistenceLogic.createDbEntity(entry);

      const eventData = EventData(
        status: EventStatus.tentative,
        title: 'Test',
        stars: 0,
      );

      // Should succeed (returns true) and hit the orElse branch which logs
      final result = await persistenceLogic.updateEvent(
        journalEntityId: entry.meta.id,
        data: eventData,
      );

      expect(result, true);

      // The entity should remain a journal entry (not converted to an event)
      final unchanged = await getIt<JournalDb>().journalEntityById(
        entry.meta.id,
      );
      expect(unchanged, isA<JournalEntry>());
    });

    test(
      'addGeolocationAsync prevents concurrent additions for same entity',
      () async {
        final persistenceLogic = getIt<PersistenceLogic>();

        // Create entry without geolocation
        final entry = JournalEntity.journalEntry(
          entryText: const EntryText(plainText: 'Entry for concurrent test'),
          meta: await persistenceLogic.createMetadata(
            dateFrom: DateTime(2024, 3, 15, 15, 30),
          ),
        );
        await persistenceLogic.createDbEntity(
          entry,
          shouldAddGeolocation: false,
        );

        // Start two concurrent geolocation additions
        // addGeolocationAsync returns FutureOr, so wrap in Future for await
        final future1 = Future.value(
          persistenceLogic.addGeolocationAsync(entry.meta.id),
        );
        final future2 = Future.value(
          persistenceLogic.addGeolocationAsync(entry.meta.id),
        );

        final results = await Future.wait([future1, future2]);

        // One should succeed and one should return null (prevented by race condition guard)
        expect(results.where((r) => r != null).length, 1);
      },
    );

    test(
      'addGeolocationAsync returns existing geolocation if one is already present',
      () async {
        final persistenceLogic = getIt<PersistenceLogic>();

        // Create entry and add geolocation
        final entry = JournalEntity.journalEntry(
          entryText: const EntryText(
            plainText: 'Entry with existing geolocation',
          ),
          meta: await persistenceLogic.createMetadata(
            dateFrom: DateTime(2024, 3, 15, 16),
          ),
        );
        await persistenceLogic.createDbEntity(
          entry,
          shouldAddGeolocation: false,
        );

        // Add geolocation first time
        final firstResult = await persistenceLogic.addGeolocationAsync(
          entry.meta.id,
        );
        expect(firstResult, isNotNull);

        // Try to add again - should return existing geolocation without overwriting
        final secondResult = await persistenceLogic.addGeolocationAsync(
          entry.meta.id,
        );

        // Should return the existing geolocation
        expect(secondResult, isNotNull);
        expect(secondResult?.latitude, firstResult?.latitude);
      },
    );

    test(
      'createMetadata generates UUID v5 when uuidV5Input is provided',
      () async {
        final persistenceLogic = getIt<PersistenceLogic>();

        final meta1 = await persistenceLogic.createMetadata(
          uuidV5Input: 'unique-input-string',
        );
        final meta2 = await persistenceLogic.createMetadata(
          uuidV5Input: 'unique-input-string',
        );

        // Same input should generate same UUID v5
        expect(meta1.id, meta2.id);
      },
    );

    test(
      'createMetadata generates UUID v1 when uuidV5Input is not provided',
      () async {
        final persistenceLogic = getIt<PersistenceLogic>();

        final meta1 = await persistenceLogic.createMetadata();
        final meta2 = await persistenceLogic.createMetadata();

        // Different calls without uuidV5Input should generate different UUIDs
        expect(meta1.id, isNot(meta2.id));
      },
    );

    test('createMetadata sets timezone and utcOffset', () async {
      final persistenceLogic = getIt<PersistenceLogic>();

      final meta = await persistenceLogic.createMetadata();

      expect(meta.timezone, isNotNull);
      expect(meta.utcOffset, isNotNull);
    });

    test('createMetadata respects optional parameters', () async {
      final persistenceLogic = getIt<PersistenceLogic>();

      final dateFrom = DateTime(2024, 1, 15, 10, 30);
      final dateTo = DateTime(2024, 1, 15, 11, 30);
      const labelIds = ['label1'];
      const categoryId = 'category-123';

      final meta = await persistenceLogic.createMetadata(
        dateFrom: dateFrom,
        dateTo: dateTo,
        private: true,
        labelIds: labelIds,
        categoryId: categoryId,
        starred: true,
        flag: EntryFlag.import,
      );

      expect(meta.dateFrom, dateFrom);
      expect(meta.dateTo, dateTo);
      expect(meta.private, true);
      expect(meta.labelIds, labelIds);
      expect(meta.categoryId, categoryId);
      expect(meta.starred, true);
      expect(meta.flag, EntryFlag.import);
    });

    test('updateMetadata with clearLabelIds=true clears labels', () async {
      final persistenceLogic = getIt<PersistenceLogic>();

      // Create entry directly to avoid async geolocation work that can outlive the test
      final testDate = DateTime(2024, 6, 15, 14, 30);
      final meta = await persistenceLogic.createMetadata(dateFrom: testDate);
      final journalEntity = JournalEntity.journalEntry(
        entryText: const EntryText(plainText: 'Entry with labels'),
        meta: meta,
      );
      await persistenceLogic.createDbEntity(
        journalEntity,
        shouldAddGeolocation: false,
      );

      // First set labels via updateMetadata
      final metaWithLabels = await persistenceLogic.updateMetadata(
        journalEntity.meta,
        labelIds: ['label1', 'label2'],
      );
      expect(metaWithLabels.labelIds, ['label1', 'label2']);

      // Then clear labels
      final metaCleared = await persistenceLogic.updateMetadata(
        metaWithLabels,
        clearLabelIds: true,
      );
      expect(metaCleared.labelIds, isNull);
    });

    test(
      'createMeasurementEntry enables geolocation when data time is close to now',
      () async {
        // Pin the clock so shouldAddGeolocation is deterministically true
        // (data time == clock.now(); covers the `true` branch) — no
        // wall-clock race (fake-time policy).
        final now = DateTime(2024, 3, 15, 10, 30);
        await getIt<JournalDb>().upsertMeasurableDataType(measurableWater);
        final measurement = await withClock(
          Clock.fixed(now),
          () => getIt<PersistenceLogic>().createMeasurementEntry(
            data: MeasurementData(
              dateFrom: now,
              dateTo: now,
              value: 250,
              dataTypeId: measurableWater.id,
            ),
            private: false,
          ),
        );

        expect(measurement, isNotNull);
        expect(measurement?.data.value, 250);

        // Drain the event queue so the fire-and-forget geolocation addition
        // (triggered by shouldAddGeolocation=true) has a chance to complete.
        await pumpEventQueue();

        // Assert the geolocation side effect: the entry in DB must now have
        // geolocation attached (from mockDeviceLocation.getCurrentGeoLocation).
        final persisted = await getIt<JournalDb>().journalEntityById(
          measurement!.meta.id,
        );
        expect(persisted?.geolocation, isNotNull);
        expect(persisted?.geolocation?.latitude, 37.7749);
        expect(persisted?.geolocation?.longitude, -122.4194);
      },
    );

    test(
      'createHabitCompletionEntry enables geolocation when data time is close to now',
      () async {
        // Pin the clock so shouldAddGeolocation is deterministically true
        // (data time == clock.now(); covers the `true` branch) — no
        // wall-clock race (fake-time policy).
        //
        // 10:32 (not the file-standard 10:30) because habit completion IDs
        // are deterministic UUIDv5 hashes of json.encode(data): reusing the
        // exact dateFrom/dateTo/habitId of the earlier
        // 'updateJournalEntityText updates HabitCompletionEntry' test would
        // collide with that entity in-suite and the insert (overwrite: false)
        // would be rejected.
        final now = DateTime(2024, 3, 15, 10, 32);
        await getIt<PersistenceLogic>().upsertEntityDefinition(habitFlossing);

        final completion = await withClock(
          Clock.fixed(now),
          () => getIt<PersistenceLogic>().createHabitCompletionEntry(
            data: HabitCompletionData(
              dateFrom: now,
              dateTo: now,
              habitId: habitFlossing.id,
            ),
            habitDefinition: habitFlossing,
          ),
        );

        expect(completion, isNotNull);
        expect(completion?.data.habitId, habitFlossing.id);

        // Drain the event queue so the fire-and-forget geolocation addition
        // (triggered by shouldAddGeolocation=true) has a chance to complete.
        await pumpEventQueue();

        // Assert the geolocation side effect: the entry in DB must now have
        // geolocation attached (from mockDeviceLocation.getCurrentGeoLocation).
        final persisted = await getIt<JournalDb>().journalEntityById(
          completion!.meta.id,
        );
        expect(persisted?.geolocation, isNotNull);
        expect(persisted?.geolocation?.latitude, 37.7749);
        expect(persisted?.geolocation?.longitude, -122.4194);
      },
    );

    test(
      'updateJournalEntityText clears import flag on JournalAudio when flag is EntryFlag.import',
      () async {
        final persistenceLogic = getIt<PersistenceLogic>();

        // Create an audio entry with EntryFlag.import so the `true` branch of
        // `newMeta.flag == EntryFlag.import ? EntryFlag.none : newMeta.flag`
        // is exercised (lines 624-626).
        final audioData = AudioData(
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 35),
          audioFile: 'import_test.m4a',
          audioDirectory: '/audio/2024-01-01/',
          duration: const Duration(seconds: 30),
        );
        final audioMeta = await persistenceLogic.createMetadata(
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          flag: EntryFlag.import,
        );
        final audioEntry = JournalEntity.journalAudio(
          data: audioData,
          meta: audioMeta,
        );
        await persistenceLogic.createDbEntity(
          audioEntry,
          shouldAddGeolocation: false,
        );

        // Confirm the entry starts with the import flag
        final before =
            await getIt<JournalDb>().journalEntityById(audioEntry.meta.id)
                as JournalAudio?;
        expect(before?.meta.flag, EntryFlag.import);

        // Update text — this should clear the import flag
        const newText = EntryText(plainText: 'Transcribed from import');
        final success = await persistenceLogic.updateJournalEntityText(
          audioEntry.meta.id,
          newText,
          DateTime(2024, 3, 15, 10, 36),
        );

        expect(success, isTrue);

        final after =
            await getIt<JournalDb>().journalEntityById(audioEntry.meta.id)
                as JournalAudio?;
        // The import flag must be cleared after text update
        expect(after?.meta.flag, EntryFlag.none);
        expect(after?.entryText?.plainText, 'Transcribed from import');
      },
    );

    test(
      'updateJournalEntityText clears import flag on JournalImage when flag is EntryFlag.import',
      () async {
        final persistenceLogic = getIt<PersistenceLogic>();

        // Create a JournalImage entry with EntryFlag.import so the `true`
        // branch of the ternary in the JournalImage block is exercised
        // (lines 637-639).
        final imageData = ImageData(
          capturedAt: DateTime(2024, 3, 15, 11),
          imageId: 'import-image-id',
          imageFile: 'import.jpg',
          imageDirectory: '/images/2024-01-01/',
        );
        final imageMeta = await persistenceLogic.createMetadata(
          dateFrom: DateTime(2024, 3, 15, 11),
          flag: EntryFlag.import,
        );
        final imageEntity = JournalEntity.journalImage(
          data: imageData,
          meta: imageMeta,
        );
        await persistenceLogic.createDbEntity(
          imageEntity,
          shouldAddGeolocation: false,
        );

        // Confirm the entry starts with the import flag
        final before =
            await getIt<JournalDb>().journalEntityById(imageEntity.meta.id)
                as JournalImage?;
        expect(before?.meta.flag, EntryFlag.import);

        // Update text — this should clear the import flag
        const newText = EntryText(plainText: 'Image caption');
        final success = await persistenceLogic.updateJournalEntityText(
          imageEntity.meta.id,
          newText,
          DateTime(2024, 3, 15, 11, 5),
        );

        expect(success, isTrue);

        final after =
            await getIt<JournalDb>().journalEntityById(imageEntity.meta.id)
                as JournalImage?;
        // The import flag must be cleared after text update
        expect(after?.meta.flag, EntryFlag.none);
        expect(after?.entryText?.plainText, 'Image caption');
      },
    );
  });

  // Error-path coverage for the `_loggingService.error(...)` calls inside the
  // catch blocks of PersistenceLogic. These run against fully mocked
  // dependencies so the wrapped operation can be made to throw on demand,
  // exercising each catch branch and asserting the documented failure result.
  group('Error path logging - ', () {
    late MockJournalDb journalDb;
    late MockUpdateNotifications updateNotifications;
    late MockDomainLogger loggingService;
    late MockOutboxService outboxService;
    late MockFts5Db fts5Db;
    late MockNotificationService notificationService;
    late MockVectorClockService vectorClockService;
    late PersistenceLogic logic;

    const boom = 'boom';

    JournalEntity buildEntry({
      String id = 'entry-id',
      VectorClock? clock,
    }) {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: clock,
        ),
        entryText: const EntryText(plainText: 'text'),
      );
    }

    /// Verifies a single `_loggingService.error(domain, ..., subDomain: X)`
    /// call was routed through the DomainLogger for the given catch branch.
    void verifyLogged(LogDomain domain, String subDomain) {
      verify(
        () => loggingService.error(
          domain,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: subDomain,
        ),
      ).called(1);
    }

    setUpAll(() {
      registerFallbackValue(const VectorClock({'host': 0}));
      registerFallbackValue(
        EntryLink.basic(
          id: 'fallback-link',
          fromId: 'fallback-from',
          toId: 'fallback-to',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        ),
      );
      registerFallbackValue(
        const ConfigFlag(
          name: 'fallback',
          description: 'fallback config flag',
          status: false,
        ),
      );
      // EntityDefinition fallback for upsertEntityDefinition stubs
      registerFallbackValue(FakeHabitDefinition());
    });

    setUp(() async {
      await getIt.reset();
      journalDb = MockJournalDb();
      updateNotifications = MockUpdateNotifications();
      loggingService = MockDomainLogger();
      outboxService = MockOutboxService();
      fts5Db = MockFts5Db();
      notificationService = MockNotificationService();
      vectorClockService = MockVectorClockService();

      when(
        () => fts5Db.insertText(
          any<JournalEntity>(),
          removePrevious: any<bool>(named: 'removePrevious'),
        ),
      ).thenAnswer((_) async {});
      when(notificationService.updateBadge).thenAnswer((_) async {});
      when(
        () => updateNotifications.notify(any<Set<String>>()),
      ).thenReturn(null);
      when(
        () => outboxService.enqueueMessage(any<SyncMessage>()),
      ).thenAnswer((_) async {});
      when(
        () => vectorClockService.getNextVectorClock(),
      ).thenAnswer((_) async => const VectorClock({'host': 1}));
      when(
        () => vectorClockService.getNextVectorClock(
          previous: any<VectorClock?>(named: 'previous'),
        ),
      ).thenAnswer((_) async => const VectorClock({'host': 1}));
      when(
        () => vectorClockService.getHost(),
      ).thenAnswer((_) async => 'test-host-id');
      when(
        () => vectorClockService.burnUnboundVectorClock(
          any<VectorClock?>(),
          reason: any<String>(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => journalDb.addLabeled(any<JournalEntity>()),
      ).thenAnswer((_) async {});
      when(
        () => journalDb.parentLinkedEntityIds(any<String>()),
      ).thenReturn(MockSelectable<String>([]));

      getIt
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<UpdateNotifications>(updateNotifications)
        ..registerSingleton<DomainLogger>(loggingService)
        ..registerSingleton<OutboxService>(outboxService)
        ..registerSingleton<Fts5Db>(fts5Db)
        ..registerSingleton<NotificationService>(notificationService)
        ..registerSingleton<VectorClockService>(vectorClockService)
        ..registerSingleton<MetadataService>(
          MetadataService(vectorClockService: vectorClockService),
        );

      logic = PersistenceLogic();
    });

    tearDown(() async {
      await getIt.reset();
    });

    /// Makes metadata creation throw so every `create*` method enters its
    /// catch block right where `createMetadata(...)` is awaited.
    void stubCreateMetadataThrows() {
      when(
        () => vectorClockService.getNextVectorClock(),
      ).thenThrow(StateError(boom));
    }

    test('createQuantitativeEntry logs and returns null on failure', () async {
      stubCreateMetadataThrows();

      final result = await logic.createQuantitativeEntry(
        QuantitativeData.discreteQuantityData(
          dateFrom: DateTime(2024, 3, 15, 10),
          dateTo: DateTime(2024, 3, 15, 10),
          value: 1,
          dataType: 'type',
          unit: 'unit',
        ),
      );

      expect(result, isNull);
      verifyLogged(LogDomain.persistence, 'createQuantitativeEntry');
    });

    test('createWorkoutEntry logs and returns null on failure', () async {
      stubCreateMetadataThrows();

      final result = await logic.createWorkoutEntry(
        WorkoutData(
          dateFrom: DateTime(2024, 3, 15, 10),
          dateTo: DateTime(2024, 3, 15, 11),
          id: 'workout-id',
          workoutType: 'RUNNING',
          energy: 100,
          distance: 1000,
          source: 'test',
        ),
      );

      expect(result, isNull);
      verifyLogged(LogDomain.persistence, 'createWorkoutEntry');
    });

    test('createSurveyEntry logs and still returns true on failure', () async {
      stubCreateMetadataThrows();

      final taskResult = RPTaskResult(identifier: 'survey')
        ..startDate = DateTime(2024, 3, 15, 10)
        ..endDate = DateTime(2024, 3, 15, 10, 5);

      final result = await logic.createSurveyEntry(
        data: SurveyData(
          taskResult: taskResult,
          scoreDefinitions: const {},
          calculatedScores: const {},
        ),
      );

      // Documented contract: createSurveyEntry returns true even on failure.
      expect(result, isTrue);
      verifyLogged(LogDomain.persistence, 'createSurveyEntry');
    });

    test('createMeasurementEntry logs and returns null on failure', () async {
      stubCreateMetadataThrows();

      final result = await logic.createMeasurementEntry(
        data: MeasurementData(
          dateFrom: DateTime(2024, 3, 15, 10),
          dateTo: DateTime(2024, 3, 15, 10),
          value: 1,
          dataTypeId: 'data-type-id',
        ),
        private: false,
      );

      expect(result, isNull);
      verifyLogged(LogDomain.persistence, 'createMeasurementEntry');
    });

    test(
      'createHabitCompletionEntry logs and returns null on failure',
      () async {
        stubCreateMetadataThrows();

        final result = await logic.createHabitCompletionEntry(
          data: HabitCompletionData(
            dateFrom: DateTime(2024, 3, 15, 10),
            dateTo: DateTime(2024, 3, 15, 10),
            habitId: 'habit-id',
          ),
          habitDefinition: null,
        );

        expect(result, isNull);
        // Note: the source reuses the 'createMeasurementEntry' subDomain here.
        verifyLogged(LogDomain.persistence, 'createMeasurementEntry');
      },
    );

    test('createTaskEntry logs and returns null on failure', () async {
      stubCreateMetadataThrows();

      final result = await logic.createTaskEntry(
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: DateTime(2024, 3, 15, 10),
            utcOffset: 60,
          ),
          title: 'title',
          statusHistory: const [],
          dateTo: DateTime(2024, 3, 15, 10),
          dateFrom: DateTime(2024, 3, 15, 10),
        ),
        entryText: const EntryText(plainText: 'task text'),
      );

      expect(result, isNull);
      verifyLogged(LogDomain.persistence, 'createTaskEntry');
    });

    test('createAiResponseEntry logs and returns null on failure', () async {
      stubCreateMetadataThrows();

      final result = await logic.createAiResponseEntry(
        data: const AiResponseData(
          model: 'model',
          systemMessage: 'system',
          prompt: 'prompt',
          thoughts: 'thoughts',
          response: 'response',
        ),
        dateFrom: DateTime(2024, 3, 15, 10),
      );

      expect(result, isNull);
      verifyLogged(LogDomain.persistence, 'createAiResponseEntry');
    });

    test('createEventEntry logs and returns null on failure', () async {
      stubCreateMetadataThrows();

      final result = await logic.createEventEntry(
        data: const EventData(
          status: EventStatus.tentative,
          title: 'Event',
          stars: 1,
        ),
        entryText: const EntryText(plainText: 'event text'),
      );

      expect(result, isNull);
      verifyLogged(LogDomain.persistence, 'createEventEntry');
    });

    test('createDbEntity logs and returns null on failure', () async {
      when(
        () => journalDb.updateJournalEntity(
          any<JournalEntity>(),
          overrideComparison: any<bool>(named: 'overrideComparison'),
          overwrite: any<bool>(named: 'overwrite'),
        ),
      ).thenThrow(StateError(boom));

      final result = await logic.createDbEntity(
        buildEntry(clock: const VectorClock({'host': 1})),
        shouldAddGeolocation: false,
      );

      expect(result, isNull);
      verifyLogged(LogDomain.persistence, 'createDbEntity');
    });

    test('updateJournalEntityText logs and returns false on failure', () async {
      when(
        () => journalDb.journalEntityById(any<String>()),
      ).thenThrow(StateError(boom));

      final result = await logic.updateJournalEntityText(
        'entry-id',
        const EntryText(plainText: 'new text'),
        DateTime(2024, 3, 15, 10, 35),
      );

      expect(result, isFalse);
      verifyLogged(LogDomain.persistence, 'updateJournalEntityText');
    });

    test('updateJournalEntry logs and returns false on failure', () async {
      when(
        () => journalDb.journalEntityById(any<String>()),
      ).thenThrow(StateError(boom));

      final result = await logic.updateJournalEntry(
        journalEntityId: 'entry-id',
        entryText: const EntryText(plainText: 'new text'),
      );

      expect(result, isFalse);
      verifyLogged(LogDomain.persistence, 'updateJournalEntry');
    });

    test('updateTask logs and returns true on failure', () async {
      when(
        () => journalDb.journalEntityById(any<String>()),
      ).thenThrow(StateError(boom));

      final result = await logic.updateTask(
        journalEntityId: 'entry-id',
        taskData: TaskData(
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: DateTime(2024, 3, 15, 10),
            utcOffset: 60,
          ),
          title: 'title',
          statusHistory: const [],
          dateTo: DateTime(2024, 3, 15, 10),
          dateFrom: DateTime(2024, 3, 15, 10),
        ),
      );

      // Documented contract: updateTask returns true even when the lookup
      // throws and the failure is logged.
      expect(result, isTrue);
      verifyLogged(LogDomain.persistence, 'updateTask');
    });

    test('updateEvent logs and returns true on failure', () async {
      when(
        () => journalDb.journalEntityById(any<String>()),
      ).thenThrow(StateError(boom));

      final result = await logic.updateEvent(
        journalEntityId: 'entry-id',
        data: const EventData(
          status: EventStatus.tentative,
          title: 'Event',
          stars: 1,
        ),
      );

      expect(result, isTrue);
      verifyLogged(LogDomain.persistence, 'updateEvent');
    });

    test('updateJournalEntity logs and returns false on failure', () async {
      // updateMetadata runs inside the VC scope; making the increment throw
      // propagates out of the scope into the outer catch block.
      when(
        () => vectorClockService.getNextVectorClock(
          previous: any<VectorClock?>(named: 'previous'),
        ),
      ).thenThrow(StateError(boom));

      final entry = buildEntry(clock: const VectorClock({'host': 1}));
      final result = await logic.updateJournalEntity(entry, entry.meta);

      expect(result, isFalse);
      verifyLogged(LogDomain.persistence, 'updateJournalEntity');
    });

    test('updateDbEntity logs and returns null on failure', () async {
      when(
        () => journalDb.updateJournalEntity(
          any<JournalEntity>(),
          overrideComparison: any<bool>(named: 'overrideComparison'),
          overwrite: any<bool>(named: 'overwrite'),
        ),
      ).thenThrow(StateError(boom));

      final result = await logic.updateDbEntity(
        buildEntry(clock: const VectorClock({'host': 1})),
      );

      expect(result, isNull);
      verifyLogged(LogDomain.persistence, 'updateDbEntity');
    });

    test(
      'updateDbEntity logs beforeNotify failure and still applies the write',
      () async {
        when(
          () => journalDb.updateJournalEntity(
            any<JournalEntity>(),
            overrideComparison: any<bool>(named: 'overrideComparison'),
            overwrite: any<bool>(named: 'overwrite'),
          ),
        ).thenAnswer((_) async => JournalUpdateResult.applied());

        final result = await logic.updateDbEntity(
          // Null vectorClock keeps `_recordJournalSequence` a no-op so the
          // only failing step is `beforeNotify`.
          buildEntry(),
          beforeNotify: () async => throw StateError(boom),
        );

        // The applied write still propagates (returns true); only the
        // beforeNotify side effect failed and was logged.
        expect(result, isTrue);
        verifyLogged(LogDomain.persistence, 'updateDbEntity.beforeNotify');
      },
    );

    group('sequence-log integration - ', () {
      late MockSyncSequenceLogService sequenceLog;

      setUp(() {
        sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => sequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenAnswer((_) async {});
        getIt.registerSingleton<SyncSequenceLogService>(sequenceLog);
      });

      test(
        'createDbEntity swallows and logs recordSentEntry failure',
        () async {
          when(
            () => journalDb.updateJournalEntity(
              any<JournalEntity>(),
              overrideComparison: any<bool>(named: 'overrideComparison'),
              overwrite: any<bool>(named: 'overwrite'),
            ),
          ).thenAnswer((_) async => JournalUpdateResult.applied());
          when(
            () => sequenceLog.recordSentEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
            ),
          ).thenThrow(StateError(boom));

          final saved = await logic.createDbEntity(
            buildEntry(clock: const VectorClock({'host': 7})),
            shouldAddGeolocation: false,
          );

          // The sequence-record failure is swallowed; the write still commits.
          expect(saved, isTrue);
          verifyLogged(LogDomain.sync, 'createDbEntity.recordSent');
        },
      );

      test(
        'createLink swallows and logs recordSentEntryLink failure',
        () async {
          when(
            () => journalDb.upsertEntryLink(any<EntryLink>()),
          ).thenAnswer((_) async => 1);
          when(
            () => sequenceLog.recordSentEntryLink(
              linkId: any(named: 'linkId'),
              vectorClock: any(named: 'vectorClock'),
            ),
          ).thenThrow(StateError(boom));

          final created = await logic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          );

          expect(created, isTrue);
          verifyLogged(LogDomain.sync, 'createLink.recordSent');
        },
      );
    });

    test(
      'createLink swallows and logs outbox enqueue failure after VC commit',
      () async {
        // Make upsertEntryLink succeed so the VC is "committed"
        when(
          () => journalDb.upsertEntryLink(any<EntryLink>()),
        ).thenAnswer((_) async => 1);
        // Make the outbox throw after the link is persisted
        when(
          () => outboxService.enqueueMessage(any<SyncMessage>()),
        ).thenThrow(StateError(boom));

        final created = await logic.createLink(
          fromId: 'from-id',
          toId: 'to-id',
        );

        // The link was persisted — createLink must still return true
        expect(created, isTrue);
        // The failure is logged through DomainLogger via getIt
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            message: any<String>(named: 'message'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'createLink.enqueue',
          ),
        ).called(1);
      },
    );

    test(
      'createDbEntity swallows and logs outbox enqueue failure after VC commit',
      () async {
        when(
          () => journalDb.updateJournalEntity(
            any<JournalEntity>(),
            overrideComparison: any<bool>(named: 'overrideComparison'),
            overwrite: any<bool>(named: 'overwrite'),
          ),
        ).thenAnswer((_) async => JournalUpdateResult.applied());
        when(
          () => outboxService.enqueueMessage(any<SyncMessage>()),
        ).thenThrow(StateError(boom));

        final saved = await logic.createDbEntity(
          buildEntry(clock: const VectorClock({'host': 3})),
          shouldAddGeolocation: false,
        );

        // DB write succeeded; enqueue failure is swallowed
        expect(saved, isTrue);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            message: any<String>(named: 'message'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'createDbEntity.enqueue',
          ),
        ).called(1);
      },
    );

    test(
      'updateDbEntity swallows and logs outbox enqueue failure after VC commit',
      () async {
        when(
          () => journalDb.updateJournalEntity(
            any<JournalEntity>(),
            overrideComparison: any<bool>(named: 'overrideComparison'),
            overwrite: any<bool>(named: 'overwrite'),
          ),
        ).thenAnswer((_) async => JournalUpdateResult.applied());
        when(
          () => outboxService.enqueueMessage(any<SyncMessage>()),
        ).thenThrow(StateError(boom));

        final applied = await logic.updateDbEntity(
          buildEntry(clock: const VectorClock({'host': 4})),
        );

        // DB write succeeded; enqueue failure is swallowed
        expect(applied, isTrue);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            message: any<String>(named: 'message'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'updateDbEntity.enqueue',
          ),
        ).called(1);
      },
    );

    test(
      'updateJournalEntity returns false when DB rejects the write (applied=false)',
      () async {
        // updateJournalEntity calls updateDbEntity which calls
        // journalDb.updateJournalEntity; returning skipped() means applied=false,
        // which exercises commitWhen: (applied) => applied with false.
        when(
          () => journalDb.updateJournalEntity(
            any<JournalEntity>(),
            overrideComparison: any<bool>(named: 'overrideComparison'),
            overwrite: any<bool>(named: 'overwrite'),
          ),
        ).thenAnswer(
          (_) async => JournalUpdateResult.skipped(
            reason: JournalUpdateSkipReason.olderOrEqual,
          ),
        );
        when(
          () => journalDb.journalEntityById(any<String>()),
        ).thenAnswer((_) async => null);

        final entry = buildEntry(clock: const VectorClock({'host': 5}));
        final result = await logic.updateJournalEntity(entry, entry.meta);

        // The write was rejected — result is false and no log error
        expect(result, isFalse);
      },
    );

    test(
      'upsertEntityDefinition emits labelsNotification for LabelDefinition',
      () async {
        when(
          () => journalDb.upsertEntityDefinition(any<EntityDefinition>()),
        ).thenAnswer((_) async => 1);

        final label = LabelDefinition(
          id: 'label-test-id',
          name: 'TestLabel',
          color: '#123456',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
        );

        final result = await logic.upsertEntityDefinition(label);

        expect(result, 1);
        // Verify that the labelsNotification was included in the notify call
        final captured = verify(
          () => updateNotifications.notify(captureAny<Set<String>>()),
        ).captured;
        final notifiedIds = captured.last as Set<String>;
        expect(notifiedIds, contains('LABELS_CHANGED'));
        expect(notifiedIds, contains('label-test-id'));
      },
    );

    test(
      'setConfigFlag notifies privateToggleNotification when flag name is private',
      () async {
        when(
          () => journalDb.upsertConfigFlag(any<ConfigFlag>()),
        ).thenAnswer((_) async => 1);

        const flag = ConfigFlag(
          name: 'private',
          description: 'Private mode',
          status: true,
        );

        await logic.setConfigFlag(flag);

        final captured = verify(
          () => updateNotifications.notify(captureAny<Set<String>>()),
        ).captured;
        final notifiedIds = captured.last as Set<String>;
        // The private flag triggers the special privateToggleNotification
        expect(notifiedIds, contains('PRIVATE_FLAG_TOGGLED'));
      },
    );

    test(
      'setConfigFlag does not notify privateToggleNotification for other flags',
      () async {
        when(
          () => journalDb.upsertConfigFlag(any<ConfigFlag>()),
        ).thenAnswer((_) async => 1);

        const flag = ConfigFlag(
          name: 'enableLogging',
          description: 'Enable logging',
          status: false,
        );

        await logic.setConfigFlag(flag);

        // No notify call expected for non-private flags
        verifyNever(
          () => updateNotifications.notify(any<Set<String>>()),
        );
      },
    );
  });

  group('persistence logic update', () {
    setUpAll(() {
      registerFallbackValue(
        const SyncMessage.journalEntity(
          id: 'fallback',
          jsonPath: '/fallback.json',
          vectorClock: VectorClock({'host': 1}),
          status: SyncEntryStatus.update,
        ),
      );
      registerFallbackValue(fallbackJournalEntity);
      registerFallbackValue(
        EntryLink.basic(
          id: 'fallback-link',
          fromId: 'fallback-from',
          toId: 'fallback-to',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: const VectorClock({'host': 1}),
        ),
      );
    });

    late MockJournalDb journalDb;
    late MockUpdateNotifications updateNotifications;
    late MockDomainLogger loggingService;
    late MockOutboxService outboxService;
    late MockFts5Db fts5Db;
    late MockNotificationService notificationService;
    late MockVectorClockService vectorClockService;
    late TestPersistenceLogic logic;

    void stubUpdateResult(JournalUpdateResult result) {
      when(
        () => journalDb.updateJournalEntity(
          any<JournalEntity>(),
          overrideComparison: any<bool>(named: 'overrideComparison'),
          overwrite: any<bool>(named: 'overwrite'),
        ),
      ).thenAnswer((_) async => result);
    }

    JournalEntity buildEntry({
      String id = 'entry-id',
      VectorClock? clock,
    }) {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: clock ?? const VectorClock({'host': 1}),
        ),
        entryText: const EntryText(plainText: 'text'),
      );
    }

    setUp(() async {
      await getIt.reset();
      journalDb = MockJournalDb();
      updateNotifications = MockUpdateNotifications();
      loggingService = MockDomainLogger();
      outboxService = MockOutboxService();
      fts5Db = MockFts5Db();
      notificationService = MockNotificationService();
      vectorClockService = MockVectorClockService();

      when(
        () => fts5Db.insertText(
          any<JournalEntity>(),
          removePrevious: any<bool>(named: 'removePrevious'),
        ),
      ).thenAnswer((_) async {});
      when(notificationService.updateBadge).thenAnswer((_) async {});
      when(
        () => updateNotifications.notify(any<Set<String>>()),
      ).thenReturn(null);
      when(
        () => outboxService.enqueueMessage(any<SyncMessage>()),
      ).thenAnswer((_) async {});
      when(
        () => vectorClockService.getNextVectorClock(),
      ).thenAnswer((_) async => const VectorClock({'host': 1}));
      when(
        () => vectorClockService.getNextVectorClock(
          previous: any<VectorClock?>(named: 'previous'),
        ),
      ).thenAnswer((_) async => const VectorClock({'host': 1}));
      when(
        () => vectorClockService.getHost(),
      ).thenAnswer((_) async => 'test-host-id');
      when(
        () => vectorClockService.burnUnboundVectorClock(
          any<VectorClock?>(),
          reason: any<String>(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => journalDb.addLabeled(any<JournalEntity>()),
      ).thenAnswer((_) async {});
      when(
        () => journalDb.parentLinkedEntityIds(any<String>()),
      ).thenReturn(MockSelectable<String>([]));
      when(
        () => journalDb.updateTaskPriorityColumn(
          id: any(named: 'id'),
          priority: any(named: 'priority'),
          rank: any(named: 'rank'),
        ),
      ).thenAnswer((_) async {});

      getIt
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<UpdateNotifications>(updateNotifications)
        ..registerSingleton<DomainLogger>(loggingService)
        ..registerSingleton<OutboxService>(outboxService)
        ..registerSingleton<Fts5Db>(fts5Db)
        ..registerSingleton<NotificationService>(notificationService)
        ..registerSingleton<VectorClockService>(vectorClockService)
        ..registerSingleton<MetadataService>(
          MetadataService(vectorClockService: vectorClockService),
        );

      logic = TestPersistenceLogic();
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('updateDbEntity returns true when update applied', () async {
      stubUpdateResult(JournalUpdateResult.applied());

      final result = await logic.updateDbEntity(buildEntry());

      expect(result, isTrue);
      verify(() => outboxService.enqueueMessage(any<SyncMessage>())).called(1);
      verify(() => updateNotifications.notify(any<Set<String>>())).called(1);
    });

    test(
      'updateDbEntity logs beforeNotify failures and still propagates changes',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());

        final result = await logic.updateDbEntity(
          buildEntry(),
          beforeNotify: () async => throw Exception('beforeNotify failed'),
        );

        expect(result, isTrue);
        verify(
          () => loggingService.error(
            LogDomain.persistence,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'updateDbEntity.beforeNotify',
          ),
        ).called(1);
        verify(() => updateNotifications.notify(any<Set<String>>())).called(1);
        verify(
          () => outboxService.enqueueMessage(any<SyncMessage>()),
        ).called(1);
        verify(
          () => fts5Db.insertText(
            any<JournalEntity>(),
            removePrevious: true,
          ),
        ).called(1);
        verify(notificationService.updateBadge).called(1);
      },
    );

    test('updateDbEntity returns false when update skipped', () async {
      stubUpdateResult(
        JournalUpdateResult.skipped(
          reason: JournalUpdateSkipReason.olderOrEqual,
        ),
      );

      final result = await logic.updateDbEntity(buildEntry());

      expect(result, isFalse);
      verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
    });

    test(
      'updateDbEntity burns the pre-minted VC counter when the write is '
      'rejected — without this the counter leaks as plain reserved since the '
      'incoming clock was minted by updateMetadata outside this scope',
      () async {
        stubUpdateResult(
          JournalUpdateResult.skipped(
            reason: JournalUpdateSkipReason.olderOrEqual,
          ),
        );

        final entry = buildEntry(clock: const VectorClock({'host': 42}));
        final result = await logic.updateDbEntity(entry);

        expect(result, isFalse);
        verify(
          () => vectorClockService.burnUnboundVectorClock(
            entry.meta.vectorClock,
            reason: any<String>(
              named: 'reason',
              that: contains('updateDbEntity write rejected id=entry-id'),
            ),
          ),
        ).called(1);
      },
    );

    test('updateDbEntity returns null on exception', () async {
      when(
        () => journalDb.updateJournalEntity(
          any<JournalEntity>(),
          overrideComparison: any<bool>(named: 'overrideComparison'),
          overwrite: any<bool>(named: 'overwrite'),
        ),
      ).thenThrow(Exception('db down'));

      final result = await logic.updateDbEntity(buildEntry());

      expect(result, isNull);
      verify(
        () => loggingService.error(
          LogDomain.persistence,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'updateDbEntity',
        ),
      ).called(1);
    });

    test(
      'updateDbEntity does not enqueue when enqueueSync is false',
      () async {
        stubUpdateResult(JournalUpdateResult.applied());

        final result = await logic.updateDbEntity(
          buildEntry(),
          enqueueSync: false,
        );

        expect(result, isTrue);
        verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
      },
    );

    glados.Glados(
      glados.any.updateDbEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'updateDbEntity matches generated notification and sync invariants',
      (
        scenario,
      ) async {
        clearInteractions(updateNotifications);
        clearInteractions(outboxService);
        clearInteractions(fts5Db);
        clearInteractions(notificationService);

        stubUpdateResult(
          scenario.applied
              ? JournalUpdateResult.applied()
              : JournalUpdateResult.skipped(
                  reason: JournalUpdateSkipReason.olderOrEqual,
                ),
        );
        when(
          () => journalDb.parentLinkedEntityIds(scenario.entity.id),
        ).thenReturn(MockSelectable<String>(scenario.parentIds));

        final result = await logic.updateDbEntity(
          scenario.entity,
          linkedId: scenario.linkedId,
          enqueueSync: scenario.enqueueSync,
        );

        expect(result, scenario.applied, reason: '$scenario');

        final notificationIds =
            verify(
                  () => updateNotifications.notify(captureAny<Set<String>>()),
                ).captured.single
                as Set<String>;
        expect(notificationIds, scenario.expectedNotificationIds);

        verify(
          () => fts5Db.insertText(
            scenario.entity,
            removePrevious: true,
          ),
        ).called(1);
        verify(notificationService.updateBadge).called(1);

        if (scenario.shouldEnqueueSync) {
          verify(
            () => outboxService.enqueueMessage(any<SyncMessage>()),
          ).called(1);
        } else {
          verifyNever(
            () => outboxService.enqueueMessage(any<SyncMessage>()),
          );
        }
      },
      tags: 'glados',
    );

    test('createDbEntity skips addLabeled when update skipped', () async {
      stubUpdateResult(
        JournalUpdateResult.skipped(
          reason: JournalUpdateSkipReason.olderOrEqual,
        ),
      );

      final entity = buildEntry(clock: const VectorClock({'host': 5}));
      final saved = await logic.createDbEntity(
        entity,
        shouldAddGeolocation: false,
      );

      expect(saved, isFalse);
      verifyNever(() => journalDb.addLabeled(any<JournalEntity>()));
      verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
      verify(
        () => vectorClockService.burnUnboundVectorClock(
          entity.meta.vectorClock,
          reason: any<String>(
            named: 'reason',
            that: contains('createDbEntity write rejected id=entry-id'),
          ),
        ),
      ).called(1);
    });

    glados.Glados(
      glados.any.createDbEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'createDbEntity matches generated context and sync invariants',
      (scenario) async {
        clearInteractions(updateNotifications);
        clearInteractions(outboxService);
        clearInteractions(notificationService);
        clearInteractions(journalDb);

        JournalEntity? persistedEntity;
        when(
          () => journalDb.updateJournalEntity(
            any<JournalEntity>(),
            overrideComparison: any<bool>(named: 'overrideComparison'),
            overwrite: any<bool>(named: 'overwrite'),
          ),
        ).thenAnswer((invocation) async {
          persistedEntity =
              invocation.positionalArguments.first as JournalEntity;
          return scenario.saved
              ? JournalUpdateResult.applied()
              : JournalUpdateResult.skipped(
                  reason: JournalUpdateSkipReason.overwritePrevented,
                );
        });
        when(
          () => journalDb.parentLinkedEntityIds(any<String>()),
        ).thenReturn(MockSelectable<String>([]));
        when(
          () => journalDb.upsertEntryLink(any<EntryLink>()),
        ).thenAnswer((_) async => 1);

        final linked = scenario.linkedEntity;
        if (linked != null) {
          when(
            () => journalDb.journalEntityById(scenario.linkedId!),
          ).thenAnswer((_) async => linked);
        }

        final result = await logic.createDbEntity(
          scenario.entity,
          linkedId: scenario.linkedId,
          enqueueSync: scenario.enqueueSync,
          shouldAddGeolocation: false,
        );

        expect(result, scenario.saved, reason: '$scenario');
        expect(persistedEntity, isNotNull, reason: '$scenario');
        expect(persistedEntity!.meta.categoryId, scenario.expectedCategoryId);
        expect(persistedEntity!.meta.private, scenario.expectedPrivate);

        final expectedOutboxMessages =
            (scenario.shouldEnqueueSync ? 1 : 0) +
            (scenario.hasLinkedEntity ? 1 : 0);
        if (expectedOutboxMessages == 0) {
          verifyNever(
            () => outboxService.enqueueMessage(any<SyncMessage>()),
          );
        } else {
          verify(
            () => outboxService.enqueueMessage(any<SyncMessage>()),
          ).called(expectedOutboxMessages);
        }

        final notifications = verify(
          () => updateNotifications.notify(captureAny<Set<String>>()),
        ).captured.cast<Set<String>>().toList();
        expect(notifications.last, scenario.expectedCreateNotificationIds);

        if (scenario.hasLinkedEntity) {
          expect(notifications.first, {scenario.linkedId, scenario.entityId});
          verify(() => journalDb.upsertEntryLink(any<EntryLink>())).called(1);
        } else {
          verifyNever(() => journalDb.upsertEntryLink(any<EntryLink>()));
        }

        verify(notificationService.updateBadge).called(1);
      },
      tags: 'glados',
    );

    group('updateJournalEntity', () {
      test(
        'adds labels only when update applies and reuses metadata',
        () async {
          final labeledCaptures = <JournalEntity>[];
          when(() => journalDb.addLabeled(captureAny())).thenAnswer((
            invocation,
          ) async {
            labeledCaptures.add(
              invocation.positionalArguments.first as JournalEntity,
            );
          });

          logic = TestPersistenceLogic(
            updateDbEntityHandler:
                (
                  entity, {
                  linkedId,
                  enqueueSync = true,
                  overrideComparison = false,
                  beforeNotify,
                }) async => true,
          );

          final baseEntry = buildEntry();
          final result = await logic.updateJournalEntity(
            baseEntry,
            baseEntry.meta,
          );

          expect(result, isTrue);
          expect(labeledCaptures, hasLength(1));
          final labeledEntity = labeledCaptures.first;
          expect(
            identical(labeledEntity.meta, logic.lastUpdateDbEntity?.meta),
            isTrue,
          );
          expect(logic.updateMetadataCalls, 1);

          clearInteractions(journalDb);
          labeledCaptures.clear();

          logic = TestPersistenceLogic(
            updateDbEntityHandler:
                (
                  entity, {
                  linkedId,
                  enqueueSync = true,
                  overrideComparison = false,
                  beforeNotify,
                }) async => false,
          );

          final skipped = await logic.updateJournalEntity(
            baseEntry,
            baseEntry.meta,
          );

          expect(skipped, isFalse);
          verifyNever(() => journalDb.addLabeled(any<JournalEntity>()));
        },
      );

      test(
        'updates task priority columns before notifying listeners for task updates',
        () async {
          final testDate = DateTime(2024, 3, 15, 10, 30);
          final callOrder = <String>[];
          Set<String>? notifiedIds;
          final task = Task(
            meta: Metadata(
              id: 'task-id',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              vectorClock: const VectorClock({'host': 1}),
            ),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-id',
                createdAt: testDate,
                utcOffset: 60,
              ),
              title: 'task',
              statusHistory: const [],
              dateTo: testDate,
              dateFrom: testDate,
              priority: TaskPriority.p0Urgent,
            ),
          );

          when(() => journalDb.journalEntityById('task-id')).thenAnswer(
            (_) async => task,
          );
          stubUpdateResult(JournalUpdateResult.applied());
          when(
            () => journalDb.updateTaskPriorityColumn(
              id: 'task-id',
              priority: 'P1',
              rank: 1,
            ),
          ).thenAnswer((_) async {
            callOrder.add('priority-column');
          });
          when(
            () => updateNotifications.notify(
              any<Set<String>>(),
              fromSync: any(named: 'fromSync'),
            ),
          ).thenAnswer((invocation) {
            callOrder.add('notify');
            notifiedIds = invocation.positionalArguments.first as Set<String>;
          });

          final updatedTask = task.copyWith(
            data: task.data.copyWith(priority: TaskPriority.p1High),
          );
          final result = await logic.updateJournalEntity(
            updatedTask,
            updatedTask.meta,
          );

          expect(result, isTrue);
          expect(callOrder, equals(['priority-column', 'notify']));
          expect(notifiedIds, contains('task-id'));
        },
      );

      test(
        'skips task priority column updates when updateJournalEntity keeps '
        'priority unchanged',
        () async {
          final testDate = DateTime(2024, 3, 15, 10, 30);
          final task = Task(
            meta: Metadata(
              id: 'task-id',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              vectorClock: const VectorClock({'host': 1}),
            ),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-id',
                createdAt: testDate,
                utcOffset: 60,
              ),
              title: 'task',
              statusHistory: const [],
              dateTo: testDate,
              dateFrom: testDate,
              priority: TaskPriority.p1High,
            ),
          );

          when(
            () => journalDb.journalEntityById('task-id'),
          ).thenAnswer((_) async => task);
          stubUpdateResult(JournalUpdateResult.applied());

          final result = await logic.updateJournalEntity(task, task.meta);

          expect(result, isTrue);
          verifyNever(
            () => journalDb.updateTaskPriorityColumn(
              id: any(named: 'id'),
              priority: any(named: 'priority'),
              rank: any(named: 'rank'),
            ),
          );
        },
      );
    });

    group('agent execution zone routing', () {
      test(
        'updateDbEntity calls notify when outside agent execution zone',
        () async {
          stubUpdateResult(JournalUpdateResult.applied());

          await logic.updateDbEntity(buildEntry());

          verify(
            () => updateNotifications.notify(any<Set<String>>()),
          ).called(1);
          verifyNever(
            () => updateNotifications.notifyUiOnly(any<Set<String>>()),
          );
        },
      );

      test(
        'updateDbEntity calls notifyUiOnly when inside agent execution zone',
        () async {
          stubUpdateResult(JournalUpdateResult.applied());
          when(
            () => updateNotifications.notifyUiOnly(any<Set<String>>()),
          ).thenReturn(null);

          await runZoned(
            () => logic.updateDbEntity(buildEntry()),
            zoneValues: {agentExecutionZoneKey: true},
          );

          verify(
            () => updateNotifications.notifyUiOnly(any<Set<String>>()),
          ).called(1);
          verifyNever(
            () => updateNotifications.notify(any<Set<String>>()),
          );
        },
      );
    });

    group('updateJournalEntityText - entity type branches', () {
      test('updates MeasurementEntry with new text and metadata', () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final measurementEntry = JournalEntity.measurement(
          meta: Metadata(
            id: 'measurement-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          data: MeasurementData(
            dateFrom: testDate,
            dateTo: testDate,
            value: 500,
            dataTypeId: 'water-type-id',
          ),
          entryText: const EntryText(plainText: 'original text'),
        );

        when(
          () => journalDb.journalEntityById('measurement-id'),
        ).thenAnswer((_) async => measurementEntry);

        logic = TestPersistenceLogic(
          updateDbEntityHandler:
              (
                entity, {
                linkedId,
                enqueueSync = true,
                overrideComparison = false,
                beforeNotify,
              }) async => true,
        );

        const newText = EntryText(plainText: 'updated measurement notes');
        final result = await logic.updateJournalEntityText(
          'measurement-id',
          newText,
          DateTime(2024, 3, 15, 10, 35),
        );

        expect(result, isTrue);
        expect(logic.lastUpdateDbEntity, isA<MeasurementEntry>());
        final updated = logic.lastUpdateDbEntity! as MeasurementEntry;
        expect(updated.entryText?.plainText, 'updated measurement notes');
        expect(updated.data.value, 500);
        expect(updated.data.dataTypeId, 'water-type-id');
        expect(logic.updateMetadataCalls, 1);
      });

      test(
        'updates HabitCompletionEntry with new text and metadata',
        () async {
          final testDate = DateTime(2024, 3, 15, 10, 30);
          final habitEntry = JournalEntity.habitCompletion(
            meta: Metadata(
              id: 'habit-id',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              vectorClock: const VectorClock({'host': 1}),
            ),
            data: HabitCompletionData(
              dateFrom: testDate,
              dateTo: testDate,
              habitId: 'flossing-habit-id',
            ),
            entryText: const EntryText(plainText: 'original habit text'),
          );

          when(
            () => journalDb.journalEntityById('habit-id'),
          ).thenAnswer((_) async => habitEntry);

          logic = TestPersistenceLogic(
            updateDbEntityHandler:
                (
                  entity, {
                  linkedId,
                  enqueueSync = true,
                  overrideComparison = false,
                  beforeNotify,
                }) async => true,
          );

          const newText = EntryText(plainText: 'updated habit notes');
          final result = await logic.updateJournalEntityText(
            'habit-id',
            newText,
            DateTime(2024, 3, 15, 10, 35),
          );

          expect(result, isTrue);
          expect(logic.lastUpdateDbEntity, isA<HabitCompletionEntry>());
          final updated = logic.lastUpdateDbEntity! as HabitCompletionEntry;
          expect(updated.entryText?.plainText, 'updated habit notes');
          expect(updated.data.habitId, 'flossing-habit-id');
          expect(logic.updateMetadataCalls, 1);
        },
      );

      test(
        'returns false when an exception is thrown during the update',
        () async {
          // Force the lookup to throw so the body runs into the catch block.
          when(
            () => journalDb.journalEntityById('boom-id'),
          ).thenThrow(StateError('boom'));

          logic = TestPersistenceLogic();

          const newText = EntryText(plainText: 'whatever');
          final result = await logic.updateJournalEntityText(
            'boom-id',
            newText,
            DateTime(2024, 3, 15, 10, 35),
          );

          expect(result, isFalse);
          verify(
            () => loggingService.error(
              LogDomain.persistence,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'updateJournalEntityText',
            ),
          ).called(1);
        },
      );
    });

    group('updateJournalEntry', () {
      test('returns false when no fields are provided', () async {
        final result = await logic.updateJournalEntry(
          journalEntityId: 'entry-id',
        );

        expect(result, isFalse);
        verifyNever(() => journalDb.journalEntityById(any<String>()));
      });

      test('updates JournalEntry text, dateFrom, and dateTo', () async {
        final entry = buildEntry();
        when(
          () => journalDb.journalEntityById('entry-id'),
        ).thenAnswer((_) async => entry);

        logic = TestPersistenceLogic(
          updateDbEntityHandler:
              (
                entity, {
                linkedId,
                enqueueSync = true,
                overrideComparison = false,
                beforeNotify,
              }) async => true,
        );

        final result = await logic.updateJournalEntry(
          journalEntityId: 'entry-id',
          entryText: const EntryText(plainText: 'updated text'),
          dateFrom: DateTime(2024, 3, 15, 9),
          dateTo: DateTime(2024, 3, 15, 11),
        );

        expect(result, isTrue);
        expect(logic.lastUpdateDbEntity, isA<JournalEntry>());
        final updated = logic.lastUpdateDbEntity! as JournalEntry;
        expect(updated.entryText?.plainText, 'updated text');
        expect(updated.meta.dateFrom, DateTime(2024, 3, 15, 9));
        expect(updated.meta.dateTo, DateTime(2024, 3, 15, 11));
        expect(logic.updateMetadataCalls, 1);
      });

      test('keeps existing text when entryText is omitted', () async {
        final entry = buildEntry();
        when(
          () => journalDb.journalEntityById('entry-id'),
        ).thenAnswer((_) async => entry);

        logic = TestPersistenceLogic(
          updateDbEntityHandler:
              (
                entity, {
                linkedId,
                enqueueSync = true,
                overrideComparison = false,
                beforeNotify,
              }) async => true,
        );

        final result = await logic.updateJournalEntry(
          journalEntityId: 'entry-id',
          dateTo: DateTime(2024, 3, 15, 12),
        );

        expect(result, isTrue);
        final updated = logic.lastUpdateDbEntity! as JournalEntry;
        expect(updated.entryText?.plainText, 'text');
        expect(updated.meta.dateTo, DateTime(2024, 3, 15, 12));
      });

      test('returns false when entity is missing', () async {
        when(
          () => journalDb.journalEntityById('missing-id'),
        ).thenAnswer((_) async => null);

        final result = await logic.updateJournalEntry(
          journalEntityId: 'missing-id',
          entryText: const EntryText(plainText: 'updated'),
        );

        expect(result, isFalse);
      });

      test('returns false when entity is not a JournalEntry', () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final task = JournalEntity.task(
          meta: Metadata(
            id: 'task-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'task-id',
              createdAt: testDate,
              utcOffset: 0,
            ),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
            title: 'Task',
          ),
        );
        when(
          () => journalDb.journalEntityById('task-id'),
        ).thenAnswer((_) async => task);

        final result = await logic.updateJournalEntry(
          journalEntityId: 'task-id',
          entryText: const EntryText(plainText: 'updated'),
        );

        expect(result, isFalse);
      });

      test('returns false and logs when lookup throws', () async {
        when(
          () => journalDb.journalEntityById('boom-id'),
        ).thenThrow(StateError('boom'));

        final result = await logic.updateJournalEntry(
          journalEntityId: 'boom-id',
          entryText: const EntryText(plainText: 'updated'),
        );

        expect(result, isFalse);
        verify(
          () => loggingService.error(
            LogDomain.persistence,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'updateJournalEntry',
          ),
        ).called(1);
      });
    });

    group('updateTask - orElse path', () {
      test('logs captureException when entity is not a Task', () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final journalEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'not-a-task-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          entryText: const EntryText(plainText: 'just a journal entry'),
        );

        when(
          () => journalDb.journalEntityById('not-a-task-id'),
        ).thenAnswer((_) async => journalEntry);

        final taskData = TaskData(
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: testDate,
            utcOffset: 60,
          ),
          title: 'test task',
          statusHistory: [],
          dateTo: testDate,
          dateFrom: testDate,
        );

        final result = await logic.updateTask(
          journalEntityId: 'not-a-task-id',
          taskData: taskData,
        );

        expect(result, isTrue);
        verify(
          () => loggingService.error(
            LogDomain.persistence,
            'not a task',
            subDomain: 'updateTask',
          ),
        ).called(1);
      });
    });

    group('updateTask', () {
      test(
        'updates priority columns before notifying listeners for priority changes',
        () async {
          final testDate = DateTime(2024, 3, 15, 10, 30);
          final callOrder = <String>[];
          Set<String>? notifiedIds;
          final task = Task(
            meta: Metadata(
              id: 'task-id',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              vectorClock: const VectorClock({'host': 1}),
            ),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-id',
                createdAt: testDate,
                utcOffset: 60,
              ),
              title: 'task',
              statusHistory: const [],
              dateTo: testDate,
              dateFrom: testDate,
              priority: TaskPriority.p1High,
            ),
          );

          when(
            () => journalDb.journalEntityById('task-id'),
          ).thenAnswer((_) async => task);
          stubUpdateResult(JournalUpdateResult.applied());
          when(
            () => journalDb.updateTaskPriorityColumn(
              id: 'task-id',
              priority: 'P0',
              rank: 0,
            ),
          ).thenAnswer((_) async {
            callOrder.add('priority-column');
          });
          when(
            () => updateNotifications.notify(
              any<Set<String>>(),
              fromSync: any(named: 'fromSync'),
            ),
          ).thenAnswer((invocation) {
            callOrder.add('notify');
            notifiedIds = invocation.positionalArguments.first as Set<String>;
          });

          final updatedTaskData = task.data.copyWith(
            priority: TaskPriority.p0Urgent,
          );

          await logic.updateTask(
            journalEntityId: 'task-id',
            taskData: updatedTaskData,
          );

          expect(callOrder, equals(['priority-column', 'notify']));
          expect(notifiedIds, contains('task-id'));
        },
      );
    });

    group('sequence-log integration', () {
      late MockSyncSequenceLogService sequenceLog;

      setUpAll(() => registerFallbackValue(const VectorClock({'host': 0})));

      setUp(() {
        sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => sequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenAnswer((_) async {});
        getIt.registerSingleton<SyncSequenceLogService>(sequenceLog);
      });

      test(
        'updateDbEntity records the journal entity sequence after applied write',
        () async {
          stubUpdateResult(JournalUpdateResult.applied());

          final entry = buildEntry();
          final result = await logic.updateDbEntity(entry);

          expect(result, isTrue);
          verify(
            () => sequenceLog.recordSentEntry(
              entryId: entry.meta.id,
              vectorClock: entry.meta.vectorClock!,
            ),
          ).called(1);
        },
      );

      test(
        'updateDbEntity does not record when the write is skipped',
        () async {
          stubUpdateResult(
            JournalUpdateResult.skipped(
              reason: JournalUpdateSkipReason.olderOrEqual,
            ),
          );

          await logic.updateDbEntity(buildEntry());

          verifyNever(
            () => sequenceLog.recordSentEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
            ),
          );
        },
      );

      test(
        'updateDbEntity sequence-record failure is swallowed and logged via '
        'LoggingService; outbox is still enqueued',
        () async {
          stubUpdateResult(JournalUpdateResult.applied());
          when(
            () => sequenceLog.recordSentEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
            ),
          ).thenThrow(StateError('sequence ledger boom'));

          final result = await logic.updateDbEntity(buildEntry());

          expect(result, isTrue);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'updateDbEntity.recordSent',
            ),
          ).called(1);
          verify(
            () => outboxService.enqueueMessage(any<SyncMessage>()),
          ).called(1);
        },
      );

      test(
        'createDbEntity records the journal entity sequence after saved write',
        () async {
          stubUpdateResult(JournalUpdateResult.applied());
          when(
            () => journalDb.parentLinkedEntityIds(any<String>()),
          ).thenReturn(MockSelectable<String>([]));

          final entity = buildEntry(clock: const VectorClock({'host': 7}));
          final saved = await logic.createDbEntity(
            entity,
            shouldAddGeolocation: false,
          );

          expect(saved, isTrue);
          verify(
            () => sequenceLog.recordSentEntry(
              entryId: entity.meta.id,
              vectorClock: entity.meta.vectorClock!,
            ),
          ).called(1);
        },
      );

      test(
        'createDbEntity sequence-record failure is swallowed and logged via '
        'LoggingService',
        () async {
          stubUpdateResult(JournalUpdateResult.applied());
          when(
            () => journalDb.parentLinkedEntityIds(any<String>()),
          ).thenReturn(MockSelectable<String>([]));
          when(
            () => sequenceLog.recordSentEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
            ),
          ).thenThrow(StateError('sequence ledger boom'));

          final entity = buildEntry(clock: const VectorClock({'host': 8}));
          final saved = await logic.createDbEntity(
            entity,
            shouldAddGeolocation: false,
          );

          expect(saved, isTrue);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'createDbEntity.recordSent',
            ),
          ).called(1);
        },
      );

      test(
        'createLink records the entry-link sequence after the upsert returns >0 '
        'rows',
        () async {
          when(
            () => journalDb.upsertEntryLink(any<EntryLink>()),
          ).thenAnswer((_) async => 1);

          final created = await logic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          );

          expect(created, isTrue);
          verify(
            () => sequenceLog.recordSentEntryLink(
              linkId: any(named: 'linkId'),
              vectorClock: const VectorClock({'host': 1}),
            ),
          ).called(1);
        },
      );

      test(
        'createLink sequence-record failure is swallowed and routed through '
        'LoggingService.captureException',
        () async {
          when(
            () => journalDb.upsertEntryLink(any<EntryLink>()),
          ).thenAnswer((_) async => 1);
          when(
            () => sequenceLog.recordSentEntryLink(
              linkId: any(named: 'linkId'),
              vectorClock: any(named: 'vectorClock'),
            ),
          ).thenThrow(StateError('sequence ledger boom'));

          final created = await logic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          );

          expect(created, isTrue);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'createLink.recordSent',
            ),
          ).called(1);
        },
      );
    });

    group('updateEvent - orElse path', () {
      test('logs captureException when entity is not an Event', () async {
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final journalEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'not-an-event-id',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            vectorClock: const VectorClock({'host': 1}),
          ),
          entryText: const EntryText(plainText: 'just a journal entry'),
        );

        when(
          () => journalDb.journalEntityById('not-an-event-id'),
        ).thenAnswer((_) async => journalEntry);

        const eventData = EventData(
          status: EventStatus.tentative,
          title: 'Test Event',
          stars: 3,
        );

        final result = await logic.updateEvent(
          journalEntityId: 'not-an-event-id',
          data: eventData,
        );

        expect(result, isTrue);
        verify(
          () => loggingService.error(
            LogDomain.persistence,
            'not an event',
            subDomain: 'updateEvent',
          ),
        ).called(1);
      });
    });
  });
}

// Mock DeviceLocation — not available in central mocks
