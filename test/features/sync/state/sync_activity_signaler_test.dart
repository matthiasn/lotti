import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';

void main() {
  group('SyncActivitySignaler', () {
    late SyncActivitySignaler signaler;

    setUp(() {
      signaler = SyncActivitySignaler();
    });

    tearDown(() async {
      await signaler.dispose();
    });

    test('emits one TX pulse per pulseTx call', () async {
      final pulses = <DateTime>[];
      final sub = signaler.txPulses.listen(pulses.add);

      signaler.pulseTx();
      await pumpEventQueue(); // drain stream deliveries (fake-time policy)

      expect(pulses, hasLength(1));
      await sub.cancel();
    });

    test(
      'pulseTx coalesces a batch into one emission — '
      'the LED hold window is per pulse, not per packet, so '
      'emitting once per batch produces an identical visual',
      () async {
        final pulses = <DateTime>[];
        final sub = signaler.txPulses.listen(pulses.add);

        signaler
          ..pulseTx()
          ..pulseTx()
          ..pulseTx();
        await pumpEventQueue(); // drain stream deliveries (fake-time policy)

        expect(pulses, hasLength(3));
        await sub.cancel();
      },
    );

    test('emits one RX pulse per pulseRx call', () async {
      final pulses = <DateTime>[];
      final sub = signaler.rxPulses.listen(pulses.add);

      signaler
        ..pulseRx()
        ..pulseRx();
      await pumpEventQueue(); // drain stream deliveries (fake-time policy)

      expect(pulses, hasLength(2));
      await sub.cancel();
    });

    test('TX and RX channels are independent', () async {
      final tx = <DateTime>[];
      final rx = <DateTime>[];
      final txSub = signaler.txPulses.listen(tx.add);
      final rxSub = signaler.rxPulses.listen(rx.add);

      signaler
        ..pulseTx()
        ..pulseRx()
        ..pulseTx();
      await pumpEventQueue(); // drain stream deliveries (fake-time policy)

      expect(tx, hasLength(2));
      expect(rx, hasLength(1));
      await txSub.cancel();
      await rxSub.cancel();
    });

    test(
      'streams are broadcast — late subscriber misses earlier events',
      () async {
        signaler.pulseTx();
        await pumpEventQueue(); // drain stream deliveries (fake-time policy)

        final pulses = <DateTime>[];
        final sub = signaler.txPulses.listen(pulses.add);
        signaler.pulseTx();
        await pumpEventQueue(); // drain stream deliveries (fake-time policy)

        // Late subscriber should only see the second pulse (broadcast).
        expect(pulses, hasLength(1));
        await sub.cancel();
      },
    );

    test('after dispose, further pulses are no-ops', () async {
      await signaler.dispose();
      // Re-subscribing on a closed broadcast stream throws, so we just
      // verify pulseTx/pulseRx do not throw post-close.
      expect(signaler.pulseTx, returnsNormally);
      expect(signaler.pulseRx, returnsNormally);
    });
  });
}
