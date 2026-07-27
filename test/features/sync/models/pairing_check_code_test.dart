import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/pairing_check_code.dart';

void main() {
  group('pairingCheckCode', () {
    const user = '@alice:example.com';
    const roomId = '!room123:example.com';
    const homeServer = 'https://matrix.example.com';

    String code({
      String user = user,
      String roomId = roomId,
      String homeServer = homeServer,
    }) => pairingCheckCode(
      user: user,
      roomId: roomId,
      homeServer: homeServer,
    );

    test('is stable, so both devices render the same string', () {
      // The whole point of the code: the inviting device derives it from its
      // persisted config, the joining device from the decoded bundle, and the
      // two must agree without ever exchanging it.
      expect(code(), code());
    });

    test('reads as two groups of three uppercase hex characters', () {
      expect(code(), matches(RegExp(r'^[0-9A-F]{3}-[0-9A-F]{3}$')));
    });

    test('changes when the account changes', () {
      expect(code(user: '@bob:example.com'), isNot(code()));
    });

    test('changes when the room changes', () {
      // A stale code pointing at an abandoned room is exactly the mistake this
      // is meant to surface.
      expect(code(roomId: '!other:example.com'), isNot(code()));
    });

    test('changes when the server changes', () {
      // The confirmation screen shows the server, so the digits under it have
      // to cover it — otherwise the one row a reader might recognise is the
      // row the comparison does not protect.
      expect(code(homeServer: 'https://other.example.com'), isNot(code()));
    });

    test('does not confuse a shifted boundary between the inputs', () {
      // Without the separators, ('@ab', 'c') and ('@a', 'bc') would hash alike.
      expect(
        code(user: '@ab', roomId: 'c'),
        isNot(code(user: '@a', roomId: 'bc')),
      );
    });

    test('is derived from sha256 of "user|roomId|homeServer"', () {
      // Pinned so a change to the derivation — which would silently break
      // pairing between an old and a new build — has to be deliberate.
      expect(code(), '6BA-6DF');
    });
  });
}
