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

  group('sortSyncDevicesForDisplay', () {
    test('orders current first, then blockers, then by last-seen recency '
        'with unknown timestamps last', () {
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
        ['CURRENT', 'BLOCKER', 'RECENT', 'OLDER', 'UNKNOWN'],
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
