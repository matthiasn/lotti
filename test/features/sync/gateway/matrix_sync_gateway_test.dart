import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';

void main() {
  group('RoomInviteEvent', () {
    test('constructor sets fields', () {
      const event = RoomInviteEvent(
        roomId: '!room:server',
        senderId: '@user:server',
      );

      expect(event.roomId, '!room:server');
      expect(event.senderId, '@user:server');
    });
  });
}
