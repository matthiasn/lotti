import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import '../../../mocks/mocks.dart';

void main() {
  SyncDeviceInfo device({
    String deviceId = 'DEV',
    String? displayName,
    DateTime? lastSeen,
    bool isCurrentDevice = false,
    bool verified = false,
    bool withKeys = false,
  }) => SyncDeviceInfo(
    deviceId: deviceId,
    displayName: displayName,
    lastSeen: lastSeen,
    isCurrentDevice: isCurrentDevice,
    verified: verified,
    keys: withKeys ? MockDeviceKeys() : null,
  );

  group('label', () {
    test('prefers the display name', () {
      expect(device(displayName: 'Pixel 7').label, 'Pixel 7');
    });

    test('falls back to the device id for a null or blank name', () {
      expect(device().label, 'DEV');
      expect(device(displayName: '  ').label, 'DEV');
    });
  });

  group('titleLabel / metaLabel', () {
    test('splits a machine-generated name into host and pairing metadata', () {
      final d = device(
        displayName: 'dammy-pixel 2026-05-14T18:22 3f9c01aa',
      );
      expect(d.titleLabel, 'dammy-pixel');
      expect(d.metaLabel, '2026-05-14T18:22 3f9c01aa');
    });

    test('leaves a human-friendly name intact', () {
      final d = device(displayName: 'Pixel 7');
      expect(d.titleLabel, 'Pixel 7');
      expect(d.metaLabel, isNull);
    });

    test('falls back to the device id without a meta line', () {
      expect(device().titleLabel, 'DEV');
      expect(device().metaLabel, isNull);
    });
  });

  group('blocksSync', () {
    test('true only for another device with keys that is unverified', () {
      expect(device(withKeys: true).blocksSync, isTrue);
    });

    test('false for the current device, verified devices and keyless '
        'sessions', () {
      expect(
        device(
          isCurrentDevice: true,
          verified: true,
          withKeys: true,
        ).blocksSync,
        isFalse,
      );
      expect(device(verified: true, withKeys: true).blocksSync, isFalse);
      expect(device().blocksSync, isFalse);
    });
  });

  group('isStaleAt', () {
    final now = DateTime(2026, 7, 26);

    test('false without a last-seen timestamp', () {
      expect(device().isStaleAt(now), isFalse);
    });

    test('false within the 30-day threshold, true beyond it', () {
      expect(
        device(lastSeen: DateTime(2026, 6, 27)).isStaleAt(now),
        isFalse,
      );
      expect(
        device(lastSeen: DateTime(2026, 6, 25)).isStaleAt(now),
        isTrue,
      );
    });
  });

  group('pairedAt / pairingHash', () {
    test('parses the pairing timestamp and hash from a generated name', () {
      final d = device(
        displayName: 'dammy-pixel 2026-05-14T18:22 3f9c01aa',
      );
      expect(d.pairedAt, DateTime(2026, 5, 14, 18, 22));
      expect(d.pairingHash, '3f9c01aa');
    });

    test('handles a generated name without a hash fragment', () {
      final d = device(displayName: 'host 2026-05-14T18:22');
      expect(d.pairedAt, DateTime(2026, 5, 14, 18, 22));
      expect(d.pairingHash, isNull);
    });

    test('returns null for human-friendly names', () {
      final d = device(displayName: 'Pixel 7');
      expect(d.pairedAt, isNull);
      expect(d.pairingHash, isNull);
    });
  });

  group('sortSyncDevicesForDisplay', () {
    test('orders blockers first, then the current device, then by last-seen '
        'recency with unknown timestamps last', () {
      final current = device(deviceId: 'CURRENT', isCurrentDevice: true);
      final blocker = device(
        deviceId: 'BLOCKER',
        withKeys: true,
        lastSeen: DateTime(2026),
      );
      final recent = device(
        deviceId: 'RECENT',
        verified: true,
        lastSeen: DateTime(2026, 7, 25),
      );
      final older = device(
        deviceId: 'OLDER',
        verified: true,
        lastSeen: DateTime(2026, 7),
      );
      final unknown = device(deviceId: 'UNKNOWN', verified: true);

      final sorted = sortSyncDevicesForDisplay([
        unknown,
        older,
        blocker,
        recent,
        current,
      ]);

      expect(
        sorted.map((d) => d.deviceId).toList(),
        ['BLOCKER', 'CURRENT', 'RECENT', 'OLDER', 'UNKNOWN'],
      );
    });

    test('does not mutate its input', () {
      final input = [
        device(deviceId: 'B', verified: true, lastSeen: DateTime(2026)),
        device(deviceId: 'A', isCurrentDevice: true),
      ];

      sortSyncDevicesForDisplay(input);

      expect(input.map((d) => d.deviceId).toList(), ['B', 'A']);
    });
  });
}
