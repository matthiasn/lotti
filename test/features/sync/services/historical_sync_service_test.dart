import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as agent_model;
import 'package:lotti/features/agents/state/agent_providers.dart'
    show agentRepositoryProvider;
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/services/historical_sync_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../database/test_utils.dart' show clearAllTables;
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

JournalEntry _buildJournalEntry({
  required String id,
  required DateTime timestamp,
  required String text,
}) {
  return testTextEntry.copyWith(
    meta: testTextEntry.meta.copyWith(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
    ),
    entryText: EntryText(plainText: text),
  );
}

EntryLink _buildEntryLink({
  required String id,
  required String fromId,
  required String toId,
  required DateTime timestamp,
}) {
  return EntryLink.basic(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: timestamp,
    updatedAt: timestamp,
    vectorClock: const VectorClock({'node': 1}),
  );
}

Future<void> _insertEntries(JournalDb db, List<JournalEntity> entries) async {
  if (entries.isEmpty) return;

  await db.batch((batch) {
    batch.insertAll(
      db.journal,
      entries.map(toDbEntity).toList(),
      mode: InsertMode.insertOrReplace,
    );
  });
}

class _TrackingJournalDb extends JournalDb {
  _TrackingJournalDb() : super(inMemoryDatabase: true);

  final linkSourcePageSizes = <int>[];
  void Function()? onLinkRowsQuery;

  @override
  Future<List<LinkedDbEntry>> linkRowsFromIdsIncludingHidden(
    List<String> fromIds,
  ) {
    linkSourcePageSizes.add(fromIds.length);
    onLinkRowsQuery?.call();
    return super.linkRowsFromIdsIncludingHidden(fromIds);
  }
}

/// Preserves the old tests' per-call repository choice while exercising a
/// freshly assembled [HistoricalSyncService] with explicit dependencies.
class _HistoricalSyncHarness {
  _HistoricalSyncHarness({
    required this.journalDb,
    required this.outboxService,
    required this.vectorClockService,
    required this.logger,
  });

  final JournalDb journalDb;
  final OutboxService outboxService;
  final VectorClockService vectorClockService;
  final DomainLogger logger;

  Future<ReSyncResult> reSyncInterval({
    required DateTime start,
    required DateTime end,
    required AgentRepository agentRepository,
    bool includeJournalEntities = true,
    bool includeAgentEntities = true,
    ReSyncProgressCallback? onProgress,
  }) {
    return HistoricalSyncService(
      journalDb: journalDb,
      agentRepository: agentRepository,
      outboxService: outboxService,
      vectorClockService: vectorClockService,
      logger: logger,
    ).reSyncInterval(
      start: start,
      end: end,
      includeJournalEntities: includeJournalEntities,
      includeAgentEntities: includeAgentEntities,
      onProgress: onProgress,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(fallbackSyncMessage);
    registerFallbackValue(FakeMetadata());
  });

  group('HistoricalSyncService', () {
    late _TrackingJournalDb journalDb;
    late _HistoricalSyncHarness historicalSync;
    late MockOutboxService outboxService;
    late MockDomainLogger mockDomainLogger;
    late MockVectorClockService vectorClockService;
    late List<SyncMessage> sentMessages;
    late List<dynamic> loggedExceptions;

    setUpAll(() {
      journalDb = _TrackingJournalDb();
    });

    setUp(() async {
      await clearAllTables(journalDb);
      journalDb
        ..linkSourcePageSizes.clear()
        ..onLinkRowsQuery = null;

      outboxService = MockOutboxService();
      mockDomainLogger = MockDomainLogger();
      vectorClockService = MockVectorClockService();
      when(
        () => vectorClockService.getHost(),
      ).thenAnswer((_) async => 'test-host-id');

      sentMessages = [];
      loggedExceptions = [];
      when(() => outboxService.enqueueMessageOrThrow(any())).thenAnswer((
        invocation,
      ) async {
        sentMessages.add(invocation.positionalArguments.first as SyncMessage);
      });
      when(
        () => mockDomainLogger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      when(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
          message: any<String?>(named: 'message'),
        ),
      ).thenAnswer((invocation) {
        loggedExceptions.add(invocation.positionalArguments[1]);
      });

      historicalSync = _HistoricalSyncHarness(
        journalDb: journalDb,
        outboxService: outboxService,
        vectorClockService: vectorClockService,
        logger: mockDomainLogger,
      );
    });

    tearDownAll(() async {
      await journalDb.close();
    });

    group('reSyncInterval', () {
      late MockAgentRepository mockAgentRepo;

      setUp(() {
        mockAgentRepo = MockAgentRepository();
        when(
          () => mockAgentRepo.countEntitiesInInterval(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer((_) async => 0);
        when(
          () => mockAgentRepo.countLinksInInterval(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer((_) async => 0);
      });

      test('enqueues all journal entities inside interval', () async {
        final baseDate = DateTime(2024);
        final entries = List.generate(
          5,
          (index) => _buildJournalEntry(
            id: 'entry-$index',
            timestamp: baseDate.add(Duration(days: index)),
            text: 'Entry $index',
          ),
        );
        await _insertEntries(journalDb, entries);

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 5)),
          agentRepository: mockAgentRepo,
        );

        final journalMessages = sentMessages
            .whereType<SyncJournalEntity>()
            .toList();
        expect(journalMessages, hasLength(entries.length));
        expect(
          journalMessages.map((m) => m.id),
          containsAll(entries.map((e) => e.meta.id)),
        );
        verify(
          () => outboxService.enqueueMessageOrThrow(any()),
        ).called(entries.length);
      });

      // Regression: a re-sync is how a freshly provisioned device gets its
      // history, and that device holds none of the referenced media. Sending
      // the entries as plain updates left it with image and audio entries it
      // could never render — the JSON synced, the blobs never did.
      test('opts every re-sent entry into carrying its media', () async {
        final timestamp = DateTime(2024, 3, 10);
        await _insertEntries(journalDb, [
          _buildJournalEntry(
            id: 'media-entry',
            timestamp: timestamp,
            text: 'Has an image',
          ),
        ]);

        await historicalSync.reSyncInterval(
          start: timestamp.subtract(const Duration(days: 1)),
          end: timestamp.add(const Duration(days: 1)),
          agentRepository: mockAgentRepo,
          includeAgentEntities: false,
        );

        final journalMessages = sentMessages
            .whereType<SyncJournalEntity>()
            .toList();
        expect(journalMessages, hasLength(1));
        expect(journalMessages.single.includeAttachments, isTrue);
      });

      test(
        'isolates a journal enqueue failure and retries only that row',
        () async {
          final timestamp = DateTime(2024, 1, 15);
          await _insertEntries(journalDb, [
            _buildJournalEntry(
              id: 'before-failure',
              timestamp: timestamp,
              text: 'Before',
            ),
            _buildJournalEntry(
              id: 'enqueue-failure',
              timestamp: timestamp.add(const Duration(minutes: 1)),
              text: 'Failure',
            ),
            _buildJournalEntry(
              id: 'after-failure',
              timestamp: timestamp.add(const Duration(minutes: 2)),
              text: 'After',
            ),
          ]);
          var failTarget = true;
          when(
            () => outboxService.enqueueMessageOrThrow(any()),
          ).thenAnswer((invocation) async {
            final message =
                invocation.positionalArguments.single as SyncMessage;
            if (failTarget &&
                message is SyncJournalEntity &&
                message.id == 'enqueue-failure') {
              throw Exception('outbox write failed');
            }
            sentMessages.add(message);
          });

          final progress = <ReSyncProgress>[];
          final result = await historicalSync.reSyncInterval(
            start: timestamp.subtract(const Duration(days: 1)),
            end: timestamp.add(const Duration(days: 1)),
            agentRepository: mockAgentRepo,
            includeAgentEntities: false,
            onProgress: progress.add,
          );

          expect(
            sentMessages.whereType<SyncJournalEntity>().map((e) => e.id),
            ['before-failure', 'after-failure'],
          );
          expect(result.succeeded, 2);
          expect(result.total, 3);
          expect(result.failures, hasLength(1));
          expect(result.failures.single.itemId, 'enqueue-failure');
          expect(
            result.failures.single.itemType,
            ReSyncItemType.journalEntity,
          );
          expect(loggedExceptions, hasLength(1));
          final journalDone = progress
              .where(
                (snapshot) =>
                    snapshot.phase == ReSyncPhase.journalEntities &&
                    snapshot.isComplete,
              )
              .single;
          expect(journalDone.failed, 1);
          expect(journalDone.succeeded, 2);

          failTarget = false;
          final retryProgress = <ReSyncProgress>[];
          final retried = await result.retryFailures(
            onProgress: retryProgress.add,
          );

          expect(retried.succeeded, 3);
          expect(retried.failures, isEmpty);
          final retryDone = retryProgress.singleWhere(
            (snapshot) => snapshot.isComplete,
          );
          expect(retryDone.processed, 1);
          expect(retryDone.succeeded, 1);
          expect(retryDone.failed, 0);
          expect(
            sentMessages.whereType<SyncJournalEntity>().map((e) => e.id),
            ['before-failure', 'after-failure', 'enqueue-failure'],
            reason: 'successful rows must not be queued again during retry',
          );
        },
      );

      test('isolates a malformed journal row before enqueue', () async {
        final timestamp = DateTime(2024, 1, 16);
        await _insertEntries(journalDb, [
          _buildJournalEntry(
            id: 'before-malformed',
            timestamp: timestamp,
            text: 'Before',
          ),
          _buildJournalEntry(
            id: 'malformed-journal',
            timestamp: timestamp.add(const Duration(minutes: 1)),
            text: 'Malformed',
          ),
          _buildJournalEntry(
            id: 'after-malformed',
            timestamp: timestamp.add(const Duration(minutes: 2)),
            text: 'After',
          ),
        ]);
        final malformedRow = await journalDb.entriesForIds([
          'malformed-journal',
        ]).getSingle();
        await journalDb
            .into(journalDb.journal)
            .insert(
              malformedRow.copyWith(serialized: '{not-json'),
              mode: InsertMode.insertOrReplace,
            );

        final result = await historicalSync.reSyncInterval(
          start: timestamp.subtract(const Duration(hours: 1)),
          end: timestamp.add(const Duration(hours: 1)),
          agentRepository: mockAgentRepo,
          includeAgentEntities: false,
        );

        expect(
          sentMessages.whereType<SyncJournalEntity>().map((entry) => entry.id),
          ['before-malformed', 'after-malformed'],
        );
        expect(result.succeeded, 2);
        expect(result.failures, hasLength(1));
        expect(result.failures.single.itemId, 'malformed-journal');
        expect(result.failures.single.error, isA<FormatException>());
        expect(loggedExceptions, hasLength(1));

        final retried = await result.retryFailures();

        expect(retried.succeeded, 2);
        expect(retried.failures, hasLength(1));
        expect(retried.failures.single.itemId, 'malformed-journal');
        expect(loggedExceptions, hasLength(2));
        expect(
          sentMessages.whereType<SyncJournalEntity>().map((entry) => entry.id),
          ['before-malformed', 'after-malformed'],
          reason: 'retry must not replay rows that were already queued',
        );
      });

      test(
        'defers entry links until their parent queues successfully',
        () async {
          final timestamp = DateTime(2024, 1, 17);
          final parent = _buildJournalEntry(
            id: 'parent-entry',
            timestamp: timestamp,
            text: 'Parent',
          );
          final target = _buildJournalEntry(
            id: 'target-entry',
            timestamp: timestamp.add(const Duration(minutes: 1)),
            text: 'Target',
          );
          await _insertEntries(journalDb, [parent, target]);
          await journalDb.upsertEntryLink(
            _buildEntryLink(
              id: 'dependent-link',
              fromId: parent.id,
              toId: 'target-entry',
              timestamp: timestamp,
            ),
          );
          var failParent = true;
          final attempts = <String>[];
          when(
            () => outboxService.enqueueMessageOrThrow(any()),
          ).thenAnswer((invocation) async {
            final message =
                invocation.positionalArguments.single as SyncMessage;
            switch (message) {
              case SyncJournalEntity(:final id):
                attempts.add(id);
                if (failParent && id == parent.id) {
                  throw StateError('parent unavailable');
                }
              case SyncEntryLink(:final entryLink):
                attempts.add(entryLink.id);
              default:
            }
            sentMessages.add(message);
          });

          final result = await historicalSync.reSyncInterval(
            start: timestamp.subtract(const Duration(hours: 1)),
            end: timestamp.add(const Duration(hours: 1)),
            agentRepository: mockAgentRepo,
            includeAgentEntities: false,
          );

          expect(attempts, ['parent-entry', 'target-entry']);
          expect(result.succeeded, 1);
          expect(result.failures, hasLength(2));
          expect(
            result.failures.map((failure) => failure.itemId),
            ['parent-entry', 'dependent-link'],
          );
          expect(loggedExceptions, hasLength(2));

          final stillFailing = await result.retryFailures();

          expect(
            attempts,
            ['parent-entry', 'target-entry', 'parent-entry'],
          );
          expect(stillFailing.failures, hasLength(2));
          expect(loggedExceptions, hasLength(4));

          failParent = false;
          final retried = await stillFailing.retryFailures();

          expect(retried.succeeded, 3);
          expect(retried.failures, isEmpty);
          expect(
            attempts,
            [
              'parent-entry',
              'target-entry',
              'parent-entry',
              'parent-entry',
              'dependent-link',
            ],
            reason: 'the parent retry must complete before its link is queued',
          );
          expect(sentMessages, hasLength(3));
        },
      );

      test('defers an entry link until its target queues', () async {
        final timestamp = DateTime(2024, 1, 17, 12);
        final source = _buildJournalEntry(
          id: 'link-source',
          timestamp: timestamp,
          text: 'Source',
        );
        final target = _buildJournalEntry(
          id: 'link-target',
          timestamp: timestamp.add(const Duration(minutes: 100)),
          text: 'Target',
        );
        final fillers = List.generate(
          99,
          (index) => _buildJournalEntry(
            id: 'link-filler-$index',
            timestamp: timestamp.add(Duration(minutes: index + 1)),
            text: 'Filler $index',
          ),
        );
        await _insertEntries(journalDb, [source, ...fillers, target]);
        await journalDb.upsertEntryLink(
          _buildEntryLink(
            id: 'target-dependent-link',
            fromId: source.id,
            toId: target.id,
            timestamp: timestamp,
          ),
        );
        var failTarget = true;
        final attempts = <String>[];
        final entityAttemptsAtLinkQuery = <int>[];
        journalDb.onLinkRowsQuery = () {
          entityAttemptsAtLinkQuery.add(attempts.length);
        };
        when(
          () => outboxService.enqueueMessageOrThrow(any()),
        ).thenAnswer((invocation) async {
          final message = invocation.positionalArguments.single as SyncMessage;
          switch (message) {
            case SyncJournalEntity(:final id):
              attempts.add(id);
              if (failTarget && id == target.id) {
                throw StateError('target unavailable');
              }
            case SyncEntryLink(:final entryLink):
              attempts.add(entryLink.id);
            default:
          }
          sentMessages.add(message);
        });

        final result = await historicalSync.reSyncInterval(
          start: timestamp.subtract(const Duration(hours: 1)),
          end: timestamp.add(const Duration(hours: 3)),
          agentRepository: mockAgentRepo,
          includeAgentEntities: false,
        );

        expect(attempts, hasLength(101));
        expect(attempts.first, source.id);
        expect(attempts.last, target.id);
        expect(attempts, isNot(contains('target-dependent-link')));
        expect(journalDb.linkSourcePageSizes, [100, 1]);
        expect(
          entityAttemptsAtLinkQuery,
          [101, 101],
          reason: 'link payload pages are read only after every entity attempt',
        );
        expect(
          result.failures.map((failure) => failure.itemId),
          ['link-target', 'target-dependent-link'],
        );

        failTarget = false;
        final retried = await result.retryFailures();

        expect(retried.failures, isEmpty);
        expect(attempts, hasLength(103));
        expect(attempts[101], target.id);
        expect(attempts.last, 'target-dependent-link');
      });

      test('isolates a malformed entry-link row before enqueue', () async {
        final timestamp = DateTime(2024, 1, 18);
        final parent = _buildJournalEntry(
          id: 'valid-link-parent',
          timestamp: timestamp,
          text: 'Parent',
        );
        final target = _buildJournalEntry(
          id: 'valid-link-target',
          timestamp: timestamp.add(const Duration(minutes: 1)),
          text: 'Target',
        );
        await _insertEntries(journalDb, [parent, target]);
        await journalDb.upsertEntryLink(
          _buildEntryLink(
            id: 'malformed-entry-link',
            fromId: parent.id,
            toId: target.id,
            timestamp: timestamp,
          ),
        );
        final malformedLinkRow = await journalDb.linksFromIds([
          parent.id,
        ]).getSingle();
        await journalDb
            .into(journalDb.linkedEntries)
            .insert(
              malformedLinkRow.copyWith(serialized: '{not-json'),
              mode: InsertMode.insertOrReplace,
            );

        final result = await historicalSync.reSyncInterval(
          start: timestamp.subtract(const Duration(hours: 1)),
          end: timestamp.add(const Duration(hours: 1)),
          agentRepository: mockAgentRepo,
          includeAgentEntities: false,
        );

        expect(result.succeeded, 2);
        expect(result.failures, hasLength(1));
        expect(result.failures.single.itemId, 'malformed-entry-link');
        expect(result.failures.single.itemType, ReSyncItemType.entryLink);
        expect(result.failures.single.error, isA<FormatException>());
        expect(sentMessages.whereType<SyncJournalEntity>(), hasLength(2));
        expect(sentMessages.whereType<SyncEntryLink>(), isEmpty);

        final retried = await result.retryFailures();

        expect(retried.succeeded, 2);
        expect(retried.failures, hasLength(1));
        expect(retried.failures.single.itemId, 'malformed-entry-link');
        expect(loggedExceptions, hasLength(2));
      });

      test('handles pagination beyond the default page size', () async {
        final baseDate = DateTime(2024, 2);
        final entries = List.generate(
          350,
          (index) => _buildJournalEntry(
            id: 'paginated-$index',
            timestamp: baseDate.add(Duration(minutes: index)),
            text: 'Paginated entry $index',
          ),
        );
        await _insertEntries(journalDb, entries);

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 2)),
          agentRepository: mockAgentRepo,
        );

        final journalMessages = sentMessages
            .whereType<SyncJournalEntity>()
            .toList();
        expect(journalMessages, hasLength(entries.length));
      });

      test('enqueues linked entry messages for linked entities', () async {
        final baseDate = DateTime(2024, 3);
        final entryA = _buildJournalEntry(
          id: 'linked-A',
          timestamp: baseDate,
          text: 'Linked entry A',
        );
        final entryB = _buildJournalEntry(
          id: 'linked-B',
          timestamp: baseDate.add(const Duration(minutes: 5)),
          text: 'Linked entry B',
        );
        await _insertEntries(journalDb, [entryA, entryB]);

        final link = _buildEntryLink(
          id: 'link-1',
          fromId: entryA.meta.id,
          toId: entryB.meta.id,
          timestamp: baseDate,
        );
        await journalDb.upsertEntryLink(link);

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(hours: 1)),
          end: baseDate.add(const Duration(hours: 1)),
          agentRepository: mockAgentRepo,
        );

        final journalMessages = sentMessages
            .whereType<SyncJournalEntity>()
            .toList();
        final linkMessages = sentMessages.whereType<SyncEntryLink>().toList();

        expect(journalMessages, hasLength(2));
        expect(linkMessages, hasLength(1));
        expect(linkMessages.first.entryLink.id, equals(link.id));
      });

      test('enqueues hidden entry links as replicated state', () async {
        final timestamp = DateTime(2024, 3, 2);
        final source = _buildJournalEntry(
          id: 'hidden-source',
          timestamp: timestamp,
          text: 'Source',
        );
        final target = _buildJournalEntry(
          id: 'hidden-target',
          timestamp: timestamp.add(const Duration(minutes: 1)),
          text: 'Target',
        );
        await _insertEntries(journalDb, [source, target]);
        await journalDb.upsertEntryLink(
          EntryLink.basic(
            id: 'hidden-history-link',
            fromId: source.id,
            toId: target.id,
            createdAt: timestamp,
            updatedAt: timestamp,
            vectorClock: const VectorClock({'node': 1}),
            hidden: true,
          ),
        );

        await historicalSync.reSyncInterval(
          start: timestamp.subtract(const Duration(hours: 1)),
          end: timestamp.add(const Duration(hours: 1)),
          agentRepository: mockAgentRepo,
          includeAgentEntities: false,
        );

        final link = sentMessages.whereType<SyncEntryLink>().single.entryLink;
        expect(link.id, 'hidden-history-link');
        expect(link.hidden, isTrue);
      });

      test('reports paged journal progress through completion', () async {
        final baseDate = DateTime(2024, 3);
        final entryA = _buildJournalEntry(
          id: 'progress-A',
          timestamp: baseDate,
          text: 'Progress A',
        );
        final entryB = _buildJournalEntry(
          id: 'progress-B',
          timestamp: baseDate.add(const Duration(minutes: 5)),
          text: 'Progress B',
        );
        await _insertEntries(journalDb, [entryA, entryB]);
        await journalDb.upsertEntryLink(
          _buildEntryLink(
            id: 'progress-link',
            fromId: entryA.meta.id,
            toId: entryB.meta.id,
            timestamp: baseDate,
          ),
        );
        final progress = <ReSyncProgress>[];

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(hours: 1)),
          end: baseDate.add(const Duration(hours: 1)),
          agentRepository: mockAgentRepo,
          includeAgentEntities: false,
          onProgress: progress.add,
        );

        expect(progress.first.phase, ReSyncPhase.journalEntities);
        expect(progress.first.processed, 0);
        expect(progress.first.total, isNull);
        expect(progress.first.isComplete, isFalse);
        expect(
          progress.any(
            (event) =>
                event.phase == ReSyncPhase.journalEntities &&
                event.processed == 2 &&
                !event.isComplete,
          ),
          isTrue,
        );
        expect(progress.last.phase, ReSyncPhase.journalEntities);
        expect(progress.last.processed, 3);
        expect(progress.last.total, 3);
        expect(progress.last.isComplete, isTrue);
      });

      test('filters journal entities by provided date range', () async {
        final baseDate = DateTime(2024, 4);
        final beforeEntry = _buildJournalEntry(
          id: 'before',
          timestamp: baseDate.subtract(const Duration(days: 2)),
          text: 'Outside before',
        );
        final insideEntry = _buildJournalEntry(
          id: 'inside',
          timestamp: baseDate,
          text: 'Inside range',
        );
        final afterEntry = _buildJournalEntry(
          id: 'after',
          timestamp: baseDate.add(const Duration(days: 2)),
          text: 'Outside after',
        );
        await _insertEntries(journalDb, [beforeEntry, insideEntry, afterEntry]);

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: mockAgentRepo,
        );

        final journalMessages = sentMessages
            .whereType<SyncJournalEntity>()
            .toList();

        expect(journalMessages, hasLength(1));
        expect(journalMessages.first.id, equals(insideEntry.meta.id));
      });

      test(
        'completes without enqueuing messages for empty intervals',
        () async {
          await historicalSync.reSyncInterval(
            start: DateTime(2024, 5),
            end: DateTime(2024, 5, 2),
            agentRepository: mockAgentRepo,
          );

          expect(sentMessages, isEmpty);
        },
      );

      test('includes relative entity path in enqueued messages', () async {
        final timestamp = DateTime(2024, 6, 15, 10, 30);
        final entry = _buildJournalEntry(
          id: 'path-test',
          timestamp: timestamp,
          text: 'Check path',
        );
        await _insertEntries(journalDb, [entry]);

        await historicalSync.reSyncInterval(
          start: timestamp.subtract(const Duration(hours: 1)),
          end: timestamp.add(const Duration(hours: 1)),
          agentRepository: mockAgentRepo,
        );

        final journalMessage = sentMessages
            .whereType<SyncJournalEntity>()
            .single;

        expect(
          journalMessage.jsonPath,
          equals('/text_entries/2024-06-15/path-test.text.json'),
        );
      });
    });

    group('reSyncInterval – agent entities and links', () {
      late AgentDatabase agentDb;
      late AgentRepository agentRepo;

      setUp(() {
        agentDb = AgentDatabase(inMemoryDatabase: true);
        agentRepo = AgentRepository(agentDb);
      });

      tearDown(() async {
        await agentDb.close();
      });

      /// Populates the in-memory agent DB with the given entities/links.
      Future<void> populateAgentDb({
        List<AgentDomainEntity> entities = const [],
        List<agent_model.AgentLink> links = const [],
      }) async {
        for (final entity in entities) {
          await agentRepo.upsertEntity(entity);
        }
        for (final link in links) {
          await agentRepo.upsertLink(link);
        }
      }

      test(
        'isolates failures across every historical payload family',
        () async {
          final timestamp = DateTime(2025, 1, 10, 9);
          final journalFailure = _buildJournalEntry(
            id: 'journal-failure',
            timestamp: timestamp,
            text: 'Fails once',
          );
          final journalSuccess = _buildJournalEntry(
            id: 'journal-success',
            timestamp: timestamp.add(const Duration(minutes: 1)),
            text: 'Still queues',
          );
          await _insertEntries(journalDb, [journalFailure, journalSuccess]);
          await journalDb.upsertEntryLink(
            _buildEntryLink(
              id: 'entry-link-failure',
              fromId: journalFailure.meta.id,
              toId: journalSuccess.meta.id,
              timestamp: timestamp,
            ),
          );

          final agentFailure = AgentDomainEntity.agent(
            id: 'agent-entity-failure',
            agentId: 'agent-1',
            kind: 'task_agent',
            displayName: 'Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'agent-state-success',
            config: const AgentConfig(),
            createdAt: timestamp,
            updatedAt: timestamp,
            vectorClock: const VectorClock({'node': 1}),
          );
          final agentSuccess = AgentDomainEntity.agentState(
            id: 'agent-state-success',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: timestamp,
            vectorClock: const VectorClock({'node': 2}),
          );
          final agentLinkFailure = agent_model.AgentLink.agentState(
            id: 'agent-link-failure',
            fromId: 'agent-1',
            toId: agentSuccess.id,
            createdAt: timestamp,
            updatedAt: timestamp,
            vectorClock: const VectorClock({'node': 3}),
          );
          await populateAgentDb(
            entities: [agentFailure, agentSuccess],
            links: [agentLinkFailure],
          );

          var failTargets = true;
          when(
            () => outboxService.enqueueMessageOrThrow(any()),
          ).thenAnswer((invocation) async {
            final message =
                invocation.positionalArguments.single as SyncMessage;
            final isTarget = switch (message) {
              SyncJournalEntity(:final id) => id == journalFailure.id,
              SyncEntryLink(:final entryLink) =>
                entryLink.id == 'entry-link-failure',
              SyncAgentEntity(:final agentEntity) =>
                agentEntity?.id == agentFailure.id,
              SyncAgentLink(:final agentLink) =>
                agentLink?.id == 'agent-link-failure',
              _ => false,
            };
            if (failTargets && isTarget) {
              throw StateError('simulated ${message.runtimeType} failure');
            }
            sentMessages.add(message);
          });

          final result = await historicalSync.reSyncInterval(
            start: timestamp.subtract(const Duration(hours: 1)),
            end: timestamp.add(const Duration(hours: 1)),
            agentRepository: agentRepo,
          );

          expect(result.total, 6);
          expect(result.succeeded, 2);
          expect(
            result.failures.map((failure) => failure.itemType).toSet(),
            ReSyncItemType.values.toSet(),
          );
          expect(
            sentMessages.map((message) => message.runtimeType).toSet(),
            {SyncJournalEntity, SyncAgentEntity},
            reason: 'each failed row must leave later phases running',
          );
          expect(loggedExceptions, hasLength(4));

          failTargets = false;
          final retried = await result.retryFailures();

          expect(retried.succeeded, 6);
          expect(retried.failures, isEmpty);
          expect(sentMessages, hasLength(6));
          verify(
            () => outboxService.enqueueMessageOrThrow(any()),
          ).called(9);
        },
      );

      test('defers an agent link until its entity endpoint queues', () async {
        final timestamp = DateTime(2025, 1, 10, 12);
        final identity = AgentDomainEntity.agent(
          id: 'dependency-agent',
          agentId: 'dependency-agent',
          kind: 'task_agent',
          displayName: 'Dependency Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'dependency-state',
          config: const AgentConfig(),
          createdAt: timestamp,
          updatedAt: timestamp,
          vectorClock: const VectorClock({'node': 1}),
        );
        final state = AgentDomainEntity.agentState(
          id: 'dependency-state',
          agentId: identity.id,
          slots: const AgentSlots(),
          updatedAt: timestamp.add(const Duration(minutes: 1)),
          vectorClock: const VectorClock({'node': 2}),
        );
        final link = agent_model.AgentLink.agentState(
          id: 'dependency-agent-link',
          fromId: identity.id,
          toId: state.id,
          createdAt: timestamp,
          updatedAt: timestamp,
          vectorClock: const VectorClock({'node': 3}),
        );
        await populateAgentDb(entities: [identity, state], links: [link]);
        var failState = true;
        final attempts = <String>[];
        when(
          () => outboxService.enqueueMessageOrThrow(any()),
        ).thenAnswer((invocation) async {
          final message = invocation.positionalArguments.single as SyncMessage;
          switch (message) {
            case SyncAgentEntity(:final agentEntity):
              final id = agentEntity!.id;
              attempts.add(id);
              if (failState && id == state.id) {
                throw StateError('state unavailable');
              }
            case SyncAgentLink(:final agentLink):
              attempts.add(agentLink!.id);
            default:
          }
          sentMessages.add(message);
        });

        final result = await historicalSync.reSyncInterval(
          start: timestamp.subtract(const Duration(hours: 1)),
          end: timestamp.add(const Duration(hours: 1)),
          agentRepository: agentRepo,
          includeJournalEntities: false,
        );

        expect(attempts, [identity.id, state.id]);
        expect(
          result.failures.map((failure) => failure.itemId),
          [state.id, link.id],
        );
        expect(result.hasFailures, isTrue);

        final stillFailing = await result.retryFailures();

        expect(
          stillFailing.failures.map((failure) => failure.itemId),
          [state.id, link.id],
        );
        expect(attempts, [identity.id, state.id, state.id]);

        failState = false;
        final retried = await stillFailing.retryFailures();

        expect(retried.failures, isEmpty);
        expect(retried.hasFailures, isFalse);
        expect(
          attempts,
          [identity.id, state.id, state.id, state.id, link.id],
        );
      });

      test('isolates malformed agent entity and link rows', () async {
        final timestamp = DateTime(2025, 1, 11, 9);
        final malformedEntity = AgentDomainEntity.agent(
          id: 'malformed-agent-entity',
          agentId: 'agent-1',
          kind: 'task_agent',
          displayName: 'Malformed agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'valid-agent-entity',
          config: const AgentConfig(),
          createdAt: timestamp,
          updatedAt: timestamp,
          vectorClock: const VectorClock({'node': 1}),
        );
        final validEntity = AgentDomainEntity.agentState(
          id: 'valid-agent-entity',
          agentId: 'agent-1',
          revision: 2,
          slots: const AgentSlots(),
          updatedAt: timestamp.add(const Duration(minutes: 1)),
          vectorClock: const VectorClock({'node': 2}),
        );
        final malformedLink = agent_model.AgentLink.agentState(
          id: 'malformed-agent-link',
          fromId: 'agent-1',
          toId: malformedEntity.id,
          createdAt: timestamp,
          updatedAt: timestamp,
          vectorClock: const VectorClock({'node': 3}),
        );
        final validLink = agent_model.AgentLink.agentState(
          id: 'valid-agent-link',
          fromId: 'agent-1',
          toId: validEntity.id,
          createdAt: timestamp,
          updatedAt: timestamp.add(const Duration(minutes: 1)),
          vectorClock: const VectorClock({'node': 4}),
        );
        await populateAgentDb(
          entities: [malformedEntity, validEntity],
          links: [malformedLink, validLink],
        );
        final malformedEntityRow = await agentDb
            .getAgentEntityById(malformedEntity.id)
            .getSingle();
        await agentDb
            .into(agentDb.agentEntities)
            .insert(
              malformedEntityRow.copyWith(serialized: '{not-json'),
              mode: InsertMode.insertOrReplace,
            );
        final malformedLinkRow = await agentDb
            .getAgentLinkById(malformedLink.id)
            .getSingle();
        await agentDb
            .into(agentDb.agentLinks)
            .insert(
              malformedLinkRow.copyWith(serialized: '{not-json'),
              mode: InsertMode.insertOrReplace,
            );

        final result = await historicalSync.reSyncInterval(
          start: timestamp.subtract(const Duration(hours: 1)),
          end: timestamp.add(const Duration(hours: 1)),
          agentRepository: agentRepo,
          includeJournalEntities: false,
        );

        expect(result.succeeded, 2);
        expect(result.failures, hasLength(2));
        expect(
          result.failures.map((failure) => failure.itemId).toSet(),
          {malformedEntity.id, malformedLink.id},
        );
        expect(
          sentMessages.whereType<SyncAgentEntity>().map(
            (message) => message.agentEntity?.id,
          ),
          [validEntity.id],
        );
        expect(
          sentMessages.whereType<SyncAgentLink>().map(
            (message) => message.agentLink?.id,
          ),
          [validLink.id],
        );
        expect(loggedExceptions, hasLength(2));

        final retried = await result.retryFailures();

        expect(retried.succeeded, 2);
        expect(retried.failures, hasLength(2));
        expect(loggedExceptions, hasLength(4));
        expect(sentMessages, hasLength(2));
      });

      test('enqueues agent entities updated within interval', () async {
        final baseDate = DateTime(2024, 10);
        final insideDate = baseDate.add(const Duration(hours: 12));

        final agentEntity = AgentDomainEntity.agent(
          id: 'agent-entity-1',
          agentId: 'agent-1',
          kind: 'task_agent',
          displayName: 'Test Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        await populateAgentDb(entities: [agentEntity]);

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final agentMessages = sentMessages
            .whereType<SyncAgentEntity>()
            .toList();
        expect(agentMessages, hasLength(1));
        expect(
          agentMessages.first.agentEntity?.id,
          equals('agent-entity-1'),
        );
      });

      test('stamps a clockless agent entity before enqueueing it', () async {
        // A row persisted with vectorClock: null is applied by the peer but
        // skipped by _recordReceivedAgentEntity, so it lands invisible to the
        // sequence log and to backfill. The sweep is the last place it can
        // still be fixed, and stamping here rather than in a preflight keeps
        // the repair inside the interval the user actually chose.
        final baseDate = DateTime(2024, 10);
        final insideDate = baseDate.add(const Duration(hours: 12));
        const stamped = VectorClock({'node': 7});

        when(
          () => vectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
          ),
        ).thenAnswer((_) async => stamped);
        await populateAgentDb(
          entities: [
            AgentDomainEntity.agent(
              id: 'clockless-entity',
              agentId: 'agent-1',
              kind: 'task_agent',
              displayName: 'Clockless Agent',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: 'state-1',
              config: const AgentConfig(),
              createdAt: insideDate,
              updatedAt: insideDate,
              vectorClock: null,
            ),
          ],
        );

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final sent = sentMessages.whereType<SyncAgentEntity>().toList();
        expect(sent, hasLength(1));
        // The message carries the clock, not the null it was stored with.
        expect(sent.first.agentEntity?.vectorClock, stamped);
        // And the repair is durable, not just applied to the outgoing copy.
        final reloaded = await agentRepo.getEntity('clockless-entity');
        expect(reloaded?.vectorClock, stamped);
      });

      test('enqueues agent links updated within interval', () async {
        final baseDate = DateTime(2024, 11);
        final insideDate = baseDate.add(const Duration(hours: 6));

        // Need an entity so the link's fromId/toId are valid.
        final entity = AgentDomainEntity.agent(
          id: 'agent-link-entity',
          agentId: 'agent-link-agent',
          kind: 'task_agent',
          displayName: 'Link Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        final link = agent_model.AgentLink.basic(
          id: 'agent-link-1',
          fromId: 'agent-link-agent',
          toId: 'agent-link-entity',
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        await populateAgentDb(entities: [entity], links: [link]);

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final linkMessages = sentMessages.whereType<SyncAgentLink>().toList();
        expect(linkMessages, hasLength(1));
        expect(linkMessages.first.agentLink?.id, equals('agent-link-1'));
      });

      test('stamps a clockless agent link before enqueueing it', () async {
        final baseDate = DateTime(2024, 11);
        final insideDate = baseDate.add(const Duration(hours: 6));
        const stamped = VectorClock({'node': 9});

        when(
          () => vectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
          ),
        ).thenAnswer((_) async => stamped);

        // The link's endpoints must exist, and the entity carries a clock
        // already so only the link exercises the stamping path here.
        final entity = AgentDomainEntity.agent(
          id: 'clockless-link-entity',
          agentId: 'clockless-link-agent',
          kind: 'task_agent',
          displayName: 'Link Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );
        final link = agent_model.AgentLink.basic(
          id: 'clockless-link',
          fromId: 'clockless-link-agent',
          toId: 'clockless-link-entity',
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: null,
        );

        await populateAgentDb(entities: [entity], links: [link]);

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final sent = sentMessages.whereType<SyncAgentLink>().toList();
        expect(sent, hasLength(1));
        expect(sent.first.agentLink?.vectorClock, stamped);

        final reloaded = await agentRepo.getLinkById('clockless-link');
        expect(reloaded?.vectorClock, stamped);
      });

      test('does not enqueue agent entities outside interval', () async {
        final baseDate = DateTime(2024, 12);
        final outsideDate = baseDate.subtract(const Duration(days: 10));

        final agentEntity = AgentDomainEntity.agent(
          id: 'agent-outside',
          agentId: 'agent-outside-id',
          kind: 'task_agent',
          displayName: 'Outside Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: outsideDate,
          updatedAt: outsideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        await populateAgentDb(entities: [agentEntity]);

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final agentMessages = sentMessages
            .whereType<SyncAgentEntity>()
            .toList();
        expect(agentMessages, isEmpty);
      });

      test('enqueues both agent entities and links together', () async {
        final baseDate = DateTime(2025);
        final insideDate = baseDate.add(const Duration(hours: 3));

        final entity1 = AgentDomainEntity.agent(
          id: 'combo-entity-1',
          agentId: 'combo-agent-1',
          kind: 'task_agent',
          displayName: 'Combo Agent 1',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        final entity2 = AgentDomainEntity.agentState(
          id: 'combo-state-1',
          agentId: 'combo-agent-1',
          revision: 1,
          slots: const AgentSlots(activeTaskId: 'task-1'),
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        final link = agent_model.AgentLink.agentState(
          id: 'combo-link-1',
          fromId: 'combo-agent-1',
          toId: 'combo-state-1',
          createdAt: insideDate,
          updatedAt: insideDate,
          vectorClock: const VectorClock({'node': 1}),
        );

        await populateAgentDb(
          entities: [entity1, entity2],
          links: [link],
        );

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(days: 1)),
          end: baseDate.add(const Duration(days: 1)),
          agentRepository: agentRepo,
        );

        final agentMessages = sentMessages
            .whereType<SyncAgentEntity>()
            .toList();
        final linkMessages = sentMessages.whereType<SyncAgentLink>().toList();

        expect(agentMessages, hasLength(2));
        expect(linkMessages, hasLength(1));
        expect(
          agentMessages.map((m) => m.agentEntity?.id),
          containsAll(['combo-entity-1', 'combo-state-1']),
        );
        expect(linkMessages.first.agentLink?.id, equals('combo-link-1'));
      });

      test('reports agent entity and link phases with totals', () async {
        final baseDate = DateTime(2025, 2);
        final entity = AgentDomainEntity.agent(
          id: 'progress-agent',
          agentId: 'progress-agent',
          kind: 'task_agent',
          displayName: 'Progress Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'progress-state',
          config: const AgentConfig(),
          createdAt: baseDate,
          updatedAt: baseDate,
          vectorClock: const VectorClock({'node': 1}),
        );
        final link = agent_model.AgentLink.basic(
          id: 'progress-agent-link',
          fromId: 'progress-agent',
          toId: 'progress-state',
          createdAt: baseDate,
          updatedAt: baseDate,
          vectorClock: const VectorClock({'node': 1}),
        );
        await populateAgentDb(entities: [entity], links: [link]);
        final progress = <ReSyncProgress>[];

        await historicalSync.reSyncInterval(
          start: baseDate.subtract(const Duration(hours: 1)),
          end: baseDate.add(const Duration(hours: 1)),
          agentRepository: agentRepo,
          includeJournalEntities: false,
          onProgress: progress.add,
        );

        expect(
          progress
              .where(
                (event) =>
                    event.phase == ReSyncPhase.agentEntities &&
                    event.isComplete,
              )
              .single
              .processed,
          1,
        );
        expect(
          progress
              .where(
                (event) =>
                    event.phase == ReSyncPhase.agentLinks && event.isComplete,
              )
              .single
              .total,
          1,
        );
      });

      test(
        'reSyncInterval skips agent sweep when includeAgentEntities=false',
        () async {
          final baseDate = DateTime(2024, 6);
          final insideDate = baseDate;

          // Seed both a journal entry and an agent entity inside the
          // window. With includeAgentEntities=false the journal entry must
          // still be enqueued but no agent messages should appear.
          final journal = _buildJournalEntry(
            id: 'journal-only-1',
            timestamp: insideDate,
            text: 'inside',
          );
          await _insertEntries(journalDb, [journal]);

          final agentEntity = AgentDomainEntity.agent(
            id: 'agent-skip-1',
            agentId: 'agent-skip-1',
            kind: 'task_agent',
            displayName: 'Skip Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: insideDate,
            updatedAt: insideDate,
            vectorClock: const VectorClock({'node': 1}),
          );
          final agentLink = agent_model.AgentLink.basic(
            id: 'agent-skip-link',
            fromId: 'agent-skip-1',
            toId: 'state-1',
            createdAt: insideDate,
            updatedAt: insideDate,
            vectorClock: const VectorClock({'node': 1}),
          );
          await populateAgentDb(
            entities: [agentEntity],
            links: [agentLink],
          );

          await historicalSync.reSyncInterval(
            start: baseDate.subtract(const Duration(days: 1)),
            end: baseDate.add(const Duration(days: 1)),
            agentRepository: agentRepo,
            includeAgentEntities: false,
          );

          // Journal sweep ran.
          expect(
            sentMessages.whereType<SyncJournalEntity>().toList(),
            isNotEmpty,
          );
          // Agent sweep did NOT run.
          expect(
            sentMessages.whereType<SyncAgentEntity>().toList(),
            isEmpty,
          );
          expect(
            sentMessages.whereType<SyncAgentLink>().toList(),
            isEmpty,
          );
        },
      );

      test(
        'reSyncInterval skips journal sweep when includeJournalEntities=false',
        () async {
          final baseDate = DateTime(2024, 7);
          final insideDate = baseDate;

          final journal = _buildJournalEntry(
            id: 'journal-skip-1',
            timestamp: insideDate,
            text: 'inside',
          );
          await _insertEntries(journalDb, [journal]);

          final agentEntity = AgentDomainEntity.agent(
            id: 'agent-only-1',
            agentId: 'agent-only-1',
            kind: 'task_agent',
            displayName: 'Only Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: insideDate,
            updatedAt: insideDate,
            vectorClock: const VectorClock({'node': 1}),
          );
          await populateAgentDb(entities: [agentEntity], links: []);

          await historicalSync.reSyncInterval(
            start: baseDate.subtract(const Duration(days: 1)),
            end: baseDate.add(const Duration(days: 1)),
            agentRepository: agentRepo,
            includeJournalEntities: false,
          );

          // No journal messages enqueued.
          expect(
            sentMessages.whereType<SyncJournalEntity>().toList(),
            isEmpty,
          );
          // Agent message present.
          expect(
            sentMessages.whereType<SyncAgentEntity>().toList(),
            hasLength(1),
          );
        },
      );

      test(
        'reSyncInterval is a no-op and logs when both filters are off',
        () async {
          final baseDate = DateTime(2024, 8);
          await historicalSync.reSyncInterval(
            start: baseDate.subtract(const Duration(days: 1)),
            end: baseDate.add(const Duration(days: 1)),
            agentRepository: agentRepo,
            includeJournalEntities: false,
            includeAgentEntities: false,
          );

          expect(sentMessages, isEmpty);
          verify(
            () => mockDomainLogger.log(
              LogDomain.sync,
              'reSyncInterval skipped — both entity-type filters disabled',
              subDomain: 'reSyncInterval',
            ),
          ).called(1);
        },
      );
    });
  });

  test('provider assembles the Sync-owned service dependencies', () async {
    await getIt.reset();
    final journalDb = MockJournalDb();
    final agentRepository = MockAgentRepository();
    final outboxService = MockOutboxService();
    final vectorClockService = MockVectorClockService();
    final logger = MockDomainLogger();
    when(
      () => logger.log(
        LogDomain.sync,
        any<String>(),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});
    getIt
      ..registerSingleton<VectorClockService>(vectorClockService)
      ..registerSingleton<DomainLogger>(logger);
    final container = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(journalDb),
        agentRepositoryProvider.overrideWithValue(agentRepository),
        outboxServiceProvider.overrideWithValue(outboxService),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await getIt.reset();
    });

    final result = await container
        .read(historicalSyncServiceProvider)
        .reSyncInterval(
          start: DateTime(2026),
          end: DateTime(2026, 1, 2),
          includeJournalEntities: false,
          includeAgentEntities: false,
        );

    expect(result.total, 0);
    verify(
      () => logger.log(
        LogDomain.sync,
        'reSyncInterval skipped — both entity-type filters disabled',
        subDomain: 'reSyncInterval',
      ),
    ).called(1);
  });
}
