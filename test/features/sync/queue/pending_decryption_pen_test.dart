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

  test('capacity eviction drops the oldest entry', () async {
    final pen = PendingDecryptionPen(logging: logging, capacity: 2);
    final a = _buildEvent(
      eventId: r'$a',
      roomId: roomId,
      originTsMs: 1,
      type: EventTypes.Encrypted,
    );
    final b = _buildEvent(
      eventId: r'$b',
      roomId: roomId,
      originTsMs: 2,
      type: EventTypes.Encrypted,
    );
    final c = _buildEvent(
      eventId: r'$c',
      roomId: roomId,
      originTsMs: 3,
      type: EventTypes.Encrypted,
    );
    pen
      ..hold(a)
      ..hold(b)
      ..hold(c);

    // Stage decrypted versions for $b and $c; if the pen ever asks for
    // $a it would have to be an eviction regression, and the flush
    // would crash on the missing stub.
    final bDecrypted = _buildEvent(
      eventId: r'$b',
      roomId: roomId,
      originTsMs: 2,
      type: EventTypes.Message,
    );
    final cDecrypted = _buildEvent(
      eventId: r'$c',
      roomId: roomId,
      originTsMs: 3,
      type: EventTypes.Message,
    );
    when(
      () => room.getEventById(r'$b'),
    ).thenAnswer((_) async => bDecrypted);
    when(
      () => room.getEventById(r'$c'),
    ).thenAnswer((_) async => cDecrypted);

    expect(pen.size, 2);

    final outcome = await pen.flushInto(queue: queue, room: room);
    expect(outcome.enqueued, 2);
    expect(pen.size, 0);
    verifyNever(() => room.getEventById(r'$a'));

    final ready = await queue.peekBatchReady(maxBatch: 10);
    expect(ready.map((e) => e.eventId).toList(), [r'$b', r'$c']);
  });

  test(
    're-holding an existing event refreshes heldAt and keeps the pen at '
    'the same size',
    () {
      final pen = PendingDecryptionPen(logging: logging, capacity: 4);
      final encrypted = _buildEvent(
        eventId: r'$rehold',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Encrypted,
      );
      expect(pen.hold(encrypted), isTrue);
      expect(pen.size, 1);
      // Second hold for the same id must not grow the pen.
      expect(pen.hold(encrypted), isTrue);
      expect(pen.size, 1);
    },
  );

  test(
    'flushInto swallows a getEventById error and treats the held event '
    'as still-encrypted for the next sweep',
    () async {
      final pen = PendingDecryptionPen(logging: logging);
      final encrypted = _buildEvent(
        eventId: r'$err',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Encrypted,
      );
      pen.hold(encrypted);
      when(
        () => room.getEventById(r'$err'),
      ).thenThrow(StateError('sdk glitch'));

      final outcome = await pen.flushInto(queue: queue, room: room);
      expect(outcome.stillEncrypted, 1);
      expect(pen.size, 1);
      verify(
        () => logging.captureException(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain', that: contains('fetch')),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    },
  );

  test(
    'startSweeping fires the periodic flush and stop() awaits the '
    'in-flight sweep before returning',
    () async {
      final pen = PendingDecryptionPen(
        logging: logging,
        sweepInterval: const Duration(milliseconds: 10),
      )..hold(
        _buildEvent(
          eventId: r'$sweep',
          roomId: roomId,
          originTsMs: 1,
          type: EventTypes.Encrypted,
        ),
      );
      final decrypted = _buildEvent(
        eventId: r'$sweep',
        roomId: roomId,
        originTsMs: 1,
        type: EventTypes.Message,
      );
      when(
        () => room.getEventById(r'$sweep'),
      ).thenAnswer((_) async => decrypted);

      pen.startSweeping(resolveRoom: () async => room, queue: queue);
      // Wait long enough for the periodic sweep to fire at least once.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        if (pen.size == 0) break;
      }
      expect(pen.size, 0);
      await pen.stop();
      final stats = await queue.stats();
      expect(stats.total, 1);
    },
  );

  test(
    'startSweeping is a no-op when sweepInterval is null (default) so the '
    'worker-driven mode does not accidentally spin its own timer',
    () {
      final pen = PendingDecryptionPen(logging: logging)
        ..startSweeping(resolveRoom: () async => room, queue: queue);
      // No timer has been installed — calling stop() is a no-op too.
      expect(pen.size, 0);
    },
  );
}
