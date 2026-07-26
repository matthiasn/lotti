import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
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
        '1 unverified device is pausing sync — delete or verify it below.',
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

  testWidgets('a failed refresh keeps the list and surfaces an error toast', (
    tester,
  ) async {
    when(
      () => mockMatrixService.getSyncDevices(),
    ).thenThrow(Exception('offline'));

    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([currentDevice]),
    );

    await tester.tap(find.byKey(const Key('sync_devices_refresh')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The established list survives; the failure is announced, not eaten.
    expect(find.byType(DeviceCard), findsOneWidget);
    expect(find.text("Couldn't load the device list."), findsOneWidget);
  });

  testWidgets('renders without an injected clock', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SyncDevicesList(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          syncDevicesControllerProvider.overrideWith(
            () => _FakeSyncDevicesController([currentDevice]),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    // No lastSeen anywhere, so the wall-clock fallback cannot make the
    // rendering time-dependent.
    expect(find.byType(DeviceCard), findsOneWidget);
  });

  testWidgets('a refresh requested mid-flight shows the spinner and is '
      'coalesced, not dropped', (tester) async {
    const otherA = SyncDeviceInfo(
      deviceId: 'OTHER_A',
      displayName: 'Old laptop',
      isCurrentDevice: false,
      verified: true,
    );
    const otherB = SyncDeviceInfo(
      deviceId: 'OTHER_B',
      displayName: 'Old tablet',
      isCurrentDevice: false,
      verified: true,
    );

    final firstFetch = Completer<List<SyncDeviceInfo>>();
    var fetchCount = 0;
    when(() => mockMatrixService.getSyncDevices()).thenAnswer((_) {
      fetchCount++;
      if (fetchCount == 1) return firstFetch.future;
      return Future.value(const [currentDevice]);
    });
    when(
      () => mockMatrixService.deleteDeviceById(any()),
    ).thenAnswer((_) async {});

    await pumpList(
      tester,
      controller: () =>
          _FakeSyncDevicesController([currentDevice, otherA, otherB]),
    );

    Future<void> deleteVia(String cardKey) async {
      await tester.ensureVisible(find.byKey(Key(cardKey)));
      await tester.tap(
        find.descendant(
          of: find.byKey(Key(cardKey)),
          matching: find.byKey(const Key('matrix_delete_device')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('DELETE DEVICE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // First deletion starts a refresh that stays in flight.
    await deleteVia('sync_device_self_OTHER_A');
    expect(fetchCount, 1);
    expect(find.byType(DesignSystemSpinner), findsOneWidget);

    // Second deletion lands while the refresh is in flight: coalesced.
    await deleteVia('sync_device_self_OTHER_B');
    expect(fetchCount, 1);

    firstFetch.complete(const [currentDevice, otherB]);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The queued refresh ran after the first one resolved.
    expect(fetchCount, 2);
  });

  testWidgets('the refresh button is disabled while the provider is still '
      'loading', (tester) async {
    final neverLoads = Completer<List<SyncDeviceInfo>>();
    when(
      () => mockMatrixService.getSyncDevices(),
    ).thenAnswer((_) => neverLoads.future);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SyncDevicesList(now: () => now),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.byKey(const Key('sync_devices_refresh')),
    );
    expect(
      button.onPressed,
      isNull,
      reason:
          'a refresh racing the initial load could let the older '
          'snapshot overwrite the newer one',
    );
    neverLoads.complete(const []);
  });

  testWidgets('a post-deletion refresh arriving after the list is disposed '
      'is a no-op', (tester) async {
    final pendingDelete = Completer<void>();
    when(
      () => mockMatrixService.deleteDeviceById('OTHER'),
    ).thenAnswer((_) => pendingDelete.future);

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

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('sync_device_self_OTHER')),
        matching: find.byKey(const Key('matrix_delete_device')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('DELETE DEVICE'));
    await tester.pump();

    // The sheet closes while the deletion is still in flight.
    await tester.pumpWidget(const SizedBox.shrink());
    pendingDelete.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a header refresh resolving after the list is disposed is a '
      'no-op', (tester) async {
    final pendingFetch = Completer<List<SyncDeviceInfo>>();
    when(
      () => mockMatrixService.getSyncDevices(),
    ).thenAnswer((_) => pendingFetch.future);

    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([currentDevice]),
    );

    await tester.tap(find.byKey(const Key('sync_devices_refresh')));
    await tester.pump();

    // The sheet closes while the fetch is still in flight.
    await tester.pumpWidget(const SizedBox.shrink());
    pendingFetch.complete(const [currentDevice]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('two users sharing a device id render as distinct cards', (
    tester,
  ) async {
    final foreignKeys = MockDeviceKeys();
    when(() => foreignKeys.deviceDisplayName).thenReturn('Peer phone');
    when(() => foreignKeys.deviceId).thenReturn('SHARED_ID');
    when(() => foreignKeys.userId).thenReturn('@peer:server');

    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([
        const SyncDeviceInfo(
          deviceId: 'SHARED_ID',
          displayName: 'My laptop',
          isCurrentDevice: false,
          verified: true,
          userId: '@me:server',
        ),
        SyncDeviceInfo(
          deviceId: 'SHARED_ID',
          displayName: 'Peer phone',
          isCurrentDevice: false,
          verified: false,
          keys: foreignKeys,
          onServer: false,
          ownAccount: false,
          userId: '@peer:server',
        ),
      ]),
    );

    // Device ids are only unique per user; composite keys keep both cards.
    expect(tester.takeException(), isNull);
    expect(find.byType(DeviceCard), findsNWidgets(2));
  });

  testWidgets('the banner names verification when every blocker is a '
      'legacy foreign device', (tester) async {
    final foreignKeys = MockDeviceKeys();
    when(() => foreignKeys.deviceDisplayName).thenReturn('Peer phone');
    when(() => foreignKeys.deviceId).thenReturn('PEER');
    when(() => foreignKeys.userId).thenReturn('@peer:server');

    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([
        currentDevice,
        SyncDeviceInfo(
          deviceId: 'PEER',
          displayName: 'Peer phone',
          isCurrentDevice: false,
          verified: false,
          keys: foreignKeys,
          onServer: false,
          ownAccount: false,
          userId: '@peer:server',
        ),
      ]),
    );

    expect(
      find.text('1 unverified device is pausing sync — verify it below.'),
      findsOneWidget,
    );
  });

  testWidgets('the banner names deletion when every blocker is an '
      'own-account session the server dropped', (tester) async {
    final ghostKeys = MockDeviceKeys();
    when(() => ghostKeys.deviceDisplayName).thenReturn('Cache ghost');
    when(() => ghostKeys.deviceId).thenReturn('CACHE_ONLY');
    when(() => ghostKeys.userId).thenReturn('@user:server');

    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([
        currentDevice,
        SyncDeviceInfo(
          deviceId: 'CACHE_ONLY',
          displayName: 'Cache ghost',
          isCurrentDevice: false,
          verified: false,
          keys: ghostKeys,
          onServer: false,
          userId: '@user:server',
        ),
      ]),
    );

    expect(
      find.text('1 unverified device is pausing sync — delete it below.'),
      findsOneWidget,
    );
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
