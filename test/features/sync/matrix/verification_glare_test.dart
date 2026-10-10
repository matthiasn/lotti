import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockKeyVerification incoming;

  setUpAll(() {
    registerFallbackValue(MockKeyVerificationRunner());
  });

  setUp(() {
    incoming = MockKeyVerification();
    when(() => incoming.userId).thenReturn('@alice:example.com');
    when(() => incoming.deviceId).thenReturn('AAA');
  });

  /// An outgoing runner whose ceremony sits at [lastStep].
  MockKeyVerificationRunner outgoingAt(
    String lastStep, {
    bool canceled = false,
  }) {
    final keyVerification = MockKeyVerification();
    when(() => keyVerification.canceled).thenReturn(canceled);
    when(() => keyVerification.userId).thenReturn('@alice:example.com');
    when(() => keyVerification.deviceId).thenReturn('PEER');
    final runner = MockKeyVerificationRunner();
    when(() => runner.lastStep).thenReturn(lastStep);
    when(() => runner.keyVerification).thenReturn(keyVerification);
    return runner;
  }

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
          outgoingAt(EventTypes.KeyVerificationRequest, canceled: true),
        ),
        isFalse,
      );
    });
  });

  group('shouldYieldTo', () {
    test('yields an unanswered request to a smaller identity', () {
      expect(
        shouldYieldTo(
          incoming: incoming,
          outgoing: outgoingAt(EventTypes.KeyVerificationRequest),
          ownUserId: '@alice:example.com',
          ownDeviceId: 'ZZZ',
        ),
        isTrue,
      );
    });

    test('keeps its own request against a larger identity', () {
      // Exactly one side yields: the peer, being larger, is the one to.
      when(() => incoming.deviceId).thenReturn('ZZZ');
      expect(
        shouldYieldTo(
          incoming: incoming,
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
          incoming: incoming,
          outgoing: outgoingAt(EventTypes.KeyVerificationReady),
          ownUserId: '@alice:example.com',
          ownDeviceId: 'ZZZ',
        ),
        isFalse,
      );
      expect(
        shouldYieldTo(
          incoming: incoming,
          outgoing: null,
          ownUserId: '@alice:example.com',
          ownDeviceId: 'ZZZ',
        ),
        isFalse,
      );
    });
  });

  group('handOffOutgoingVerification', () {
    late MockMatrixService service;
    late StreamController<KeyVerificationRunner> outgoingStream;
    late List<KeyVerificationRunner> published;

    setUp(() {
      service = MockMatrixService();
      outgoingStream = StreamController<KeyVerificationRunner>.broadcast();
      addTearDown(outgoingStream.close);
      published = [];
      final subscription = outgoingStream.stream.listen(published.add);
      addTearDown(subscription.cancel);
      when(
        () => service.keyVerificationController,
      ).thenReturn(outgoingStream);
      when(
        () => incoming.lastStep,
      ).thenReturn(EventTypes.KeyVerificationRequest);
      when(() => incoming.isDone).thenReturn(false);
      when(incoming.acceptVerification).thenAnswer((_) async {});
    });

    test(
      "detaches and cancels the own ceremony, then accepts the peer's in its "
      'place on the stream the open sheet renders',
      () async {
        final outgoing = outgoingAt(EventTypes.KeyVerificationRequest);
        final outgoingKeyVerification = outgoing.keyVerification;
        when(outgoing.stopTimer).thenReturn(null);
        when(outgoingKeyVerification.cancel).thenAnswer((_) async {});
        when(() => service.keyVerificationRunner).thenReturn(outgoing);

        final runner = await handOffOutgoingVerification(
          service: service,
          incoming: incoming,
          domainLogger: MockDomainLogger(),
        );
        addTearDown(runner.stopTimer);
        await pumpEventQueue();

        // Detached first: a still-attached runner would publish the cancelled
        // state and the sheet would arm its auto-dismiss mid-ceremony.
        verifyInOrder([
          outgoing.stopTimer,
          outgoingKeyVerification.cancel,
        ]);
        expect(runner.keyVerification, same(incoming));
        verify(() => service.keyVerificationRunner = runner).called(1);
        verify(incoming.acceptVerification).called(1);
        expect(published, [runner]);
      },
    );

    test("with no ceremony of its own it simply answers the peer's", () async {
      when(() => service.keyVerificationRunner).thenReturn(null);

      final runner = await handOffOutgoingVerification(
        service: service,
        incoming: incoming,
        domainLogger: MockDomainLogger(),
      );
      addTearDown(runner.stopTimer);

      verify(() => service.keyVerificationRunner = runner).called(1);
      verify(incoming.acceptVerification).called(1);
    });
  });
}
