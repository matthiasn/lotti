import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

InboundEventQueueItem _buildRow({
  int queueId = 7,
  String eventId = r'$row',
  String roomId = '!room:example.org',
  int originTs = 4242,
  String producer = 'bootstrap',
  String rawJson = r'{"event_id":"$row"}',
  int enqueuedAt = 1111,
  int attempts = 3,
  int leaseUntil = 999,
  String status = 'leased',
}) => InboundEventQueueItem(
  queueId: queueId,
  eventId: eventId,
  roomId: roomId,
  originTs: originTs,
  producer: producer,
  rawJson: rawJson,
  enqueuedAt: enqueuedAt,
  attempts: attempts,
  nextDueAt: 0,
  leaseUntil: leaseUntil,
  status: status,
  resurrectionCount: 0,
);

void main() {
  group('EnqueueResult', () {
    test('empty carries zero for every counter and ts bound', () {
      const r = EnqueueResult.empty;
      expect(r.accepted, 0);
      expect(r.duplicatesDropped, 0);
      expect(r.filteredOutByType, 0);
      expect(r.deferredPendingDecryption, 0);
      expect(r.oldestTsAccepted, 0);
      expect(r.newestTsAccepted, 0);
    });
  });

  group('producerFromName', () {
    test('resolves every stored enum name back to its producer', () {
      for (final producer in InboundEventProducer.values) {
        expect(producerFromName(producer.name), producer);
      }
    });

    test('unknown name falls back to live', () {
      expect(producerFromName('fromTheFuture'), InboundEventProducer.live);
      expect(producerFromName(''), InboundEventProducer.live);
    });
  });

  glados.Glados(
    glados.any.letterOrDigits,
    glados.ExploreConfig(numRuns: 120),
  ).test('producerFromName resolves a known name or falls back to live', (
    name,
  ) {
    final resolved = producerFromName(name);
    final exact = InboundEventProducer.values.where((p) => p.name == name);
    expect(
      resolved,
      exact.isEmpty ? InboundEventProducer.live : exact.single,
      reason: 'name=$name',
    );
  }, tags: 'glados');

  group('InboundQueueEntry.fromRow', () {
    test('maps every column and applies the freshly stamped lease', () {
      final entry = InboundQueueEntry.fromRow(_buildRow(), leaseUntil: 5555);
      expect(entry.queueId, 7);
      expect(entry.eventId, r'$row');
      expect(entry.roomId, '!room:example.org');
      expect(entry.originTs, 4242);
      expect(entry.producer, InboundEventProducer.bootstrap);
      expect(entry.enqueuedAt, 1111);
      expect(entry.attempts, 3);
      expect(entry.rawJson, r'{"event_id":"$row"}');
      // peekBatchReady stamps the lease after selecting; the entry must
      // carry the fresh lease, not the stale row value (999).
      expect(entry.leaseUntil, 5555);
    });

    test('unknown stored producer name resolves to live', () {
      final entry = InboundQueueEntry.fromRow(
        _buildRow(producer: 'not-a-producer'),
        leaseUntil: 0,
      );
      expect(entry.producer, InboundEventProducer.live);
    });
  });

  group('InboundQueueEntry.toEvent', () {
    test('materialises the stored rawJson against the given room', () {
      const roomId = '!room:example.org';
      final room = MockRoom();
      when(() => room.id).thenReturn(roomId);
      final entry = InboundQueueEntry.fromRow(
        _buildRow(
          eventId: r'$mat',
          rawJson: jsonEncode(<String, dynamic>{
            'event_id': r'$mat',
            'room_id': roomId,
            'origin_server_ts': 4242,
            'type': EventTypes.Message,
            // Event.fromJson requires a non-null sender field.
            'sender': '@alice:example.org',
            'content': <String, dynamic>{'msgtype': 'm.text', 'body': 'hi'},
          }),
        ),
        leaseUntil: 0,
      );
      final event = entry.toEvent(room);
      expect(event.eventId, r'$mat');
      expect(event.roomId, roomId);
      expect(event.originServerTs.millisecondsSinceEpoch, 4242);
      expect(event.senderId, '@alice:example.org');
      expect(event.content['body'], 'hi');
    });
  });

  group('InboundQueueStatuses', () {
    test('string values match the sync_db DDL literals', () {
      // The partial indices in lib/database/sync_db.dart are declared
      // with these literals; a drifting constant would silently
      // de-optimise every clamp/resurrection query.
      expect(InboundQueueStatuses.enqueued, 'enqueued');
      expect(InboundQueueStatuses.leased, 'leased');
      expect(InboundQueueStatuses.retrying, 'retrying');
      expect(InboundQueueStatuses.applied, 'applied');
      expect(InboundQueueStatuses.abandoned, 'abandoned');
    });

    test('active and peekable cover the same drainable set', () {
      expect(
        InboundQueueStatuses.active.toSet(),
        InboundQueueStatuses.peekable.toSet(),
      );
      expect(
        InboundQueueStatuses.active,
        isNot(contains(InboundQueueStatuses.applied)),
      );
      expect(
        InboundQueueStatuses.active,
        isNot(contains(InboundQueueStatuses.abandoned)),
      );
    });
  });
}
