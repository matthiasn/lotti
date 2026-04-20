import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockEvent extends Mock implements Event {}

class _MockRoom extends Mock implements Room {}

Event _buildEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
  required String type,
  Map<String, dynamic>? content,
}) {
  final event = _MockEvent();
  final c = content ?? <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(type);
  when(() => event.content).thenReturn(c);
  when(() => event.text).thenReturn('stub');
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(originTsMs));
  when(event.toJson).thenReturn(<String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': type,
    'content': c,
  });
  return event;
}

void main() {
  late SyncDatabase db;
  late MockLoggingService logging;
  late InboundQueue queue;
  late _MockRoom room;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockLoggingService();
    queue = InboundQueue(db: db, logging: logging);
    room = _MockRoom();
    when(() => room.id).thenReturn(roomId);
  });

  tearDown(() async {
    await queue.dispose();
    await db.close();
  });

  test(
    'hold returns false for already-decrypted events so producer can enqueue them',
    () {
      final pen = PendingDecryptionPen(logging: logging);
      final plain = _buildEvent(
        eventId: r'$plain',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Message,
      );
      expect(pen.hold(plain), isFalse);
      expect(pen.size, 0);
    },
  );

  test('hold retains encrypted events (F3)', () {
    final pen = PendingDecryptionPen(logging: logging);
    final enc = _buildEvent(
      eventId: r'$enc',
      roomId: roomId,
      originTsMs: 1,
      type: EventTypes.Encrypted,
    );
    expect(pen.hold(enc), isTrue);
    expect(pen.size, 1);
  });

  test(
    'flushInto forwards decrypted events to the queue via room.getEventById',
    () async {
      final pen = PendingDecryptionPen(logging: logging);
      const encId = r'$rotate';
      final encrypted = _buildEvent(
        eventId: encId,
        roomId: roomId,
        originTsMs: 100,
        type: EventTypes.Encrypted,
      );
      pen.hold(encrypted);

      final decrypted = _buildEvent(
        eventId: encId,
        roomId: roomId,
        originTsMs: 100,
        type: EventTypes.Message,
      );
      when(() => room.getEventById(encId)).thenAnswer((_) async => decrypted);

      final outcome = await pen.flushInto(queue: queue, room: room);
      expect(outcome.enqueued, 1);
      expect(outcome.stillEncrypted, 0);
      expect(pen.size, 0);

      final stats = await queue.stats();
      expect(stats.total, 1);
    },
  );

  test('flushInto keeps still-encrypted events for the next sweep', () async {
    final pen = PendingDecryptionPen(logging: logging);
    final encrypted = _buildEvent(
      eventId: r'$stuck',
      roomId: roomId,
      originTsMs: 1,
      type: EventTypes.Encrypted,
    );
    pen.hold(encrypted);
    when(() => room.getEventById(r'$stuck')).thenAnswer((_) async => encrypted);

    final outcome = await pen.flushInto(queue: queue, room: room);
    expect(outcome.enqueued, 0);
    expect(outcome.stillEncrypted, 1);
    expect(pen.size, 1);
  });

  test(
    'entry exceeding maxAttempts is dropped without being enqueued',
    () async {
      final pen = PendingDecryptionPen(logging: logging, maxAttempts: 2);
      final encrypted = _buildEvent(
        eventId: r'$doomed',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Encrypted,
      );
      pen.hold(encrypted);
      when(
        () => room.getEventById(r'$doomed'),
      ).thenAnswer((_) async => encrypted);

      await pen.flushInto(queue: queue, room: room);
      await pen.flushInto(queue: queue, room: room);

      expect(pen.size, 0);
      final stats = await queue.stats();
      expect(stats.total, 0);
    },
  );

  test('capacity eviction drops the oldest entry', () {
    final pen = PendingDecryptionPen(logging: logging, capacity: 2)
      ..hold(
        _buildEvent(
          eventId: r'$a',
          roomId: roomId,
          originTsMs: 1,
          type: EventTypes.Encrypted,
        ),
      )
      ..hold(
        _buildEvent(
          eventId: r'$b',
          roomId: roomId,
          originTsMs: 2,
          type: EventTypes.Encrypted,
        ),
      )
      ..hold(
        _buildEvent(
          eventId: r'$c',
          roomId: roomId,
          originTsMs: 3,
          type: EventTypes.Encrypted,
        ),
      );
    expect(pen.size, 2);
  });
}
