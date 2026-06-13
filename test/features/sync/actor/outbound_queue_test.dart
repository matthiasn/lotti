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
import 'outbound_queue_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OutboundQueue', () {
    late SyncDatabase db;
    late MockMatrixSdkGateway gateway;
    late MockMatrixClient client;
    late MockRoom room;
    final events = <Map<String, Object?>>[];

    // No setUpTestGetIt()/tearDownTestGetIt() here on purpose: OutboundQueue
    // takes all of its collaborators (SyncDatabase, MatrixSdkGateway, the event
    // sink) via its constructor and never touches the global getIt locator, so
    // there is no service-locator state to register or to leak into other tests.
    // The in-memory SyncDatabase is closed in tearDown.
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
        hBuildOutbox(
          subject: 'first',
          message: hSyncMessageJson('id1'),
          createdAt: DateTime(2024, 1, 2),
        ),
      );
      await db.addOutboxItem(
        hBuildOutbox(
          subject: 'second',
          message: hSyncMessageJson('id2'),
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
        hBuildOutbox(
          subject: 'first',
          message: hSyncMessageJson('id1'),
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
        hBuildOutbox(
          subject: 'first',
          message: hSyncMessageJson('id1'),
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
        hBuildOutbox(
          subject: 'first',
          message: hSyncMessageJson('id1'),
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
        hBuildOutbox(
          subject: 'first',
          message: hSyncMessageJson('id1'),
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
        hBuildOutbox(
          subject: 'first',
          message: hSyncMessageJson('id1'),
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
          hBuildOutbox(
            subject: 'first',
            message: hSyncMessageJson('id1'),
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
        hStubGeneratedRooms(client: localClient, roomMode: scenario.roomMode);
        when(
          () => localGateway.sendText(
            roomId: any<String>(named: 'roomId'),
            message: any<String>(named: 'message'),
            messageType: 'com.lotti.sync.message',
            displayPendingEvent: false,
          ),
        ).thenAnswer((_) async {
          switch (scenario.sendPlan) {
            case GeneratedOutboundSendPlan.success:
              return hGeneratedEventId;
            case GeneratedOutboundSendPlan.throws:
              throw StateError('generated send failure');
            case GeneratedOutboundSendPlan.throwsAndDisconnects:
              queue.updateConnectivity(isConnected: false);
              throw StateError('generated send failure');
            case GeneratedOutboundSendPlan.throwsAndDisposes:
              queue.dispose();
              throw StateError('generated send failure');
          }
        });

        try {
          await hInsertGeneratedOutboxRows(
            db: localDb,
            scenario: scenario,
          );

          queue = OutboundQueue(
            syncDatabase: localDb,
            gateway: localGateway,
            emitEvent: generatedEvents.add,
            retryDelay: hGeneratedRetryDelay,
            errorDelay: hGeneratedErrorDelay,
            maxRetries: hGeneratedMaxRetries,
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
            final sentJson = hDecodeSentSyncMessage(
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
            expect(generatedEvents.single['eventId'], hGeneratedEventId);
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

    glados.Glados(
      glados.any.generatedRoomTopology,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'resolves to the sync room iff exactly one room is sync-marked',
      (kinds) async {
        final localDb = SyncDatabase(inMemoryDatabase: true);
        final localGateway = MockMatrixSdkGateway();
        final localClient = MockMatrixClient();
        final generatedEvents = <Map<String, Object?>>[];

        // Build the generated room list and compute the oracle: the resolver
        // returns a room id only when exactly one room is sync-marked
        // (throwing rooms are treated as unmarked).
        final markedIds = <String>[];
        final rooms = <Room>[];
        for (var index = 0; index < kinds.length; index++) {
          final kind = kinds[index];
          final id = '!generated-room-$index:localhost';
          rooms.add(
            hGeneratedRoom(
              id: id,
              isSyncMarked: kind == GeneratedRoomKind.marked,
              throwsOnState: kind == GeneratedRoomKind.throwing,
            ),
          );
          if (kind == GeneratedRoomKind.marked) {
            markedIds.add(id);
          }
        }
        final expectedRoomId = markedIds.length == 1 ? markedIds.single : null;

        when(() => localGateway.client).thenReturn(localClient);
        when(() => localClient.rooms).thenReturn(rooms);
        when(
          () => localGateway.sendText(
            roomId: any<String>(named: 'roomId'),
            message: any<String>(named: 'message'),
            messageType: 'com.lotti.sync.message',
            displayPendingEvent: false,
          ),
        ).thenAnswer((_) async => hGeneratedEventId);

        try {
          // No explicit override → resolution depends purely on room topology.
          await localDb.addOutboxItem(
            hBuildOutbox(
              subject: 'resolve-head',
              message: hSyncMessageJson('resolve-head'),
              createdAt: DateTime(2024, 1, 2),
            ),
          );

          final queue = OutboundQueue(
            syncDatabase: localDb,
            gateway: localGateway,
            emitEvent: generatedEvents.add,
          );

          final delay = await queue.drain();
          final head = await localDb.getOutboxItemById(1);

          if (expectedRoomId == null) {
            // Ambiguous or absent sync room → nothing is sent, item untouched.
            expect(delay, isNull);
            expect(head!.status, OutboxStatus.pending.index);
            verifyNever(
              () => localGateway.sendText(
                roomId: any<String>(named: 'roomId'),
                message: any<String>(named: 'message'),
                messageType: any<String>(named: 'messageType'),
                displayPendingEvent: any<bool>(named: 'displayPendingEvent'),
              ),
            );
            expect(generatedEvents, isEmpty);
          } else {
            // Exactly one marked room → it receives the send and is marked sent.
            expect(head!.status, OutboxStatus.sent.index);
            verify(
              () => localGateway.sendText(
                roomId: expectedRoomId,
                message: any<String>(named: 'message'),
                messageType: 'com.lotti.sync.message',
                displayPendingEvent: false,
              ),
            ).called(1);
            expect(generatedEvents.single['event'], 'sendAck');
            expect(generatedEvents.single['roomId'], expectedRoomId);
          }
        } finally {
          await localDb.close();
        }
      },
      tags: 'glados',
    );
  });
}
