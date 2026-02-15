import 'dart:convert';

// ignore_for_file: avoid_redundant_argument_values, cascade_invocations,
// directives_ordering
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/actor/outbound_queue.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSdkGateway extends Mock implements MatrixSdkGateway {}

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OutboundQueue', () {
    late SyncDatabase db;
    late MockMatrixSdkGateway gateway;
    late MockClient client;
    late MockRoom room;
    final events = <Map<String, Object?>>[];

    setUp(() {
      db = SyncDatabase(inMemoryDatabase: true);
      gateway = MockMatrixSdkGateway();
      client = MockClient();
      room = MockRoom();
      events.clear();

      when(() => gateway.client).thenReturn(client);
      when(() => room.id).thenReturn('!room:localhost');
    });

    tearDown(() async {
      await db.close();
    });

    test('drains one queued row and marks it sent', () async {
      when(() => client.rooms).thenReturn([room]);
      when(() => gateway.sendText(
            roomId: '!room:localhost',
            message: any<String>(named: 'message'),
            messageType: 'com.lotti.sync.message',
            displayPendingEvent: false,
          )).thenAnswer((_) async => r'$event:1');

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
      when(() => client.rooms).thenReturn([room]);
      when(() => gateway.sendText(
            roomId: '!room:localhost',
            message: any<String>(named: 'message'),
            messageType: 'com.lotti.sync.message',
            displayPendingEvent: false,
          )).thenAnswer((_) async {
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
          createdAt: DateTime(2024, 1, 1),
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
      when(() => client.rooms).thenReturn([room]);
      await db.addOutboxItem(
        _buildOutbox(
          subject: 'first',
          message: _syncMessageJson('id1'),
          createdAt: DateTime(2024, 1, 1),
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
      );
      queue.updateSyncRoomId('!override:localhost');

      when(() => client.rooms).thenReturn([room]);
      when(() => gateway.sendText(
            roomId: '!override:localhost',
            message: any<String>(named: 'message'),
            messageType: 'com.lotti.sync.message',
            displayPendingEvent: false,
          )).thenAnswer((_) async => r'$event:1');

      await db.addOutboxItem(
        _buildOutbox(
          subject: 'first',
          message: _syncMessageJson('id1'),
          createdAt: DateTime(2024, 1, 1),
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
  });
}
