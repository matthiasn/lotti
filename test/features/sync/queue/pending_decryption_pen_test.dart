import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

Event _buildEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
  required String type,
  Map<String, dynamic>? content,
}) {
  final event = MockEvent();
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

enum _GeneratedPenOperationKind {
  holdEncrypted,
  holdPlain,
  flushAllStillEncrypted,
  flushAllDecrypt,
  flushTargetDecrypt,
  flushTargetThrows,
}

class _GeneratedPenOperation {
  const _GeneratedPenOperation({
    required this.kind,
    required this.targetSlot,
  });

  final _GeneratedPenOperationKind kind;
  final int targetSlot;

  String get eventId =>
      r'$pen-'
      '$targetSlot';

  bool get isFlush {
    switch (kind) {
      case _GeneratedPenOperationKind.flushAllStillEncrypted:
      case _GeneratedPenOperationKind.flushAllDecrypt:
      case _GeneratedPenOperationKind.flushTargetDecrypt:
      case _GeneratedPenOperationKind.flushTargetThrows:
        return true;
      case _GeneratedPenOperationKind.holdEncrypted:
      case _GeneratedPenOperationKind.holdPlain:
        return false;
    }
  }

  bool decrypts(String eventId) {
    switch (kind) {
      case _GeneratedPenOperationKind.flushAllDecrypt:
        return true;
      case _GeneratedPenOperationKind.flushTargetDecrypt:
        return eventId == this.eventId;
      case _GeneratedPenOperationKind.holdEncrypted:
      case _GeneratedPenOperationKind.holdPlain:
      case _GeneratedPenOperationKind.flushAllStillEncrypted:
      case _GeneratedPenOperationKind.flushTargetThrows:
        return false;
    }
  }

  bool throwsFor(String eventId) =>
      kind == _GeneratedPenOperationKind.flushTargetThrows &&
      eventId == this.eventId;

  @override
  String toString() {
    return '_GeneratedPenOperation('
        'kind: $kind, '
        'targetSlot: $targetSlot'
        ')';
  }
}

class _GeneratedPenScenario {
  const _GeneratedPenScenario({
    required this.capacity,
    required this.maxAttempts,
    required this.operations,
  });

  final int capacity;
  final int maxAttempts;
  final List<_GeneratedPenOperation> operations;

  @override
  String toString() {
    return '_GeneratedPenScenario('
        'capacity: $capacity, '
        'maxAttempts: $maxAttempts, '
        'operations: $operations'
        ')';
  }
}

class _ExpectedHeldPenEntry {
  int attempts = 0;
}

class _ExpectedPenFlush {
  const _ExpectedPenFlush({
    required this.enqueued,
    required this.stillEncrypted,
    required this.dropped,
  });

  final int enqueued;
  final int stillEncrypted;
  final int dropped;
}

class _ExpectedPenModel {
  _ExpectedPenModel({
    required this.capacity,
    required this.maxAttempts,
  });

  final int capacity;
  final int maxAttempts;
  final LinkedHashMap<String, _ExpectedHeldPenEntry> held =
      LinkedHashMap<String, _ExpectedHeldPenEntry>();
  final Set<String> queuedEventIds = <String>{};

  void holdEncrypted(String eventId) {
    final existing = held.remove(eventId) ?? _ExpectedHeldPenEntry();
    held[eventId] = existing;
    while (held.length > capacity) {
      held.remove(held.keys.first);
    }
  }

  _ExpectedPenFlush flush(_GeneratedPenOperation operation) {
    var enqueued = 0;
    var stillEncrypted = 0;
    var dropped = 0;
    final decrypted = <String>[];

    for (final eventId in held.keys.toList(growable: false)) {
      final entry = held[eventId];
      if (entry == null) continue;

      if (operation.decrypts(eventId)) {
        decrypted.add(eventId);
        continue;
      }

      entry.attempts++;
      if (entry.attempts >= maxAttempts) {
        held.remove(eventId);
        dropped++;
      } else {
        stillEncrypted++;
      }
    }

    for (final eventId in decrypted) {
      held.remove(eventId);
      queuedEventIds.add(eventId);
    }
    enqueued = decrypted.length;

    return _ExpectedPenFlush(
      enqueued: enqueued,
      stillEncrypted: stillEncrypted,
      dropped: dropped,
    );
  }
}

extension _AnyPendingDecryptionPenScenario on glados.Any {
  glados.Generator<_GeneratedPenOperationKind> get penOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedPenOperationKind.values);

  glados.Generator<_GeneratedPenOperation> get penOperation =>
      glados.CombinableAny(this).combine2(
        penOperationKind,
        glados.IntAnys(this).intInRange(0, 5),
        (
          _GeneratedPenOperationKind kind,
          int targetSlot,
        ) => _GeneratedPenOperation(kind: kind, targetSlot: targetSlot),
      );

  glados.Generator<_GeneratedPenScenario> get penScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(1, 5),
        glados.IntAnys(this).intInRange(1, 4),
        glados.ListAnys(this).listWithLengthInRange(1, 24, penOperation),
        (
          int capacity,
          int maxAttempts,
          List<_GeneratedPenOperation> operations,
        ) => _GeneratedPenScenario(
          capacity: capacity,
          maxAttempts: maxAttempts,
          operations: operations,
        ),
      );
}

void main() {
  late SyncDatabase db;
  late MockDomainLogger logging;
  late InboundQueue queue;
  late MockRoom room;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockDomainLogger();
    queue = InboundQueue(db: db, logging: logging);
    room = MockRoom();
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
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any(named: 'subDomain', that: contains('fetch')),
        ),
      ).called(1);
    },
  );

  test(
    'startSweeping fires the periodic flush and stop() awaits the '
    'in-flight sweep before returning',
    () async {
      final pen =
          PendingDecryptionPen(
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

      final enqueued = queue.depthChanges.firstWhere(
        (signal) => signal.total == 1,
      );
      pen.startSweeping(resolveRoom: () async => room, queue: queue);
      await enqueued.timeout(const Duration(seconds: 2));
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

  glados.Glados(
    glados.any.penScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'generated hold and flush sequences match the bounded pen model',
    (scenario) async {
      final localDb = SyncDatabase(inMemoryDatabase: true);
      final localLogging = MockDomainLogger();
      final localQueue = InboundQueue(db: localDb, logging: localLogging);
      final localRoom = MockRoom();
      when(() => localRoom.id).thenReturn(roomId);

      try {
        final pen = PendingDecryptionPen(
          logging: localLogging,
          capacity: scenario.capacity,
          maxAttempts: scenario.maxAttempts,
        );
        final expected = _ExpectedPenModel(
          capacity: scenario.capacity,
          maxAttempts: scenario.maxAttempts,
        );
        var activeFlush = const _GeneratedPenOperation(
          kind: _GeneratedPenOperationKind.flushAllStillEncrypted,
          targetSlot: 0,
        );
        when(
          () => localRoom.getEventById(any()),
        ).thenAnswer((invocation) async {
          final eventId = invocation.positionalArguments.single as String;
          if (activeFlush.throwsFor(eventId)) {
            throw StateError('generated fetch failure');
          }
          return _buildEvent(
            eventId: eventId,
            roomId: roomId,
            originTsMs: 1000 + int.parse(eventId.split('-').last),
            type: activeFlush.decrypts(eventId)
                ? EventTypes.Message
                : EventTypes.Encrypted,
          );
        });

        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case _GeneratedPenOperationKind.holdEncrypted:
              expect(
                pen.hold(
                  _buildEvent(
                    eventId: operation.eventId,
                    roomId: roomId,
                    originTsMs: 1000 + operation.targetSlot,
                    type: EventTypes.Encrypted,
                  ),
                ),
                isTrue,
              );
              expected.holdEncrypted(operation.eventId);
            case _GeneratedPenOperationKind.holdPlain:
              expect(
                pen.hold(
                  _buildEvent(
                    eventId: operation.eventId,
                    roomId: roomId,
                    originTsMs: 1000 + operation.targetSlot,
                    type: EventTypes.Message,
                  ),
                ),
                isFalse,
              );
            case _GeneratedPenOperationKind.flushAllStillEncrypted:
            case _GeneratedPenOperationKind.flushAllDecrypt:
            case _GeneratedPenOperationKind.flushTargetDecrypt:
            case _GeneratedPenOperationKind.flushTargetThrows:
              activeFlush = operation;
              final actual = await pen.flushInto(
                queue: localQueue,
                room: localRoom,
              );
              final expectedFlush = expected.flush(operation);
              expect(actual.enqueued, expectedFlush.enqueued);
              expect(actual.stillEncrypted, expectedFlush.stillEncrypted);
              expect(actual.dropped, expectedFlush.dropped);
          }

          expect(pen.size, expected.held.length);
        }

        final stats = await localQueue.stats();
        expect(stats.total, expected.queuedEventIds.length);
      } finally {
        await localQueue.dispose();
        await localDb.close();
      }
    },
    tags: 'glados',
  );
}
