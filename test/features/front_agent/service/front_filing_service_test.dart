import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/service/front_filing_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const doorId = 'dispatch-1:door:0';
  final stamp = DateTime(2026, 10, 26, 9);

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications notifications;
  late List<AgentDomainEntity> upserts;
  late List<(String, String?, String?)> written;
  late List<String> madeTasks;
  late List<String> deleted;
  late JournalEntity? Function(String text) entryFor;
  late Task? Function(String title) taskFor;
  late FrontFilingService service;

  Metadata meta(String id, {String? categoryId}) => Metadata(
    id: id,
    createdAt: stamp,
    updatedAt: stamp,
    dateFrom: stamp,
    dateTo: stamp,
    categoryId: categoryId,
  );

  JournalEntity textEntry(String id, String text) => JournalEntity.journalEntry(
    meta: meta(id),
    entryText: EntryText(plainText: text),
  );

  Task task(String id, String title, {String? categoryId}) {
    final status = TaskStatus.open(id: 's', createdAt: stamp, utcOffset: 0);
    return JournalEntity.task(
          meta: meta(id, categoryId: categoryId),
          data: TaskData(
            status: status,
            statusHistory: [status],
            dateFrom: stamp,
            dateTo: stamp,
            title: title,
          ),
        )
        as Task;
  }

  /// Seeds the door's payload with [outcome].
  FrontDoorRecord seed(
    FrontDoorOutcome outcome, {
    String text = 'The hinge arrived.',
    FrontDestinationKind kind = FrontDestinationKind.task,
    String? destinationId = 'garden',
  }) {
    final record = FrontDoorRecord(
      segmentIndex: 0,
      text: text,
      kind: kind,
      destinationId: destinationId,
      ownerTitle: 'Garden',
      status: FrontDoorStatus.done,
      claimedAt: stamp.toUtc(),
      outcome: outcome,
    );
    when(() => repository.getEntity('$doorId:payload')).thenAnswer(
      (_) async => makeTestMessagePayload(
        id: '$doorId:payload',
        agentId: frontAgentId,
        content: record.toJson(),
      ),
    );
    return record;
  }

  /// The outcome the one rewrite stored.
  FrontDoorRecord rewritten() {
    final payload = upserts.whereType<AgentMessagePayloadEntity>().single;
    expect(payload.id, '$doorId:payload');
    expect(payload.agentId, frontAgentId);
    return FrontDoorRecord.fromJson(payload.content)!;
  }

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    journalDb = MockJournalDb();
    notifications = MockUpdateNotifications();
    upserts = [];
    written = [];
    madeTasks = [];
    deleted = [];
    entryFor = (text) => textEntry('entry-1', text);
    taskFor = (title) => task('task-new', title);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => notifications.notifyUiOnly(any())).thenReturn(null);
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
    service = FrontFilingService(
      repository: repository,
      syncService: syncService,
      journalDb: journalDb,
      notifications: notifications,
      writeTextEntry: (text, {linkedId, categoryId}) async {
        written.add((text, linkedId, categoryId));
        return entryFor(text);
      },
      makeTask: (title) async {
        madeTasks.add(title);
        return taskFor(title);
      },
      deleteEntry: (id) async {
        deleted.add(id);
        return true;
      },
    );
  });

  group('fileUnderTask', () {
    test("writes the user's words verbatim as an entry linked to the task, in "
        "the task's category, and records the entry", () async {
      seed(const FrontDoorProposal(ownerId: 'garden'));
      when(() => journalDb.journalEntityById('garden')).thenAnswer(
        (_) async => task('garden', 'Repair the nest box', categoryId: 'cat-1'),
      );

      await service.fileUnderTask(doorId);

      expect(written, [('The hinge arrived.', 'garden', 'cat-1')]);
      final outcome = rewritten().outcome! as FrontDoorFiled;
      expect(outcome.entryId, 'entry-1');
      expect(outcome.ownerId, 'garden');
      verify(
        () => notifications.notifyUiOnly({frontAgentId, agentNotification}),
      ).called(1);
    });

    test(
      'a task that is gone still files under its id, with no category',
      () async {
        seed(const FrontDoorProposal(ownerId: 'garden'));
        await service.fileUnderTask(doorId);
        expect(written.single.$3, isNull);
      },
    );

    test(
      'an entry that was not written leaves the proposal standing',
      () async {
        seed(const FrontDoorProposal(ownerId: 'garden'));
        entryFor = (_) => null;
        await expectLater(service.fileUnderTask(doorId), throwsStateError);
        expect(upserts, isEmpty);
      },
    );

    test('a door that is not a proposal any more refuses', () async {
      seed(const FrontDoorFiled(entryId: 'e', ownerId: 'garden'));
      await expectLater(
        service.fileUnderTask(doorId),
        throwsA(isA<FrontDoorStateException>()),
      );
      expect(written, isEmpty);
      expect(upserts, isEmpty);
    });

    test('a door with no record at all refuses', () async {
      await expectLater(
        service.decline(doorId),
        throwsA(
          isA<FrontDoorStateException>().having(
            (e) => e.toString(),
            'message',
            contains(doorId),
          ),
        ),
      );
    });
  });

  test('decline writes nothing and records the refusal', () async {
    seed(const FrontDoorProposal(ownerId: 'garden'));
    await service.decline(doorId);
    expect(written, isEmpty);
    expect(rewritten().outcome, isA<FrontDoorDeclined>());
  });

  group('unfile', () {
    test('deletes the entry and makes the door a proposal again, marked '
        'unfiled', () async {
      seed(const FrontDoorFiled(entryId: 'entry-1', ownerId: 'garden'));
      await service.unfile(doorId);
      expect(deleted, ['entry-1']);
      final outcome = rewritten().outcome! as FrontDoorProposal;
      expect(outcome.ownerId, 'garden');
      expect(outcome.unfiled, isTrue);
    });

    test('a note has no owner to go back to and refuses', () async {
      seed(const FrontDoorFiled(entryId: 'entry-1'));
      await expectLater(
        service.unfile(doorId),
        throwsA(isA<FrontDoorStateException>()),
      );
      expect(deleted, isEmpty);
    });
  });

  group('the inbox', () {
    test('saveAsNote writes the words as an entry owned by nothing', () async {
      seed(
        const FrontDoorInbox(),
        kind: FrontDestinationKind.unrouted,
        destinationId: null,
        text: 'Learn accordion.',
      );
      await service.saveAsNote(doorId);
      expect(written, [('Learn accordion.', null, null)]);
      final outcome = rewritten().outcome! as FrontDoorFiled;
      expect(outcome.entryId, 'entry-1');
      expect(outcome.ownerId, isNull);
    });

    test(
      'makeTask titles a task with the trimmed words and records it',
      () async {
        seed(
          const FrontDoorInbox(newKind: FrontNewKind.task),
          kind: FrontDestinationKind.newThing,
          destinationId: null,
          text: '  Buy a hose. ',
        );
        await service.makeTask(doorId);
        expect(madeTasks, ['Buy a hose.']);
        expect(
          (rewritten().outcome! as FrontDoorTaskCreated).taskId,
          'task-new',
        );
      },
    );

    test('a task that was not created leaves the item in the inbox', () async {
      seed(
        const FrontDoorInbox(),
        kind: FrontDestinationKind.unrouted,
        destinationId: null,
      );
      taskFor = (_) => null;
      await expectLater(service.makeTask(doorId), throwsStateError);
      expect(upserts, isEmpty);
    });

    test('an item already taken somewhere refuses both actions', () async {
      seed(const FrontDoorTaskCreated(taskId: 't'));
      await expectLater(
        service.saveAsNote(doorId),
        throwsA(isA<FrontDoorStateException>()),
      );
      await expectLater(
        service.makeTask(doorId),
        throwsA(isA<FrontDoorStateException>()),
      );
    });
  });
}
