import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/actor/outbound_queue.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

OutboxCompanion _buildOutbox({
  required String subject,
  required String message,
  required DateTime createdAt,
  int retries = 0,
}) {
  return OutboxCompanion(
    status: Value(OutboxStatus.pending.index),
    subject: Value(subject),
    message: Value(message),
    createdAt: Value(createdAt),
    updatedAt: Value(createdAt),
    retries: Value(retries),
  );
}

String _syncMessageJson(String id) =>
    jsonEncode(SyncMessage.aiConfigDelete(id: id).toJson());

const _generatedExplicitRoomId = '!generated-explicit:localhost';
const _generatedSyncRoomId = '!generated-sync:localhost';
const _generatedEventId = r'$generated-event';
const _generatedRetryDelay = Duration(milliseconds: 50);
const _generatedErrorDelay = Duration(milliseconds: 250);
const _generatedMaxRetries = 3;

enum _GeneratedOutboundRoomMode {
  explicit,
  uniqueMarked,
  noMarked,
  multipleMarked,
  throwingAndUniqueMarked,
}

enum _GeneratedOutboundStartState {
  connected,
  disconnected,
  disposed,
}

enum _GeneratedOutboundPayloadShape {
  valid,
  invalidJson,
  nonMapJson,
}

enum _GeneratedOutboundSendPlan {
  success,
  throws,
  throwsAndDisconnects,
  throwsAndDisposes,
}

class _GeneratedOutboundDrainScenario {
  const _GeneratedOutboundDrainScenario({
    required this.roomMode,
    required this.startState,
    required this.hasItem,
    required this.payloadShape,
    required this.sendPlan,
    required this.initialRetries,
    required this.pendingTailCount,
  });

  final _GeneratedOutboundRoomMode roomMode;
  final _GeneratedOutboundStartState startState;
  final bool hasItem;
  final _GeneratedOutboundPayloadShape payloadShape;
  final _GeneratedOutboundSendPlan sendPlan;
  final int initialRetries;
  final int pendingTailCount;

  String? get configuredRoomId =>
      roomMode == _GeneratedOutboundRoomMode.explicit
      ? _generatedExplicitRoomId
      : null;

  String? get expectedRoomId {
    return switch (roomMode) {
      _GeneratedOutboundRoomMode.explicit => _generatedExplicitRoomId,
      _GeneratedOutboundRoomMode.uniqueMarked => _generatedSyncRoomId,
      _GeneratedOutboundRoomMode.noMarked => null,
      _GeneratedOutboundRoomMode.multipleMarked => null,
      _GeneratedOutboundRoomMode.throwingAndUniqueMarked =>
        _generatedSyncRoomId,
    };
  }

  bool get isConnected =>
      startState != _GeneratedOutboundStartState.disconnected;

  bool get isDisposedBeforeDrain =>
      startState == _GeneratedOutboundStartState.disposed;

  bool get isReadyToClaim =>
      hasItem &&
      isConnected &&
      !isDisposedBeforeDrain &&
      expectedRoomId != null;

  bool get sendsToGateway =>
      isReadyToClaim && payloadShape == _GeneratedOutboundPayloadShape.valid;

  bool get succeeds =>
      sendsToGateway && sendPlan == _GeneratedOutboundSendPlan.success;

  bool get failsAfterClaim => isReadyToClaim && !succeeds;

  bool get reachesRetryCap => initialRetries + 1 >= _generatedMaxRetries;

  bool get failureChangesQueueState {
    return sendsToGateway &&
        (sendPlan == _GeneratedOutboundSendPlan.throwsAndDisconnects ||
            sendPlan == _GeneratedOutboundSendPlan.throwsAndDisposes);
  }

  String get headSubject => 'generated-head';

  String get headMessage {
    return switch (payloadShape) {
      _GeneratedOutboundPayloadShape.valid => _syncMessageJson(headSubject),
      _GeneratedOutboundPayloadShape.invalidJson => '{not-json',
      _GeneratedOutboundPayloadShape.nonMapJson => jsonEncode(['not-a-map']),
    };
  }

  Duration? get expectedDelay {
    if (!isReadyToClaim) {
      return null;
    }
    if (succeeds) {
      return pendingTailCount > 0 ? Duration.zero : null;
    }
    if (failureChangesQueueState) {
      return _generatedErrorDelay;
    }
    return reachesRetryCap ? Duration.zero : _generatedRetryDelay;
  }

  int? get expectedHeadStatus {
    if (!hasItem) {
      return null;
    }
    if (!isReadyToClaim) {
      return OutboxStatus.pending.index;
    }
    if (succeeds) {
      return OutboxStatus.sent.index;
    }
    return reachesRetryCap
        ? OutboxStatus.error.index
        : OutboxStatus.pending.index;
  }

  int? get expectedHeadRetries {
    if (!hasItem) {
      return null;
    }
    if (!failsAfterClaim) {
      return initialRetries;
    }
    return initialRetries + 1;
  }

  @override
  String toString() {
    return '_GeneratedOutboundDrainScenario('
        'roomMode: $roomMode, '
        'startState: $startState, '
        'hasItem: $hasItem, '
        'payloadShape: $payloadShape, '
        'sendPlan: $sendPlan, '
        'initialRetries: $initialRetries, '
        'pendingTailCount: $pendingTailCount'
        ')';
  }
}

extension _AnyGeneratedOutboundDrainScenario on glados.Any {
  glados.Generator<_GeneratedOutboundRoomMode> get outboundRoomMode =>
      glados.AnyUtils(this).choose(_GeneratedOutboundRoomMode.values);

  glados.Generator<_GeneratedOutboundStartState> get outboundStartState =>
      glados.AnyUtils(this).choose(_GeneratedOutboundStartState.values);

  glados.Generator<_GeneratedOutboundPayloadShape> get outboundPayloadShape =>
      glados.AnyUtils(this).choose(_GeneratedOutboundPayloadShape.values);

  glados.Generator<_GeneratedOutboundSendPlan> get outboundSendPlan =>
      glados.AnyUtils(this).choose(_GeneratedOutboundSendPlan.values);

  glados.Generator<_GeneratedOutboundDrainScenario> get outboundDrainScenario =>
      glados.CombinableAny(this).combine7(
        outboundRoomMode,
        outboundStartState,
        glados.BoolAny(this).bool,
        outboundPayloadShape,
        outboundSendPlan,
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 3),
        (
          _GeneratedOutboundRoomMode roomMode,
          _GeneratedOutboundStartState startState,
          bool hasItem,
          _GeneratedOutboundPayloadShape payloadShape,
          _GeneratedOutboundSendPlan sendPlan,
          int initialRetries,
          int pendingTailCount,
        ) => _GeneratedOutboundDrainScenario(
          roomMode: roomMode,
          startState: startState,
          hasItem: hasItem,
          payloadShape: payloadShape,
          sendPlan: sendPlan,
          initialRetries: initialRetries,
          pendingTailCount: pendingTailCount,
        ),
      );
}

MockRoom _generatedRoom({
  required String id,
  required bool isSyncMarked,
  bool throwsOnState = false,
}) {
  final room = MockRoom();
  when(() => room.id).thenReturn(id);
  if (throwsOnState) {
    when(() => room.getState(lottiSyncRoomStateType)).thenThrow(
      StateError('state unavailable'),
    );
  } else {
    when(() => room.getState(lottiSyncRoomStateType)).thenReturn(
      isSyncMarked ? MockStrippedStateEvent() : null,
    );
  }
  return room;
}

void _stubGeneratedRooms({
  required MockMatrixClient client,
  required _GeneratedOutboundRoomMode roomMode,
}) {
  final rooms = switch (roomMode) {
    _GeneratedOutboundRoomMode.explicit => <Room>[],
    _GeneratedOutboundRoomMode.uniqueMarked => <Room>[
      _generatedRoom(id: '!generated-other:localhost', isSyncMarked: false),
      _generatedRoom(id: _generatedSyncRoomId, isSyncMarked: true),
    ],
    _GeneratedOutboundRoomMode.noMarked => <Room>[
      _generatedRoom(id: '!generated-other:localhost', isSyncMarked: false),
    ],
    _GeneratedOutboundRoomMode.multipleMarked => <Room>[
      _generatedRoom(id: '!generated-sync-a:localhost', isSyncMarked: true),
      _generatedRoom(id: '!generated-sync-b:localhost', isSyncMarked: true),
    ],
    _GeneratedOutboundRoomMode.throwingAndUniqueMarked => <Room>[
      _generatedRoom(
        id: '!generated-throwing:localhost',
        isSyncMarked: false,
        throwsOnState: true,
      ),
      _generatedRoom(id: _generatedSyncRoomId, isSyncMarked: true),
    ],
  };
  when(() => client.rooms).thenReturn(rooms);
}

Future<void> _insertGeneratedOutboxRows({
  required SyncDatabase db,
  required _GeneratedOutboundDrainScenario scenario,
}) async {
  if (!scenario.hasItem) {
    return;
  }

  final base = DateTime(2024, 1, 2);
  await db.addOutboxItem(
    _buildOutbox(
      subject: scenario.headSubject,
      message: scenario.headMessage,
      createdAt: base,
      retries: scenario.initialRetries,
    ),
  );

  for (var index = 0; index < scenario.pendingTailCount; index++) {
    await db.addOutboxItem(
      _buildOutbox(
        subject: 'generated-tail-$index',
        message: _syncMessageJson('generated-tail-$index'),
        createdAt: base.add(Duration(minutes: index + 1)),
      ),
    );
  }
}

Map<String, dynamic> _decodeSentSyncMessage(String encoded) {
  return jsonDecode(utf8.decode(base64.decode(encoded)))
      as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OutboundQueue', () {
    late SyncDatabase db;
    late MockMatrixSdkGateway gateway;
    late MockMatrixClient client;
    late MockRoom room;
    final events = <Map<String, Object?>>[];

    setUp(() {
      db = SyncDatabase(inMemoryDatabase: true);
      gateway = MockMatrixSdkGateway();
      client = MockMatrixClient();
      room = MockRoom();
      events.clear();

      when(() => gateway.client).thenReturn(client);
      when(() => room.id).thenReturn('!room:localhost');
      when(() => room.getState(any<String>())).thenReturn(null);
    });

    tearDown(() async {
      await db.close();
    });

    test('drains one queued row and marks it sent', () async {
      when(
        () => room.getState(lottiSyncRoomStateType),
      ).thenReturn(MockStrippedStateEvent());
      when(() => client.rooms).thenReturn([room]);
      when(
        () => gateway.sendText(
          roomId: '!room:localhost',
          message: any<String>(named: 'message'),
          messageType: 'com.lotti.sync.message',
          displayPendingEvent: false,
        ),
      ).thenAnswer((_) async => r'$event:1');

      await db.addOutboxItem(
        _buildOutbox(
          subject: 'first',
          message: _syncMessageJson('id1'),
          createdAt: DateTime(2024, 1, 2),
        ),
      );
      await db.addOutboxItem(
        _buildOutbox(
          subject: 'second',
          message: _syncMessageJson('id2'),
          createdAt: DateTime(2024, 1, 3),
        ),
      );

      final queue = OutboundQueue(
        syncDatabase: db,
        gateway: gateway,
        emitEvent: events.add,
      );
      final delay = await queue.drain();
      final first = await db.getOutboxItemById(1);
      final second = await db.getOutboxItemById(2);
      final sentEvents = events.where(
        (event) => event['event'] == 'sendAck',
      );
      final sentEvent = sentEvents.singleOrNull;

      expect(delay, Duration.zero);
      expect(first?.status, OutboxStatus.sent.index);
      expect(second?.status, OutboxStatus.pending.index);
      expect(sentEvent, isNotNull);
      expect(sentEvent!['itemId'], 1);
      verify(
        () => gateway.sendText(
          roomId: '!room:localhost',
          message: any<String>(named: 'message'),
          messageType: 'com.lotti.sync.message',
          displayPendingEvent: false,
        ),
      ).called(1);
    });

    test('retries a failed send and schedules delay', () async {
      var attempt = 0;
      when(
        () => room.getState(lottiSyncRoomStateType),
      ).thenReturn(MockStrippedStateEvent());
      when(() => client.rooms).thenReturn([room]);
      when(
        () => gateway.sendText(
          roomId: '!room:localhost',
          message: any<String>(named: 'message'),
          messageType: 'com.lotti.sync.message',
          displayPendingEvent: false,
        ),
      ).thenAnswer((_) async {
        attempt++;
        if (attempt == 1) {
          throw Exception('send failed');
        }
        return r'$event:1';
      });

      await db.addOutboxItem(
        _buildOutbox(
          subject: 'first',
          message: _syncMessageJson('id1'),
          createdAt: DateTime(2024),
        ),
      );

      final queue = OutboundQueue(
        syncDatabase: db,
        gateway: gateway,
        emitEvent: events.add,
        retryDelay: const Duration(milliseconds: 50),
      );

      final firstDelay = await queue.drain();
      final failed = await db.getOutboxItemById(1);
      final failedEvents = events.where(
        (event) => event['event'] == 'sendFailed',
      );
      final failedEvent = failedEvents.singleOrNull;

      expect(firstDelay, const Duration(milliseconds: 50));
      expect(failed?.status, OutboxStatus.pending.index);
      expect(failed?.retries, 1);
      expect(failedEvent, isNotNull);
      expect(failedEvent!['attempts'], 1);

      final secondDelay = await queue.drain();
      final sent = await db.getOutboxItemById(1);

      expect(secondDelay, isNull);
      expect(sent?.status, OutboxStatus.sent.index);
      expect(sent?.retries, 1);
      expect(attempt, 2);
    });

    test('does not drain when disconnected', () async {
      when(
        () => room.getState(lottiSyncRoomStateType),
      ).thenReturn(MockStrippedStateEvent());
      when(() => client.rooms).thenReturn([room]);
      await db.addOutboxItem(
        _buildOutbox(
          subject: 'first',
          message: _syncMessageJson('id1'),
          createdAt: DateTime(2024),
        ),
      );

      final queue = OutboundQueue(
        syncDatabase: db,
        gateway: gateway,
        emitEvent: events.add,
        connected: false,
      );

      final delay = await queue.drain();

      expect(delay, isNull);
      verifyNever(
        () => gateway.sendText(
          roomId: any<String>(named: 'roomId'),
          message: any<String>(named: 'message'),
          messageType: any<String>(named: 'messageType'),
          displayPendingEvent: any<bool>(named: 'displayPendingEvent'),
        ),
      );
    });

    test('uses configured sync room id when available', () async {
      final queue = OutboundQueue(
        syncDatabase: db,
        gateway: gateway,
        emitEvent: events.add,
      )..updateSyncRoomId('!override:localhost');

      when(() => client.rooms).thenReturn([room]);
      when(
        () => gateway.sendText(
          roomId: '!override:localhost',
          message: any<String>(named: 'message'),
          messageType: 'com.lotti.sync.message',
          displayPendingEvent: false,
        ),
      ).thenAnswer((_) async => r'$event:1');

      await db.addOutboxItem(
        _buildOutbox(
          subject: 'first',
          message: _syncMessageJson('id1'),
          createdAt: DateTime(2024),
        ),
      );

      final delay = await queue.drain();

      expect(delay, isNull);
      verify(
        () => gateway.sendText(
          roomId: '!override:localhost',
          message: any<String>(named: 'message'),
          messageType: 'com.lotti.sync.message',
          displayPendingEvent: false,
        ),
      ).called(1);
    });

    test('does not drain when no explicit sync room is identifiable', () async {
      when(() => client.rooms).thenReturn([]);

      await db.addOutboxItem(
        _buildOutbox(
          subject: 'first',
          message: _syncMessageJson('id1'),
          createdAt: DateTime(2024),
        ),
      );

      final queue = OutboundQueue(
        syncDatabase: db,
        gateway: gateway,
        emitEvent: events.add,
      );
      final delay = await queue.drain();

      expect(delay, isNull);
      verifyNever(
        () => gateway.sendText(
          roomId: any<String>(named: 'roomId'),
          message: any<String>(named: 'message'),
          messageType: any<String>(named: 'messageType'),
          displayPendingEvent: any<bool>(named: 'displayPendingEvent'),
        ),
      );
    });

    test('uses the uniquely sync-marked room when override is unset', () async {
      final syncRoom = MockRoom();
      when(() => syncRoom.id).thenReturn('!sync-room:localhost');
      when(() => syncRoom.getState(lottiSyncRoomStateType)).thenReturn(
        MockStrippedStateEvent(),
      );
      when(() => client.rooms).thenReturn([room, syncRoom]);
      when(() => room.getState(lottiSyncRoomStateType)).thenReturn(null);
      when(
        () => gateway.sendText(
          roomId: '!sync-room:localhost',
          message: any<String>(named: 'message'),
          messageType: 'com.lotti.sync.message',
          displayPendingEvent: false,
        ),
      ).thenAnswer((_) async => r'$event:1');

      await db.addOutboxItem(
        _buildOutbox(
          subject: 'first',
          message: _syncMessageJson('id1'),
          createdAt: DateTime(2024),
        ),
      );

      final queue = OutboundQueue(
        syncDatabase: db,
        gateway: gateway,
        emitEvent: events.add,
      );
      final delay = await queue.drain();

      expect(delay, isNull);
      verify(
        () => gateway.sendText(
          roomId: '!sync-room:localhost',
          message: any<String>(named: 'message'),
          messageType: 'com.lotti.sync.message',
          displayPendingEvent: false,
        ),
      ).called(1);
    });

    test(
      'does not drain when multiple sync-marked rooms are present',
      () async {
        final syncRoom = MockRoom();
        final competingRoom = MockRoom();

        when(() => syncRoom.id).thenReturn('!sync-room-1:localhost');
        when(() => competingRoom.id).thenReturn('!sync-room-2:localhost');
        when(() => syncRoom.getState(lottiSyncRoomStateType)).thenReturn(
          MockStrippedStateEvent(),
        );
        when(() => competingRoom.getState(lottiSyncRoomStateType)).thenReturn(
          MockStrippedStateEvent(),
        );
        when(() => client.rooms).thenReturn([syncRoom, competingRoom]);

        await db.addOutboxItem(
          _buildOutbox(
            subject: 'first',
            message: _syncMessageJson('id1'),
            createdAt: DateTime(2024),
          ),
        );

        final queue = OutboundQueue(
          syncDatabase: db,
          gateway: gateway,
          emitEvent: events.add,
        );
        final delay = await queue.drain();

        expect(delay, isNull);
        verifyNever(
          () => gateway.sendText(
            roomId: any<String>(named: 'roomId'),
            message: any<String>(named: 'message'),
            messageType: any<String>(named: 'messageType'),
            displayPendingEvent: any<bool>(named: 'displayPendingEvent'),
          ),
        );
      },
    );

    glados.Glados(
      glados.any.outboundDrainScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'generated drain scenarios match claim/send/retry state model',
      (scenario) async {
        final localDb = SyncDatabase(inMemoryDatabase: true);
        final localGateway = MockMatrixSdkGateway();
        final localClient = MockMatrixClient();
        final generatedEvents = <Map<String, Object?>>[];
        late OutboundQueue queue;

        when(() => localGateway.client).thenReturn(localClient);
        _stubGeneratedRooms(client: localClient, roomMode: scenario.roomMode);
        when(
          () => localGateway.sendText(
            roomId: any<String>(named: 'roomId'),
            message: any<String>(named: 'message'),
            messageType: 'com.lotti.sync.message',
            displayPendingEvent: false,
          ),
        ).thenAnswer((_) async {
          switch (scenario.sendPlan) {
            case _GeneratedOutboundSendPlan.success:
              return _generatedEventId;
            case _GeneratedOutboundSendPlan.throws:
              throw StateError('generated send failure');
            case _GeneratedOutboundSendPlan.throwsAndDisconnects:
              queue.updateConnectivity(isConnected: false);
              throw StateError('generated send failure');
            case _GeneratedOutboundSendPlan.throwsAndDisposes:
              queue.dispose();
              throw StateError('generated send failure');
          }
        });

        try {
          await _insertGeneratedOutboxRows(
            db: localDb,
            scenario: scenario,
          );

          queue = OutboundQueue(
            syncDatabase: localDb,
            gateway: localGateway,
            emitEvent: generatedEvents.add,
            retryDelay: _generatedRetryDelay,
            errorDelay: _generatedErrorDelay,
            maxRetries: _generatedMaxRetries,
            connected: scenario.isConnected,
            syncRoomId: scenario.configuredRoomId,
          );
          if (scenario.isDisposedBeforeDrain) {
            queue.dispose();
          }

          final delay = await queue.drain();
          final rows = await localDb.allOutboxItems;

          expect(delay, scenario.expectedDelay);
          if (!scenario.hasItem) {
            expect(rows, isEmpty);
          } else {
            final head = await localDb.getOutboxItemById(1);
            expect(head, isNotNull);
            expect(head!.status, scenario.expectedHeadStatus);
            expect(head.retries, scenario.expectedHeadRetries);
            for (var id = 2; id <= scenario.pendingTailCount + 1; id++) {
              final tail = await localDb.getOutboxItemById(id);
              expect(tail, isNotNull);
              expect(tail!.status, OutboxStatus.pending.index);
              expect(tail.retries, 0);
            }
          }

          if (scenario.sendsToGateway) {
            final verification = verify(
              () => localGateway.sendText(
                roomId: scenario.expectedRoomId!,
                message: captureAny<String>(named: 'message'),
                messageType: 'com.lotti.sync.message',
                displayPendingEvent: false,
              ),
            )..called(1);
            final sentJson = _decodeSentSyncMessage(
              verification.captured.single as String,
            );
            expect(
              sentJson,
              SyncMessage.aiConfigDelete(id: scenario.headSubject).toJson(),
            );
          } else {
            verifyNever(
              () => localGateway.sendText(
                roomId: any<String>(named: 'roomId'),
                message: any<String>(named: 'message'),
                messageType: any<String>(named: 'messageType'),
                displayPendingEvent: any<bool>(named: 'displayPendingEvent'),
              ),
            );
          }

          if (scenario.succeeds) {
            expect(generatedEvents, hasLength(1));
            expect(generatedEvents.single['event'], 'sendAck');
            expect(generatedEvents.single['itemId'], 1);
            expect(generatedEvents.single['subject'], scenario.headSubject);
            expect(generatedEvents.single['roomId'], scenario.expectedRoomId);
            expect(generatedEvents.single['eventId'], _generatedEventId);
          } else if (scenario.failsAfterClaim) {
            expect(generatedEvents, hasLength(1));
            expect(generatedEvents.single['event'], 'sendFailed');
            expect(generatedEvents.single['itemId'], 1);
            expect(generatedEvents.single['subject'], scenario.headSubject);
            expect(
              generatedEvents.single['attempts'],
              scenario.initialRetries + 1,
            );
            expect(generatedEvents.single['roomId'], scenario.expectedRoomId);
          } else {
            expect(generatedEvents, isEmpty);
          }
        } finally {
          await localDb.close();
        }
      },
      tags: 'glados',
    );
  });
}
