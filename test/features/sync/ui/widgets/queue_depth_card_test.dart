import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/ui/widgets/queue_depth_card.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _MockEvent extends Mock implements Event {}

Event _buildEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
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
  const roomId = '!roomA:example.org';

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

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('renders zero when the queue is empty', (tester) async {
    await tester.pumpWidget(wrap(QueueDepthCard(queue: queue)));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.text('Inbound queue'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.textContaining('Queue empty'), findsOneWidget);
  });

  testWidgets(
    'reflects enqueued events and per-producer breakdown',
    (tester) async {
      await tester.pumpWidget(wrap(QueueDepthCard(queue: queue)));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      await queue.enqueueBatch(
        [
          _buildEvent(eventId: r'$a', roomId: roomId, originTsMs: 1),
          _buildEvent(eventId: r'$b', roomId: roomId, originTsMs: 2),
        ],
        producer: InboundEventProducer.live,
      );
      await queue.enqueueBatch(
        [
          _buildEvent(eventId: r'$c', roomId: roomId, originTsMs: 3),
        ],
        producer: InboundEventProducer.bridge,
      );
      // Allow the broadcast depth stream + setState cycle to land.
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('live: 2'), findsOneWidget);
      expect(find.textContaining('bridge: 1'), findsOneWidget);
    },
  );
}
