import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/service/front_filing_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../projects/test_utils.dart';

void main() {
  /// The setup of a task made of bare words, left as it was.
  const asSaid = FrontTaskChoices(
    start: FrontTaskStart.open,
    priority: TaskPriority.p2Medium,
  );

  setUpAll(registerAllFallbackValues);

  const doorId = 'dispatch-1:door:0';
  final stamp = DateTime(2026, 10, 26, 9);

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications notifications;
  late List<AgentDomainEntity> upserts;
  late List<(String, String, String?, String?)> written;
  late List<(String, String)> madeTasks;
  late List<(String, String)> madeEvents;
  late JournalEvent? Function(String title) eventFor;
  late List<(FrontTaskDraft, String)> madeDrafts;
  late List<String> deleted;

  /// What was started for a task once it was made, in order.
  late List<(FrontTaskExtra, String)> started;

  /// The record rewrites and the starts, in the order they happened.
  late List<String> order;

  /// Whether a cover can be drawn for a task in a category, and the
  /// categories it was asked for.
  late bool Function(String? categoryId) canDraw;
  late List<String?> coverAsked;
  late MockDomainLogger logger;

  /// What starting an extra does, beyond being recorded.
  late void Function(FrontTaskExtra extra) onStart;
  late bool deleteResult;
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
    FrontTaskDraft? task,
  }) {
    final record = FrontDoorRecord(
      task: task,
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
    madeEvents = [];
    eventFor = (title) => JournalEvent(
      meta: meta('event-new'),
      data: EventData(title: title, stars: 0, status: EventStatus.tentative),
    );
    madeDrafts = [];
    deleted = [];
    started = [];
    order = [];
    canDraw = (_) => true;
    coverAsked = [];
    logger = MockDomainLogger();
    onStart = (_) {};
    deleteResult = true;
    entryFor = (text) => textEntry('entry-1', text);
    taskFor = (title) => task('task-new', title);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
      order.add('record');
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
      writeTextEntry: (text, {required id, linkedId, categoryId}) async {
        written.add((text, id, linkedId, categoryId));
        return entryFor(text);
      },
      makeTask: (draft, {required id, required words}) async {
        madeTasks.add((draft.title, id));
        madeDrafts.add((draft, words));
        return taskFor(draft.title);
      },
      makeEvent: (title, {required id}) async {
        madeEvents.add((title, id));
        return eventFor(title);
      },
      deleteEntry: (id) async {
        deleted.add(id);
        return deleteResult;
      },
      startExtra: (extra, {required taskId}) {
        started.add((extra, taskId));
        order.add('start ${extra.name}');
        onStart(extra);
      },
      canDrawCover: (categoryId) async {
        coverAsked.add(categoryId);
        return canDraw(categoryId);
      },
      domainLogger: logger,
    );
  });

  group('fileUnderOwner', () {
    test("writes the user's words verbatim as an entry linked to the task, in "
        "the task's category, and records the entry", () async {
      seed(const FrontDoorProposal(ownerId: 'garden'));
      when(() => journalDb.journalEntityById('garden')).thenAnswer(
        (_) async => task('garden', 'Repair the nest box', categoryId: 'cat-1'),
      );

      await service.fileUnderOwner(doorId);

      expect(written, [
        (
          'The hinge arrived.',
          frontDoorEntryId(doorId, generation: 0),
          'garden',
          'cat-1',
        ),
      ]);
      final outcome = rewritten().outcome! as FrontDoorFiled;
      expect(outcome.entryId, 'entry-1');
      expect(outcome.ownerId, 'garden');
      expect(outcome.generation, 0);
      verify(
        () => notifications.notifyUiOnly({frontAgentId, agentNotification}),
      ).called(1);
    });

    test('files under a project the same way: linked under it, in its '
        'category, so its agent reads it in its log', () async {
      seed(
        const FrontDoorProposal(ownerId: 'survey'),
        kind: FrontDestinationKind.project,
        destinationId: 'survey',
      );
      when(() => journalDb.journalEntityById('survey')).thenAnswer(
        (_) async => makeTestProject(
          id: 'survey',
          title: 'Nest survey',
          categoryId: 'cat-2',
        ),
      );

      await service.fileUnderOwner(doorId);

      expect(written.single.$3, 'survey');
      expect(written.single.$4, 'cat-2');
      final outcome = rewritten().outcome! as FrontDoorFiled;
      expect(outcome.ownerId, 'survey');
    });

    test(
      'a task that is gone still files under its id, with no category',
      () async {
        seed(const FrontDoorProposal(ownerId: 'garden'));
        await service.fileUnderOwner(doorId);
        expect(written.single.$4, isNull);
      },
    );

    test(
      'an entry that was not written leaves the proposal standing',
      () async {
        seed(const FrontDoorProposal(ownerId: 'garden'));
        entryFor = (_) => null;
        await expectLater(service.fileUnderOwner(doorId), throwsStateError);
        expect(upserts, isEmpty);
      },
    );

    test('a door that is not a proposal any more refuses', () async {
      seed(const FrontDoorFiled(entryId: 'e', ownerId: 'garden'));
      await expectLater(
        service.fileUnderOwner(doorId),
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

  group('a change to today', () {
    test('declined, its words go to the inbox, writing nothing', () async {
      seed(
        const FrontDoorDay(),
        kind: FrontDestinationKind.day,
        destinationId: null,
      );
      await service.decline(doorId);
      expect(written, isEmpty);
      final outcome = rewritten().outcome! as FrontDoorInbox;
      expect(outcome.ownerId, isNull);
      expect(outcome.newKind, isNull);
    });

    test(
      'settles once a plan was accepted for it, writing nothing here',
      () async {
        seed(
          const FrontDoorDay(),
          kind: FrontDestinationKind.day,
          destinationId: null,
        );
        await service.markDayPlanned(doorId, DateTime(2026, 11));
        expect(written, isEmpty);
        final outcome = rewritten().outcome! as FrontDoorDayPlanned;
        expect(outcome.day, DateTime(2026, 11));
      },
    );

    test(
      'a door that is not a change to today refuses to settle as one',
      () async {
        seed(const FrontDoorProposal(ownerId: 'garden'));
        await expectLater(
          service.markDayPlanned(doorId, DateTime(2026, 11)),
          throwsA(isA<FrontDoorStateException>()),
        );
        expect(upserts, isEmpty);
      },
    );
  });

  group('markProjectCreated', () {
    test('settles an inbox item on the project the form made of it', () async {
      seed(
        const FrontDoorInbox(newKind: FrontNewKind.project),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
      );
      await service.markProjectCreated(doorId, 'p-1');
      expect(written, isEmpty);
      final outcome = rewritten().outcome! as FrontDoorProjectCreated;
      expect(outcome.projectId, 'p-1');
    });

    test('an item already settled refuses', () async {
      seed(const FrontDoorDeclined());
      await expectLater(
        service.markProjectCreated(doorId, 'p-1'),
        throwsA(isA<FrontDoorStateException>()),
      );
      expect(upserts, isEmpty);
    });
  });

  group('decline', () {
    test('sends a proposal to the inbox, writing nothing, with the task it '
        'was proposed under kept on the item', () async {
      seed(const FrontDoorProposal(ownerId: 'garden', generation: 2));
      await service.decline(doorId);
      expect(written, isEmpty);
      final inbox = rewritten().outcome! as FrontDoorInbox;
      expect(inbox.ownerId, 'garden');
      expect(inbox.generation, 2);
      expect(inbox.newKind, isNull);
    });

    test('leaves an inbox item where it is, keeping what it was', () async {
      seed(
        const FrontDoorInbox(newKind: FrontNewKind.goal, generation: 1),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
      );
      await service.decline(doorId);
      final left = rewritten().outcome! as FrontDoorDeclined;
      expect(left.newKind, FrontNewKind.goal);
      expect(left.generation, 1);
      expect(left.ownerId, isNull);

      upserts.clear();
      seed(const FrontDoorInbox(ownerId: 'garden', generation: 2));
      await service.decline(doorId);
      final leftProposal = rewritten().outcome! as FrontDoorDeclined;
      expect(leftProposal.ownerId, 'garden');
      expect(leftProposal.generation, 2);
      expect(written, isEmpty);
    });

    test('a settled door has nothing to say no to', () async {
      seed(const FrontDoorFiled(entryId: 'entry-1', ownerId: 'garden'));
      await expectLater(
        service.decline(doorId),
        throwsA(isA<FrontDoorStateException>()),
      );
      expect(upserts, isEmpty);
    });
  });

  group('undoDecline', () {
    test('makes a left proposal the same proposal again, nothing written or '
        'deleted in between', () async {
      seed(const FrontDoorDeclined(ownerId: 'garden', generation: 2));
      await service.undoDecline(doorId);
      expect(written, isEmpty);
      expect(deleted, isEmpty);
      final proposal = rewritten().outcome! as FrontDoorProposal;
      expect(proposal.ownerId, 'garden');
      expect(proposal.generation, 2);
    });

    test('makes a left inbox item an inbox item again, leading with the '
        'same chip', () async {
      seed(
        const FrontDoorDeclined(newKind: FrontNewKind.goal, generation: 1),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
      );
      await service.undoDecline(doorId);
      final inbox = rewritten().outcome! as FrontDoorInbox;
      expect(inbox.newKind, FrontNewKind.goal);
      expect(inbox.generation, 1);
      expect(inbox.ownerId, isNull);
    });

    test('a refusal recorded before the proposal was kept on it falls back '
        "on a task door's destination, and on the inbox otherwise", () async {
      seed(const FrontDoorDeclined());
      await service.undoDecline(doorId);
      final proposal = rewritten().outcome! as FrontDoorProposal;
      expect(proposal.ownerId, 'garden');
      expect(proposal.generation, 0);

      upserts.clear();
      seed(
        const FrontDoorDeclined(),
        kind: FrontDestinationKind.unrouted,
        destinationId: null,
      );
      await service.undoDecline(doorId);
      expect(rewritten().outcome, isA<FrontDoorInbox>());
    });

    test('on a door that is not left, it refuses', () async {
      seed(const FrontDoorProposal(ownerId: 'garden'));
      await expectLater(
        service.undoDecline(doorId),
        throwsA(isA<FrontDoorStateException>()),
      );
      expect(upserts, isEmpty);
    });
  });

  group('takeBack', () {
    test('deletes the entry and makes the door a proposal again, one '
        'generation on, so a re-file gets a fresh entry', () async {
      seed(
        const FrontDoorFiled(
          entryId: 'entry-1',
          ownerId: 'garden',
          generation: 1,
        ),
      );
      await service.takeBack(doorId);
      expect(deleted, ['entry-1']);
      final outcome = rewritten().outcome! as FrontDoorProposal;
      expect(outcome.ownerId, 'garden');
      expect(outcome.unfiled, isTrue);
      expect(outcome.generation, 2);
    });

    test('a re-file after an unfile names the next generation', () async {
      seed(const FrontDoorProposal(ownerId: 'garden', generation: 2));
      await service.fileUnderOwner(doorId);
      expect(written.single.$2, frontDoorEntryId(doorId, generation: 2));
      expect(
        frontDoorEntryId(doorId, generation: 2),
        isNot(frontDoorEntryId(doorId, generation: 0)),
      );
      expect((rewritten().outcome! as FrontDoorFiled).generation, 2);
    });

    test('a delete that did not happen leaves the door filed', () async {
      seed(const FrontDoorFiled(entryId: 'entry-1', ownerId: 'garden'));
      deleteResult = false;
      when(() => journalDb.journalEntityById('entry-1')).thenAnswer(
        (_) async => textEntry('entry-1', 'still here'),
      );
      await expectLater(service.takeBack(doorId), throwsStateError);
      expect(upserts, isEmpty);
    });

    test(
      'an entry already gone from the journal counts as taken out',
      () async {
        seed(const FrontDoorFiled(entryId: 'entry-1', ownerId: 'garden'));
        deleteResult = false;
        await service.takeBack(doorId);
        expect(rewritten().outcome, isA<FrontDoorProposal>());
      },
    );

    test('a note goes back to the inbox, one generation on, leading with '
        'the same chip', () async {
      seed(
        const FrontDoorFiled(entryId: 'entry-1', newKind: FrontNewKind.goal),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
      );
      await service.takeBack(doorId);
      expect(deleted, ['entry-1']);
      final inbox = rewritten().outcome! as FrontDoorInbox;
      expect(inbox.newKind, FrontNewKind.goal);
      expect(inbox.generation, 1);
    });

    test('a task made of an inbox item is deleted and the item is back in '
        'the inbox', () async {
      seed(
        const FrontDoorTaskCreated(
          taskId: 'task-new',
          newKind: FrontNewKind.task,
          generation: 1,
        ),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
      );
      await service.takeBack(doorId);
      expect(deleted, ['task-new']);
      final inbox = rewritten().outcome! as FrontDoorInbox;
      expect(inbox.newKind, FrontNewKind.task);
      expect(inbox.generation, 2);
    });

    test(
      'a task still there after the delete leaves the door as it was',
      () async {
        seed(const FrontDoorTaskCreated(taskId: 'task-new'));
        deleteResult = false;
        when(() => journalDb.journalEntityById('task-new')).thenAnswer(
          (_) async => task('task-new', 'still here'),
        );
        await expectLater(service.takeBack(doorId), throwsStateError);
        expect(upserts, isEmpty);
      },
    );

    test('an event made of an inbox item is deleted and the item is back in '
        'the inbox, one generation on, leading as it did', () async {
      seed(
        const FrontDoorEventCreated(
          eventId: 'event-new',
          newKind: FrontNewKind.goal,
          generation: 1,
        ),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
      );

      await service.takeBack(doorId);

      expect(deleted, ['event-new']);
      final inbox = rewritten().outcome! as FrontDoorInbox;
      expect(inbox.newKind, FrontNewKind.goal);
      expect(inbox.generation, 2);
    });

    test(
      'an event still there after the delete leaves the door as it was',
      () async {
        seed(const FrontDoorEventCreated(eventId: 'event-new'));
        deleteResult = false;
        when(() => journalDb.journalEntityById('event-new')).thenAnswer(
          (_) async => eventFor('still here'),
        );

        await expectLater(service.takeBack(doorId), throwsStateError);
        expect(upserts, isEmpty);
      },
    );

    test('a door that wrote nothing has nothing to take back', () async {
      seed(const FrontDoorDeclined(ownerId: 'garden'));
      await expectLater(
        service.takeBack(doorId),
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
      expect(written, [
        ('Learn accordion.', frontDoorNoteId(doorId), null, null),
      ]);
      final outcome = rewritten().outcome! as FrontDoorFiled;
      expect(outcome.entryId, 'entry-1');
      expect(outcome.ownerId, isNull);
      expect(outcome.generation, 0);
    });

    test('an item taken back writes its next note or task under a fresh '
        'id, and the receipt keeps the generation and the kind', () async {
      seed(
        const FrontDoorInbox(newKind: FrontNewKind.goal, generation: 1),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
      );
      await service.saveAsNote(doorId);
      expect(written.single.$2, frontDoorNoteId(doorId, generation: 1));
      expect(
        frontDoorNoteId(doorId, generation: 1),
        isNot(frontDoorNoteId(doorId)),
      );
      final note = rewritten().outcome! as FrontDoorFiled;
      expect(note.newKind, FrontNewKind.goal);
      expect(note.generation, 1);

      upserts.clear();
      seed(
        const FrontDoorInbox(newKind: FrontNewKind.task, generation: 2),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
      );
      await service.makeTask(doorId, choices: asSaid);
      expect(madeTasks.single.$2, frontDoorTaskId(doorId, generation: 2));
      expect(
        frontDoorTaskId(doorId, generation: 2),
        isNot(frontDoorTaskId(doorId)),
      );
      final made = rewritten().outcome! as FrontDoorTaskCreated;
      expect(made.newKind, FrontNewKind.task);
      expect(made.generation, 2);
    });

    test('makeTask titles a task with the trimmed words and records it, '
        'with when the tap made it', () async {
      seed(
        const FrontDoorInbox(newKind: FrontNewKind.task),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
        text: '  Buy a hose. ',
      );
      final tapped = DateTime.utc(2026, 11, 8, 9, 20);
      await withClock(
        Clock.fixed(tapped),
        () => service.makeTask(doorId, choices: asSaid),
      );
      expect(madeTasks, [('Buy a hose.', frontDoorTaskId(doorId))]);
      final made = rewritten().outcome! as FrontDoorTaskCreated;
      expect(made.taskId, 'task-new');
      expect(made.at, tapped);
    });

    test(
      "makeTask fills the task from the router's draft and keeps the words",
      () async {
        final draft = FrontTaskDraft(
          title: 'Buy a hose',
          categoryId: 'cat-1',
          priority: TaskPriority.p1High,
          due: DateTime(2026, 11, 9),
        );
        seed(
          const FrontDoorInbox(newKind: FrontNewKind.task),
          kind: FrontDestinationKind.newThing,
          destinationId: null,
          text: ' I need to buy a hose by tomorrow, high priority. ',
          task: draft,
        );
        await service.makeTask(
          doorId,
          choices: FrontTaskChoices.of(draft),
        );
        final (made, words) = madeDrafts.single;
        // Stored and read back with the record, field for field.
        expect(made.title, draft.title);
        expect(made.categoryId, 'cat-1');
        expect(made.priority, TaskPriority.p1High);
        expect(made.due, DateTime(2026, 11, 9));
        expect(words, 'I need to buy a hose by tomorrow, high priority.');
        expect(madeTasks.single.$2, frontDoorTaskId(doorId));
      },
    );

    test('makeTask makes the task as the user set it up, over what the '
        'words said', () async {
      seed(
        const FrontDoorInbox(newKind: FrontNewKind.task),
        kind: FrontDestinationKind.newThing,
        destinationId: null,
        text: 'Buy a hose, high priority.',
        task: const FrontTaskDraft(
          title: 'Buy a hose',
          categoryId: 'cat-1',
          priority: TaskPriority.p1High,
        ),
      );
      await service.makeTask(
        doorId,
        choices: FrontTaskChoices(
          start: FrontTaskStart.inProgress,
          priority: TaskPriority.p0Urgent,
          due: DateTime(2026, 11, 11),
        ),
      );
      final (made, _) = madeDrafts.single;
      expect(made.status, FrontTaskStart.inProgress);
      expect(made.priority, TaskPriority.p0Urgent);
      expect(made.due, DateTime(2026, 11, 11));
      // What the user did not set up stays as the words said.
      expect(made.title, 'Buy a hose');
      expect(made.categoryId, 'cat-1');
    });

    test(
      'makeEvent titles an event with the trimmed words under the id the '
      "door names, and records it with the item's guess and generation",
      () async {
        seed(
          const FrontDoorInbox(newKind: FrontNewKind.project, generation: 2),
          kind: FrontDestinationKind.newThing,
          destinationId: null,
          text: '  Launch-day rehearsal on Friday. ',
        );

        await service.makeEvent(doorId);

        expect(madeEvents, [
          (
            'Launch-day rehearsal on Friday.',
            frontDoorEventId(doorId, generation: 2),
          ),
        ]);
        final made = rewritten().outcome! as FrontDoorEventCreated;
        expect(made.eventId, 'event-new');
        expect(made.newKind, FrontNewKind.project);
        expect(made.generation, 2);
        verify(
          () => notifications.notifyUiOnly({frontAgentId, agentNotification}),
        ).called(1);
      },
    );

    test(
      'an event that was not created leaves the item in the inbox',
      () async {
        seed(
          const FrontDoorInbox(),
          kind: FrontDestinationKind.unrouted,
          destinationId: null,
        );
        eventFor = (_) => null;

        await expectLater(service.makeEvent(doorId), throwsStateError);
        expect(upserts, isEmpty);
      },
    );

    test('each generation of an item gets an event id of its own, and the '
        'same door and generation the same one', () {
      expect(
        frontDoorEventId(doorId, generation: 0),
        frontDoorEventId(doorId, generation: 0),
      );
      expect(
        {
          frontDoorEventId(doorId, generation: 0),
          frontDoorEventId(doorId, generation: 1),
          frontDoorEventId('other:door:0', generation: 0),
          frontDoorTaskId(doorId),
          frontDoorNoteId(doorId),
        },
        hasLength(5),
      );
    });

    test('a note that was not written leaves the item in the inbox', () async {
      seed(
        const FrontDoorInbox(),
        kind: FrontDestinationKind.unrouted,
        destinationId: null,
      );
      entryFor = (_) => null;
      await expectLater(service.saveAsNote(doorId), throwsStateError);
      expect(upserts, isEmpty);
    });

    test('a task that was not created leaves the item in the inbox', () async {
      seed(
        const FrontDoorInbox(),
        kind: FrontDestinationKind.unrouted,
        destinationId: null,
      );
      taskFor = (_) => null;
      await expectLater(
        service.makeTask(doorId, choices: asSaid),
        throwsStateError,
      );
      expect(upserts, isEmpty);
    });

    test('an item already taken somewhere refuses every action', () async {
      seed(const FrontDoorTaskCreated(taskId: 't'));
      await expectLater(
        service.saveAsNote(doorId),
        throwsA(isA<FrontDoorStateException>()),
      );
      await expectLater(
        service.makeTask(doorId, choices: asSaid),
        throwsA(isA<FrontDoorStateException>()),
      );
      await expectLater(
        service.makeEvent(doorId),
        throwsA(isA<FrontDoorStateException>()),
      );
      expect(madeEvents, isEmpty);
    });
  });

  group('what is generated with a task', () {
    const withCover = FrontTaskChoices(
      start: FrontTaskStart.open,
      priority: TaskPriority.p2Medium,
      coverArt: true,
    );

    void seedInbox({FrontTaskDraft? draft}) => seed(
      const FrontDoorInbox(newKind: FrontNewKind.task),
      kind: FrontDestinationKind.newThing,
      destinationId: null,
      text: 'Check the ice-pad weather window.',
      task: draft,
    );

    FrontDoorTaskCreated created() =>
        rewritten().outcome! as FrontDoorTaskCreated;

    test('a task made as said starts nothing and stores no extras', () async {
      seedInbox();
      await service.makeTask(doorId, choices: asSaid);
      expect(started, isEmpty);
      expect(created().extras, isEmpty);
      expect(created().toJson().containsKey('extras'), isFalse);
    });

    test('cover art chosen in the setup is started for the task and kept on '
        'the outcome', () async {
      seedInbox();
      await service.makeTask(doorId, choices: withCover);
      expect(started, [(FrontTaskExtra.coverArt, 'task-new')]);
      expect(created().extras, {FrontTaskExtra.coverArt});
      // The maker is told too, so the draft it makes says what was chosen.
      expect(madeDrafts.single.$1.coverArt, isTrue);
    });

    test('a coding prompt asked for is started for the task and kept on the '
        'outcome, with no cover art', () async {
      seedInbox();
      await service.makeTask(doorId, choices: asSaid, codingPrompt: true);
      expect(started, [(FrontTaskExtra.codingPrompt, 'task-new')]);
      expect(created().extras, {FrontTaskExtra.codingPrompt});
      expect(madeDrafts.single.$1.coverArt, isFalse);
    });

    test('both are started, each once', () async {
      seedInbox();
      await service.makeTask(doorId, choices: withCover, codingPrompt: true);
      expect(started, [
        (FrontTaskExtra.coverArt, 'task-new'),
        (FrontTaskExtra.codingPrompt, 'task-new'),
      ]);
      expect(created().extras, FrontTaskExtra.values.toSet());
    });

    test("cover art the words asked for rides the draft's choices", () async {
      const draft = FrontTaskDraft(title: 'Check the weather', coverArt: true);
      seedInbox(draft: draft);
      await service.makeTask(doorId, choices: FrontTaskChoices.of(draft));
      expect(started, [(FrontTaskExtra.coverArt, 'task-new')]);
    });

    test('the user turning the cover off wins over the words', () async {
      seedInbox(
        draft: const FrontTaskDraft(title: 'Check the weather', coverArt: true),
      );
      await service.makeTask(doorId, choices: asSaid);
      expect(started, isEmpty);
      expect(madeDrafts.single.$1.coverArt, isFalse);
    });

    test(
      'nothing is started before the record says the task is made',
      () async {
        seedInbox();
        await service.makeTask(doorId, choices: withCover, codingPrompt: true);
        expect(order, ['record', 'start coverArt', 'start codingPrompt']);
      },
    );

    group('where no profile can draw a cover', () {
      setUp(() => canDraw = (_) => false);

      test('a cover chosen is left out: not made with, not started, not '
          'said to be requested', () async {
        seedInbox();
        await service.makeTask(doorId, choices: withCover);
        expect(madeDrafts.single.$1.coverArt, isFalse);
        expect(started, isEmpty);
        expect(created().extras, isEmpty);
      });

      test('a coding prompt asked for with it still is, the cover the words '
          'asked for dropped', () async {
        const draft = FrontTaskDraft(
          title: 'Check the weather',
          categoryId: 'cat-1',
          coverArt: true,
        );
        seedInbox(draft: draft);
        await service.makeTask(
          doorId,
          choices: FrontTaskChoices.of(draft),
          codingPrompt: true,
        );
        expect(started, [(FrontTaskExtra.codingPrompt, 'task-new')]);
        expect(created().extras, {FrontTaskExtra.codingPrompt});
        // Asked for the category she read the task into.
        expect(coverAsked, ['cat-1']);
      });
    });

    test("whether a cover can be drawn is asked for the draft's category, "
        'none for bare words, and only when one was chosen', () async {
      seedInbox(
        draft: const FrontTaskDraft(title: 'Check', categoryId: 'cat-9'),
      );
      await service.makeTask(doorId, choices: asSaid);
      expect(coverAsked, isEmpty);

      await service.makeTask(doorId, choices: withCover);
      expect(coverAsked, ['cat-9']);

      seedInbox();
      await service.makeTask(doorId, choices: withCover);
      expect(coverAsked, ['cat-9', null]);
    });

    test('a start that throws is logged and never fails the task made: the '
        'record stands and the other extra still starts', () async {
      seedInbox();
      final failure = StateError('container gone');
      onStart = (extra) {
        if (extra == FrontTaskExtra.coverArt) throw failure;
      };

      await service.makeTask(doorId, choices: withCover, codingPrompt: true);

      expect(created().extras, FrontTaskExtra.values.toSet());
      expect(started.map((start) => start.$1), FrontTaskExtra.values);
      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          failure,
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'makeTask.startExtra',
          message: any(named: 'message', that: contains('coverArt')),
        ),
      ).called(1);
    });

    test('a task that was not created starts nothing', () async {
      seedInbox();
      taskFor = (_) => null;
      await expectLater(
        service.makeTask(doorId, choices: withCover, codingPrompt: true),
        throwsStateError,
      );
      expect(started, isEmpty);
    });

    test('a record that did not follow starts nothing, so the retry starts '
        'each once', () async {
      seedInbox();
      when(
        () => syncService.upsertEntity(any()),
      ).thenAnswer((_) async => throw StateError('sync down'));
      await expectLater(
        service.makeTask(doorId, choices: withCover),
        throwsStateError,
      );
      expect(started, isEmpty);

      when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
      await service.makeTask(doorId, choices: withCover);
      expect(started, [(FrontTaskExtra.coverArt, 'task-new')]);
    });
  });
}
