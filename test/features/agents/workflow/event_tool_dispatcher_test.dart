import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/event_tool_dispatcher.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../relationships/helpers/test_people.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockJournalRepository mockJournalRepository;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockCache;
  late EventToolDispatcher dispatcher;

  const eventId = 'event-1';
  const categoryId = 'cat-1';
  final now = DateTime(2026, 6, 20, 19, 30);

  Metadata meta(String id, {String? categoryId}) => Metadata(
    id: id,
    createdAt: now,
    updatedAt: now,
    dateFrom: now,
    dateTo: now,
    categoryId: categoryId,
  );

  final eventEntity = JournalEntity.event(
    meta: meta(eventId, categoryId: categoryId),
    data: const EventData(
      title: 'Trip',
      stars: 0,
      status: EventStatus.completed,
    ),
  );

  final category = CategoryDefinition(
    id: categoryId,
    name: 'Travel',
    private: false,
    active: true,
    createdAt: now,
    updatedAt: now,
    vectorClock: null,
    defaultProfileId: 'profile-1',
  );

  final createdTask = Task(
    meta: meta('task-9'),
    data: TaskData(
      title: 'Share the album',
      status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
    ),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(const EntryText(plainText: ''));
    registerFallbackValue(
      TaskData(
        title: '',
        status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
      ),
    );
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockJournalRepository = MockJournalRepository();
    mockPersistenceLogic = MockPersistenceLogic();
    mockCache = MockEntitiesCacheService();
    dispatcher = EventToolDispatcher(
      journalDb: mockJournalDb,
      journalRepository: mockJournalRepository,
      persistenceLogic: mockPersistenceLogic,
      entitiesCacheService: mockCache,
    );

    when(
      () => mockJournalRepository.getJournalEntityById(eventId),
    ).thenAnswer((_) async => eventEntity);
    when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);
    when(
      () => mockJournalDb.journalEntityMapForIdsIncludingDeleted(any()),
    ).thenAnswer((_) async => const {});
    // A task found by its derived id reads as deleted unless a test says
    // otherwise.
    when(
      () => mockJournalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
  });

  test('suggest_follow_up_task creates a task linked to the event', () async {
    when(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => createdTask);

    final result = await dispatcher.dispatch(
      EventAgentToolNames.suggestFollowUpTask,
      {'title': '  Share the album  ', 'notes': 'Everyone asked.'},
      eventId,
    );

    expect(result.success, isTrue);
    expect(result.mutatedEntityId, 'task-9');

    final captured = verify(
      () => mockPersistenceLogic.createTaskEntry(
        data: captureAny(named: 'data'),
        entryText: captureAny(named: 'entryText'),
        linkedId: captureAny(named: 'linkedId'),
        categoryId: captureAny(named: 'categoryId'),
      ),
    ).captured;
    final data = captured[0] as TaskData;
    final entryText = captured[1] as EntryText;
    expect(data.title, 'Share the album'); // trimmed
    expect(data.profileId, 'profile-1'); // inherited from the category
    expect(entryText.plainText, 'Everyone asked.');
    expect(captured[2], eventId); // linkedId links the task to the event
    expect(captured[3], categoryId);
  });

  test(
    'logs the follow-up creation when a domain logger is configured',
    () async {
      final loggingDispatcher = EventToolDispatcher(
        journalDb: mockJournalDb,
        journalRepository: mockJournalRepository,
        persistenceLogic: mockPersistenceLogic,
        entitiesCacheService: mockCache,
        domainLogger: DomainLogger(loggingService: LoggingService())
          ..enabledDomains.add(LogDomain.agentRuntime),
      );
      when(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => createdTask);

      final result = await loggingDispatcher.dispatch(
        EventAgentToolNames.suggestFollowUpTask,
        {'title': 'Share the album'},
        eventId,
      );

      expect(result.success, isTrue);
      expect(result.mutatedEntityId, 'task-9');
    },
  );

  test('rejects an empty title and creates nothing', () async {
    final result = await dispatcher.dispatch(
      EventAgentToolNames.suggestFollowUpTask,
      {'title': '   '},
      eventId,
    );

    expect(result.success, isFalse);
    verifyNever(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    );
  });

  test('reports failure when task creation returns null', () async {
    when(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => null);

    final result = await dispatcher.dispatch(
      EventAgentToolNames.suggestFollowUpTask,
      {'title': 'X'},
      eventId,
    );

    expect(result.success, isFalse);
    expect(result.errorMessage, contains('Task creation failed'));
  });

  test('rejects an unknown tool', () async {
    final result = await dispatcher.dispatch('set_event_cover', {}, eventId);

    expect(result.success, isFalse);
    expect(result.output, contains('Unknown tool'));
  });

  // Defense-in-depth for the human-only rating/cover invariant: even if a
  // foreign tool name somehow reached the event dispatcher (it cannot — the
  // strategy only persists `eventDeferredTools`), the dispatcher refuses every
  // tool except suggest_follow_up_task and never touches the event entity.
  for (final foreign in const [
    'set_event_status',
    'set_event_rating',
    'set_event_cover',
    'set_task_status',
    'update_project_status',
    'update_report',
    'create_task',
  ]) {
    test(
      'refuses the non-follow-up tool "$foreign" and creates nothing',
      () async {
        final result = await dispatcher.dispatch(foreign, {'x': 1}, eventId);

        expect(result.success, isFalse);
        verifyNever(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        );
      },
    );
  }

  test('refuses to create a task when the event is gone', () async {
    when(
      () => mockJournalRepository.getJournalEntityById(eventId),
    ).thenAnswer((_) async => null);

    final result = await dispatcher.dispatch(
      EventAgentToolNames.suggestFollowUpTask,
      {'title': 'X'},
      eventId,
    );

    expect(result.success, isFalse);
    expect(result.errorMessage, contains('Event missing or deleted'));
    verifyNever(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    );
  });

  test('refuses to create a task when the event is soft-deleted', () async {
    final deletedEvent = JournalEntity.event(
      meta: Metadata(
        id: eventId,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: categoryId,
        deletedAt: now,
      ),
      data: const EventData(
        title: 'Trip',
        stars: 0,
        status: EventStatus.completed,
      ),
    );
    when(
      () => mockJournalRepository.getJournalEntityById(eventId),
    ).thenAnswer((_) async => deletedEvent);

    final result = await dispatcher.dispatch(
      EventAgentToolNames.suggestFollowUpTask,
      {'title': 'X'},
      eventId,
    );

    expect(result.success, isFalse);
    verifyNever(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    );
  });

  group('suggest_person', () {
    final pip = makeTestPerson(id: 'pip', title: 'Pip Penguin');

    void stubEntities({JournalEntity? person}) {
      when(
        () => mockJournalRepository.getJournalEntityById(eventId),
      ).thenAnswer((_) async => eventEntity);
      when(
        () => mockJournalRepository.getJournalEntityById('pip'),
      ).thenAnswer((_) async => person);
    }

    Future<ToolExecutionResult> accept() => dispatcher.dispatch(
      EventAgentToolNames.suggestPerson,
      {'personId': 'pip', 'personName': 'Pip Penguin'},
      eventId,
    );

    test("puts the event on the person's timeline", () async {
      stubEntities(person: pip);
      when(
        () => mockPersistenceLogic.createLink(
          fromId: 'pip',
          toId: eventId,
          linkType: EntryLinkType.relationship,
        ),
      ).thenAnswer((_) async => true);

      final result = await accept();

      expect(result.success, isTrue);
      expect(result.output, 'Added Pip Penguin to the event');
      expect(result.mutatedEntityId, eventId);
    });

    test('logs the link under the event-person subdomain', () async {
      final logger = MockDomainLogger();
      final logging = EventToolDispatcher(
        journalDb: mockJournalDb,
        journalRepository: mockJournalRepository,
        persistenceLogic: mockPersistenceLogic,
        entitiesCacheService: mockCache,
        domainLogger: logger,
      );
      stubEntities(person: pip);
      when(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => true);

      await logging.dispatch(
        EventAgentToolNames.suggestPerson,
        const {'personId': 'pip'},
        eventId,
      );

      verify(
        () => logger.log(
          LogDomain.agentRuntime,
          any(that: contains('linked person')),
          subDomain: 'event-person',
        ),
      ).called(1);
    });

    test('a link already there counts as done', () async {
      stubEntities(person: pip);
      when(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => mockJournalDb.linksBetween(
          'pip',
          eventId,
          type: 'RelationshipLink',
        ),
      ).thenAnswer(
        (_) async => [
          EntryLink.relationship(
            id: 'l',
            fromId: 'pip',
            toId: eventId,
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        ],
      );

      expect((await accept()).success, isTrue);
    });

    test('fails, retryably, when the link cannot be written', () async {
      stubEntities(person: pip);
      when(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => mockJournalDb.linksBetween(
          any(),
          any(),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => []);

      final result = await accept();

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Person link failed');
    });

    test('refuses while the person is gone, linking nothing', () async {
      stubEntities(
        person: pip.copyWith(meta: pip.meta.copyWith(deletedAt: now)),
      );

      final result = await accept();

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Person missing or deleted; not linked');
      verifyNever(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      );
    });

    test('refuses an id that is not a person', () async {
      stubEntities(person: eventEntity);

      expect((await accept()).success, isFalse);
    });

    test('refuses while the event is gone', () async {
      when(
        () => mockJournalRepository.getJournalEntityById(eventId),
      ).thenAnswer((_) async => null);

      final result = await accept();

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Event missing or deleted; person not linked',
      );
    });

    test('refuses a missing person id', () async {
      final result = await dispatcher.dispatch(
        EventAgentToolNames.suggestPerson,
        const {'personId': ' '},
        eventId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Missing personId');
    });
  });

  group('a confirmed proposal (ADR 0075)', () {
    const effect = ChangeEffect(key: 'event-set:0');
    final derivedId = effect.entityId('task');

    Future<ToolExecutionResult> accept() => dispatcher.dispatch(
      EventAgentToolNames.suggestFollowUpTask,
      effect.addTo({'title': 'Share the album'}),
      eventId,
    );

    void stubCreate(Task? created) => when(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
        uuidV5Input: any(named: 'uuidV5Input'),
      ),
    ).thenAnswer((_) async => created);

    test('creates the task under the id derived from the item', () async {
      stubCreate(createdTask.copyWith(meta: meta(derivedId)));

      final result = await accept();

      expect(result.success, isTrue);
      expect(result.mutatedEntityId, derivedId);
      final input = verify(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
          uuidV5Input: captureAny(named: 'uuidV5Input'),
        ),
      ).captured.single;
      expect(input, effect.entityInput('task'));
    });

    test(
      'creates nothing when the other device accepted it first, and names '
      'its task',
      () async {
        when(
          () => mockJournalDb.journalEntityMapForIdsIncludingDeleted([
            derivedId,
          ]),
        ).thenAnswer((_) async => {derivedId: createdTask});

        final result = await accept();

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, derivedId);
        verifyNever(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        );
      },
    );

    test(
      "reports success when the other device's task lands between the "
      'check and the write',
      () async {
        var lookups = 0;
        when(
          () => mockJournalDb.journalEntityMapForIdsIncludingDeleted([
            derivedId,
          ]),
        ).thenAnswer(
          (_) async => lookups++ == 0 ? const {} : {derivedId: createdTask},
        );
        // The insert refuses the id the synced task already holds.
        stubCreate(null);

        final result = await accept();

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, derivedId);
        expect(lookups, 2);
      },
    );

    // An earlier application can have stopped between the task and its
    // link to the event — the app died — so a run again links a live task
    // and creates nothing (`specs/tla/ChangeDispatchRecovery.tla`,
    // TailOnRerun); a task deleted since is left unlinked.
    for (final live in [true, false]) {
      test('a task found from an earlier run is '
          '${live ? 'linked to the event' : 'left alone, deleted'}', () async {
        when(
          () => mockJournalDb.journalEntityMapForIdsIncludingDeleted([
            derivedId,
          ]),
        ).thenAnswer((_) async => {derivedId: createdTask});
        when(
          () => mockJournalDb.journalEntityById(derivedId),
        ).thenAnswer((_) async => live ? createdTask : null);
        Future<bool> link() =>
            mockPersistenceLogic.createLink(fromId: eventId, toId: derivedId);
        when(link).thenAnswer((_) async => true);

        final result = await accept();

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, derivedId);
        if (live) {
          verify(link).called(1);
        } else {
          verifyNever(link);
        }
        verifyNever(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
            uuidV5Input: any(named: 'uuidV5Input'),
          ),
        );
      });
    }

    test('a task found from an earlier run whose link cannot be written '
        'fails retryably', () async {
      when(
        () => mockJournalDb.journalEntityMapForIdsIncludingDeleted([
          derivedId,
        ]),
      ).thenAnswer((_) async => {derivedId: createdTask});
      when(
        () => mockJournalDb.journalEntityById(derivedId),
      ).thenAnswer((_) async => createdTask);
      when(
        () => mockPersistenceLogic.createLink(fromId: eventId, toId: derivedId),
      ).thenAnswer((_) async => false);
      when(
        () => mockJournalDb.linksBetween(
          eventId,
          derivedId,
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => const []);

      final result = await accept();

      expect(result.success, isFalse);
      expect(result.nonRetryable, isFalse);
      expect(result.errorMessage, 'Follow-up task link failed');
    });

    test('still fails when the write fails and no task exists', () async {
      stubCreate(null);

      final result = await accept();

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Task creation failed');
    });
  });
}
