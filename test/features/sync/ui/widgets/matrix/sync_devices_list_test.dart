import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_devices_list.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

class _FakeSyncDevicesController extends SyncDevicesController {
  _FakeSyncDevicesController(this.devices);

  final List<SyncDeviceInfo> devices;
  int buildCount = 0;

  @override
  Future<List<SyncDeviceInfo>> build() async {
    buildCount++;
    return devices;
  }
}

class _ThrowingSyncDevicesController extends SyncDevicesController {
  @override
  Future<List<SyncDeviceInfo>> build() async => throw Exception('offline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 7, 26, 12);

  late MockMatrixService mockMatrixService;

  const currentDevice = SyncDeviceInfo(
    deviceId: 'THIS',
    displayName: 'This desktop',
    isCurrentDevice: true,
    verified: true,
  );

  setUp(() {
    mockMatrixService = MockMatrixService();
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(
      () => mockMatrixService.getSyncDevices(),
    ).thenAnswer((_) async => []);
  });

  Future<void> pumpList(
    WidgetTester tester, {
    required SyncDevicesController Function() controller,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SyncDevicesList(now: () => now),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          syncDevicesControllerProvider.overrideWith(controller),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  SyncDeviceInfo unverifiedDevice({bool withKeys = true}) {
    final keys = MockDeviceKeys();
    when(() => keys.deviceDisplayName).thenReturn('Uninstalled phone');
    when(() => keys.deviceId).thenReturn('GHOST');
    when(() => keys.userId).thenReturn('@user:server');
    return SyncDeviceInfo(
      deviceId: 'GHOST',
      displayName: 'Uninstalled phone',
      lastSeen: DateTime(2026, 5, 14),
      isCurrentDevice: false,
      verified: false,
      keys: withKeys ? keys : null,
    );
  }

  testWidgets('renders one card per device', (tester) async {
    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([
        currentDevice,
        unverifiedDevice(),
      ]),
    );

    expect(find.byType(DeviceCard), findsNWidgets(2));
    expect(find.text('This desktop'), findsOneWidget);
    expect(find.text('Uninstalled phone'), findsOneWidget);
  });

  testWidgets('shows the paused banner only while a device blocks sync', (
    tester,
  ) async {
    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([
        currentDevice,
        unverifiedDevice(),
      ]),
    );

    expect(
      find.byKey(const Key('sync_devices_paused_banner')),
      findsOneWidget,
    );
    expect(
      find.text(
        '1 unverified device is pausing sync — verify or remove it below.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hides the banner when every device is verified', (
    tester,
  ) async {
    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([
        currentDevice,
        const SyncDeviceInfo(
          deviceId: 'OTHER',
          displayName: 'Old laptop',
          isCurrentDevice: false,
          verified: true,
        ),
      ]),
    );

    expect(find.byKey(const Key('sync_devices_paused_banner')), findsNothing);
  });

  testWidgets('a keyless session does not trigger the paused banner', (
    tester,
  ) async {
    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([
        currentDevice,
        unverifiedDevice(withKeys: false),
      ]),
    );

    expect(find.byKey(const Key('sync_devices_paused_banner')), findsNothing);
  });

  testWidgets('notes when no other devices are signed in', (tester) async {
    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([currentDevice]),
    );

    expect(find.text('No other devices are signed in.'), findsOneWidget);
  });

  testWidgets('shows the load-failed message when the first fetch fails', (
    tester,
  ) async {
    await pumpList(
      tester,
      controller: _ThrowingSyncDevicesController.new,
    );

    expect(
      find.byKey(const Key('sync_devices_load_failed')),
      findsOneWidget,
    );
    expect(find.byType(DeviceCard), findsNothing);
  });

  testWidgets('announces that sync resumed when the last blocker disappears', (
    tester,
  ) async {
    when(
      () => mockMatrixService.getSyncDevices(),
    ).thenAnswer((_) async => [currentDevice]);

    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([
        currentDevice,
        unverifiedDevice(),
      ]),
    );
    expect(
      find.byKey(const Key('sync_devices_paused_banner')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('sync_devices_refresh')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('sync_devices_paused_banner')), findsNothing);
    expect(find.text('Sync is running again.'), findsOneWidget);
  });

  testWidgets('the refresh button re-fetches the device list', (tester) async {
    when(() => mockMatrixService.getSyncDevices()).thenAnswer(
      (_) async => [
        currentDevice,
        const SyncDeviceInfo(
          deviceId: 'NEW',
          displayName: 'Freshly paired phone',
          isCurrentDevice: false,
          verified: true,
        ),
      ],
    );

    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([currentDevice]),
    );
    // The initial list comes from the overridden build, not the service.
    verifyNever(() => mockMatrixService.getSyncDevices());
    expect(find.byType(DeviceCard), findsOneWidget);

    await tester.tap(find.byKey(const Key('sync_devices_refresh')));
    await tester.pump();
    await tester.pump();

    // The overridden controller still runs the real refresh(), which
    // re-fetches through the service and swaps in the new list.
    verify(() => mockMatrixService.getSyncDevices()).called(1);
    expect(find.byType(DeviceCard), findsNWidgets(2));
    expect(find.text('Freshly paired phone'), findsOneWidget);
  });
}
