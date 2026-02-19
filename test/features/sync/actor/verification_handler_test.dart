import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/actor/verification_handler.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:mocktail/mocktail.dart';

class MockKeyVerification extends Mock implements KeyVerification {}

void main() {
  group('VerificationHandler', () {
    test('tracks incoming verification and emits events', () {
      final events = <Map<String, Object?>>[];
      final verification = MockKeyVerification();
      final onUpdateHistory = <void Function()?>[];

      void previousOnUpdate() {}
      when(() => verification.lastStep)
          .thenReturn('m.key.verification.request');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(() => verification.onUpdate).thenAnswer((_) => previousOnUpdate);
      when(() => verification.onUpdate = any()).thenAnswer((invocation) {
        final next = invocation.positionalArguments.first as void Function()?;
        onUpdateHistory.add(next);
        return null;
      });
      when(verification.cancel).thenAnswer(
        (_) async => Future<void>.value(),
      );

      final handler = VerificationHandler(
        onStateChanged: events.add,
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      handler.trackIncoming(verification);

      expect(handler.snapshot()['hasIncoming'], isTrue);
      expect(events, hasLength(1));
      expect(events.last['event'], 'verificationState');
      expect(events.last['direction'], 'incoming');
      expect(events.last['step'], 'm.key.verification.request');
      expect(events.last['isDone'], isFalse);
      expect(onUpdateHistory, isNotEmpty);
    });

    test('emits updates when verification step changes', () {
      final events = <Map<String, Object?>>[];
      final verification = MockKeyVerification();

      var done = false;
      var step = 'm.key.verification.ready';

      void Function()? capturedOnUpdate;
      when(() => verification.lastStep).thenAnswer((_) => step);
      when(() => verification.isDone).thenAnswer((_) => done);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis)
          .thenAnswer((_) => <KeyVerificationEmoji>[]);
      when(() => verification.onUpdate).thenAnswer((_) => capturedOnUpdate);
      when(() => verification.onUpdate = any()).thenAnswer((invocation) {
        capturedOnUpdate =
            invocation.positionalArguments.first as void Function()?;
        return null;
      });
      when(verification.cancel).thenAnswer(
        (_) async => Future<void>.value(),
      );

      final handler = VerificationHandler(
        onStateChanged: events.add,
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      handler.trackIncoming(verification);
      expect(events, hasLength(1));

      step = 'm.key.verification.key';
      capturedOnUpdate?.call();
      expect(events, hasLength(2));
      expect(events.last['step'], 'm.key.verification.key');

      done = true;
      capturedOnUpdate?.call();
      expect(events, hasLength(3));
      expect(events.last['isDone'], isTrue);
      expect(handler.snapshot()['hasIncoming'], isFalse);
    });

    test('acceptVerification requires active incoming verification', () async {
      final verification = MockKeyVerification();
      final handler = VerificationHandler(
        onStateChanged: (_) {},
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      when(verification.acceptVerification)
          .thenAnswer((_) async => Future<void>.value());
      when(() => verification.lastStep).thenReturn('m.key.verification.ready');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(() => verification.onUpdate).thenReturn(null);
      when(() => verification.onUpdate = any()).thenReturn(null);
      when(verification.cancel).thenAnswer(
        (_) async => Future<void>.value(),
      );

      await expectLater(
        handler.acceptVerification,
        throwsA(
          predicate(
            (Object e) =>
                e is StateError &&
                e.message == 'No incoming verification to accept',
          ),
        ),
      );

      handler.trackIncoming(verification);
      await handler.acceptVerification();
      verify(verification.acceptVerification).called(1);
    });

    test('acceptSas requires an active verification', () async {
      final handler = VerificationHandler(
        onStateChanged: (_) {},
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      await expectLater(
        handler.acceptSas,
        throwsA(
          predicate(
            (Object e) =>
                e is StateError &&
                e.message == 'No active verification for acceptSas',
          ),
        ),
      );

      final verification = MockKeyVerification();
      when(verification.acceptSas).thenAnswer((_) async {});
      when(() => verification.lastStep).thenReturn('m.key.verification.key');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(() => verification.onUpdate).thenReturn(null);
      when(() => verification.onUpdate = any()).thenReturn(null);
      when(verification.cancel).thenAnswer(
        (_) async => Future<void>.value(),
      );

      handler.trackIncoming(verification);
      await handler.acceptSas();
      verify(verification.acceptSas).called(1);
    });

    test('cancel clears active verifications and restores callbacks', () async {
      final events = <Map<String, Object?>>[];
      final incoming = MockKeyVerification();
      final outgoing = MockKeyVerification();

      void Function()? incomingPrevious;
      void Function()? incomingCurrent;
      void Function()? outgoingPrevious;
      void Function()? outgoingCurrent;

      when(() => incoming.lastStep).thenReturn('m.key.verification.ready');
      when(() => incoming.isDone).thenReturn(false);
      when(() => incoming.canceled).thenReturn(false);
      when(() => incoming.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(incoming.cancel).thenAnswer((_) async => Future<void>.value());
      incomingPrevious = () {};
      when(() => incoming.onUpdate).thenAnswer((_) => incomingPrevious);
      when(() => incoming.onUpdate = any()).thenAnswer((invocation) {
        incomingCurrent =
            invocation.positionalArguments.first as void Function()?;
        return null;
      });

      when(() => outgoing.lastStep).thenReturn('m.key.verification.ready');
      when(() => outgoing.isDone).thenReturn(false);
      when(() => outgoing.canceled).thenReturn(false);
      when(() => outgoing.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(outgoing.cancel).thenAnswer((_) async => Future<void>.value());
      outgoingPrevious = () {};
      when(() => outgoing.onUpdate).thenAnswer((_) => outgoingPrevious);
      when(() => outgoing.onUpdate = any()).thenAnswer((invocation) {
        outgoingCurrent =
            invocation.positionalArguments.first as void Function()?;
        return null;
      });

      final handler = VerificationHandler(
        onStateChanged: events.add,
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      handler
        ..trackIncoming(incoming)
        ..trackOutgoing(outgoing);

      expect(handler.snapshot()['hasIncoming'], isTrue);
      expect(handler.snapshot()['hasOutgoing'], isTrue);

      await handler.cancel();

      expect(handler.snapshot()['hasIncoming'], isFalse);
      expect(handler.snapshot()['hasOutgoing'], isFalse);
      expect(incomingCurrent, same(incomingPrevious));
      expect(outgoingCurrent, same(outgoingPrevious));
      verify(incoming.cancel).called(1);
      verify(outgoing.cancel).called(1);
      expect(events, isNotEmpty);
    });

    test('dispose cancels tracked outgoing verification', () async {
      final outgoing = MockKeyVerification();

      when(() => outgoing.lastStep).thenReturn('m.key.verification.ready');
      when(() => outgoing.isDone).thenReturn(false);
      when(() => outgoing.canceled).thenReturn(false);
      when(() => outgoing.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      when(() => outgoing.onUpdate).thenReturn(null);
      when(() => outgoing.onUpdate = any()).thenReturn(null);
      when(outgoing.cancel).thenAnswer((_) async => Future<void>.value());

      final handler = VerificationHandler(
        onStateChanged: (_) {},
        pollInterval: Duration.zero,
      )..trackOutgoing(outgoing);
      await handler.dispose();

      verify(outgoing.cancel).called(1);
      expect(handler.snapshot()['hasOutgoing'], isFalse);
    });

    test(
        'outgoing completion clears outgoing state and invokes previous update',
        () {
      final events = <Map<String, Object?>>[];
      final outgoing = MockKeyVerification();

      var done = false;
      var previousCalled = false;
      void Function()? capturedOnUpdate;

      when(() => outgoing.lastStep).thenReturn('m.key.verification.key');
      when(() => outgoing.isDone).thenAnswer((_) => done);
      when(() => outgoing.canceled).thenReturn(false);
      when(() => outgoing.sasEmojis).thenReturn(<KeyVerificationEmoji>[
        KeyVerificationEmoji(1),
      ]);
      when(() => outgoing.onUpdate).thenAnswer((_) => () {
            previousCalled = true;
          });
      when(() => outgoing.onUpdate = any()).thenAnswer((invocation) {
        capturedOnUpdate =
            invocation.positionalArguments.first as void Function()?;
        return null;
      });
      when(outgoing.cancel).thenAnswer((_) async => Future<void>.value());

      final handler = VerificationHandler(
        onStateChanged: events.add,
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      handler.trackOutgoing(outgoing);
      expect(events.last['emojis'], isNotEmpty);

      done = true;
      capturedOnUpdate?.call();

      expect(previousCalled, isTrue);
      expect(handler.snapshot()['hasOutgoing'], isFalse);
    });

    test('emoji serialization is guarded when sasEmojis throws', () {
      final events = <Map<String, Object?>>[];
      final outgoing = MockKeyVerification();

      when(() => outgoing.lastStep).thenReturn('m.key.verification.key');
      when(() => outgoing.isDone).thenReturn(false);
      when(() => outgoing.canceled).thenReturn(false);
      when(() => outgoing.sasEmojis).thenThrow(Exception('sas failed'));
      when(() => outgoing.onUpdate).thenReturn(null);
      when(() => outgoing.onUpdate = any()).thenReturn(null);
      when(outgoing.cancel).thenAnswer((_) async => Future<void>.value());

      final handler = VerificationHandler(
        onStateChanged: events.add,
        pollInterval: Duration.zero,
      );
      addTearDown(handler.dispose);

      handler.trackOutgoing(outgoing);
      expect(events.last['emojis'], isEmpty);
      expect(handler.snapshot()['outgoingEmojis'], isEmpty);
    });
  });
}
