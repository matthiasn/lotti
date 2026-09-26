import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
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
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../database/sync_db_test_utils.dart';
import '../../../mocks/mocks.dart';
import '../../agents/agent_test_device.dart';
import '../../agents/test_data/entity_factories.dart';
import '../matrix/sync_event_processor_test_helpers.dart' as processor_harness;
import '../queue/queue_apply_adapter_test_helpers.dart' show hBuildEntry;

/// A transport-controlled replica with production persistence, enqueue writers,
/// repair services and receive adapter. Only the outbox facade's scheduling and
/// dispatch are replaced; no Matrix SDK/network or attachment loader is exercised.
class _HeadReplica {
  _HeadReplica(this.host, {int? maxBatchSize}) {
    when(
      () => logging.error(
        LogDomain.sync,
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((invocation) {
      lastError = invocation.positionalArguments[1];
    });
    agents = AgentTestDevice(host, background: false);
    vc = agents.clocks;
    when(() => agents.outbox.enqueueMessage(any())).thenAnswer(
      (invocation) =>
          enqueue(invocation.positionalArguments.single as SyncMessage),
    );
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
      documentsDirectory: directory,
      saveJson: saveJson,
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
    responses =
        BackfillResponseHandler(
            journalDb: journal,
            sequenceLogService: sequence,
            outboxService: outbox,
            loggingService: logging,
            vectorClockService: vc,
            responseCooldown: Duration.zero,
          )
          ..onSequenceHead = requests.noteSequenceHead
          ..agentRepository = agents.repository;
    final processor =
        SyncEventProcessor(
            loggingService: logging,
            updateNotifications: processor_harness.updateNotifications,
            aiConfigRepository: processor_harness.aiConfigRepository,
            savedTaskFiltersRepository:
                processor_harness.savedTaskFiltersRepository,
            settingsDb: processor_harness.settingsDb,
            journalEntityLoader: processor_harness.journalEntityLoader,
            documentsDirectory: directory,
            sequenceLogService: sequence,
          )
          ..backfillResponseHandler = responses
          ..agentRepository = agents.repository;
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
  final Directory directory = Directory.systemTemp.createTempSync(
    'sync-conformance-',
  );
  late final AgentTestDevice agents;
  late final MockVectorClockService vc;
  final logging = MockDomainLogger();
  final outbox = MockOutboxService();
  final room = MockRoom();
  late final SyncSequenceLogService sequence;
  late final OutboxEnqueueWriter writer;
  late final BackfillRequestService requests;
  late final BackfillResponseHandler responses;
  late final InboundApplyFn apply;
  int eventCounter = 0;
  Object? lastError;

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
      SyncAgentEntity() => writer.enqueueAgentEntity(
        msg: prepared,
        commonFields: fields,
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
    await agents.close();
    await directory.delete(recursive: true);
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
        expect(request.entries.map((entry) => (entry.hostId, entry.counter)), [
          ('announcing', 1),
          ('ordinary', 1),
        ]);
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

/// Cross-family conformance belongs to the responder suite; the head/request
/// suite above reuses the same real stores and transport-controlled replicas.
void registerMixedFamilyBackfillConformanceTests() {
  group('mixed-family composed conformance', () {
    setUpAll(processor_harness.registerSyncProcessorFallbacks);
    setUp(processor_harness.setUpProcessorMocks);

    for (final deviceCount in [2, 3]) {
      for (var seed = 0; seed < 4; seed++) {
        test(
          'mixed-family fork and repair on $deviceCount devices, seed $seed',
          () async {
            var now = DateTime.utc(2026, 9, 26);
            await withClock(Clock(() => now), () async {
              final devices = List.generate(
                deviceCount,
                (index) => _HeadReplica('host-$index'),
              );
              addTearDown(() async {
                for (final device in devices.reversed) {
                  await device.close();
                }
              });
              final origin = devices[0];
              final other = devices[1];
              final lagging = devices.last;
              const sharedId = 'same-id-different-families';
              await origin.agents.sync.upsertEntity(
                makeTestIdentity(
                  id: sharedId,
                  agentId: sharedId,
                  displayName: 'first',
                  updatedAt: now,
                ),
              );
              final first = (await origin.drain()).single;
              now = now.add(const Duration(seconds: 1));
              await other.agents.sync.upsertEntity(
                makeTestIdentity(
                  id: sharedId,
                  agentId: sharedId,
                  displayName: 'concurrent',
                  updatedAt: now,
                ),
              );
              final fork = (await other.drain()).single;
              final firstEntity =
                  (await origin.agents.repository.getEntity(
                        sharedId,
                      ))!
                      as AgentIdentityEntity;
              now = now.add(const Duration(seconds: 1));
              await origin.agents.sync.upsertEntity(
                firstEntity.copyWith(displayName: 'successor', updatedAt: now),
              );
              final successor = (await origin.drain()).single;
              final expectedAgent = await origin.agents.repository.getEntity(
                sharedId,
              );
              final link = EntryLink.basic(
                id: sharedId,
                fromId: 'from',
                toId: 'to',
                createdAt: now,
                updatedAt: now,
                vectorClock: await origin.vc.getNextVectorClock(),
              );
              expect(link.vectorClock, VectorClock({origin.host: 3}));
              await origin.journal.upsertEntryLink(link);
              await origin.enqueue(
                SyncMessage.entryLink(
                  entryLink: link,
                  status: SyncEntryStatus.update,
                ),
              );
              final otherFamily = (await origin.drain()).single;
              // Reorder and duplicate transport deliveries independently per peer.
              // The lagging peer loses the final two writes, including the tail.
              for (final (index, device) in devices.indexed) {
                final deliveries = [
                  first,
                  fork,
                  if (device != lagging) successor,
                  if (device != lagging) otherFamily,
                ]..shuffle(Random(seed * 3 + index));
                for (final message in deliveries) {
                  expect(
                    await device.receive(message),
                    ApplyOutcome.applied,
                    reason: '${device.lastError}',
                  );
                  expect(
                    await device.receive(message),
                    ApplyOutcome.applied,
                    reason: '${device.lastError}',
                  );
                }
              }
              expect(await lagging.journal.entryLinkById(sharedId), isNull);
              // A domain commit succeeds but its receipt fails. The only later
              // input is a periodic head and backfill; no manual retry/restart.
              await lagging.database.customStatement("""
              CREATE TRIGGER fail_mixed_receipt BEFORE INSERT ON sync_sequence_log
              BEGIN SELECT RAISE(ABORT, 'receipt unavailable'); END
            """);
              expect(await lagging.receive(successor), ApplyOutcome.retriable);
              expect(
                await lagging.agents.repository.getEntity(sharedId),
                expectedAgent,
              );
              await lagging.database.customStatement(
                'DROP TRIGGER fail_mixed_receipt',
              );
              await origin.requests.announceOwnSequenceHead();
              final head = (await origin.drain()).single;
              expect(await lagging.receive(head), ApplyOutcome.applied);
              expect(await lagging.requests.processAutomaticBackfill(), 2);
              for (final request in await lagging.drain()) {
                expect(await origin.receive(request), ApplyOutcome.applied);
              }
              final repairs = await origin.drain();
              expect(repairs.whereType<SyncAgentEntity>(), hasLength(1));
              expect(repairs.whereType<SyncEntryLink>(), hasLength(1));
              for (final repair in repairs.reversed) {
                expect(await lagging.receive(repair), ApplyOutcome.applied);
                expect(await lagging.receive(repair), ApplyOutcome.applied);
              }
              for (final device in devices) {
                expect(
                  await device.agents.repository.getEntity(sharedId),
                  expectedAgent,
                );
                expect(await device.journal.entryLinkById(sharedId), link);
                for (final counter in [1, 2, 3]) {
                  final receipt = await device.database
                      .getEntryByHostAndCounter(
                        origin.host,
                        counter,
                      );
                  expect(
                    receipt?.status,
                    isIn([
                      SyncSequenceStatus.received.index,
                      SyncSequenceStatus.backfilled.index,
                    ]),
                  );
                }
              }
              expect(await lagging.requests.processAutomaticBackfill(), 0);
            });
          },
        );
      }
    }
  });
}
