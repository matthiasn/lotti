import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/task_link_handler.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late MockDomainLogger mockDomainLogger;
  late TaskLinkHandler handler;

  const sourceTaskId = 'source-task-001';
  const targetTaskId = 'target-task-001';
  final testDate = DateTime(2024, 6, 15, 12);

  Task makeTask(String id, {String title = 'Target Task'}) {
    return Task(
      meta: Metadata(
        id: id,
        dateFrom: testDate,
        dateTo: testDate,
        createdAt: testDate,
        updatedAt: testDate,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: id,
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: title,
      ),
    );
  }

  EntryLink makeLink({
    required String fromId,
    required String toId,
    required EntryLinkType type,
    bool? hidden,
    DateTime? deletedAt,
  }) => type.buildLink(
    id: 'link-$fromId-$toId-${type.name}',
    fromId: fromId,
    toId: toId,
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
    hidden: hidden,
    deletedAt: deletedAt,
  );

  setUp(() {
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();
    mockDomainLogger = MockDomainLogger();

    handler = TaskLinkHandler(
      persistenceLogic: mockPersistenceLogic,
      journalDb: mockJournalDb,
      domainLogger: mockDomainLogger,
    );

    when(
      () => mockJournalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockJournalDb.journalEntityById(targetTaskId),
    ).thenAnswer((_) async => makeTask(targetTaskId));
    when(
      () => mockJournalDb.typedLinksForTaskIds(
        any(),
        types: any(named: 'types'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => mockPersistenceLogic.createLink(
        fromId: any(named: 'fromId'),
        toId: any(named: 'toId'),
        linkType: any(named: 'linkType'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => mockDomainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);
  });

  void verifyNoLinkWritten() {
    verifyNever(
      () => mockPersistenceLogic.createLink(
        fromId: any(named: 'fromId'),
        toId: any(named: 'toId'),
        linkType: any(named: 'linkType'),
      ),
    );
  }

  group('TaskLinkHandler validation', () {
    test('rejects a missing relation and lists the vocabulary', () async {
      final result = await handler.handle(sourceTaskId, {
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Invalid relation');
      expect(result.output, contains('is_blocked_by'));
      expect(result.output, contains('is_superseded_by'));
      verifyNoLinkWritten();
    });

    test('rejects an unknown relation phrase', () async {
      final result = await handler.handle(sourceTaskId, {
        'relation': 'parent_of',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Invalid relation');
      verifyNoLinkWritten();
    });

    test('rejects a missing targetTaskId', () async {
      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Missing targetTaskId');
      verifyNoLinkWritten();
    });

    test('rejects linking a task to itself', () async {
      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
        'targetTaskId': sourceTaskId,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Self-link rejected');
      verifyNoLinkWritten();
    });

    test('rejects a target that does not exist', () async {
      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
        'targetTaskId': 'no-such-task',
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Target task lookup failed');
      verifyNoLinkWritten();
    });

    test('rejects a target that is not a Task', () async {
      when(
        () => mockJournalDb.journalEntityById('entry-001'),
      ).thenAnswer(
        (_) async => JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-001',
            dateFrom: testDate,
            dateTo: testDate,
            createdAt: testDate,
            updatedAt: testDate,
          ),
        ),
      );

      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
        'targetTaskId': 'entry-001',
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Target task lookup failed');
      verifyNoLinkWritten();
    });

    test('rejects a tombstoned target task', () async {
      final deleted = makeTask(targetTaskId);
      when(
        () => mockJournalDb.journalEntityById(targetTaskId),
      ).thenAnswer(
        (_) async => deleted.copyWith(
          meta: deleted.meta.copyWith(deletedAt: testDate),
        ),
      );

      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Target task lookup failed');
      verifyNoLinkWritten();
    });
  });

  group('TaskLinkHandler direction semantics', () {
    test('"blocks" stores the anchor as the blocker', () async {
      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isTrue);
      expect(result.mutatedEntityId, targetTaskId);
      verify(
        () => mockPersistenceLogic.createLink(
          fromId: sourceTaskId,
          toId: targetTaskId,
          linkType: EntryLinkType.blocks,
        ),
      ).called(1);
    });

    test('"is_blocked_by" stores the target as the blocker', () async {
      final result = await handler.handle(sourceTaskId, {
        'relation': 'is_blocked_by',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isTrue);
      verify(
        () => mockPersistenceLogic.createLink(
          fromId: targetTaskId,
          toId: sourceTaskId,
          linkType: EntryLinkType.blocks,
        ),
      ).called(1);
    });

    test('"is_superseded_by" stores the target as the superseder', () async {
      final result = await handler.handle(sourceTaskId, {
        'relation': 'is_superseded_by',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isTrue);
      verify(
        () => mockPersistenceLogic.createLink(
          fromId: targetTaskId,
          toId: sourceTaskId,
          linkType: EntryLinkType.supersedes,
        ),
      ).called(1);
    });

    test('trims whitespace from the target id before resolving', () async {
      final result = await handler.handle(sourceTaskId, {
        'relation': 'relates_to',
        'targetTaskId': '  $targetTaskId ',
      });

      expect(result.success, isTrue);
      verify(
        () => mockPersistenceLogic.createLink(
          fromId: sourceTaskId,
          toId: targetTaskId,
          // Asserting the exact type written, even though it is the default.
          // ignore: avoid_redundant_argument_values
          linkType: EntryLinkType.basic,
        ),
      ).called(1);
    });

    glados.Glados(
      glados.AnyUtils(glados.any).choose(relationshipDirectedOptions),
      glados.ExploreConfig(numRuns: 40),
    ).test(
      'every relation writes exactly its canonical edge and type',
      (relation) async {
        final localPersistence = MockPersistenceLogic();
        final localDb = MockJournalDb();
        final localHandler = TaskLinkHandler(
          persistenceLogic: localPersistence,
          journalDb: localDb,
        );
        when(
          () => localDb.journalEntityById(targetTaskId),
        ).thenAnswer((_) async => makeTask(targetTaskId));
        when(
          () => localDb.typedLinksForTaskIds(
            any(),
            types: any(named: 'types'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => localPersistence.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: any(named: 'linkType'),
          ),
        ).thenAnswer((_) async => true);

        final result = await localHandler.handle(sourceTaskId, {
          'relation': relation.wireName,
          'targetTaskId': targetTaskId,
        });

        expect(result.success, isTrue, reason: '$relation');
        expect(
          result.output,
          contains(relation.englishPhrase),
          reason: '$relation',
        );
        final endpoints = relation.canonicalEndpoints(
          anchorId: sourceTaskId,
          otherId: targetTaskId,
        );
        verify(
          () => localPersistence.createLink(
            fromId: endpoints.fromId,
            toId: endpoints.toId,
            linkType: relation.type,
          ),
        ).called(1);
      },
      tags: 'glados',
    );
  });

  group('TaskLinkHandler existing-link precheck', () {
    test('reports success without writing when the edge already exists',
        () async {
      when(
        () => mockJournalDb.typedLinksForTaskIds(
          any(),
          types: any(named: 'types'),
        ),
      ).thenAnswer(
        (_) async => [
          makeLink(
            fromId: sourceTaskId,
            toId: targetTaskId,
            type: EntryLinkType.blocks,
          ),
        ],
      );

      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isTrue);
      expect(result.output, contains('Already linked'));
      expect(result.mutatedEntityId, isNull);
      verifyNoLinkWritten();
    });

    test('a tombstoned or hidden duplicate does not block creation', () async {
      when(
        () => mockJournalDb.typedLinksForTaskIds(
          any(),
          types: any(named: 'types'),
        ),
      ).thenAnswer(
        (_) async => [
          makeLink(
            fromId: sourceTaskId,
            toId: targetTaskId,
            type: EntryLinkType.blocks,
            deletedAt: testDate,
          ),
          makeLink(
            fromId: sourceTaskId,
            toId: targetTaskId,
            type: EntryLinkType.blocks,
            hidden: true,
          ),
        ],
      );

      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isTrue);
      expect(result.output, contains('Linked'));
      verify(
        () => mockPersistenceLogic.createLink(
          fromId: sourceTaskId,
          toId: targetTaskId,
          linkType: EntryLinkType.blocks,
        ),
      ).called(1);
    });

    test('the reverse direction of an existing edge is not a duplicate',
        () async {
      when(
        () => mockJournalDb.typedLinksForTaskIds(
          any(),
          types: any(named: 'types'),
        ),
      ).thenAnswer(
        (_) async => [
          // target blocks source — the OPPOSITE of what we are asserting.
          makeLink(
            fromId: targetTaskId,
            toId: sourceTaskId,
            type: EntryLinkType.blocks,
          ),
        ],
      );

      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isTrue);
      verify(
        () => mockPersistenceLogic.createLink(
          fromId: sourceTaskId,
          toId: targetTaskId,
          linkType: EntryLinkType.blocks,
        ),
      ).called(1);
    });

    test('a failing precheck falls through to createLink', () async {
      when(
        () => mockJournalDb.typedLinksForTaskIds(
          any(),
          types: any(named: 'types'),
        ),
      ).thenThrow(Exception('db down'));

      final result = await handler.handle(sourceTaskId, {
        'relation': 'blocks',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isTrue);
      verify(
        () => mockPersistenceLogic.createLink(
          fromId: sourceTaskId,
          toId: targetTaskId,
          linkType: EntryLinkType.blocks,
        ),
      ).called(1);
    });
  });

  group('TaskLinkHandler createLink refusal', () {
    test('a refused blocks edge is reported as a cycle', () async {
      when(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => false);

      final result = await handler.handle(sourceTaskId, {
        'relation': 'is_blocked_by',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('blocking cycle'));
    });

    test('a refused non-blocks edge reports a generic failure', () async {
      when(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => false);

      final result = await handler.handle(sourceTaskId, {
        'relation': 'supersedes',
        'targetTaskId': targetTaskId,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('could not be created'));
      expect(result.errorMessage, isNot(contains('cycle')));
    });
  });

  group('TaskLinkHandler output', () {
    test('names the relation and the target title', () async {
      when(
        () => mockJournalDb.journalEntityById(targetTaskId),
      ).thenAnswer(
        (_) async => makeTask(targetTaskId, title: 'Ship the migration'),
      );

      final result = await handler.handle(sourceTaskId, {
        'relation': 'is_blocked_by',
        'targetTaskId': targetTaskId,
      });

      expect(
        result.output,
        'Linked: this task is blocked by "Ship the migration"',
      );
    });
  });
}
