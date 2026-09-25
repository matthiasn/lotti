import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_enqueue_writer.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/agent_test_device.dart';
import '../../ai_consumption/test_utils.dart';

part 'outbox_model_conformance.dart';

/// Shared collaborators for constructing an [OutboxEnqueueWriter] with the
/// central mocks: recorded `saveJson` writes and a faithful copy of the
/// service's path-confinement check.
class _WriterBench {
  factory _WriterBench({
    String? Function(String relativePath)? safePayloadFullPath,
    Future<void> Function(String path, String json)? saveJson,
    bool withSequenceLog = true,
  }) {
    final documentsDirectory = Directory(
      p.join(p.separator, 'outbox-writer-docs'),
    );
    final journalDb = MockJournalDb();
    final loggingService = MockDomainLogger();
    final syncDatabase = MockSyncDatabase();
    final sequenceLogService = withSequenceLog
        ? MockSyncSequenceLogService()
        : null;
    final savedJson = <({String path, String json})>[];

    // Mirrors OutboxService._safePayloadFullPath so path-confinement behavior
    // matches production wiring.
    String? defaultSafePath(String relativePath) {
      final relativeJoined = p.joinAll(
        relativePath.split('/').where((part) => part.isNotEmpty),
      );
      final docsRoot = p.normalize(documentsDirectory.path);
      final fullPath = p.normalize(p.join(docsRoot, relativeJoined));
      if (!p.isWithin(docsRoot, fullPath) && docsRoot != fullPath) {
        return null;
      }
      return fullPath;
    }

    when(() => syncDatabase.addOutboxItem(any())).thenAnswer((_) async => 1);
    if (sequenceLogService != null) {
      when(
        () => sequenceLogService.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => sequenceLogService.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenAnswer((_) async {});
    }

    final writer = OutboxEnqueueWriter(
      journalDb: journalDb,
      loggingService: loggingService,
      syncDatabase: syncDatabase,
      documentsDirectory: documentsDirectory,
      saveJson:
          saveJson ??
          (path, json) async => savedJson.add((path: path, json: json)),
      safePayloadFullPath: safePayloadFullPath ?? defaultSafePath,
      sequenceLogService: sequenceLogService,
    );

    return _WriterBench._(
      journalDb: journalDb,
      loggingService: loggingService,
      syncDatabase: syncDatabase,
      sequenceLogService: sequenceLogService,
      documentsDirectory: documentsDirectory,
      savedJson: savedJson,
      writer: writer,
    );
  }

  _WriterBench._({
    required this.journalDb,
    required this.loggingService,
    required this.syncDatabase,
    required this.sequenceLogService,
    required this.documentsDirectory,
    required this.savedJson,
    required this.writer,
  });

  final MockJournalDb journalDb;
  final MockDomainLogger loggingService;
  final MockSyncDatabase syncDatabase;
  final MockSyncSequenceLogService? sequenceLogService;
  final Directory documentsDirectory;
  final List<({String path, String json})> savedJson;
  final OutboxEnqueueWriter writer;

  /// The single companion captured from `addOutboxItem`.
  OutboxCompanion capturedOutboxItem() {
    final captured = verify(
      () => syncDatabase.addOutboxItem(captureAny()),
    ).captured;
    expect(captured, hasLength(1));
    return captured.single as OutboxCompanion;
  }
}

SyncMessage _decode(String message) =>
    SyncMessage.fromJson(json.decode(message) as Map<String, dynamic>);

OutboxCompanion _commonFields(
  SyncMessage message, {
  int priority = 1,
}) {
  final jsonString = jsonEncode(message.toJson());
  return OutboxCompanion(
    status: Value(OutboxStatus.pending.index),
    message: Value(jsonString),
    createdAt: Value(DateTime(2024, 3, 15)),
    updatedAt: Value(DateTime(2024, 3, 15)),
    payloadSize: Value(utf8.encode(jsonString).length),
    priority: Value(priority),
  );
}

SyncEntryLink _entryLinkMessage({
  String id = 'link-1',
  VectorClock? vectorClock,
  List<VectorClock>? coveredVectorClocks,
  String? originatingHostId,
}) =>
    SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: id,
            fromId: 'from-1',
            toId: 'to-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: vectorClock,
          ),
          status: SyncEntryStatus.update,
          coveredVectorClocks: coveredVectorClocks,
          originatingHostId: originatingHostId,
        )
        as SyncEntryLink;

SyncConsumptionEvent _consumptionEventMessage({
  String id = 'evt-1',
  VectorClock? vectorClock,
  List<VectorClock>? coveredVectorClocks,
  String? originatingHostId,
}) =>
    SyncMessage.consumptionEvent(
          event: makeConsumptionEvent(id: id, vectorClock: vectorClock),
          status: SyncEntryStatus.update,
          coveredVectorClocks: coveredVectorClocks,
          originatingHostId: originatingHostId,
        )
        as SyncConsumptionEvent;

AgentDomainEntity _agentEntity({
  String id = 'agent-1',
  VectorClock? vectorClock,
}) => AgentDomainEntity.agent(
  id: id,
  agentId: id,
  kind: 'task_agent',
  displayName: 'Test agent',
  lifecycle: AgentLifecycle.active,
  mode: AgentInteractionMode.autonomous,
  allowedCategoryIds: const {},
  currentStateId: 'state-1',
  config: const AgentConfig(),
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  vectorClock: vectorClock,
);

void main() {
  setUpAll(registerAllFallbackValues);

  _registerOutboxModelConformance();

  group('enqueueEntryLink', () {
    test(
      'writes outbox row with link subject and records the sequence log',
      () async {
        final bench = _WriterBench();
        const vc = VectorClock({'host-A': 5});
        final msg = _entryLinkMessage(vectorClock: vc);

        await bench.writer.enqueueEntryLink(
          msg: msg,
          commonFields: _commonFields(msg, priority: OutboxPriority.high.index),
          host: 'host-A',
          hostHash: 'hh',
        );

        final companion = bench.capturedOutboxItem();
        expect(companion.subject.value, 'hh:link:5');
        expect(companion.outboxEntryId.value, 'link-1');
        final decoded = _decode(companion.message.value) as SyncEntryLink;
        expect(decoded.entryLink.id, 'link-1');
        expect(decoded.entryLink.fromId, 'from-1');
        expect(decoded.entryLink.toId, 'to-1');

        verify(
          () => bench.sequenceLogService!.recordSentEntryLink(
            linkId: 'link-1',
            vectorClock: vc,
          ),
        ).called(1);
      },
    );

    test(
      'uses counterless subject when the link carries no local counter',
      () async {
        final bench = _WriterBench();
        final msg = _entryLinkMessage();

        await bench.writer.enqueueEntryLink(
          msg: msg,
          commonFields: _commonFields(msg),
          host: 'host-A',
          hostHash: 'hh',
        );

        expect(bench.capturedOutboxItem().subject.value, 'hh:link');
        // Without a vector clock there is nothing to record in the
        // sequence log.
        verifyNever(
          () => bench.sequenceLogService!.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        );
      },
    );
  });

  group('enqueueAgentEntity / enqueueAgentPayload', () {
    test('saves the payload json under the documents directory and writes '
        'the outbox row + sequence log', () async {
      final bench = _WriterBench();
      const vc = VectorClock({'host-A': 10});
      final msg =
          SyncMessage.agentEntity(
                agentEntity: _agentEntity(vectorClock: vc),
                status: SyncEntryStatus.update,
              )
              as SyncAgentEntity;

      await bench.writer.enqueueAgentEntity(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(bench.savedJson, hasLength(1));
      expect(
        bench.savedJson.single.path,
        p.join(bench.documentsDirectory.path, 'agent_entities', 'agent-1.json'),
      );
      final savedEntity = AgentDomainEntity.fromJson(
        json.decode(bench.savedJson.single.json) as Map<String, dynamic>,
      );
      expect(savedEntity.id, 'agent-1');

      final companion = bench.capturedOutboxItem();
      expect(companion.subject.value, 'agentEntity:agent-1');
      expect(companion.outboxEntryId.value, 'agent-1');
      final decoded = _decode(companion.message.value) as SyncAgentEntity;
      expect(decoded.jsonPath, '/agent_entities/agent-1.json');

      verify(
        () => bench.sequenceLogService!.recordSentEntry(
          entryId: 'agent-1',
          vectorClock: vc,
          payloadType: SyncSequencePayloadType.agentEntity,
        ),
      ).called(1);
    });

    test('skips a null agent entity without touching the outbox', () async {
      final bench = _WriterBench();
      const msg =
          SyncMessage.agentEntity(status: SyncEntryStatus.update)
              as SyncAgentEntity;

      await bench.writer.enqueueAgentEntity(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(bench.savedJson, isEmpty);
      verifyNever(() => bench.syncDatabase.addOutboxItem(any()));
    });

    test('rejects relative paths escaping the documents directory', () async {
      final bench = _WriterBench();

      await bench.writer.enqueueAgentPayload(
        id: 'agent-evil',
        payloadJson: '{}',
        relativePath: '/../../escape.json',
        enrichedMessage: const SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
        ),
        subjectPrefix: 'agentEntity',
        typeName: 'SyncAgentEntity',
        commonFields: _commonFields(
          const SyncMessage.agentEntity(status: SyncEntryStatus.update),
        ),
        vectorClock: null,
        payloadType: SyncSequencePayloadType.agentEntity,
      );

      expect(bench.savedJson, isEmpty);
      verifyNever(() => bench.syncDatabase.addOutboxItem(any()));
      verify(
        () => bench.loggingService.log(
          any(),
          any(that: contains('invalid agent payload path')),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });

    test('falls back to an inline-payload row when saveJson throws', () async {
      final bench = _WriterBench(
        saveJson: (_, _) async => throw const FileSystemException('disk'),
      );
      const vc = VectorClock({'host-A': 10});
      final msg =
          SyncMessage.agentEntity(
                agentEntity: _agentEntity(vectorClock: vc),
                status: SyncEntryStatus.update,
              )
              as SyncAgentEntity;
      final commonFields = _commonFields(msg);

      await bench.writer.enqueueAgentEntity(
        msg: msg,
        commonFields: commonFields,
      );

      final companion = bench.capturedOutboxItem();
      expect(companion.subject.value, 'agentEntity:agent-1');
      expect(companion.outboxEntryId.value, 'agent-1');
      // The inline fallback keeps the original message payload (no jsonPath
      // enrichment) so the sender's legacy path can rebuild the file.
      expect(companion.message.value, commonFields.message.value);
      verifyNever(
        () => bench.sequenceLogService!.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
      verify(
        () => bench.loggingService.error(
          any(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'enqueueMessage.saveAgentPayload',
        ),
      ).called(1);
    });
  });

  group('enqueueNotification', () {
    const vc = VectorClock({'host-A': 3});
    const msg =
        SyncMessage.notification(
              id: 'notif-1',
              jsonPath: '/notifications/notif-1.json',
              vectorClock: vc,
              originatingHostId: 'host-A',
            )
            as SyncNotification;

    test('writes the outbox row and records the sequence log', () async {
      final bench = _WriterBench();

      await bench.writer.enqueueNotification(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      final companion = bench.capturedOutboxItem();
      expect(companion.subject.value, 'notification:notif-1');
      expect(companion.filePath.value, '/notifications/notif-1.json');
      expect(companion.outboxEntryId.value, 'notif-1');
      final decoded = _decode(companion.message.value) as SyncNotification;
      expect(
        decoded.coveredVectorClocks!.map((covered) => covered.vclock),
        contains(equals({'host-A': 3})),
      );

      verify(
        () => bench.sequenceLogService!.recordSentEntry(
          entryId: 'notif-1',
          vectorClock: vc,
          payloadType: SyncSequencePayloadType.notification,
        ),
      ).called(1);
    });

    test('skips when the payload path is rejected', () async {
      final bench = _WriterBench(safePayloadFullPath: (_) => null);

      await bench.writer.enqueueNotification(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      verifyNever(() => bench.syncDatabase.addOutboxItem(any()));
      verifyNever(
        () => bench.sequenceLogService!.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
    });
  });

  group('enqueueNotificationStateUpdate', () {
    test('adds the row and records the state-update payload type', () async {
      final bench = _WriterBench();
      const vc = VectorClock({'host-A': 4});
      final msg =
          SyncMessage.notificationStateUpdate(
                id: 'notif-1',
                vectorClock: vc,
                originatingHostId: 'host-A',
                seenAt: DateTime(2024, 3, 15),
              )
              as SyncNotificationStateUpdate;

      await bench.writer.enqueueNotificationStateUpdate(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(
        bench.capturedOutboxItem().subject.value,
        'notificationStateUpdate:notif-1',
      );
      verify(
        () => bench.sequenceLogService!.recordSentEntry(
          entryId: 'notif-1',
          vectorClock: vc,
          payloadType: SyncSequencePayloadType.notificationStateUpdate,
        ),
      ).called(1);
    });
  });

  group('enqueueConsumptionEvent', () {
    test(
      'adds the row keyed by event id and records the consumption '
      'payload type in the sequence log',
      () async {
        final bench = _WriterBench();
        const vc = VectorClock({'host-A': 7});
        final msg = _consumptionEventMessage(vectorClock: vc);

        await bench.writer.enqueueConsumptionEvent(
          msg: msg,
          commonFields: _commonFields(msg),
        );

        final companion = bench.capturedOutboxItem();
        expect(companion.subject.value, 'consumptionEvent:evt-1');
        expect(companion.outboxEntryId.value, 'evt-1');
        final decoded = _decode(companion.message.value);
        expect(
          decoded,
          isA<SyncConsumptionEvent>()
              .having((m) => m.event.id, 'event.id', 'evt-1')
              .having((m) => m.event.vectorClock, 'event.vectorClock', vc),
        );

        verify(
          () => bench.sequenceLogService!.recordSentEntry(
            entryId: 'evt-1',
            vectorClock: vc,
            payloadType: SyncSequencePayloadType.consumptionEvent,
          ),
        ).called(1);
      },
    );

    test(
      'still writes the row but skips sequence recording when the event '
      'carries no vector clock',
      () async {
        final bench = _WriterBench();
        final msg = _consumptionEventMessage();

        await bench.writer.enqueueConsumptionEvent(
          msg: msg,
          commonFields: _commonFields(msg),
        );

        final companion = bench.capturedOutboxItem();
        expect(companion.subject.value, 'consumptionEvent:evt-1');
        expect(companion.outboxEntryId.value, 'evt-1');
        verifyNever(
          () => bench.sequenceLogService!.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        );
      },
    );
  });

  group('enqueueConfigFlag', () {
    const msg =
        SyncMessage.configFlag(
              name: 'flag-a',
              description: 'Flag A',
              status: true,
            )
            as SyncConfigFlag;

    test('inserts a fresh row keyed by flag name', () async {
      final bench = _WriterBench();

      await bench.writer.enqueueConfigFlag(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      final companion = bench.capturedOutboxItem();
      expect(companion.subject.value, 'configFlag:flag-a');
      expect(companion.outboxEntryId.value, 'configFlag:flag-a');
    });
  });

  group('record helpers', () {
    test(
      'recordNotificationSent swallows and logs sequence-log errors',
      () async {
        final bench = _WriterBench();
        when(
          () => bench.sequenceLogService!.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(StateError('sequence log down'));

        await bench.writer.recordNotificationSent(
          entryId: 'notif-1',
          vectorClock: const VectorClock({'host-A': 1}),
          payloadType: SyncSequencePayloadType.notification,
        );

        verify(
          () => bench.loggingService.error(
            any(),
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'recordSent',
          ),
        ).called(1);
      },
    );

    test('recordAgentSent is a no-op without a vector clock', () async {
      final bench = _WriterBench();

      await bench.writer.recordAgentSent(
        entryId: 'agent-1',
        vectorClock: null,
        payloadType: SyncSequencePayloadType.agentEntity,
      );

      verifyNever(
        () => bench.sequenceLogService!.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
    });

    test('record helpers are no-ops without a sequence log service', () async {
      final bench = _WriterBench(withSequenceLog: false);

      await bench.writer.recordNotificationSent(
        entryId: 'notif-1',
        vectorClock: const VectorClock({'host-A': 1}),
        payloadType: SyncSequencePayloadType.notification,
      );
      await bench.writer.recordAgentSent(
        entryId: 'agent-1',
        vectorClock: const VectorClock({'host-A': 1}),
        payloadType: SyncSequencePayloadType.agentEntity,
      );

      // No sequence log wired — nothing to verify beyond clean completion;
      // an error here would have thrown.
      verifyNever(
        () => bench.loggingService.error(
          any(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      );
    });
  });

  group('prepareMessage', () {
    test(
      'stamps originating host and covers the current clock on entry links',
      () async {
        final bench = _WriterBench();
        const vc = VectorClock({'host-A': 5});
        final msg = _entryLinkMessage(vectorClock: vc);

        final prepared =
            await bench.writer.prepareMessage(msg, 'host-A') as SyncEntryLink;

        expect(prepared.originatingHostId, 'host-A');
        expect(
          prepared.coveredVectorClocks!.map((covered) => covered.vclock),
          contains(equals({'host-A': 5})),
        );
      },
    );

    test('keeps an existing originating host on config flags', () async {
      final bench = _WriterBench();
      const msg = SyncMessage.configFlag(
        name: 'flag-a',
        description: 'Flag A',
        status: true,
        originatingHostId: 'host-B',
      );

      final prepared =
          await bench.writer.prepareMessage(msg, 'host-A') as SyncConfigFlag;

      expect(prepared.originatingHostId, 'host-B');
    });

    test(
      'stamps originating host and covered clock on agent entities',
      () async {
        final bench = _WriterBench();
        const vc = VectorClock({'host-A': 10});
        final msg =
            SyncMessage.agentEntity(
                  agentEntity: _agentEntity(vectorClock: vc),
                  status: SyncEntryStatus.update,
                )
                as SyncAgentEntity;

        final prepared =
            await bench.writer.prepareMessage(msg, 'host-A') as SyncAgentEntity;

        expect(prepared.originatingHostId, 'host-A');
        expect(
          prepared.coveredVectorClocks!.map((covered) => covered.vclock),
          contains(equals({'host-A': 10})),
        );
      },
    );

    test(
      'stamps originating host and covers the event clock on '
      'consumption events',
      () async {
        final bench = _WriterBench();
        const vc = VectorClock({'host-A': 7});
        const priorCovered = VectorClock({'host-B': 2});
        final msg = _consumptionEventMessage(
          vectorClock: vc,
          coveredVectorClocks: const [priorCovered],
        );

        final prepared =
            await bench.writer.prepareMessage(msg, 'host-A')
                as SyncConsumptionEvent;

        expect(prepared.originatingHostId, 'host-A');
        expect(
          prepared.coveredVectorClocks!.map((covered) => covered.vclock),
          containsAll(<Map<String, int>>[
            {'host-B': 2},
            {'host-A': 7},
          ]),
        );
      },
    );

    test(
      'keeps an existing originating host and null covered clocks on a '
      'clockless consumption event',
      () async {
        final bench = _WriterBench();
        final msg = _consumptionEventMessage(originatingHostId: 'host-B');

        final prepared =
            await bench.writer.prepareMessage(msg, 'host-A')
                as SyncConsumptionEvent;

        expect(prepared.originatingHostId, 'host-B');
        expect(prepared.coveredVectorClocks, isNull);
      },
    );

    test(
      'leaves the originating host unset on consumption events when no '
      'local host is known but still covers the event clock',
      () async {
        final bench = _WriterBench();
        const vc = VectorClock({'host-A': 7});
        final msg = _consumptionEventMessage(vectorClock: vc);

        final prepared =
            await bench.writer.prepareMessage(msg, null)
                as SyncConsumptionEvent;

        expect(prepared.originatingHostId, isNull);
        expect(prepared.coveredVectorClocks!.single.vclock, {'host-A': 7});
      },
    );
  });

  // ADR 0086: enqueue appends one immutable row per version and never merges.
  // Replayed against a real SyncDatabase, where concurrent enqueues of one
  // entity interleave the way they do in the app.
  group('append-only enqueue (ADR 0086)', () {
    late SyncDatabase db;

    setUp(() => db = SyncDatabase(inMemoryDatabase: true));
    tearDown(() async => db.close());

    OutboxEnqueueWriter realWriter() => OutboxEnqueueWriter(
      journalDb: MockJournalDb(),
      loggingService: MockDomainLogger(),
      syncDatabase: db,
      documentsDirectory: Directory(p.join(p.separator, 'outbox-writer-docs')),
      saveJson: (_, _) async {},
      safePayloadFullPath: (_) => null,
      sequenceLogService: null,
    );

    Future<void> enqueueAgentAt(OutboxEnqueueWriter writer, int counter) {
      final msg =
          SyncMessage.agentEntity(
                agentEntity: _agentEntity(
                  vectorClock: VectorClock({'host-A': counter}),
                ),
                status: SyncEntryStatus.update,
              )
              as SyncAgentEntity;
      return writer.enqueueAgentEntity(
        msg: msg,
        commonFields: _commonFields(msg),
      );
    }

    Future<void> enqueueLinkAt(OutboxEnqueueWriter writer, int counter) {
      final msg = _entryLinkMessage(
        vectorClock: VectorClock({'host-A': counter}),
      );
      return writer.enqueueEntryLink(
        msg: msg,
        commonFields: _commonFields(msg),
        host: 'host-A',
        hostHash: 'hash',
      );
    }

    int counterOf(OutboxItem item) => switch (_decode(item.message)) {
      final SyncAgentEntity m => m.agentEntity!.vectorClock!.vclock['host-A']!,
      final SyncEntryLink m => m.entryLink.vectorClock!.vclock['host-A']!,
      final other => throw StateError('unexpected $other'),
    };

    test('concurrent enqueues of one entity lose nothing: one row per '
        'version, each carrying its own counter', () async {
      final writer = realWriter();
      await Future.wait([
        for (final counter in [1, 2, 3]) enqueueAgentAt(writer, counter),
        for (final counter in [1, 2, 3]) enqueueLinkAt(writer, counter),
      ]);

      final rows = await db.getOutboxItems(
        statuses: const [OutboxStatus.pending],
      );
      final agentRows = rows.where((r) => r.outboxEntryId == 'agent-1');
      final linkRows = rows.where((r) => r.outboxEntryId == 'link-1');
      expect(agentRows.map(counterOf).toSet(), {1, 2, 3});
      expect(linkRows.map(counterOf).toSet(), {1, 2, 3});
      expect(rows, hasLength(6));
    });

    test('config flag enqueues append a row each, keyed by the flag', () async {
      final writer = realWriter();
      for (final status in [true, false]) {
        final msg =
            SyncMessage.configFlag(
                  name: 'private',
                  description: 'd',
                  status: status,
                )
                as SyncConfigFlag;
        await writer.enqueueConfigFlag(
          msg: msg,
          commonFields: _commonFields(msg),
        );
      }

      final rows = (await db.getOutboxItems()).reversed.toList();
      expect(rows.map((r) => r.outboxEntryId), [
        'configFlag:private',
        'configFlag:private',
      ]);
      expect(
        rows.map((r) => (_decode(r.message) as SyncConfigFlag).status),
        [true, false],
      );
    });
    Future<List<SyncMessage>> drain() async {
      final wire = <SyncMessage>[];
      final sender = MockOutboxMessageSender();
      when(() => sender.send(any())).thenAnswer((invocation) async {
        final message = invocation.positionalArguments.single as SyncMessage;
        wire.addAll(message is SyncOutboxBundle ? message.children : [message]);
        return true;
      });
      final processor = OutboxProcessor(
        repository: DatabaseOutboxRepository(db),
        messageSender: sender,
        loggingService: MockDomainLogger(),
      );
      await processor.processQueue();
      expect(
        await db.getOutboxItems(statuses: const [OutboxStatus.pending]),
        isEmpty,
      );
      return wire;
    }

    for (final kind in ['entryLink', 'agentEntity', 'agentLink']) {
      for (final reverse in [false, true]) {
        test(
          '$kind preserves concurrent payloads (reverse=$reverse)',
          () async {
            await setUpTestGetIt();
            addTearDown(tearDownTestGetIt);
            final writer = realWriter();
            const clocks = [
              VectorClock({'host-A': 2, 'host-B': 1}),
              VectorClock({'host-A': 1, 'host-B': 2}),
            ];
            for (final vc in reverse ? clocks.reversed : clocks) {
              final msg = switch (kind) {
                'entryLink' => _entryLinkMessage(vectorClock: vc),
                'agentEntity' => SyncMessage.agentEntity(
                  agentEntity: _agentEntity(vectorClock: vc),
                  status: SyncEntryStatus.update,
                ),
                _ => SyncMessage.agentLink(
                  agentLink: AgentLink.basic(
                    id: 'agent-link-1',
                    fromId: 'from-1',
                    toId: 'to-1',
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2024, 3, 15),
                    vectorClock: vc,
                  ),
                  status: SyncEntryStatus.update,
                ),
              };
              await switch (msg) {
                final SyncEntryLink m => writer.enqueueEntryLink(
                  msg: m,
                  commonFields: _commonFields(m),
                  host: 'host-A',
                  hostHash: 'hash',
                ),
                final SyncAgentEntity m => writer.enqueueAgentEntity(
                  msg: m,
                  commonFields: _commonFields(m),
                ),
                final SyncAgentLink m => writer.enqueueAgentLink(
                  msg: m,
                  commonFields: _commonFields(m),
                ),
                _ => throw StateError('unexpected $msg'),
              };
            }
            final messages = (await db.getOutboxItems()).map(
              (row) => _decode(row.message),
            );
            final payloadClocks = messages.map(
              (msg) => switch (msg) {
                final SyncEntryLink m => m.entryLink.vectorClock,
                final SyncAgentEntity m => m.agentEntity!.vectorClock,
                final SyncAgentLink m => m.agentLink!.vectorClock,
                _ => throw StateError('unexpected $msg'),
              },
            );
            expect(payloadClocks, unorderedEquals(clocks));
            final wire = await drain();
            expect(wire, hasLength(2));
            expect(
              await db.getOutboxItems(statuses: const [OutboxStatus.sent]),
              hasLength(2),
            );
            for (final delivered in [wire, wire.reversed]) {
              final journal = JournalDb(inMemoryDatabase: true);
              final peer = AgentTestDevice('peer');
              addTearDown(journal.close);
              addTearDown(peer.close);
              for (final message in delivered) {
                switch (message) {
                  case final SyncEntryLink m:
                    await journal.upsertEntryLink(m.entryLink);
                  case final SyncAgentEntity m:
                    await peer.receiveEntity(m.agentEntity!);
                  case final SyncAgentLink m:
                    await peer.receiveLink(m.agentLink!);
                  default:
                    fail('Unexpected inline payload $message');
                }
              }
              final receivedClock = switch (kind) {
                'entryLink' => (await journal.entryLinkById(
                  'link-1',
                ))?.vectorClock,
                'agentEntity' => (await peer.repository.getEntity(
                  'agent-1',
                ))?.vectorClock,
                _ => (await peer.repository.getLinkByIdIncludingDeleted(
                  'agent-link-1',
                ))?.vectorClock,
              };
              // Equal timestamps use canonical clock order: A:2 wins in
              // both receive orders, including when it was enqueued first.
              expect(receivedClock, clocks.first);
            }
            for (final msg in wire) {
              final (payload, covered) = switch (msg) {
                final SyncEntryLink m => (
                  m.entryLink.vectorClock!,
                  m.coveredVectorClocks,
                ),
                final SyncAgentEntity m => (
                  m.agentEntity!.vectorClock!,
                  m.coveredVectorClocks,
                ),
                final SyncAgentLink m => (
                  m.agentLink!.vectorClock!,
                  m.coveredVectorClocks,
                ),
                _ => throw StateError('unexpected $msg'),
              };
              expect(
                covered ?? <VectorClock>[],
                everyElement(
                  predicate<VectorClock>(
                    (vc) =>
                        VectorClock.compare(payload, vc) !=
                        VclockStatus.concurrent,
                  ),
                ),
              );
            }
          },
        );
      }
    }

    for (final reverse in [false, true]) {
      test('different inline kinds sharing an id stay separate '
          '(reverse=$reverse)', () async {
        final writer = realWriter();
        const vc = VectorClock({'host-A': 1});
        final link = _entryLinkMessage(id: 'shared-id', vectorClock: vc);
        final agent =
            SyncMessage.agentEntity(
                  agentEntity: _agentEntity(id: 'shared-id', vectorClock: vc),
                  status: SyncEntryStatus.update,
                )
                as SyncAgentEntity;
        final enqueues = [
          () => writer.enqueueEntryLink(
            msg: link,
            commonFields: _commonFields(link),
            host: 'host-A',
            hostHash: 'hash',
          ),
          () => writer.enqueueAgentEntity(
            msg: agent,
            commonFields: _commonFields(agent),
          ),
        ];
        for (final enqueue in reverse ? enqueues.reversed : enqueues) {
          await enqueue();
        }
        final wire = await drain();
        expect(wire, hasLength(2));
        expect(
          wire.map(
            (message) => switch (message) {
              final SyncEntryLink m => m.entryLink,
              final SyncAgentEntity m => m.agentEntity,
              final other => throw StateError('unexpected $other'),
            },
          ),
          unorderedEquals([link.entryLink, agent.agentEntity]),
        );
      });
    }

    for (final pendingClock in [
      null,
      const VectorClock({}),
      const VectorClock({'host-A': 1}),
    ]) {
      for (final incomingClock in [null, const VectorClock({})]) {
        test(
          'clockless link snapshots stay separate ($pendingClock, $incomingClock)',
          () async {
            final writer = realWriter();
            for (final vc in [pendingClock, incomingClock]) {
              final msg = _entryLinkMessage(vectorClock: vc);
              await writer.enqueueEntryLink(
                msg: msg,
                commonFields: _commonFields(msg),
                host: 'host-A',
                hostHash: 'hash',
              );
            }
            final wire = await drain();
            expect(wire, hasLength(2));
            expect(
              wire.map(
                (message) => (message as SyncEntryLink).entryLink.vectorClock,
              ),
              unorderedEquals([pendingClock, incomingClock]),
            );
            expect(
              wire.map(
                (message) => (message as SyncEntryLink).coveredVectorClocks,
              ),
              everyElement(isNull),
            );
          },
        );
      }
    }
  });
}
