import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/wake/sync_lease_gate.dart';

/// A gate over controllable sync, connection and inbox signals.
class _GateBench {
  _GateBench({
    this.syncEnabled = true,
    this.connected = true,
  }) {
    gate = SyncLeaseGate(
      syncEnabled: () async => syncEnabled,
      connected: () => connected,
      connectivityChanges: connectivity.stream,
      waitForInboxDrained: (timeout) async {
        drainTimeouts.add(timeout);
        await onDrain?.call();
      },
      drainTimeout: const Duration(seconds: 30),
    );
  }

  bool syncEnabled;
  bool connected;
  final connectivity = StreamController<bool>.broadcast();
  final drainTimeouts = <Duration>[];

  /// What the inbox drain does before it returns.
  Future<void> Function()? onDrain;
  late final SyncLeaseGate gate;

  Future<void> report({required bool online}) async {
    connectivity.add(online);
    await pumpEventQueue();
  }

  Future<void> dispose() async {
    await gate.dispose();
    await connectivity.close();
  }
}

void main() {
  group('SyncLeaseGate.ready', () {
    test('is open with sync off, without waiting on any inbox', () async {
      final bench = _GateBench(syncEnabled: false, connected: false);
      addTearDown(bench.dispose);
      await bench.report(online: false);

      // No peers to race: offline does not matter.
      expect(await bench.gate.ready(), isTrue);
      expect(bench.drainTimeouts, isEmpty);
    });

    test(
      'opens once connected and the inbox drained within the timeout',
      () async {
        final bench = _GateBench();
        addTearDown(bench.dispose);

        expect(await bench.gate.ready(), isTrue);
        expect(bench.drainTimeouts, [const Duration(seconds: 30)]);
      },
    );

    test(
      'stays closed while disconnected, without waiting on the inbox',
      () async {
        final bench = _GateBench(connected: false);
        addTearDown(bench.dispose);

        expect(await bench.gate.ready(), isFalse);
        expect(bench.drainTimeouts, isEmpty);
      },
    );

    test('stays closed after the connectivity stream reports offline, even '
        'while the client still thinks it is logged in', () async {
      final bench = _GateBench();
      addTearDown(bench.dispose);
      await bench.report(online: false);

      expect(await bench.gate.ready(), isFalse);
      expect(bench.drainTimeouts, isEmpty);

      await bench.report(online: true);
      expect(await bench.gate.ready(), isTrue);
    });

    test('stays closed when the inbox does not drain in time', () async {
      final bench = _GateBench()
        ..onDrain = () async => throw TimeoutException('backlog');
      addTearDown(bench.dispose);

      expect(await bench.gate.ready(), isFalse);
    });

    test(
      'stays closed when the connection drops while the inbox drains',
      () async {
        final bench = _GateBench();
        bench.onDrain = () async => bench.report(online: false);
        addTearDown(bench.dispose);

        expect(await bench.gate.ready(), isFalse);
        expect(bench.gate.epoch, 1);
      },
    );

    test('closes when the client logs out while the inbox drains', () async {
      final bench = _GateBench();
      bench.onDrain = () async => bench.connected = false;
      addTearDown(bench.dispose);

      expect(await bench.gate.ready(), isFalse);
    });
  });

  group('SyncLeaseGate.epoch', () {
    test('counts connection losses, not reports', () async {
      final bench = _GateBench();
      addTearDown(bench.dispose);
      expect(bench.gate.epoch, 0);

      await bench.report(online: true);
      expect(bench.gate.epoch, 0);
      await bench.report(online: false);
      await bench.report(online: false);
      expect(bench.gate.epoch, 1);
      await bench.report(online: true);
      expect(bench.gate.epoch, 1);
      await bench.report(online: false);
      expect(bench.gate.epoch, 2);
    });

    test('stops counting once disposed', () async {
      final bench = _GateBench();
      await bench.gate.dispose();

      await bench.report(online: false);
      expect(bench.gate.epoch, 0);
      await bench.connectivity.close();
    });

    glados.Glados(
      glados.any.list(glados.any.bool),
      glados.ExploreConfig(numRuns: 120),
    ).test('equals the number of online-to-offline transitions', (
      reports,
    ) async {
      final bench = _GateBench();
      try {
        for (final online in reports) {
          await bench.report(online: online);
        }
        // The gate starts online.
        var expected = 0;
        var previous = true;
        for (final online in reports) {
          if (previous && !online) expected++;
          previous = online;
        }
        expect(bench.gate.epoch, expected, reason: '$reports');
      } finally {
        await bench.dispose();
      }
    }, tags: 'glados');
  });
}
