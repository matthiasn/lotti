import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:matrix/matrix.dart' show EventTypes;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../sync_verification_fixtures.dart';

void main() {
  /// The peer's unanswered request, from `@alice:example.com/[deviceId]`.
  SyncVerificationState incomingFrom(String deviceId) => verificationState(
    id: 'incoming',
    direction: SyncVerificationDirection.incoming,
    peerDeviceId: deviceId,
    lastStep: EventTypes.KeyVerificationRequest,
  );

  /// This device's own ceremony toward PEER, sitting at [lastStep].
  SyncVerificationState outgoingAt(
    String lastStep, {
    bool cancelled = false,
  }) => verificationState(
    id: 'outgoing',
    peerDeviceId: 'PEER',
    lastStep: lastStep,
    outcome: cancelled
        ? KeyVerificationOutcome.cancelled
        : KeyVerificationOutcome.pending,
  );

  group('verificationIdentity', () {
    test('orders by user, then device, as the SDK orders a glare', () {
      final earlier = verificationIdentity(userId: '@a:x', deviceId: 'B');
      final later = verificationIdentity(userId: '@a:x', deviceId: 'C');
      final otherUser = verificationIdentity(userId: '@b:x', deviceId: 'A');

      expect(earlier.compareTo(later), isNegative);
      expect(later.compareTo(otherUser), isNegative);
    });

    test('tolerates a session without an identity yet', () {
      expect(verificationIdentity(userId: null, deviceId: null), '|');
    });

    test('is the identity a state reports for its peer', () {
      expect(
        incomingFrom('AAA').peerIdentity,
        verificationIdentity(userId: '@alice:example.com', deviceId: 'AAA'),
      );
    });
  });

  group('isUnansweredRequest', () {
    test('holds before the request is sent and while it awaits ready', () {
      expect(isUnansweredRequest(outgoingAt('')), isTrue);
      expect(
        isUnansweredRequest(outgoingAt(EventTypes.KeyVerificationRequest)),
        isTrue,
      );
    });

    test('fails once the peer answered or the ceremony ended', () {
      expect(
        isUnansweredRequest(outgoingAt(EventTypes.KeyVerificationReady)),
        isFalse,
      );
      expect(
        isUnansweredRequest(
          outgoingAt(EventTypes.KeyVerificationRequest, cancelled: true),
        ),
        isFalse,
      );
    });
  });

  group('shouldYieldTo', () {
    test('yields an unanswered request to a smaller identity', () {
      expect(
        shouldYieldTo(
          incoming: incomingFrom('AAA'),
          outgoing: outgoingAt(EventTypes.KeyVerificationRequest),
          ownUserId: '@alice:example.com',
          ownDeviceId: 'ZZZ',
        ),
        isTrue,
      );
    });

    test('keeps its own request against a larger identity', () {
      // Exactly one side yields: the peer, being larger, is the one to.
      expect(
        shouldYieldTo(
          incoming: incomingFrom('ZZZ'),
          outgoing: outgoingAt(EventTypes.KeyVerificationRequest),
          ownUserId: '@alice:example.com',
          ownDeviceId: 'AAA',
        ),
        isFalse,
      );
    });

    test('never yields a ceremony the peer has answered, nor without one', () {
      expect(
        shouldYieldTo(
          incoming: incomingFrom('AAA'),
          outgoing: outgoingAt(EventTypes.KeyVerificationReady),
          ownUserId: '@alice:example.com',
          ownDeviceId: 'ZZZ',
        ),
        isFalse,
      );
      expect(
        shouldYieldTo(
          incoming: incomingFrom('AAA'),
          outgoing: null,
          ownUserId: '@alice:example.com',
          ownDeviceId: 'ZZZ',
        ),
        isFalse,
      );
    });
  });

  group('reofferOnOwnVerification', () {
    test('calls back once for each ceremony the service stores, not for a '
        "ceremony's later steps nor for one it does not hold", () async {
      final service = MockMatrixService();
      final stream = StreamController<SyncVerificationState>.broadcast();
      addTearDown(stream.close);
      when(
        () => service.outgoingVerifications,
      ).thenAnswer((_) => stream.stream);
      final first = verificationState(id: 'first');
      final firstLater = verificationState(
        id: 'first',
        lastStep: EventTypes.KeyVerificationRequest,
      );
      final second = verificationState(id: 'second');
      final stranger = verificationState(id: 'stranger');
      SyncVerificationState? stored;
      when(() => service.outgoingVerification).thenAnswer((_) => stored);
      var reoffers = 0;
      final subscription = reofferOnOwnVerification(service, () => reoffers++);
      addTearDown(subscription.cancel);

      stored = first;
      stream
        ..add(first)
        ..add(firstLater)
        ..add(stranger);
      await pumpEventQueue();
      expect(reoffers, 1);

      stored = second;
      stream.add(second);
      await pumpEventQueue();
      expect(reoffers, 2);
    });
  });
}
