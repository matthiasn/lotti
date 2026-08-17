// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(const VectorClock(<String, int>{}));
  });

  late NotificationsDb notificationsDb;
  late MockVectorClockService vectorClockService;
  late MockOutboxService outboxService;
  late MockUpdateNotifications updateNotifications;
  late MockNotificationScheduler scheduler;
  late NotificationRepository repository;

  final fixedNow = DateTime.utc(2026, 5, 17, 10);

  setUp(() {
    notificationsDb = NotificationsDb(
      inMemoryDatabase: true,
      background: false,
    );
    vectorClockService = MockVectorClockService();
    outboxService = MockOutboxService();
    updateNotifications = MockUpdateNotifications();
    scheduler = MockNotificationScheduler();

    when(() => vectorClockService.getHost()).thenAnswer((_) async => 'host-a');
    when(
      () => vectorClockService.getNextVectorClock(
        previous: any(named: 'previous'),
      ),
    ).thenAnswer((_) async => const VectorClock({'host-a': 1}));
    when(
      () => outboxService.enqueueNotification(
        any<NotificationEntity>(),
        originatingHostId: any(named: 'originatingHostId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => outboxService.enqueueNotificationStateUpdate(
        id: any(named: 'id'),
        seenAt: any(named: 'seenAt'),
        actedOnAt: any(named: 'actedOnAt'),
        deletedAt: any(named: 'deletedAt'),
        vectorClock: any(named: 'vectorClock'),
        originatingHostId: any(named: 'originatingHostId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => scheduler.schedule(
        any<NotificationEntity>(),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async {});

    repository = NotificationRepository(
      notificationsDb: notificationsDb,
      vectorClockService: vectorClockService,
      outboxService: outboxService,
      updateNotifications: updateNotifications,
      scheduler: scheduler,
      now: () => fixedNow,
    );
  });

  tearDown(() async {
    await notificationsDb.close();
  });

  group('NotificationRepository.create', () {
    test(
      'createTaskSuggestion uses linkedTaskId-derived id by default',
      () async {
        final saved = await repository.createTaskSuggestion(
          linkedTaskId: 'task-default',
          suggestionCount: 1,
          title: 'Look',
          body: 'b',
        );

        expect(
          saved!.meta.id,
          repository.notificationIdForTaskSuggestion('task-default'),
        );
      },
    );

    test(
      'createTaskSuggestion seeds fresh waves by change-set id while '
      'retiring older open rows for the same task',
      () async {
        final first = await repository.createTaskSuggestion(
          linkedTaskId: 'task-X',
          suggestionCount: 1,
          title: 'First wave',
          body: 'b',
          idSeed: 'change-set-1',
        );
        final second = await repository.createTaskSuggestion(
          linkedTaskId: 'task-X',
          suggestionCount: 1,
          title: 'Second wave',
          body: 'b',
          idSeed: 'change-set-2',
        );

        // Different seeds → different inbox rows.
        expect(first!.meta.id, isNot(second!.meta.id));
        // The seeded id matches the same derivation the producer would use
        // if it called the helper directly.
        expect(
          first.meta.id,
          repository.notificationIdForTaskSuggestion('change-set-1'),
        );
        expect(
          second.meta.id,
          repository.notificationIdForTaskSuggestion('change-set-2'),
        );
        // Both rows still deep-link to the underlying task.
        expect(first.linkedEntityId, 'task-X');
        expect(second.linkedEntityId, 'task-X');
        expect(
          (await notificationsDb.notificationById(first.id))?.meta.deletedAt,
          fixedNow,
        );
        expect(
          (await notificationsDb.dueNow(fixedNow)).map((row) => row.id),
          [second.id],
        );
      },
    );

    test(
      'createTaskSuggestion retires seen-but-unacted rows for the same task',
      () async {
        final first = await repository.createTaskSuggestion(
          linkedTaskId: 'task-seen-open',
          suggestionCount: 1,
          title: 'First wave',
          body: 'b',
          idSeed: 'seen-change-set-1',
        );
        await repository.markSeen(first!.id);

        final second = await repository.createTaskSuggestion(
          linkedTaskId: 'task-seen-open',
          suggestionCount: 2,
          title: 'Second wave',
          body: 'b',
          idSeed: 'seen-change-set-2',
        );

        expect(
          (await notificationsDb.notificationById(first.id))?.meta.seenAt,
          fixedNow,
        );
        expect(
          (await notificationsDb.notificationById(first.id))?.meta.deletedAt,
          fixedNow,
        );
        expect(
          (await notificationsDb.notificationById(second!.id))?.meta.deletedAt,
          isNull,
        );
      },
    );

    test(
      'createTaskSuggestion keeps the old row when replacement host is missing',
      () async {
        final first = await repository.createTaskSuggestion(
          linkedTaskId: 'task-host-missing',
          suggestionCount: 1,
          title: 'First wave',
          body: 'b',
          idSeed: 'host-change-set-1',
        );
        when(() => vectorClockService.getHost()).thenAnswer((_) async => null);
        clearInteractions(updateNotifications);
        clearInteractions(outboxService);
        clearInteractions(scheduler);

        final replacement = await repository.createTaskSuggestion(
          linkedTaskId: 'task-host-missing',
          suggestionCount: 2,
          title: 'Second wave',
          body: 'b',
          idSeed: 'host-change-set-2',
        );

        expect(replacement, isNull);
        expect(
          (await notificationsDb.notificationById(first!.id))?.meta.deletedAt,
          isNull,
        );
        expect(
          await notificationsDb.notificationById(
            repository.notificationIdForTaskSuggestion('host-change-set-2'),
          ),
          isNull,
        );
        verifyNever(
          () => outboxService.enqueueNotification(any<NotificationEntity>()),
        );
        verifyNever(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        );
      },
    );

    test(
      'createTaskSuggestion keeps old rows when replacement upsert is no-op',
      () async {
        final old = _entityForCreate(
          id: 'old-open-noop',
          linkedTaskId: 'task-noop-replacement',
          createdAt: fixedNow,
          updatedAt: fixedNow,
          scheduledFor: fixedNow,
          vectorClock: const VectorClock({'host-a': 1}),
          originatingHostId: 'host-a',
        );
        final replacement = _entityForCreate(
          id: 'replacement-noop',
          linkedTaskId: 'task-noop-replacement',
          createdAt: fixedNow,
          updatedAt: fixedNow,
          scheduledFor: fixedNow,
          vectorClock: const VectorClock({'host-a': 1}),
          originatingHostId: 'host-a',
        );
        await notificationsDb.upsertNotification(old);
        await notificationsDb.upsertNotification(replacement);
        clearInteractions(updateNotifications);
        clearInteractions(outboxService);
        clearInteractions(scheduler);

        final result = await repository.create(replacement);

        expect(result, isNull);
        expect(
          (await notificationsDb.notificationById(old.id))?.meta.deletedAt,
          isNull,
        );
        verifyNever(
          () => outboxService.enqueueNotification(any<NotificationEntity>()),
        );
        verifyNever(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        );
      },
    );

    test(
      'serializes concurrent task-suggestion creates for the same task',
      () async {
        final saved = await Future.wait([
          for (var i = 0; i < 5; i++)
            repository.createTaskSuggestion(
              linkedTaskId: 'task-concurrent',
              suggestionCount: i + 1,
              title: 'Wave $i',
              body: 'Concurrent task',
              idSeed: 'concurrent-change-set-$i',
            ),
        ]);

        final openRows = await notificationsDb.dueNow(fixedNow);
        final openSuggestions = openRows
            .whereType<TaskSuggestionNotification>()
            .where((row) => row.linkedTaskId == 'task-concurrent')
            .toList();

        expect(openSuggestions, hasLength(1));
        expect(openSuggestions.single.id, saved.last!.id);

        final allRows = await notificationsDb.forLinkedEntity(
          'task-concurrent',
        );
        expect(
          allRows.where(
            (row) =>
                row.meta.seenAt == null &&
                row.meta.actedOnAt == null &&
                row.meta.deletedAt == null,
          ),
          hasLength(1),
        );
      },
    );

    test(
      'createTaskSuggestion enriches meta, persists, enqueues and notifies',
      () async {
        final saved = await repository.createTaskSuggestion(
          linkedTaskId: 'task-1',
          suggestionCount: 3,
          title: 'Review suggestions',
          body: 'Three tasks need review',
          category: 'work',
        );

        expect(saved, isA<TaskSuggestionNotification>());
        final entity = saved! as TaskSuggestionNotification;
        expect(entity.linkedTaskId, 'task-1');
        expect(entity.suggestionCount, 3);
        expect(entity.title, 'Review suggestions');
        expect(entity.body, 'Three tasks need review');
        expect(entity.meta.id, isNotEmpty);
        expect(entity.meta.originatingHostId, 'host-a');
        expect(entity.meta.updatedAt, fixedNow);
        expect(entity.meta.scheduledFor, fixedNow);
        expect(entity.meta.vectorClock, const VectorClock({'host-a': 1}));
        expect(entity.meta.category, 'work');

        expect(
          await notificationsDb.notificationById(entity.meta.id),
          entity,
        );

        verify(
          () => vectorClockService.getNextVectorClock(previous: null),
        ).called(1);
        verify(() => outboxService.enqueueNotification(entity)).called(1);
        verify(() => scheduler.schedule(entity, now: fixedNow)).called(1);
        verify(
          () => updateNotifications.notify(
            {entity.meta.id, 'task-1', inboxNotification},
            fromSync: false,
          ),
        ).called(1);
      },
    );

    test('returns null when vector clock service has no host yet', () async {
      when(() => vectorClockService.getHost()).thenAnswer((_) async => null);

      final saved = await repository.createTaskSuggestion(
        linkedTaskId: 'task-no-host',
        suggestionCount: 1,
        title: 't',
        body: 'b',
      );

      expect(saved, isNull);
      expect(
        await notificationsDb.notificationById(
          repository.notificationIdForTaskSuggestion('task-no-host'),
        ),
        isNull,
      );
      verifyNever(
        () => outboxService.enqueueNotification(any<NotificationEntity>()),
      );
    });

    test(
      'create skips side effects when upsert is a no-op merge',
      () async {
        // Seed an identical row so the merge in upsertNotification returns
        // null (no change).
        final placeholder = _entityForCreate(
          id: 'existing-no-op',
          linkedTaskId: 'task-noop',
          createdAt: fixedNow,
          updatedAt: fixedNow,
          scheduledFor: fixedNow,
          vectorClock: const VectorClock({'host-a': 1}),
          originatingHostId: 'host-a',
        );
        await notificationsDb.upsertNotification(placeholder);
        clearInteractions(updateNotifications);
        clearInteractions(outboxService);
        clearInteractions(scheduler);

        final result = await repository.create(placeholder);

        expect(result, isNull);
        verifyNever(
          () => outboxService.enqueueNotification(any<NotificationEntity>()),
        );
        verifyNever(
          () => scheduler.schedule(
            any<NotificationEntity>(),
            now: any(named: 'now'),
          ),
        );
        verifyNever(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        );
      },
    );

    test(
      'create forwards an existing non-empty vector clock as previous',
      () async {
        final placeholder = _entityForCreate(
          id: 'with-prior-clock',
          linkedTaskId: 'task-prior',
          createdAt: fixedNow,
          updatedAt: fixedNow,
          scheduledFor: fixedNow,
          vectorClock: const VectorClock({'host-a': 5}),
          originatingHostId: '',
        );

        await repository.create(placeholder);

        verify(
          () => vectorClockService.getNextVectorClock(
            previous: const VectorClock({'host-a': 5}),
          ),
        ).called(1);
      },
    );
  });

  group('NotificationRepository state changes', () {
    Future<NotificationEntity> seed({
      DateTime? seenAt,
      DateTime? actedOnAt,
      DateTime? deletedAt,
    }) async {
      final base = _entityForCreate(
        id: 'state-test',
        linkedTaskId: 'task-state',
        createdAt: fixedNow.subtract(const Duration(hours: 2)),
        updatedAt: fixedNow.subtract(const Duration(hours: 1)),
        scheduledFor: fixedNow,
        vectorClock: const VectorClock({'host-a': 1}),
        originatingHostId: 'host-a',
        seenAt: seenAt,
        actedOnAt: actedOnAt,
        deletedAt: deletedAt,
      );
      await notificationsDb.upsertNotification(base);
      clearInteractions(updateNotifications);
      clearInteractions(outboxService);
      clearInteractions(scheduler);
      return base;
    }

    test(
      'markSeen merges state, enqueues update and notifies UI only',
      () async {
        await seed();
        when(
          () => vectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
          ),
        ).thenAnswer((_) async => const VectorClock({'host-a': 2}));

        final updated = await repository.markSeen('state-test');

        expect(updated, isNotNull);
        expect(updated!.meta.seenAt, fixedNow);
        expect(updated.meta.vectorClock, const VectorClock({'host-a': 2}));

        verify(
          () => outboxService.enqueueNotificationStateUpdate(
            id: 'state-test',
            seenAt: fixedNow,
            actedOnAt: null,
            deletedAt: null,
            vectorClock: const VectorClock({'host-a': 2}),
            originatingHostId: 'host-a',
          ),
        ).called(1);
        verify(() => scheduler.schedule(updated)).called(1);
        verify(
          () => updateNotifications.notifyUiOnly(
            {'state-test', 'task-state', inboxNotification},
          ),
        ).called(1);
        verifyNever(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        );
      },
    );

    test('retract forwards deletedAt only', () async {
      await seed();
      await repository.retract('state-test');

      verify(
        () => outboxService.enqueueNotificationStateUpdate(
          id: 'state-test',
          seenAt: null,
          actedOnAt: null,
          deletedAt: fixedNow,
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: 'host-a',
        ),
      ).called(1);
    });

    test(
      'markTaskSuggestionsActedOn marks every open suggestion row for a task',
      () async {
        await notificationsDb.upsertNotification(
          _entityForCreate(
            id: 'task-row-1',
            linkedTaskId: 'task-shared',
            createdAt: fixedNow,
            updatedAt: fixedNow,
            scheduledFor: fixedNow,
            vectorClock: const VectorClock({'host-a': 1}),
            originatingHostId: 'host-a',
            seenAt: fixedNow.subtract(const Duration(minutes: 5)),
          ),
        );
        await notificationsDb.upsertNotification(
          _entityForCreate(
            id: 'task-row-2',
            linkedTaskId: 'task-shared',
            createdAt: fixedNow,
            updatedAt: fixedNow,
            scheduledFor: fixedNow,
            vectorClock: const VectorClock({'host-a': 1}),
            originatingHostId: 'host-a',
          ),
        );
        clearInteractions(updateNotifications);

        final updated = await repository.markTaskSuggestionsActedOn(
          'task-shared',
        );

        expect(updated, hasLength(2));
        expect(
          (await notificationsDb.notificationById(
            'task-row-1',
          ))?.meta.actedOnAt,
          fixedNow,
        );
        expect(
          (await notificationsDb.notificationById(
            'task-row-2',
          ))?.meta.actedOnAt,
          fixedNow,
        );
        verify(
          () => updateNotifications.notifyUiOnly(
            any(
              that: containsAll(
                {'task-shared', inboxNotification},
              ),
            ),
          ),
        ).called(2);
        verifyNever(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any(named: 'fromSync'),
          ),
        );
      },
    );

    test(
      'retractTaskSuggestionsForTask skips already terminal rows',
      () async {
        await notificationsDb.upsertNotification(
          _entityForCreate(
            id: 'open-row',
            linkedTaskId: 'task-shared',
            createdAt: fixedNow,
            updatedAt: fixedNow,
            scheduledFor: fixedNow,
            vectorClock: const VectorClock({'host-a': 1}),
            originatingHostId: 'host-a',
          ),
        );
        await notificationsDb.upsertNotification(
          _entityForCreate(
            id: 'acted-row',
            linkedTaskId: 'task-shared',
            createdAt: fixedNow,
            updatedAt: fixedNow,
            scheduledFor: fixedNow,
            vectorClock: const VectorClock({'host-a': 1}),
            originatingHostId: 'host-a',
            actedOnAt: fixedNow.subtract(const Duration(minutes: 5)),
          ),
        );

        final updated = await repository.retractTaskSuggestionsForTask(
          'task-shared',
        );

        expect(updated.map((row) => row.id), ['open-row']);
        expect(
          (await notificationsDb.notificationById('open-row'))?.meta.deletedAt,
          fixedNow,
        );
        expect(
          (await notificationsDb.notificationById('acted-row'))?.meta.deletedAt,
          isNull,
        );
      },
    );

    test('state mutation returns null when notification is missing', () async {
      final result = await repository.markSeen('does-not-exist');

      expect(result, isNull);
      verifyNever(() => vectorClockService.getHost());
      verifyNever(
        () => outboxService.enqueueNotificationStateUpdate(
          id: any(named: 'id'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      );
    });

    test(
      'state mutation is idempotent when the field is already populated',
      () async {
        await seed(seenAt: fixedNow.subtract(const Duration(minutes: 5)));

        final result = await repository.markSeen('state-test');

        expect(result, isNull);
        verifyNever(() => vectorClockService.getHost());
        verifyNever(
          () => outboxService.enqueueNotificationStateUpdate(
            id: any(named: 'id'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          ),
        );
      },
    );

    test('state mutation returns null when host is unavailable', () async {
      await seed();
      when(() => vectorClockService.getHost()).thenAnswer((_) async => null);

      final result = await repository.markSeen('state-test');

      expect(result, isNull);
      verifyNever(
        () => outboxService.enqueueNotificationStateUpdate(
          id: any(named: 'id'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      );
    });
  });

  // Every write here runs inside `withVcScope(..., commitWhen: ...)`, and the
  // predicate is what stops a failed write from burning a vector-clock tick.
  // The shared mock documents that it runs the action and *ignores* the
  // predicate, so a local subclass is needed to see it at all.
  group('NotificationRepository vector-clock commit rule', () {
    late _CommitEvaluatingVectorClockService commitClock;
    late NotificationRepository commitRepository;

    setUp(() {
      commitClock = _CommitEvaluatingVectorClockService();
      when(() => commitClock.getHost()).thenAnswer((_) async => 'host-a');
      when(
        () => commitClock.getNextVectorClock(previous: any(named: 'previous')),
      ).thenAnswer((_) async => const VectorClock({'host-a': 1}));
      commitRepository = NotificationRepository(
        notificationsDb: notificationsDb,
        vectorClockService: commitClock,
        outboxService: outboxService,
        updateNotifications: updateNotifications,
        scheduler: scheduler,
        now: () => fixedNow,
      );
    });

    test('a create that produced a row commits the scope', () async {
      await commitRepository.createRelationshipCheckIn(
        linkedRelationshipId: 'rel-1',
        dueDayKey: '2026-06-16',
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
        scheduledFor: DateTime.utc(2026, 6, 16, 9),
      );

      expect(commitClock.commits, [true]);
    });

    test('a create with no host yet does not commit', () async {
      // No host means no vector clock can be attributed, so the row is not
      // written — and the scope must not commit, or the tick is spent on a
      // write that never happened.
      when(() => commitClock.getHost()).thenAnswer((_) async => null);

      final saved = await commitRepository.createRelationshipCheckIn(
        linkedRelationshipId: 'rel-1',
        dueDayKey: '2026-06-16',
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
        scheduledFor: DateTime.utc(2026, 6, 16, 9),
      );

      expect(saved, isNull);
      expect(commitClock.commits, [false]);
    });

    test('a state transition that changed something commits', () async {
      final saved = await commitRepository.createRelationshipCheckIn(
        linkedRelationshipId: 'rel-1',
        dueDayKey: '2026-06-16',
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
        scheduledFor: DateTime.utc(2026, 6, 16, 9),
      );
      commitClock.commits.clear();

      await commitRepository.retract(saved!.id);

      expect(commitClock.commits, [true]);
    });

    test('a state transition with no host does not commit', () async {
      final saved = await commitRepository.createRelationshipCheckIn(
        linkedRelationshipId: 'rel-1',
        dueDayKey: '2026-06-16',
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
        scheduledFor: DateTime.utc(2026, 6, 16, 9),
      );
      commitClock.commits.clear();
      when(() => commitClock.getHost()).thenAnswer((_) async => null);

      final result = await commitRepository.markSeen(saved!.id);

      expect(result, isNull);
      expect(commitClock.commits, [false]);
    });
  });

  group('NotificationRepository notification IDs', () {
    test(
      'notification id helpers are deterministic and version 5 UUIDs',
      () {
        expect(
          repository.notificationIdForTaskSuggestion('task-1'),
          repository.notificationIdForTaskSuggestion('task-1'),
        );
        expect(
          repository.notificationIdForTaskSuggestion('task-1'),
          '78bbe9c1-bf78-5350-a95e-dfa887718e20',
        );
        expect(
          repository.notificationIdForTaskSuggestion('task-1'),
          isNot(repository.notificationIdForTaskSuggestion('task-2')),
        );
        // UUID v5 in 8-4-4-4-12 form, version nibble = 5.
        final id = repository.notificationIdForTaskSuggestion('task-1');
        expect(
          id,
          matches(
            RegExp(
              '^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-'
              r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
      },
    );

    test(
      'check-in ids are episode-scoped, not relationship-scoped',
      () {
        // Two episodes of the same person must be two rows: the lifecycle
        // marks are monotonic, so reusing one row would mean a dismissal in
        // August permanently silences September.
        final august = repository.notificationIdForRelationshipCheckIn(
          linkedRelationshipId: 'rel-1',
          dueDayKey: '2026-08-17',
        );
        final september = repository.notificationIdForRelationshipCheckIn(
          linkedRelationshipId: 'rel-1',
          dueDayKey: '2026-09-16',
        );
        final otherPerson = repository.notificationIdForRelationshipCheckIn(
          linkedRelationshipId: 'rel-2',
          dueDayKey: '2026-08-17',
        );

        expect(august, isNot(september));
        expect(august, isNot(otherPerson));
        // Deterministic across devices — two phones deriving the same episode
        // converge on one row instead of double-nudging.
        expect(
          august,
          repository.notificationIdForRelationshipCheckIn(
            linkedRelationshipId: 'rel-1',
            dueDayKey: '2026-08-17',
          ),
        );
        expect(
          august,
          matches(
            RegExp(
              '^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-'
              r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        // Distinct namespace from the task-suggestion helper, so a
        // relationship id can never collide with a task id.
        expect(
          august,
          isNot(repository.notificationIdForTaskSuggestion('rel-1')),
        );
      },
    );
  });

  group('NotificationRepository.createRelationshipCheckIn', () {
    final dueDay = DateTime.utc(2026, 6, 16, 9);

    Future<NotificationEntity?> arm({
      String relationshipId = 'rel-1',
      String dueDayKey = '2026-06-16',
      String title = 'Check in with Anna?',
      DateTime? scheduledFor,
    }) => repository.createRelationshipCheckIn(
      linkedRelationshipId: relationshipId,
      dueDayKey: dueDayKey,
      title: title,
      body: 'A good moment to reach out.',
      scheduledFor: scheduledFor ?? dueDay,
      category: 'cat-1',
    );

    test('writes a schedulable row carrying the person and category', () async {
      final saved = await arm();

      expect(saved, isA<RelationshipCheckInNotification>());
      expect(
        saved!.meta.id,
        repository.notificationIdForRelationshipCheckIn(
          linkedRelationshipId: 'rel-1',
          dueDayKey: '2026-06-16',
        ),
      );
      expect(saved.linkedEntityId, 'rel-1');
      expect(saved.meta.scheduledFor, dueDay);
      expect(saved.meta.category, 'cat-1');
      expect(saved.type, 'relationshipCheckIn');
      // Handed straight to the scheduler, which is what puts the alarm on the
      // OS clock while the app is still open.
      verify(() => scheduler.schedule(saved, now: fixedNow)).called(1);
    });

    test('a second arm for the same episode writes nothing', () async {
      await arm();
      clearInteractions(scheduler);
      clearInteractions(outboxService);

      final again = await arm();

      // The producer re-derives this on every daily tick and every check-in
      // write. Upserting would bump updatedAt, enqueue an outbox message and
      // re-notify listeners every single tick — the €0 no-op property of the
      // deterministic tier depends on this returning early.
      expect(again, isNull);
      verifyNever(
        () => scheduler.schedule(
          any<NotificationEntity>(),
          now: any(named: 'now'),
        ),
      );
      verifyNever(
        () => outboxService.enqueueNotification(
          any<NotificationEntity>(),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      );
    });

    test('never resurrects an episode the user dismissed', () async {
      final saved = await arm();
      await repository.retract(saved!.id);
      clearInteractions(scheduler);

      final again = await arm();

      expect(again, isNull);
      final stored = await notificationsDb.notificationById(saved.id);
      expect(stored!.meta.deletedAt, isNotNull);
      verifyNever(
        () => scheduler.schedule(
          any<NotificationEntity>(),
          now: any(named: 'now'),
        ),
      );
    });

    test('a new episode is armed even while the old one is open', () async {
      // A check-in logged mid-cadence moves the due day; the new episode must
      // arm regardless of what happened to the previous one.
      await arm();
      final next = await arm(dueDayKey: '2026-07-16');

      expect(next, isNotNull);
      expect(next!.meta.id, isNot((await arm())?.id));
    });
  });

  group('NotificationRepository.retractRelationshipCheckIns', () {
    Future<NotificationEntity> armEpisode(String dueDayKey) async {
      final saved = await repository.createRelationshipCheckIn(
        linkedRelationshipId: 'rel-1',
        dueDayKey: dueDayKey,
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
        scheduledFor: DateTime.utc(2026, 6, 16, 9),
      );
      return saved!;
    }

    test('retracts every open episode when nothing is spared', () async {
      final first = await armEpisode('2026-06-16');
      final second = await armEpisode('2026-07-16');

      final retracted = await repository.retractRelationshipCheckIns('rel-1');

      expect(
        retracted.map((row) => row.id).toSet(),
        {first.id, second.id},
      );
      for (final id in [first.id, second.id]) {
        expect(
          (await notificationsDb.notificationById(id))!.meta.deletedAt,
          isNotNull,
        );
      }
    });

    test('spares the episode currently armed', () async {
      final superseded = await armEpisode('2026-06-16');
      final current = await armEpisode('2026-07-16');

      final retracted = await repository.retractRelationshipCheckIns(
        'rel-1',
        exceptId: current.id,
      );

      expect(retracted.map((row) => row.id), [superseded.id]);
      expect(
        (await notificationsDb.notificationById(current.id))!.meta.deletedAt,
        isNull,
      );
    });

    test("leaves another person's reminders alone", () async {
      final mine = await armEpisode('2026-06-16');
      final theirs = await repository.createRelationshipCheckIn(
        linkedRelationshipId: 'rel-2',
        dueDayKey: '2026-06-16',
        title: 'Check in with Ben?',
        body: 'A good moment to reach out.',
        scheduledFor: DateTime.utc(2026, 6, 16, 9),
      );

      final retracted = await repository.retractRelationshipCheckIns('rel-1');

      expect(retracted.map((row) => row.id), [mine.id]);
      expect(
        (await notificationsDb.notificationById(theirs!.id))!.meta.deletedAt,
        isNull,
      );
    });

    test('is idempotent — a second pass writes nothing', () async {
      await armEpisode('2026-06-16');
      await repository.retractRelationshipCheckIns('rel-1');
      clearInteractions(outboxService);

      final second = await repository.retractRelationshipCheckIns('rel-1');

      expect(second, isEmpty);
      verifyNever(
        () => outboxService.enqueueNotificationStateUpdate(
          id: any(named: 'id'),
          seenAt: any(named: 'seenAt'),
          actedOnAt: any(named: 'actedOnAt'),
          deletedAt: any(named: 'deletedAt'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      );
    });

    test('ignores task rows linked to the same id', () async {
      // `forLinkedEntity` is not variant-scoped, so the filter has to be.
      await repository.createTaskSuggestion(
        linkedTaskId: 'rel-1',
        suggestionCount: 1,
        title: 'Suggestion',
        body: 'b',
      );
      final reminder = await armEpisode('2026-06-16');

      final retracted = await repository.retractRelationshipCheckIns('rel-1');

      expect(retracted.map((row) => row.id), [reminder.id]);
    });
  });
}

NotificationEntity _entityForCreate({
  required String id,
  required String linkedTaskId,
  required DateTime createdAt,
  required DateTime updatedAt,
  required DateTime scheduledFor,
  required VectorClock vectorClock,
  required String originatingHostId,
  DateTime? seenAt,
  DateTime? actedOnAt,
  DateTime? deletedAt,
}) {
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      scheduledFor: scheduledFor,
      seenAt: seenAt,
      actedOnAt: actedOnAt,
      deletedAt: deletedAt,
      vectorClock: vectorClock,
      originatingHostId: originatingHostId,
    ),
    linkedTaskId: linkedTaskId,
    suggestionCount: 2,
    title: 'Title',
    body: 'Body',
  );
}

/// [MockVectorClockService] that actually evaluates `commitWhen`.
///
/// The shared mock deliberately runs the action and ignores the predicate, so
/// the commit rule — a write that produced nothing must not commit the scope,
/// and therefore must not spend a vector-clock tick — is invisible to any test
/// using it. Overriding one method keeps the rest of the shared stubs.
class _CommitEvaluatingVectorClockService extends MockVectorClockService {
  final List<bool> commits = [];

  @override
  Future<T> withVcScope<T>(
    Future<T> Function() action, {
    bool Function(T result)? commitWhen,
  }) async {
    final result = await action();
    if (commitWhen != null) commits.add(commitWhen(result));
    return result;
  }
}
