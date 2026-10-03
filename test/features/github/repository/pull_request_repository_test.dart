import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/domain/pull_request_write_rule.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
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
    // Per test: the global teardown resets platform channel mocks, so a fake
    // set once for the file is gone by the time a bundled run reaches it.
    setFakeDocumentsPath();
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
      (await repository.link(
        taskId: taskId,
        ref: ref,
        snapshot: snapshot,
      )).linked!;

  /// Another task, stored like the first one.
  Future<String> anotherTask() async {
    final other = testTask.copyWith(
      meta: testTask.meta.copyWith(id: 'another-task'),
    );
    await getIt<PersistenceLogic>().createDbEntity(other);
    return other.meta.id;
  }

  Future<PullRequestEntry?> stored(String id) async =>
      await journalDb.journalEntityByIdIncludingDeleted(id)
          as PullRequestEntry?;

  group('track', () {
    Future<Task> storedTask() async =>
        (await journalDb.journalEntityById(taskId))! as Task;

    test(
      'turns tracking on, on the task as stored, and keeps it across a '
      'later write from a copy read before',
      () async {
        expect(testTask.data.tracksPullRequests, isFalse);
        final before = await storedTask();

        expect(await repository.track(taskId), isTrue);
        final after = await storedTask();
        expect(after.data.tracksPullRequests, isTrue);
        expect(after.data.title, before.data.title);

        // A screen that read the task before tracking was on saves a rename.
        await JournalRepository().updateJournalEntity(
          before.copyWith(data: before.data.copyWith(title: 'Renamed')),
        );
        final renamed = await storedTask();
        expect(renamed.data.title, 'Renamed');
        expect(renamed.data.tracksPullRequests, isTrue);
      },
    );

    test(
      'a direct write from a copy read before tracking was on — a date or '
      'label change — keeps it',
      () async {
        final before = await storedTask();
        await repository.track(taskId);

        final logic = getIt<PersistenceLogic>();
        await logic.updateDbEntity(
          before.copyWith(meta: await logic.updateMetadata(before.meta)),
        );

        expect((await storedTask()).data.tracksPullRequests, isTrue);
      },
    );

    test('a task that tracks already is not written again', () async {
      await repository.track(taskId);
      final clock = (await storedTask()).meta.vectorClock;

      expect(await repository.track(taskId), isTrue);
      expect((await storedTask()).meta.vectorClock, clock);
    });

    test('an entry that is not a task is not tracked', () async {
      final entry = await linked();
      expect(await repository.track(entry.id), isFalse);
      expect(await repository.track('missing'), isFalse);
    });
  });

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
        expect(await repository.holdersOf([ref]), {
          ref.key: {taskId},
        });
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
      expect(again.linked, isNull);
      expect(again.heldBy, {taskId});
      expect(await repository.forTask(taskId), hasLength(1));
    });

    test(
      'a pull request another task holds is linked to a second task only '
      'once the user confirmed it',
      () async {
        await linked();
        final other = await anotherTask();

        final unasked = await repository.link(taskId: other, ref: ref);
        expect(unasked.linked, isNull);
        expect(unasked.heldBy, {taskId});
        expect(await repository.forTask(other), isEmpty);

        final confirmed = await repository.link(
          taskId: other,
          ref: ref,
          alsoElsewhere: true,
        );
        expect(confirmed.linked, isNotNull);
        expect(await repository.forTask(other), hasLength(1));
        expect(await repository.holdersOf([ref]), {
          ref.key: {taskId, other},
        });
      },
    );

    test(
      'a confirmed link still refuses a pull request this task holds '
      '(RecheckAtConfirm)',
      () async {
        await linked();

        final again = await repository.link(
          taskId: taskId,
          ref: ref,
          alsoElsewhere: true,
        );

        expect(again.linked, isNull);
        expect(again.heldBy, {taskId});
        expect(await repository.forTask(taskId), hasLength(1));
      },
    );

    test(
      "unlinking from one task leaves another task's link to the same pull "
      'request',
      () async {
        await linked();
        final other = await anotherTask();
        await repository.link(taskId: other, ref: ref, alsoElsewhere: true);

        await repository.unlink(taskId: taskId, ref: ref);

        expect(await repository.forTask(taskId), isEmpty);
        expect(await repository.forTask(other), hasLength(1));
        expect(await repository.holdersOf([ref]), {
          ref.key: {other},
        });
      },
    );

    test(
      'two links started at once on this device, for two tasks, link once '
      '(AtomicLink)',
      () async {
        final other = await anotherTask();

        final attempts = await Future.wait([
          repository.link(taskId: taskId, ref: ref),
          repository.link(taskId: other, ref: ref),
        ]);

        expect(attempts.where((a) => a.linked != null), hasLength(1));
        expect(
          (await repository.holdersOf([ref]))[ref.key],
          hasLength(1),
        );
      },
    );

    test('a pull request unlinked from its task is free again', () async {
      await linked();
      await repository.unlink(taskId: taskId, ref: ref);
      final other = await anotherTask();

      expect(await repository.holdersOf([ref]), isEmpty);
      expect(
        (await repository.link(taskId: other, ref: ref)).linked,
        isNotNull,
      );
    });
  });

  test('holdersOf is empty for no pull requests, or none held', () async {
    expect(await repository.holdersOf(const []), isEmpty);
    expect(
      await repository.holdersOf(const [
        PullRequestRef(owner: 'o', repo: 'r', number: 1),
      ]),
      isEmpty,
    );
  });

  test(
    'forTask lists live pull requests newest first — by number while none '
    'has been read yet',
    () async {
      for (final number in [7, 3, 5]) {
        await repository.link(
          taskId: taskId,
          ref: PullRequestRef(owner: 'o', repo: 'r', number: number),
        );
      }
      final gone = (await repository.forTask(taskId)).first;
      await repository.unlink(taskId: taskId, ref: gone.data.ref);

      expect(gone.data.number, 7);
      expect(
        (await repository.forTask(taskId)).map((e) => e.data.number),
        [5, 3],
      );
      expect(await repository.forTask('another-task'), isEmpty);
    },
  );

  test(
    'a duplicate another device created before the two synced is shown '
    'once, the same one everywhere, and unlinking removes both',
    () async {
      final linkedHere = await linked(snapshot: prSnapshot());
      // What sync delivers from a device that linked the same pull request
      // before it saw this one: another entry, another id.
      final fromPeer = prEntry(clock: {'peer': 1}, id: 'aaaa-from-peer');
      await getIt<PersistenceLogic>().createDbEntity(
        fromPeer,
        linkedId: taskId,
        shouldAddGeolocation: false,
      );

      final shown = await repository.forTask(taskId);
      expect(shown.map((e) => e.id), [
        [
          linkedHere.id,
          fromPeer.id,
        ].reduce((a, b) => a.compareTo(b) < 0 ? a : b),
      ]);

      expect(await repository.unlink(taskId: taskId, ref: ref), isTrue);
      expect(await repository.forTask(taskId), isEmpty);
      expect((await stored(linkedHere.id))?.isDeleted, isTrue);
      expect((await stored(fromPeer.id))?.isDeleted, isTrue);
    },
  );

  test(
    'unlinking a pull request the task does not hold unlinks nothing',
    () async {
      await linked();
      expect(
        await repository.unlink(
          taskId: taskId,
          ref: const PullRequestRef(owner: 'o', repo: 'r', number: 1),
        ),
        isFalse,
      );
      expect(await repository.forTask(taskId), hasLength(1));
    },
  );

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
        expect(await repository.unlink(taskId: taskId, ref: ref), isTrue);

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

  group('summaries', () {
    AiResponseData summary(String input, {String text = 'Did the thing.'}) =>
        AiResponseData(
          model: 'model',
          systemMessage: 'system',
          prompt: input,
          thoughts: '',
          response: text,
          type: AiResponseType.pullRequestSummary,
          oneLiner: 'One line.',
          tldr: text,
        );

    test(
      'a summary is an AI response linked from the pull request entry, in '
      'its category, sent to the other devices, and read back for the '
      'content it was written from',
      () async {
        final entry = await linked(snapshot: prSnapshot());

        expect(
          await repository.addSummary(
            entry,
            summary('input'),
            start: prFixtureEpoch,
          ),
          isTrue,
        );

        final responses = (await journalDb.getLinkedEntities(
          entry.id,
        )).whereType<AiResponseEntry>().toList();
        expect(responses, hasLength(1));
        expect(responses.single.meta.categoryId, testTask.meta.categoryId);
        final sent = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured.whereType<SyncJournalEntity>().map((m) => m.id);
        expect(sent, contains(responses.single.meta.id));
        expect(
          await repository.summaryOf(entry.id, 'input'),
          const PullRequestSummary(
            oneLiner: 'One line.',
            tldr: 'Did the thing.',
          ),
        );
        expect(await repository.summaryOf(entry.id, 'other input'), isNull);
      },
    );

    test(
      'storing a summary notifies the pull request entry, never the task, '
      'so it cannot wake the task agent',
      () async {
        final entry = await linked(snapshot: prSnapshot());
        clearInteractions(mockUpdateNotifications);

        await repository.addSummary(
          entry,
          summary('input'),
          start: prFixtureEpoch,
        );

        final notified = verify(
          () => mockUpdateNotifications.notify(captureAny()),
        ).captured.cast<Set<String>>().expand((ids) => ids).toSet();
        expect(notified, contains(entry.id));
        expect(notified, isNot(contains(taskId)));
      },
    );

    test(
      'only a non-blank pull request summary counts, and the newest of two '
      'wins',
      () async {
        final entry = await linked(snapshot: prSnapshot());
        await repository.addSummary(
          entry,
          summary('input').copyWith(type: AiResponseType.audioSummary),
          start: prFixtureEpoch,
        );
        await repository.addSummary(
          entry,
          summary('input', text: '  '),
          start: prFixtureEpoch.add(const Duration(minutes: 3)),
        );
        expect(await repository.summaryOf(entry.id, 'input'), isNull);

        await repository.addSummary(
          entry,
          summary('input', text: 'Older.'),
          start: prFixtureEpoch,
        );
        await repository.addSummary(
          entry,
          summary('input', text: 'Newer.'),
          start: prFixtureEpoch.add(const Duration(minutes: 1)),
        );
        expect(
          (await repository.summaryOf(entry.id, 'input'))?.tldr,
          'Newer.',
        );
      },
    );

    test(
      'a summary without a TL;DR is read from its response, and a blank '
      'one-liner as none',
      () async {
        final entry = await linked(snapshot: prSnapshot());
        await repository.addSummary(
          entry,
          summary('input').copyWith(
            tldr: null,
            oneLiner: ' ',
            response: 'From the body.',
          ),
          start: prFixtureEpoch,
        );
        expect(
          await repository.summaryOf(entry.id, 'input'),
          const PullRequestSummary(oneLiner: null, tldr: 'From the body.'),
        );
      },
    );
  });
}
