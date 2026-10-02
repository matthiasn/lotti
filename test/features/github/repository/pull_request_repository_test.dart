import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/domain/pull_request_write_rule.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
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

import '../../../helpers/fallbacks.dart';
import '../../../helpers/path_provider.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../pull_request_fixtures.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  setFakeDocumentsPath();

  final mockNotificationService = MockNotificationService();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockFts5Db = MockFts5Db();
  final mockOutboxService = MockOutboxService();
  final mockTimeService = MockTimeService();

  late JournalDb journalDb;
  late SettingsDb settingsDb;
  late PullRequestRepository repository;

  const ref = PullRequestRef(owner: 'matthiasn', repo: 'lotti', number: 42);
  final taskId = testTask.meta.id;

  setUp(() async {
    settingsDb = SettingsDb(inMemoryDatabase: true);
    journalDb = JournalDb(inMemoryDatabase: true);
    await initConfigFlags(journalDb, inMemoryDatabase: true);

    when(mockNotificationService.updateBadge).thenAnswer((_) async {});
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(
      () => mockFts5Db.insertText(any(), removePrevious: true),
    ).thenAnswer((_) async {});
    when(
      () => mockOutboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});

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
            MetadataService(vectorClockService: getIt<VectorClockService>()),
          )
          ..registerSingleton<GeolocationService>(MockGeolocationService())
          ..registerSingleton<TimeService>(mockTimeService)
          ..registerSingleton<NavService>(MockNavService())
          ..registerSingleton<EntitiesCacheService>(MockEntitiesCacheService())
          ..registerSingleton<PersistenceLogic>(PersistenceLogic());
      },
    );

    repository = PullRequestRepository(
      journalDb: journalDb,
      persistenceLogic: getIt<PersistenceLogic>(),
      journalRepository: JournalRepository(),
    );
    await getIt<PersistenceLogic>().createDbEntity(testTask);
  });

  tearDown(() async {
    await tearDownTestGetIt();
    await journalDb.close();
    await settingsDb.close();
  });

  Future<PullRequestEntry> linked({PullRequestSnapshot? snapshot}) async =>
      (await repository.link(taskId: taskId, ref: ref, snapshot: snapshot))!;

  Future<PullRequestEntry?> stored(String id) async =>
      await journalDb.journalEntityByIdIncludingDeleted(id)
          as PullRequestEntry?;

  group('link', () {
    test(
      'creates a pull request entry linked from the task, with its first '
      'observation, and inherits the task category, never a location',
      () async {
        final entry = await linked(snapshot: prSnapshot());

        final tasks = await repository.forTask(taskId);
        expect(tasks.map((e) => e.id), [entry.id]);
        final row = await stored(entry.id);
        expect(row?.data.ref, ref);
        expect(row?.data.snapshot, prSnapshot());
        expect(row?.meta.categoryId, testTask.meta.categoryId);
        expect(row?.geolocation, isNull);
        expect(await repository.isLinked(taskId: taskId, ref: ref), isTrue);
      },
    );

    test('the same pull request is linked once, whatever case it was '
        'pasted in', () async {
      await linked();
      final again = await repository.link(
        taskId: taskId,
        ref: const PullRequestRef(
          owner: 'MatthiasN',
          repo: 'LOTTI',
          number: 42,
        ),
      );
      expect(again, isNull);
      expect(await repository.forTask(taskId), hasLength(1));
    });
  });

  test('forTask lists live pull requests by number', () async {
    for (final number in [7, 3, 5]) {
      await repository.link(
        taskId: taskId,
        ref: PullRequestRef(owner: 'o', repo: 'r', number: number),
      );
    }
    final gone = (await repository.forTask(taskId)).first;
    await repository.unlink(gone.id);

    expect(
      (await repository.forTask(taskId)).map((e) => e.data.number),
      [5, 7],
    );
    expect(await repository.forTask('another-task'), isEmpty);
  });

  group('persistObservation', () {
    test('writes a newer, changed observation under a new clock', () async {
      final entry = await linked(snapshot: prSnapshot());
      final before = (await stored(entry.id))!.meta.vectorClock;
      final newer = prSnapshot(second: 5, status: PullRequestStatus.merged);

      expect(await repository.persistObservation(entry.id, newer), isTrue);

      final row = await stored(entry.id);
      expect(row?.data.snapshot, newer);
      expect(row?.meta.vectorClock, isNot(before));
    });

    test('skips an older observation, and an unchanged one that is still '
        'recent', () async {
      final entry = await linked(snapshot: prSnapshot(second: 10));

      expect(
        await repository.persistObservation(entry.id, prSnapshot(second: 5)),
        isFalse,
      );
      expect(
        await repository.persistObservation(entry.id, prSnapshot(second: 20)),
        isFalse,
      );
      expect((await stored(entry.id))?.data.snapshot, prSnapshot(second: 10));

      final restamp = prSnapshot(
        second: 10 + pullRequestRestampAfter.inSeconds,
      );
      expect(await repository.persistObservation(entry.id, restamp), isTrue);
      expect((await stored(entry.id))?.data.snapshot, restamp);
    });

    test(
      'never writes over an unlink that happened while the refresh was in '
      'flight',
      () async {
        final entry = await linked(snapshot: prSnapshot());
        expect(await repository.unlink(entry.id), isTrue);

        expect(
          await repository.persistObservation(
            entry.id,
            prSnapshot(second: 5, title: 'Changed'),
          ),
          isFalse,
        );
        final row = await stored(entry.id);
        expect(row?.isDeleted, isTrue);
        expect(row?.data.snapshot, prSnapshot());
      },
    );

    test('an unknown entry is not written', () async {
      expect(
        await repository.persistObservation('missing', prSnapshot()),
        isFalse,
      );
    });
  });
}
