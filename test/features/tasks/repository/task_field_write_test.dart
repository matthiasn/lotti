import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/repository/task_field_write.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/path_provider.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import 'task_field_writes_model_conformance.dart';

/// A [JournalDb] that lands a version from another device right after the
/// next read of a row — between a writer's read and the write it builds on
/// that read, the interleaving the compare-and-set exists for.
class _RacingJournalDb extends JournalDb {
  _RacingJournalDb() : super(inMemoryDatabase: true);

  /// Lands once, after the next read of any row.
  Future<void> Function()? landAfterNextRead;

  @override
  Future<JournalEntity?> journalEntityById(String id) async {
    final read = await super.journalEntityById(id);
    final land = landAfterNextRead;
    if (land != null) {
      landAfterNextRead = null;
      await land();
    }
    return read;
  }
}

/// [writeTaskField] against a real in-memory [JournalDb] behind the real
/// [PersistenceLogic] and [JournalRepository]: the comparison runs on the row
/// as stored, inside the write, so these tests read the row back rather than
/// trusting a mock (`specs/tla/TaskFieldWrites.tla`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockNotificationService = MockNotificationService();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockFts5Db = MockFts5Db();
  final mockOutboxService = MockOutboxService();

  late _RacingJournalDb journalDb;
  late SettingsDb settingsDb;
  late JournalRepository repository;
  late PersistenceLogic persistence;
  var remoteCounter = 0;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    setFakeDocumentsPath();
    settingsDb = SettingsDb(inMemoryDatabase: true);
    journalDb = _RacingJournalDb();
    await initConfigFlags(journalDb, inMemoryDatabase: true);

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

    final documentsDirectory = await getApplicationDocumentsDirectory();
    await setUpTestGetIt(
      additionalSetup: () {
        void put<T extends Object>(T instance) {
          if (getIt.isRegistered<T>()) getIt.unregister<T>();
          getIt.registerSingleton<T>(instance);
        }

        put<UpdateNotifications>(mockUpdateNotifications);
        put<Directory>(documentsDirectory);
        put<SettingsDb>(settingsDb);
        put<Fts5Db>(mockFts5Db);
        put<JournalDb>(journalDb);
        put<OutboxService>(mockOutboxService);
        put<NotificationService>(mockNotificationService);
        put<VectorClockService>(VectorClockService());
        put<TimeService>(MockTimeService());
        put<NavService>(MockNavService());
        put<EntitiesCacheService>(MockEntitiesCacheService());
        put<DomainLogger>(DomainLogger(loggingService: LoggingService()));
        put<MetadataService>(
          MetadataService(vectorClockService: getIt<VectorClockService>()),
        );
        put<GeolocationService>(MockGeolocationService());
        put<PersistenceLogic>(PersistenceLogic());
      },
    );
    persistence = getIt<PersistenceLogic>();
    repository = JournalRepository();
  });

  tearDown(() async {
    await tearDownTestGetIt();
    await journalDb.close();
    await settingsDb.close();
  });

  /// Stores a task and returns it as read back: the copy a tool call takes.
  Future<Task> storedTask({Set<String>? effects}) async {
    final meta = await persistence.createMetadata();
    await persistence.createDbEntity(
      testTask.copyWith(
        meta: meta,
        data: testTask.data.copyWith(
          title: 'Feed the penguins',
          priority: TaskPriority.p2Medium,
          appliedChangeEffects: effects,
        ),
      ),
    );
    return (await journalDb.journalEntityById(meta.id))! as Task;
  }

  Future<Task> reread(String id) async =>
      (await journalDb.journalEntityById(id))! as Task;

  /// Lands [data] on the stored row as a version from another device.
  Future<void> landFromSync(String id, TaskData Function(TaskData) data) async {
    final stored = await reread(id);
    await journalDb.updateJournalEntity(
      stored.copyWith(
        meta: stored.meta.copyWith(
          vectorClock: VectorClock({
            ...?stored.meta.vectorClock?.vclock,
            'other-device': ++remoteCounter,
          }),
        ),
        data: data(stored.data),
      ),
    );
  }

  Future<TaskFieldWrite> writeTitle(Task task, String title) => writeTaskField(
    journalRepository: repository,
    task: task,
    field: (data) => data.title,
    set: (stored) => stored.copyWith(title: title),
  );

  group('writeTaskField', () {
    test('sets the field and answers the task as stored', () async {
      final task = await storedTask();

      final write = await writeTitle(task, 'Feed the penguins twice');

      final stored = await reread(task.id);
      expect(stored.data.title, 'Feed the penguins twice');
      expect(write, isA<TaskFieldWritten>());
      expect((write as TaskFieldWritten).task.data, stored.data);
      expect(write.task.meta.vectorClock, stored.meta.vectorClock);
    });

    test('keeps a field another writer set since the call read the task — it '
        'builds on the stored row, not the copy (NoLostFieldEdit)', () async {
      final task = await storedTask();
      await persistence.updateTask(
        journalEntityId: task.id,
        change: (stored) => stored.copyWith(priority: TaskPriority.p0Urgent),
      );

      final write = await writeTitle(task, 'Feed the penguins twice');

      final stored = await reread(task.id);
      expect(write, isA<TaskFieldWritten>());
      expect(stored.data.title, 'Feed the penguins twice');
      expect(stored.data.priority, TaskPriority.p0Urgent);
    });

    test('writes nothing when the field changed since the call read it, and '
        'answers the newer value (NoBlindAgentWrite)', () async {
      final task = await storedTask();
      await persistence.updateTask(
        journalEntityId: task.id,
        change: (stored) => stored.copyWith(title: 'Set by the user'),
      );
      final before = await reread(task.id);

      final write = await writeTitle(task, 'Set by the agent');

      final stored = await reread(task.id);
      expect(write, isA<TaskFieldMoved>());
      expect((write as TaskFieldMoved).task.data.title, 'Set by the user');
      expect(stored.data.title, 'Set by the user');
      // Nothing was written: the row is the version the user stored.
      expect(stored.meta.vectorClock, before.meta.vectorClock);
    });

    test('compares again on the version sync lands between the write’s read '
        'and its write, so the synced value stands', () async {
      final task = await storedTask();
      journalDb.landAfterNextRead = () => landFromSync(
        task.id,
        (data) => data.copyWith(title: 'Set on the phone'),
      );

      final write = await writeTitle(task, 'Set by the agent');

      final stored = await reread(task.id);
      expect(write, isA<TaskFieldMoved>());
      expect(stored.data.title, 'Set on the phone');
      expect(stored.meta.vectorClock?.vclock['other-device'], remoteCounter);
    });

    test('builds again on a synced version that changed another field, '
        'keeping both', () async {
      final task = await storedTask();
      journalDb.landAfterNextRead = () => landFromSync(
        task.id,
        (data) => data.copyWith(estimate: const Duration(minutes: 90)),
      );

      final write = await writeTitle(task, 'Set by the agent');

      final stored = await reread(task.id);
      expect(write, isA<TaskFieldWritten>());
      expect(stored.data.title, 'Set by the agent');
      expect(stored.data.estimate, const Duration(minutes: 90));
    });

    test("records the call's change effects in the same version as the value, "
        'joined with the stored ones (ADR 0098)', () async {
      final task = await storedTask(effects: {'stored-set:0'});
      final withKey = task.copyWith(
        data: task.data.copyWith(
          appliedChangeEffects: {'stored-set:0', 'agent-set:1'},
        ),
      );

      await writeTitle(withKey, 'Feed the penguins twice');

      final stored = await reread(task.id);
      expect(stored.data.title, 'Feed the penguins twice');
      expect(stored.data.appliedChangeEffects, {'stored-set:0', 'agent-set:1'});
    });

    test('records no change effect when nothing was applied', () async {
      final task = await storedTask(effects: {'stored-set:0'});
      await persistence.updateTask(
        journalEntityId: task.id,
        change: (stored) => stored.copyWith(title: 'Set by the user'),
      );

      final write = await writeTitle(
        task.copyWith(
          data: task.data.copyWith(
            appliedChangeEffects: {'stored-set:0', 'agent-set:1'},
          ),
        ),
        'Set by the agent',
      );

      expect(write, isA<TaskFieldMoved>());
      expect((await reread(task.id)).data.appliedChangeEffects, {
        'stored-set:0',
      });
    });

    test('fails when the task does not exist', () async {
      final task = testTask.copyWith(
        meta: testTask.meta.copyWith(id: 'never-stored'),
      );

      final write = await writeTitle(task, 'anything');

      expect(write, isA<TaskFieldWriteFailed>());
      expect(await journalDb.journalEntityById('never-stored'), isNull);
    });
  });

  registerTaskFieldWritesConformance();
}
