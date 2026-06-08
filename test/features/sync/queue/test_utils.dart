import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Builds a fully stubbed Matrix [Event] shaped like a Lotti sync
/// payload for the queue-pipeline tests.
///
/// Shared factory for the `lib/features/sync/queue/` test suite — the
/// `InboundQueue`, `InboundWorker` and coordinator tests all need the
/// same `MockEvent` wiring (eventId / roomId / type / content / text /
/// originServerTs / toJson). Defaults to an accepted sync message;
/// callers vary [type] and [content] for the filtered/encrypted/
/// non-payload cases.
Event buildSyncEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
  String type = EventTypes.Message,
  Map<String, dynamic>? content,
}) {
  final event = MockEvent();
  final eventContent = content ?? <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(type);
  when(() => event.content).thenReturn(eventContent);
  when(() => event.text).thenReturn('stub text');
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(originTsMs));
  when(event.toJson).thenReturn(<String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': type,
    'content': eventContent,
  });
  return event;
}
