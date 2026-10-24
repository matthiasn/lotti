import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/sync_envelope.dart';

void main() {
  group('StoredSyncEnvelope.fromStoredJson', () {
    const roomId = '!room:example.org';
    final stored = <String, dynamic>{
      'event_id': r'$stored',
      'room_id': roomId,
      'sender': '@alice:example.org',
      'origin_server_ts': 4242,
      'type': 'm.room.message',
      'content': <String, dynamic>{'msgtype': 'm.text', 'body': 'aGk='},
    };

    test('reads what the apply path needs from what Event.toJson wrote', () {
      final envelope = StoredSyncEnvelope.fromStoredJson(
        stored,
        roomId: roomId,
      );

      expect(envelope.eventId, r'$stored');
      expect(envelope.roomId, roomId);
      expect(envelope.senderId, '@alice:example.org');
      expect(envelope.originServerTs.millisecondsSinceEpoch, 4242);
      expect(envelope.text, 'aGk=');
    });

    test('takes the room from the queue row, not from the JSON', () {
      final envelope = StoredSyncEnvelope.fromStoredJson(
        {...stored, 'room_id': '!other:example.org'},
        roomId: roomId,
      );

      expect(envelope.roomId, roomId);
    });

    test('reads a missing or non-string body as the empty string, as '
        'Event.text does', () {
      final noBody = StoredSyncEnvelope.fromStoredJson(
        {
          ...stored,
          'content': <String, dynamic>{'msgtype': 'm.text'},
        },
        roomId: roomId,
      );
      final numericBody = StoredSyncEnvelope.fromStoredJson(
        {
          ...stored,
          'content': <String, dynamic>{'body': 7},
        },
        roomId: roomId,
      );
      final noContent = StoredSyncEnvelope.fromStoredJson(
        {...stored, 'content': 'not a map'},
        roomId: roomId,
      );

      expect(noBody.text, '');
      expect(numericBody.text, '');
      expect(noContent.text, '');
    });

    test('throws on JSON that is not an event, so the row is skipped', () {
      expect(
        () => StoredSyncEnvelope.fromStoredJson(
          {...stored}..remove('event_id'),
          roomId: roomId,
        ),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => StoredSyncEnvelope.fromStoredJson(
          {...stored, 'origin_server_ts': 'yesterday'},
          roomId: roomId,
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
