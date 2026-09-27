import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_stores.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../ai_consumption/test_utils.dart';

final _date = DateTime(2024, 3, 15);

void main() {
  late MockOutboxService outbox;

  List<SyncMessage> enqueued() => [
    ...verify(() => outbox.enqueueMessage(captureAny())).captured
        .cast<SyncMessage>(),
  ];

  setUpAll(registerAllFallbackValues);

  setUp(() {
    outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    when(
      () => outbox.enqueueNotification(
        any(),
        originatingHostId: any(named: 'originatingHostId'),
        rethrowFailure: any(named: 'rethrowFailure'),
      ),
    ).thenAnswer((_) async {});
  });

  group('JournalDeepBackfillStore', () {
    late JournalDb db;
    late JournalDeepBackfillStore store;

    JournalEntity entry(String id, VectorClock clock, {bool deleted = false}) =>
        testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            id: id,
            vectorClock: clock,
            deletedAt: deleted ? _date : null,
          ),
        );

    Future<void> addConflict(JournalEntity version, {bool resolved = false}) =>
        db.addConflict(
          Conflict(
            id: version.meta.id,
            versionKey: version.meta.vectorClock!.canonicalKey,
            createdAt: _date,
            updatedAt: _date,
            serialized: jsonEncode(version.toJson()),
            schemaVersion: 0,
            status: (resolved
                    ? ConflictStatus.resolved
                    : ConflictStatus.unresolved)
                .index,
          ),
        );

    setUp(() async {
      db = JournalDb(inMemoryDatabase: true);
      store = JournalDeepBackfillStore(journalDb: db, outboxService: outbox);
      await db.upsertJournalDbEntity(
        toDbEntity(entry('a', const VectorClock({'h': 1}))),
      );
      await db.upsertJournalDbEntity(
        toDbEntity(entry('b', const VectorClock({'h': 2}), deleted: true)),
      );
    });

    tearDown(() => db.close());

    test('advertises rows by their meta clock, deletions included', () async {
      expect(store.payloadType, SyncSequencePayloadType.journalEntity);
      expect(await store.count(), 2);
      expect(await store.page(after: null, limit: 10), [
        (id: 'a', clock: const VectorClock({'h': 1})),
        (id: 'b', clock: const VectorClock({'h': 2})),
      ]);
      expect(await store.range(start: 'b', end: null), {
        'b': const VectorClock({'h': 2}),
      });
    });

    test('reads only open conflicts, in the range', () async {
      await addConflict(entry('a', const VectorClock({'o': 1})));
      await addConflict(
        entry('a', const VectorClock({'o': 2})),
        resolved: true,
      );
      await addConflict(entry('b', const VectorClock({'o': 3})));

      expect(await store.openConflicts(start: null, end: 'b'), {
        'a': [const VectorClock({'o': 1})],
      });
    });

    test('resends each row and every open conflict version of it, with '
        'media only where asked, and skips unknown ids', () async {
      await addConflict(entry('a', const VectorClock({'o': 1})));

      final sent = await store.enqueueCurrent(
        {'a', 'b', 'unknown'},
        withMedia: {'b'},
      );

      expect(sent, 2);
      final messages = enqueued().cast<SyncJournalEntity>();
      expect(
        messages.map((m) => (m.id, m.vectorClock, m.includeAttachments)),
        unorderedEquals([
          ('a', const VectorClock({'h': 1}), false),
          ('a', const VectorClock({'o': 1}), false),
          ('b', const VectorClock({'h': 2}), true),
        ]),
      );
      expect(
        messages.every((m) => m.status == SyncEntryStatus.update),
        isTrue,
      );
    });

    test('resends nothing for no ids', () async {
      expect(await store.enqueueCurrent({}, withMedia: {}), 0);
      verifyNever(() => outbox.enqueueMessage(any()));
    });
  });

  group('entryLinkDeepBackfillStore', () {
    late JournalDb db;

    setUp(() async {
      db = JournalDb(inMemoryDatabase: true);
      await db.upsertEntryLink(
        EntryLink.basic(
          id: 'link-1',
          fromId: 'from',
          toId: 'to',
          createdAt: _date,
          updatedAt: _date,
          vectorClock: const VectorClock({'h': 4}),
          deletedAt: _date,
        ),
      );
    });

    tearDown(() => db.close());

    test('advertises links, removals included, and resends them as entry '
        'links', () async {
      final store = entryLinkDeepBackfillStore(
        journalDb: db,
        outboxService: outbox,
      );

      expect(store.payloadType, SyncSequencePayloadType.entryLink);
      expect(await store.range(start: null, end: null), {
        'link-1': const VectorClock({'h': 4}),
      });
      expect(await store.enqueueCurrent({'link-1'}, withMedia: {}), 1);
      final message = enqueued().single as SyncEntryLink;
      expect(message.entryLink.id, 'link-1');
      expect(message.entryLink.deletedAt, _date);
      expect(message.status, SyncEntryStatus.update);
    });
  });

  group('agent stores', () {
    late AgentDatabase db;
    late AgentRepository repository;

    setUp(() async {
      db = AgentDatabase(inMemoryDatabase: true, background: false);
      repository = AgentRepository(db);
      await repository.upsertEntity(
        AgentDomainEntity.agent(
          id: 'agent-1',
          agentId: 'agent-1',
          kind: 'task_agent',
          displayName: 'Test',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: _date,
          updatedAt: _date,
          vectorClock: const VectorClock({'h': 5}),
        ),
      );
      await repository.upsertLink(
        model.AgentLink.basic(
          id: 'alink-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: _date,
          updatedAt: _date,
          vectorClock: const VectorClock({'h': 6}),
        ),
      );
    });

    tearDown(() => db.close());

    test('agent entities travel as agent entity messages', () async {
      final store = agentEntityDeepBackfillStore(
        agentDatabase: db,
        outboxService: outbox,
      );

      expect(store.payloadType, SyncSequencePayloadType.agentEntity);
      expect(await store.page(after: null, limit: 5), [
        (id: 'agent-1', clock: const VectorClock({'h': 5})),
      ]);
      expect(await store.enqueueCurrent({'agent-1'}, withMedia: {}), 1);
      final message = enqueued().single as SyncAgentEntity;
      expect(message.agentEntity?.id, 'agent-1');
    });

    test('agent links travel as agent link messages', () async {
      final store = agentLinkDeepBackfillStore(
        agentDatabase: db,
        outboxService: outbox,
      );

      expect(store.payloadType, SyncSequencePayloadType.agentLink);
      expect(await store.count(), 1);
      expect(await store.enqueueCurrent({'alink-1'}, withMedia: {}), 1);
      final message = enqueued().single as SyncAgentLink;
      expect(message.agentLink?.id, 'alink-1');
      expect(message.agentLink?.vectorClock, const VectorClock({'h': 6}));
    });
  });

  group('notificationDeepBackfillStore', () {
    late NotificationsDb db;

    setUp(() async {
      db = NotificationsDb(inMemoryDatabase: true, background: false);
      await db.upsertNotification(
        NotificationEntity.taskSuggestion(
          meta: NotificationMeta(
            id: 'n-1',
            createdAt: _date,
            updatedAt: _date,
            scheduledFor: _date,
            deletedAt: _date,
            vectorClock: const VectorClock({'h': 7}),
            originatingHostId: 'h',
          ),
          linkedTaskId: 'task-1',
          suggestionCount: 1,
          title: 'Task reminder',
          body: 'Review this task',
        ),
      );
    });

    tearDown(() => db.close());

    test('reads the clock column and resends the whole notification', () async {
      final store = notificationDeepBackfillStore(
        notificationsDb: db,
        outboxService: outbox,
      );

      expect(store.payloadType, SyncSequencePayloadType.notification);
      expect(await store.range(start: null, end: null), {
        'n-1': const VectorClock({'h': 7}),
      });
      expect(await store.enqueueCurrent({'n-1'}, withMedia: {}), 1);
      final sent = verify(
        () => outbox.enqueueNotification(captureAny()),
      ).captured.single as NotificationEntity;
      expect(sent.meta.id, 'n-1');
      expect(sent.meta.deletedAt, _date);
    });
  });

  group('consumptionDeepBackfillStore', () {
    late ConsumptionDatabase db;

    setUp(() async {
      db = ConsumptionDatabase(inMemoryDatabase: true);
      await ConsumptionRepository(db).upsertEvent(
        makeConsumptionEvent(
          id: 'c-1',
          vectorClock: const VectorClock({'h': 8}),
        ),
      );
    });

    tearDown(() => db.close());

    test('consumption events travel as consumption event messages', () async {
      final store = consumptionDeepBackfillStore(
        consumptionDatabase: db,
        outboxService: outbox,
      );

      expect(store.payloadType, SyncSequencePayloadType.consumptionEvent);
      expect(await store.page(after: null, limit: 5), [
        (id: 'c-1', clock: const VectorClock({'h': 8})),
      ]);
      expect(await store.enqueueCurrent({'c-1', 'none'}, withMedia: {}), 1);
      final message = enqueued().single as SyncConsumptionEvent;
      expect(message.event.id, 'c-1');
    });
  });
}
