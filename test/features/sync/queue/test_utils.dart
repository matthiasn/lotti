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

/// Wires [room] so `PendingDecryptionPen` can ask the SDK to decrypt.
///
/// The pen calls `room.client.encryption.decryptRoomEvent`, not
/// `room.getEventById`. That distinction is the point: `getEventById` returns
/// the SDK's stored copy whenever it has one, so polling it could only ever
/// *observe* a decryption performed elsewhere — it never attempted one, and
/// never triggered the SDK's `maybeAutoRequest` for the missing session.
///
/// Benches therefore have to provide an `Encryption`. This one resolves
/// against whatever the room currently reports for that event id, which is
/// what they already stub, so a test that makes an event "become decrypted"
/// keeps working unchanged.
void stubPenDecryption(MockRoom room) {
  // Owned here rather than pushed onto every bench: the helper is the only
  // reason these tests need an `Event` matcher at all.
  registerFallbackValue(
    buildSyncEvent(
      eventId: r'$penFallback',
      roomId: '!fallback:example.org',
      originTsMs: 0,
    ),
  );
  final client = MockMatrixClient();
  final encryption = MockEncryption();
  when(() => room.client).thenReturn(client);
  when(() => client.encryption).thenReturn(encryption);
  when(() => encryption.decryptRoomEvent(any())).thenAnswer((invocation) async {
    final event = invocation.positionalArguments.single as Event;
    return await room.getEventById(event.eventId) ?? event;
  });
}
