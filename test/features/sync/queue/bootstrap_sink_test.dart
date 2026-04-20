import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/bootstrap_sink.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockEvent extends Mock implements Event {}

Event _buildEvent({
  required String eventId,
  required int originTsMs,
  String roomId = '!roomA:example.org',
}) {
  final event = _MockEvent();
  final content = <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(EventTypes.Message);
  when(() => event.content).thenReturn(content);
  when(() => event.text).thenReturn('stub');
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(originTsMs));
  when(event.toJson).thenReturn(<String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': EventTypes.Message,
    'content': content,
  });
  return event;
}

void main() {
  late SyncDatabase db;
  late MockLoggingService logging;
  late InboundQueue queue;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockLoggingService();
    queue = InboundQueue(db: db, logging: logging);
  });

  tearDown(() async {
    await queue.dispose();
    await db.close();
  });

  BootstrapPageInfo info(int pageIndex, int total) => BootstrapPageInfo(
    pageIndex: pageIndex,
    totalEventsSoFar: total,
    oldestTimestampSoFar: null,
    serverHasMore: true,
    elapsed: const Duration(milliseconds: 1),
  );

  test(
    'onPage forwards events to queue and returns true under high-water',
    () async {
      final sink = QueueBootstrapSink(queue: queue, logging: logging);
      final events = [
        _buildEvent(eventId: r'$a', originTsMs: 1),
        _buildEvent(eventId: r'$b', originTsMs: 2),
      ];
      final cont = await sink.onPage(events, info(0, events.length));
      expect(cont, isTrue);
      final stats = await queue.stats();
      expect(stats.total, 2);
      expect(stats.byProducer[InboundEventProducer.bootstrap], 2);
    },
  );

  test('cancelSignal stops pagination between pages', () async {
    // Make the pre-cancel queue contain >highWater entries so the sink
    // awaits drain when the next onPage fires.
    for (var i = 0; i < 5; i++) {
      await queue.enqueueLive(
        _buildEvent(eventId: '\$pre$i', originTsMs: i),
      );
    }
    // Cancel signal completes immediately.
    final cancel = Future<void>.value();
    final sink = QueueBootstrapSink(
      queue: queue,
      logging: logging,
      highWater: 0,
      backPressureTimeout: const Duration(seconds: 5),
      cancelSignal: cancel,
    );
    final next = [
      _buildEvent(eventId: r'$page1', originTsMs: 100),
    ];
    final cont = await sink.onPage(next, info(0, 6));
    expect(cont, isFalse);
  });

  test(
    'back-pressure timeout returns false so paging halts on wedged worker',
    () async {
      for (var i = 0; i < 5; i++) {
        await queue.enqueueLive(
          _buildEvent(eventId: '\$pre$i', originTsMs: i),
        );
      }
      final sink = QueueBootstrapSink(
        queue: queue,
        logging: logging,
        highWater: 0,
        backPressureTimeout: const Duration(milliseconds: 50),
      );
      final page = [
        _buildEvent(eventId: r'$x', originTsMs: 1000),
      ];
      final cont = await sink.onPage(page, info(0, 6));
      expect(cont, isFalse);
    },
  );
}
