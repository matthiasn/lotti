import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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
import '../../ai_consumption/test_utils.dart';

part 'outbox_model_conformance.dart';

/// Shared collaborators for constructing an [OutboxEnqueueWriter] with the
/// central mocks: recorded `saveJson` writes, recorded `enqueueNextSendRequest`
/// delays, and a faithful copy of the service's path-confinement check.
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
    final scheduledDelays = <Duration>[];

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
    when(
      () => syncDatabase.findPendingByEntryId(any()),
    ).thenAnswer((_) async => null);
    when(
      () => syncDatabase.updateOutboxMessage(
        itemId: any(named: 'itemId'),
        newMessage: any(named: 'newMessage'),
        newSubject: any(named: 'newSubject'),
        payloadSize: any(named: 'payloadSize'),
        priority: any(named: 'priority'),
      ),
    ).thenAnswer((_) async => 1);
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
      when(
        () => sequenceLogService.getLastSentVectorClockForEntry(any()),
      ).thenAnswer((_) async => null);
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
      enqueueNextSendRequest:
          ({Duration delay = const Duration(milliseconds: 1)}) async {
            scheduledDelays.add(delay);
          },
      sequenceLogService: sequenceLogService,
    );

    return _WriterBench._(
      journalDb: journalDb,
      loggingService: loggingService,
      syncDatabase: syncDatabase,
      sequenceLogService: sequenceLogService,
      documentsDirectory: documentsDirectory,
      savedJson: savedJson,
      scheduledDelays: scheduledDelays,
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
    required this.scheduledDelays,
    required this.writer,
  });

  final MockJournalDb journalDb;
  final MockDomainLogger loggingService;
  final MockSyncDatabase syncDatabase;
  final MockSyncSequenceLogService? sequenceLogService;
  final Directory documentsDirectory;
  final List<({String path, String json})> savedJson;
  final List<Duration> scheduledDelays;
  final OutboxEnqueueWriter writer;

  /// The single companion captured from `addOutboxItem`.
  OutboxCompanion capturedOutboxItem() {
    final captured = verify(
      () => syncDatabase.addOutboxItem(captureAny()),
    ).captured;
    expect(captured, hasLength(1));
    return captured.single as OutboxCompanion;
  }

  /// The named arguments captured from a single `updateOutboxMessage` call,
  /// in declaration order (itemId, newMessage, newSubject, payloadSize,
  /// priority).
  List<dynamic> capturedUpdate() {
    return verify(
      () => syncDatabase.updateOutboxMessage(
        itemId: captureAny(named: 'itemId'),
        newMessage: captureAny(named: 'newMessage'),
        newSubject: captureAny(named: 'newSubject'),
        payloadSize: captureAny(named: 'payloadSize'),
        priority: captureAny(named: 'priority'),
      ),
    ).captured;
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

OutboxItem _pendingItem({
  required String message,
  required String entryId,
  int priority = 1,
}) => OutboxItem(
  id: 7,
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  status: OutboxStatus.pending.index,
  retries: 0,
  message: message,
  subject: 'old-subject',
  outboxEntryId: entryId,
  priority: priority,
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

        final merged = await bench.writer.enqueueEntryLink(
          msg: msg,
          commonFields: _commonFields(msg, priority: OutboxPriority.high.index),
          host: 'host-A',
          hostHash: 'hh',
        );

        expect(merged, isFalse);
        expect(bench.scheduledDelays, isEmpty);

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

    test(
      'merges into an existing pending row and schedules the next send',
      () async {
        final bench = _WriterBench();
        const oldVc = VectorClock({'host-A': 4});
        const newVc = VectorClock({'host-A': 5});
        final oldMsg = _entryLinkMessage(vectorClock: oldVc);
        final newMsg = _entryLinkMessage(vectorClock: newVc);

        when(
          () => bench.syncDatabase.findPendingByEntryId('link-1'),
        ).thenAnswer(
          (_) async => _pendingItem(
            message: jsonEncode(oldMsg.toJson()),
            entryId: 'link-1',
            priority: OutboxPriority.low.index,
          ),
        );

        final merged = await bench.writer.enqueueEntryLink(
          msg: newMsg,
          commonFields: _commonFields(
            newMsg,
            priority: OutboxPriority.high.index,
          ),
          host: 'host-A',
          hostHash: 'hh',
        );

        expect(merged, isTrue);
        expect(bench.scheduledDelays, [const Duration(seconds: 1)]);
        verifyNever(() => bench.syncDatabase.addOutboxItem(any()));

        final captured = bench.capturedUpdate();
        expect(captured[0], 7); // itemId
        expect(captured[2], 'hh:link:5'); // newSubject
        expect(captured[4], OutboxPriority.high.index); // min(low, high)
        final decoded = _decode(captured[1] as String) as SyncEntryLink;
        expect(
          decoded.coveredVectorClocks!.map((vc) => vc.vclock),
          containsAll(<Map<String, int>>[
            {'host-A': 4},
            {'host-A': 5},
          ]),
        );

        verify(
          () => bench.sequenceLogService!.recordSentEntryLink(
            linkId: 'link-1',
            vectorClock: newVc,
          ),
        ).called(1);
      },
    );

    test('inserts a fresh merged row when the pending row vanished '
        '(update affected 0 rows)', () async {
      final bench = _WriterBench();
      final oldMsg = _entryLinkMessage(
        vectorClock: const VectorClock({'host-A': 4}),
      );
      final newMsg = _entryLinkMessage(
        vectorClock: const VectorClock({'host-A': 5}),
      );

      when(
        () => bench.syncDatabase.findPendingByEntryId('link-1'),
      ).thenAnswer(
        (_) async => _pendingItem(
          message: jsonEncode(oldMsg.toJson()),
          entryId: 'link-1',
        ),
      );
      when(
        () => bench.syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => 0);

      final merged = await bench.writer.enqueueEntryLink(
        msg: newMsg,
        commonFields: _commonFields(newMsg),
        host: 'host-A',
        hostHash: 'hh',
      );

      expect(merged, isTrue);
      final companion = bench.capturedOutboxItem();
      expect(companion.subject.value, 'hh:link:5');
      expect(companion.outboxEntryId.value, 'link-1');
      final decoded = _decode(companion.message.value) as SyncEntryLink;
      expect(
        decoded.coveredVectorClocks!.map((vc) => vc.vclock),
        contains(equals({'host-A': 4})),
      );
    });

    test(
      'enriches covered clocks from the sequence log on fresh enqueue',
      () async {
        final bench = _WriterBench();
        const lastSentVc = VectorClock({'host-A': 3});
        const newVc = VectorClock({'host-A': 5});
        when(
          () => bench.sequenceLogService!.getLastSentVectorClockForEntry(
            'link-1',
          ),
        ).thenAnswer((_) async => lastSentVc);

        final msg = _entryLinkMessage(vectorClock: newVc);
        await bench.writer.enqueueEntryLink(
          msg: msg,
          commonFields: _commonFields(msg),
          host: 'host-A',
          hostHash: 'hh',
        );

        final decoded =
            _decode(bench.capturedOutboxItem().message.value) as SyncEntryLink;
        expect(
          decoded.coveredVectorClocks!.map((vc) => vc.vclock),
          contains(equals({'host-A': 3})),
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

      final merged = await bench.writer.enqueueAgentEntity(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(merged, isFalse);
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

      final merged = await bench.writer.enqueueAgentEntity(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(merged, isFalse);
      expect(bench.savedJson, isEmpty);
      verifyNever(() => bench.syncDatabase.addOutboxItem(any()));
    });

    test('rejects relative paths escaping the documents directory', () async {
      final bench = _WriterBench();

      final merged = await bench.writer.enqueueAgentPayload(
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

      expect(merged, isFalse);
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

      final merged = await bench.writer.enqueueAgentEntity(
        msg: msg,
        commonFields: commonFields,
      );

      expect(merged, isFalse);
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

    test('merges into an existing pending agent row and schedules the next '
        'send', () async {
      final bench = _WriterBench();
      const oldVc = VectorClock({'host-A': 9});
      const newVc = VectorClock({'host-A': 10});
      final oldMsg = SyncMessage.agentEntity(
        agentEntity: _agentEntity(vectorClock: oldVc),
        status: SyncEntryStatus.update,
      );
      final newMsg =
          SyncMessage.agentEntity(
                agentEntity: _agentEntity(vectorClock: newVc),
                status: SyncEntryStatus.update,
              )
              as SyncAgentEntity;

      when(
        () => bench.syncDatabase.findPendingByEntryId('agent-1'),
      ).thenAnswer(
        (_) async => _pendingItem(
          message: jsonEncode(oldMsg.toJson()),
          entryId: 'agent-1',
        ),
      );

      final merged = await bench.writer.enqueueAgentEntity(
        msg: newMsg,
        commonFields: _commonFields(newMsg),
      );

      expect(merged, isTrue);
      expect(bench.scheduledDelays, [const Duration(seconds: 1)]);
      verifyNever(() => bench.syncDatabase.addOutboxItem(any()));

      final captured = bench.capturedUpdate();
      expect(captured[2], 'agentEntity:agent-1'); // newSubject
      final decoded = _decode(captured[1] as String) as SyncAgentEntity;
      expect(
        decoded.coveredVectorClocks!.map((vc) => vc.vclock),
        containsAll(<Map<String, int>>[
          {'host-A': 9},
          {'host-A': 10},
        ]),
      );

      verify(
        () => bench.sequenceLogService!.recordSentEntry(
          entryId: 'agent-1',
          vectorClock: newVc,
          payloadType: SyncSequencePayloadType.agentEntity,
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

      final merged = await bench.writer.enqueueNotification(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(merged, isFalse);
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

      final merged = await bench.writer.enqueueNotification(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(merged, isFalse);
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

      final merged = await bench.writer.enqueueNotificationStateUpdate(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(merged, isFalse);
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

        final merged = await bench.writer.enqueueConsumptionEvent(
          msg: msg,
          commonFields: _commonFields(msg),
        );

        expect(merged, isFalse);
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

        final merged = await bench.writer.enqueueConsumptionEvent(
          msg: msg,
          commonFields: _commonFields(msg),
        );

        expect(merged, isFalse);
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

      final merged = await bench.writer.enqueueConfigFlag(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(merged, isFalse);
      final companion = bench.capturedOutboxItem();
      expect(companion.subject.value, 'configFlag:flag-a');
      expect(companion.outboxEntryId.value, 'configFlag:flag-a');
    });

    test('merges a pending flag row and schedules the next send', () async {
      final bench = _WriterBench();
      when(
        () => bench.syncDatabase.findPendingByEntryId('configFlag:flag-a'),
      ).thenAnswer(
        (_) async => _pendingItem(
          message: jsonEncode(msg.toJson()),
          entryId: 'configFlag:flag-a',
        ),
      );

      final merged = await bench.writer.enqueueConfigFlag(
        msg: msg,
        commonFields: _commonFields(msg),
      );

      expect(merged, isTrue);
      expect(bench.scheduledDelays, [const Duration(seconds: 1)]);
      verifyNever(() => bench.syncDatabase.addOutboxItem(any()));
      final captured = bench.capturedUpdate();
      expect(captured[2], 'configFlag:flag-a');
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

  // The holes TLC found in specs/tla/Outbox.tla (ADR 0085), replayed against
  // a real SyncDatabase outbox so the merge's read and write interleave the
  // way they do in the app.
  group('merge under concurrent and out-of-order enqueues (ADR 0085)', () {
    late SyncDatabase db;

    setUp(() => db = SyncDatabase(inMemoryDatabase: true));
    tearDown(() async => db.close());

    OutboxEnqueueWriter realWriter({
      MockSyncSequenceLogService? sequenceLogService,
    }) => OutboxEnqueueWriter(
      journalDb: MockJournalDb(),
      loggingService: MockDomainLogger(),
      syncDatabase: db,
      documentsDirectory: Directory(p.join(p.separator, 'outbox-writer-docs')),
      saveJson: (_, _) async {},
      safePayloadFullPath: (_) => null,
      enqueueNextSendRequest:
          ({Duration delay = const Duration(milliseconds: 1)}) async {},
      sequenceLogService: sequenceLogService,
    );

    Future<bool> enqueueAgentAt(OutboxEnqueueWriter writer, int counter) {
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

    Future<bool> enqueueLinkAt(OutboxEnqueueWriter writer, int counter) {
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

    /// Every live row as (payload counter, covered counters).
    Future<List<({int payload, Set<int> covered})>> liveRows() async {
      final items = await db.getOutboxItems(
        statuses: const [OutboxStatus.pending, OutboxStatus.sending],
      );
      return [
        for (final item in items.reversed)
          switch (_decode(item.message)) {
            final SyncAgentEntity m => (
              payload: m.agentEntity!.vectorClock!.vclock['host-A']!,
              covered: {
                for (final vc in m.coveredVectorClocks ?? <VectorClock>[])
                  vc.vclock['host-A']!,
              },
            ),
            final SyncEntryLink m => (
              payload: m.entryLink.vectorClock!.vclock['host-A']!,
              covered: {
                for (final vc in m.coveredVectorClocks ?? <VectorClock>[])
                  vc.vclock['host-A']!,
              },
            ),
            final other => throw StateError('unexpected $other'),
          },
      ];
    }

    test('two concurrent enqueues of one agent keep every counter '
        '(NoLostCounter)', () async {
      // TLC: v1 is pending; the enqueues of v2 and v3 both read it, v2
      // writes {v2, covers v1}, then v3 writes {v3, covers v1} over it and
      // counter 2 is in no row at all.
      final writer = realWriter();
      await enqueueAgentAt(writer, 1);

      await Future.wait([enqueueAgentAt(writer, 2), enqueueAgentAt(writer, 3)]);

      final rows = await liveRows();
      expect(rows, hasLength(1));
      expect(rows.single.payload, 3);
      expect(rows.single.covered, containsAll(<int>[1, 2]));
    });

    test('an agent enqueue arriving after a newer one keeps the newer '
        'payload (MergeNeverRegresses)', () async {
      final writer = realWriter();
      await enqueueAgentAt(writer, 3);
      await enqueueAgentAt(writer, 2);

      final rows = await liveRows();
      expect(rows, hasLength(1));
      expect(rows.single.payload, 3);
      expect(rows.single.covered, contains(2));
    });

    test('an entry-link enqueue arriving after a newer one keeps the newer '
        'link and its subject (MergeNeverRegresses)', () async {
      final writer = realWriter();
      await enqueueLinkAt(writer, 3);
      await enqueueLinkAt(writer, 2);

      final rows = await liveRows();
      expect(rows, hasLength(1));
      expect(rows.single.payload, 3);
      expect(rows.single.covered, contains(2));
      final items = await db.getOutboxItems();
      expect(items.single.subject, 'hash:link:3');
    });

    test('an invalid pending clock never outranks the incoming link', () async {
      // VectorClock.compare throws on a negative counter; the merge then
      // takes the incoming link, as it did before newest-wins.
      final writer = realWriter();
      await enqueueLinkAt(writer, -1);
      await enqueueLinkAt(writer, 2);

      final rows = await liveRows();
      expect(rows.single.payload, 2);
      expect(rows.single.covered, containsAll(<int>[-1, 2]));
    });

    test('a fresh inline row covers the last sent counter only when its '
        'payload is newer (CoversOnlyOlder)', () async {
      // TLC: version 3 is recorded and in flight when a late enqueue of
      // version 2 inserts a fresh row; enriched with counter 3, it would let
      // a peer mark 3 received while holding only version 2.
      final sequenceLog = MockSyncSequenceLogService();
      when(
        () => sequenceLog.getLastSentVectorClockForEntry(any()),
      ).thenAnswer((_) async => const VectorClock({'host-A': 3}));
      when(
        () => sequenceLog.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => sequenceLog.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenAnswer((_) async {});
      final writer = realWriter(sequenceLogService: sequenceLog);

      await enqueueAgentAt(writer, 2);
      await enqueueLinkAt(writer, 2);
      final stale = await liveRows();
      expect(stale.map((row) => row.payload), [2, 2]);
      expect(stale.map((row) => row.covered), everyElement(isEmpty));

      // A newer payload still picks up the predecessor, as before.
      await db.delete(db.outbox).go();
      await enqueueAgentAt(writer, 4);
      await enqueueLinkAt(writer, 4);
      final fresh = await liveRows();
      expect(fresh.map((row) => row.payload), [4, 4]);
      expect(fresh.map((row) => row.covered), everyElement(equals({3})));
    });
  });
}
