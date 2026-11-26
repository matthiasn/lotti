import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/agents/agent_database.dart' show AgentDatabase;
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart' show JournalDb;
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/agents/sync/agent_entity_receive.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

/// One device's real agent persistence and sync stack, for tests that need
/// what the code actually commits: an in-memory agent database behind the
/// real [AgentRepository] and [AgentSyncService], a vector clock that issues
/// [host]'s counters as `VectorClockService` does, and an outbox that
/// records what the device sends.
///
/// Two failures can be injected. [failClockFor] makes the clock reservation
/// for one payload id throw: a write that fails before its row is stored,
/// which rolls back the transaction around it. [outboxFails] makes the
/// outbox refuse messages: a transaction that commits and then fails
/// flushing, which `AgentSyncService.runInTransaction` reports by throwing.
///
/// `firstCounter` is the first counter the host issues: 1 for a host this
/// build creates (`firstVectorClockCounter`), 0 for one an older build
/// created (ADR 0080).
///
/// `background` runs the database on a background isolate, as the app does;
/// a trace under `fakeAsync` needs it off. [reboot] is a process death and
/// restart: a fresh repository and sync service over the same database,
/// with the counter — which the real service persists — carried over.
/// [onSent] sees every accepted message as it is accepted.
///
/// [receiveEnvelope] applies a sync message through the real
/// `SyncEventProcessor` wired with [attachProcessor], so a test asserts on
/// what the receive committed. [holdNextStoredReadOf] parks one read of a
/// stored version, which is how a test places a local write between a
/// receive's read and its write.
///
/// Callers close the database with [close] (in `addTearDown`).
class AgentTestDevice {
  AgentTestDevice(
    this.host, {
    int firstCounter = firstVectorClockCounter,
    bool background = true,
    this.onSent,
  }) : _counter = firstCounter - 1,
       db = AgentDatabase(inMemoryDatabase: true, background: background) {
    when(
      () => clocks.getNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((invocation) async {
      final payload = invocation.namedArguments[#payload] as VcPayloadRef?;
      if (payload != null && payload.id == failClockFor) {
        throw StateError('clock reservation failed for ${payload.id}');
      }
      // This host's next counter, caught up past whatever the previous
      // clock already holds for it.
      final previous = invocation.namedArguments[#previous] as VectorClock?;
      final own = previous?.vclock[host];
      _counter = (own != null && own > _counter ? own : _counter) + 1;
      return VectorClock({...?previous?.vclock, host: _counter});
    });
    when(() => outbox.enqueueMessage(any())).thenAnswer((invocation) async {
      if (outboxFails) throw StateError('outbox unavailable after commit');
      final message = invocation.positionalArguments.single as SyncMessage;
      sent.add(message);
      onSent?.call(message);
    });
    reboot();
  }

  final String host;
  final AgentDatabase db;
  final void Function(SyncMessage message)? onSent;
  late AgentRepository repository;
  final clocks = MockVectorClockService();
  final outbox = MockOutboxService();
  late AgentSyncService sync;

  void reboot() {
    repository = _holdable = _HoldableAgentRepository(db);
    _processor?.agentRepository = repository;
    sync = AgentSyncService(
      repository: repository,
      outboxService: outbox,
      vectorClockService: clocks,
    );
  }

  /// Every message the outbox accepted, in order.
  final sent = <SyncMessage>[];

  /// The payload id whose clock reservation throws, or `null`.
  String? failClockFor;

  /// Whether the outbox refuses messages.
  bool outboxFails = false;

  int _counter;

  late _HoldableAgentRepository _holdable;
  SyncEventProcessor? _processor;

  /// Makes [processor] apply agent records to this device's database; a
  /// [reboot] wires it to the fresh repository.
  void attachProcessor(SyncEventProcessor processor) =>
      _processor = processor..agentRepository = repository;

  /// Receives [message] through the attached processor's real `process`:
  /// decode, resolve against the stored row, write, notify, record.
  ///
  /// [envelope] and [journalDb] default to bare mocks; a test that stubs the
  /// event id or timestamp, or asserts on journal writes, passes its own.
  Future<void> receiveEnvelope(
    SyncMessage message, {
    MockEvent? envelope,
    JournalDb? journalDb,
  }) {
    final event = envelope ?? MockEvent();
    if (envelope == null) {
      when(() => event.eventId).thenReturn('event-id');
      when(() => event.originServerTs).thenReturn(DateTime(2024));
    }
    when(
      () => event.text,
    ).thenReturn(base64.encode(utf8.encode(json.encode(message.toJson()))));
    return _processor!.process(
      envelope: event,
      journalDb: journalDb ?? MockJournalDb(),
    );
  }

  /// Parks the next stored-version read of entity or link [id] — the read a
  /// receive resolves against — until the returned completer completes. The
  /// row is read first and handed over afterwards, so a receive that reads
  /// outside its transaction resolves against a version a local write has
  /// since replaced.
  Completer<void> holdNextStoredReadOf(String id) => _holdable.hold(id);

  /// The agent entities this device sent, in order.
  List<AgentDomainEntity> get sentEntities => [
    for (final message in sent)
      ?message.mapOrNull(agentEntity: (m) => m.agentEntity),
  ];

  /// The agent links this device sent, in order.
  List<AgentLink> get sentLinks => [
    for (final message in sent)
      ?message.mapOrNull(agentLink: (m) => m.agentLink),
  ];

  /// Receives [incoming] the way `SyncEventProcessor` applies an agent
  /// entity: refused when this device deleted its agent
  /// ([refusesWriteAboutDeletedAgent]), else through
  /// [resolveReceivedAgentEntity] — the stored row, a
  /// tombstone included, resolved by [resolveAgentEntityVersions] (for two
  /// agent-state rows, with the order of their heads in the local message
  /// DAG) — and written in the same transaction. A malformed clock fails the
  /// test rather than being logged.
  Future<void> receiveEntity(AgentDomainEntity incoming) =>
      repository.runInTransaction(() async {
        if (await refusesWriteAboutDeletedAgent(repository, {
          incoming.agentId,
        })) {
          return;
        }
        final receipt = await resolveReceivedAgentEntity(
          repository,
          incoming,
          onMalformedClock: Error.throwWithStackTrace,
        );
        final toWrite = receipt.toWrite;
        if (toWrite != null) await repository.upsertEntity(toWrite);
      });

  /// Receives [incoming] the way `SyncEventProcessor` applies an agent link:
  /// refused when this device deleted an agent at either end, else the
  /// stored version, a tombstone included, read and written in one
  /// transaction, resolved by [resolveAgentLinkVersions].
  Future<void> receiveLink(AgentLink incoming) =>
      repository.runInTransaction(() async {
        if (await refusesWriteAboutDeletedAgent(repository, {
          incoming.fromId,
          incoming.toId,
        })) {
          return;
        }
        final local = await repository.getLinkByIdIncludingDeleted(
          incoming.id,
        );
        if (local == null ||
            !identical(
              resolveAgentLinkVersions(local: local, incoming: incoming),
              local,
            )) {
          await repository.upsertLink(incoming);
        }
      });

  Future<void> close() => db.close();
}

/// The real repository, able to park one stored-version read.
class _HoldableAgentRepository extends AgentRepository {
  _HoldableAgentRepository(super.db);

  String? _heldId;
  var _release = Completer<void>();

  Completer<void> hold(String id) {
    _heldId = id;
    return _release = Completer<void>();
  }

  Future<T> _afterRelease<T>(String id, T row) async {
    if (id == _heldId) {
      _heldId = null;
      await _release.future;
    }
    return row;
  }

  @override
  Future<AgentDomainEntity?> getEntityIncludingDeleted(String id) async =>
      _afterRelease(id, await super.getEntityIncludingDeleted(id));

  @override
  Future<AgentLink?> getLinkByIdIncludingDeleted(String id) async =>
      _afterRelease(id, await super.getLinkByIdIncludingDeleted(id));
}
