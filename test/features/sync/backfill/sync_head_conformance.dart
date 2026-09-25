import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_enqueue_writer.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/queue_apply_adapter.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../database/sync_db_test_utils.dart';
import '../../../mocks/mocks.dart';
import '../matrix/sync_event_processor_test_helpers.dart' as processor_harness;
import '../queue/queue_apply_adapter_test_helpers.dart' show hBuildEntry;

/// A transport-controlled replica with production persistence, enqueue writers,
/// repair services and receive adapter. Only the outbox facade's scheduling and
/// dispatch are replaced; no Matrix SDK/network or attachment loader is exercised.
class _HeadReplica {
  _HeadReplica(this.host, {int? maxBatchSize}) {
    when(vc.getHost).thenAnswer((_) async => host);
    when(() => vc.initialized).thenAnswer((_) async {});
    sequence = SyncSequenceLogService(
      syncDatabase: database,
      vectorClockService: vc,
      loggingService: logging,
    );
    writer = OutboxEnqueueWriter(
      journalDb: journal,
      loggingService: logging,
      syncDatabase: database,
      documentsDirectory: Directory('/unused-inline-sync-payloads'),
      saveJson: (_, _) async => throw StateError('inline payloads only'),
      safePayloadFullPath: (_) => null,
      sequenceLogService: sequence,
    );
    when(() => outbox.enqueueMessageOrThrow(any())).thenAnswer(
      (invocation) =>
          enqueue(invocation.positionalArguments.single as SyncMessage),
    );
    when(() => outbox.enqueueMessage(any())).thenAnswer(
      (invocation) =>
          enqueue(invocation.positionalArguments.single as SyncMessage),
    );
    requests = BackfillRequestService(
      sequenceLogService: sequence,
      syncDatabase: database,
      outboxService: outbox,
      vectorClockService: vc,
      loggingService: logging,
      requestRetryCooldown: Duration.zero,
      maxBatchSize: maxBatchSize,
    );
    responses = BackfillResponseHandler(
      journalDb: journal,
      sequenceLogService: sequence,
      outboxService: outbox,
      loggingService: logging,
      vectorClockService: vc,
      responseCooldown: Duration.zero,
    )..onSequenceHead = requests.noteSequenceHead;
    final processor = SyncEventProcessor(
      loggingService: logging,
      updateNotifications: processor_harness.updateNotifications,
      aiConfigRepository: processor_harness.aiConfigRepository,
      savedTaskFiltersRepository: processor_harness.savedTaskFiltersRepository,
      settingsDb: processor_harness.settingsDb,
      journalEntityLoader: processor_harness.journalEntityLoader,
      sequenceLogService: sequence,
    )..backfillResponseHandler = responses;
    apply = QueueApplyAdapter(
      processor: processor,
      journalDb: journal,
      logging: logging,
      hasOlderActiveEntry: (_) async => false,
    ).bind();
    when(() => room.id).thenReturn('!head-conformance:example.org');
  }

  final String host;
  final database = SyncDatabase(inMemoryDatabase: true, background: false);
  final journal = JournalDb(inMemoryDatabase: true);
  final vc = MockVectorClockService();
  final logging = MockDomainLogger();
  final outbox = MockOutboxService();
  final room = MockRoom();
  late final SyncSequenceLogService sequence;
  late final OutboxEnqueueWriter writer;
  late final BackfillRequestService requests;
  late final BackfillResponseHandler responses;
  late final InboundApplyFn apply;
  int eventCounter = 0;

  Future<void> enqueue(SyncMessage message) async {
    final prepared = await writer.prepareMessage(message, host);
    final fields = buildOutboxCompanion(
      status: OutboxStatus.pending,
      createdAt: clock.now(),
      message: jsonEncode(prepared.toJson()),
    );
    await switch (prepared) {
      SyncEntryLink() => writer.enqueueEntryLink(
        msg: prepared,
        commonFields: fields,
        host: host,
        hostHash: host,
      ),
      SyncBackfillRequest() => writer.enqueueBackfillRequest(
        msg: prepared,
        commonFields: fields,
      ),
      SyncBackfillResponse() => writer.enqueueBackfillResponse(
        msg: prepared,
        commonFields: fields,
      ),
      _ => throw StateError('unsupported conformance message: $prepared'),
    };
  }

  /// Read wire messages from claimed durable rows, then acknowledge the send.
  /// Tests choose which room deliveries are dropped, duplicated or reordered.
  Future<List<SyncMessage>> drain() async {
    final repository = DatabaseOutboxRepository(database);
    final messages = <SyncMessage>[];
    while (true) {
      final item = await repository.claim();
      if (item == null) break;
      messages.add(
        SyncMessage.fromJson(jsonDecode(item.message) as Map<String, dynamic>),
      );
      await repository.markSent(item);
    }
    return messages;
  }

  Future<ApplyOutcome> receive(SyncMessage message) => apply(
    hBuildEntry(
      eventId: '\$head-$host-${eventCounter++}',
      roomId: room.id,
      originTsMs: 1,
      body: processor_harness.encodeMessage(message),
    ),
    room,
  );

  Future<void> close() async {
    await requests.stopAndDrain();
    await database.close();
    await journal.close();
  }
}

void registerSyncHeadConformanceTests() {
  group('lost-tail composed conformance', () {
    setUpAll(processor_harness.registerSyncProcessorFallbacks);
    setUp(processor_harness.setUpProcessorMocks);

    for (final batchSize in [1, 2, 3, 8]) {
      test(
        'ordinary gaps share capacity with head repairs at limit $batchSize',
        () async {
          final now = DateTime.utc(2026, 9, 26);
          await withClock(Clock.fixed(now), () async {
            final replica = _HeadReplica('receiver', maxBatchSize: batchSize);
            addTearDown(replica.close);
            for (final host in ['announcing', 'ordinary']) {
              for (var counter = 1; counter <= batchSize * 3; counter++) {
                final old = host == 'announcing';
                final created = old
                    ? DateTime.utc(2024)
                    : now.subtract(const Duration(minutes: 20));
                await replica.database.recordSequenceEntry(
                  SyncSequenceLogCompanion(
                    hostId: Value(host),
                    counter: Value(counter),
                    status: Value(
                      old
                          ? SyncSequenceStatus.unresolvable.index
                          : SyncSequenceStatus.missing.index,
                    ),
                    createdAt: Value(created),
                    updatedAt: Value(created),
                    requestCount: Value(old ? 99 : 0),
                  ),
                );
              }
            }
            replica.requests.noteSequenceHead('announcing', batchSize * 3);
            final requestedHosts = <String>{};
            for (var pass = 0; pass < 2; pass++) {
              expect(
                await replica.requests.processAutomaticBackfill(),
                batchSize,
              );
              final request =
                  (await replica.drain()).single as SyncBackfillRequest;
              expect(request.entries, hasLength(batchSize));
              expect(
                request.entries
                    .map((entry) => (entry.hostId, entry.counter))
                    .toSet(),
                hasLength(batchSize),
              );
              final hosts = request.entries
                  .map((entry) => entry.hostId)
                  .toSet();
              requestedHosts.addAll(hosts);
              if (batchSize > 1) expect(hosts, {'announcing', 'ordinary'});
            }
            expect(requestedHosts, {'announcing', 'ordinary'});
          });
        },
      );
    }

    test('overlapping candidates retain the ordinary request slot', () async {
      final now = DateTime.utc(2026, 9, 26);
      await withClock(Clock.fixed(now), () async {
        final replica = _HeadReplica('receiver', maxBatchSize: 2);
        addTearDown(replica.close);
        for (final row in [
          (host: 'announcing', counter: 1, old: false),
          (host: 'announcing', counter: 2, old: true),
          (host: 'ordinary', counter: 1, old: false),
        ]) {
          final created = row.old
              ? DateTime.utc(2024)
              : now.subtract(
                  Duration(minutes: row.host == 'announcing' ? 30 : 20),
                );
          await replica.database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: Value(row.host),
              counter: Value(row.counter),
              status: Value(
                row.old
                    ? SyncSequenceStatus.unresolvable.index
                    : SyncSequenceStatus.missing.index,
              ),
              createdAt: Value(created),
              updatedAt: Value(created),
            ),
          );
        }
        replica.requests.noteSequenceHead('announcing', 2);
        expect(await replica.requests.processAutomaticBackfill(), 2);
        final request = (await replica.drain()).single as SyncBackfillRequest;
        expect(
          request.entries.map((entry) => (entry.hostId, entry.counter)),
          [('announcing', 1), ('ordinary', 1)],
        );
      });
    });

    for (final replicas in [2, 3]) {
      test(
        'repairs dropped tail and failed receipts across $replicas replicas',
        () async {
          await withClock(Clock.fixed(DateTime.utc(2026, 9, 26)), () async {
            final devices = [
              for (var index = 0; index < replicas; index++)
                _HeadReplica('host-$index'),
            ];
            for (final device in devices) {
              addTearDown(device.close);
            }
            final origin = devices.first;
            final lagging = devices[1];
            final link = EntryLink.basic(
              id: 'lost-tail-link',
              fromId: 'from',
              toId: 'to',
              createdAt: clock.now(),
              updatedAt: clock.now(),
              vectorClock: VectorClock({origin.host: 1}),
            );
            await origin.journal.upsertEntryLink(link);
            await origin.enqueue(
              SyncMessage.entryLink(
                entryLink: link,
                status: SyncEntryStatus.update,
              ),
            );
            final original = (await origin.drain()).single;
            // The final payload and the first announcement both miss host-1.
            for (final peer in devices.skip(2)) {
              expect(await peer.receive(original), ApplyOutcome.applied);
            }
            await origin.requests.announceOwnSequenceHead();
            expect(await origin.drain(), hasLength(1));
            expect(await lagging.requests.processAutomaticBackfill(), 0);
            expect(await lagging.journal.entryLinkById(link.id), isNull);

            // No new user write, restart or manual repair: another periodic pass
            // announces the same settled head and uncovers the missing final row.
            await origin.requests.announceOwnSequenceHead();
            final head = (await origin.drain()).single;
            expect(await lagging.receive(head), ApplyOutcome.applied);
            expect(
              await lagging.database.getLastCounterForHost(origin.host),
              isNull,
            );
            expect(await lagging.requests.processAutomaticBackfill(), 1);
            expect(await lagging.requests.processAutomaticBackfill(), 0);
            final request = (await lagging.drain()).single;
            expect(await origin.receive(request), ApplyOutcome.applied);
            final response = await origin.drain();
            final payload = response.single as SyncEntryLink;

            // The announcement and request must not forge a payload receipt.
            expect(await lagging.journal.entryLinkById(link.id), isNull);
            expect(
              (await lagging.database.getEntryByHostAndCounter(
                origin.host,
                1,
              ))?.status,
              SyncSequenceStatus.requested.index,
            );
            await lagging.database.customStatement('''
            CREATE TRIGGER fail_receipt BEFORE INSERT ON sync_sequence_log
            BEGIN SELECT RAISE(ABORT, 'receipt unavailable'); END
          ''');
            expect(await lagging.receive(payload), ApplyOutcome.retriable);
            expect(
              (await lagging.database.getEntryByHostAndCounter(
                origin.host,
                1,
              ))?.status,
              SyncSequenceStatus.requested.index,
            );
            expect(await lagging.journal.entryLinkById(link.id), link);
            await lagging.database.customStatement('DROP TRIGGER fail_receipt');
            // Drop the failed delivery's retry too; periodic repair must recover.
            expect(await lagging.receive(head), ApplyOutcome.applied);
            expect(await lagging.requests.processAutomaticBackfill(), 1);
            for (final message in await lagging.drain()) {
              expect(await origin.receive(message), ApplyOutcome.applied);
            }
            for (final message in (await origin.drain()).reversed) {
              expect(await lagging.receive(message), ApplyOutcome.applied);
              expect(await lagging.receive(message), ApplyOutcome.applied);
            }
            for (final peer in devices.skip(1)) {
              expect(await peer.journal.entryLinkById(link.id), link);
              expect(
                (await peer.database.getEntryByHostAndCounter(
                  origin.host,
                  1,
                ))?.status,
                isIn([
                  SyncSequenceStatus.received.index,
                  SyncSequenceStatus.backfilled.index,
                ]),
              );
              expect(await peer.database.getLastCounterForHost(origin.host), 1);
            }
            expect(await lagging.requests.processAutomaticBackfill(), 0);
            expect(await lagging.drain(), isEmpty);
          });
        },
      );
    }
  });
}
