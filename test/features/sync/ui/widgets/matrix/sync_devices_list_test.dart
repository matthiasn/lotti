import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/sizing_tokens.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/add_device_page.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_devices_list.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_ui/material_ui.dart';
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

  setUp(() async {
    await setUpTestGetIt();
    mockMatrixService = MockMatrixService();
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(
      () => mockMatrixService.getSyncDevices(),
    ).thenAnswer((_) async => []);
    // The header derives the sync server from the account id.
    final mockClient = MockMatrixClient();
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@alice:example.com');
  });

  tearDown(tearDownTestGetIt);

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
        "1 unverified device can't read new entries — delete or verify it "
        'below.',
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
    expect(
      find.text('Every paired device can read your entries again.'),
      findsOneWidget,
    );
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
      await tester.tap(
        find.descendant(
          of: find.byType(DesignSystemModalActionBar),
          matching: find.text('Remove from sync'),
        ),
      );
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
    await tester.tap(
      find.descendant(
        of: find.byType(DesignSystemModalActionBar),
        matching: find.text('Remove from sync'),
      ),
    );
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
      find.text(
        "1 unverified device can't read new entries — verify it below.",
      ),
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
      find.text(
        "1 unverified device can't read new entries — delete it below.",
      ),
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

  testWidgets('offers Add device above the roster, on every platform', (
    tester,
  ) async {
    for (final mobile in [true, false]) {
      final wasDesktop = isDesktop;
      final wasMobile = isMobile;
      isDesktop = !mobile;
      isMobile = mobile;
      addTearDown(() {
        isDesktop = wasDesktop;
        isMobile = wasMobile;
      });

      await pumpList(
        tester,
        controller: () => _FakeSyncDevicesController([currentDevice]),
      );

      // Pairing must be reachable from the surface that manages devices, and
      // a phone that outlives its desktop has to be able to onboard the
      // replacement — so this is not desktop-only.
      final addDevice = find.byKey(const Key('sync_devices_add_device'));
      expect(addDevice, findsOneWidget);

      // It leads the roster: the empty-ish list must offer the remedy first.
      final addY = tester.getTopLeft(addDevice).dy;
      final cardY = tester.getTopLeft(find.byType(DeviceCard).first).dy;
      expect(addY, lessThan(cardY));

      // And it carries the accent. As an outline it lost the weight contest
      // to the page's destructive controls, which is the wrong hierarchy for
      // the one constructive action the surface exists to offer.
      expect(
        tester.widget<DesignSystemButton>(addDevice).variant,
        DesignSystemButtonVariant.primary,
      );
      expect(
        tester.widget<DesignSystemButton>(addDevice).tapTargetSize,
        MaterialTapTargetSize.padded,
      );
      expect(tester.getSize(addDevice).height, TapTargets.minimum);
      expect(
        tester
            .getSize(
              find.descendant(of: addDevice, matching: find.byType(Ink)),
            )
            .height,
        lessThan(TapTargets.minimum),
      );
    }
  });

  testWidgets('the header counts the devices on their server', (tester) async {
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

    // With no resolved homeserver, the account-id domain is the fallback.
    expect(find.byKey(const Key('sync_devices_count')), findsOneWidget);
    expect(find.text('2 devices on example.com'), findsOneWidget);
  });

  testWidgets('the header names the homeserver over the account-id domain', (
    tester,
  ) async {
    // A Matrix ID's domain can differ from the host actually serving the
    // account; the roster must name the server it talks to.
    final mockClient = MockMatrixClient();
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@alice:example.com');
    when(
      () => mockClient.homeserver,
    ).thenReturn(Uri.parse('https://matrix.example.com'));

    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([currentDevice]),
    );

    expect(find.text('1 device on matrix.example.com'), findsOneWidget);
  });

  testWidgets('the count skips sessions the server no longer lists', (
    tester,
  ) async {
    // The roster can carry a cache-only leftover — unverified keys the
    // homeserver already dropped. "N devices on <server>" must not claim
    // the server has what it explicitly does not.
    const cacheOnly = SyncDeviceInfo(
      deviceId: 'STALE',
      displayName: 'Stale cache entry',
      isCurrentDevice: false,
      verified: false,
      onServer: false,
    );
    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([
        currentDevice,
        cacheOnly,
      ]),
    );

    // Both rows render — removal needs the card — but only the session the
    // server still lists is counted as being on it.
    expect(find.byType(DeviceCard), findsNWidgets(2));
    expect(find.text('1 device on example.com'), findsOneWidget);
  });

  testWidgets('the header wraps rather than overflowing at large text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 390,
            child: SyncDevicesList(now: () => now),
          ),
        ),
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

    // The count breaks onto its own run instead of two unshrinkable
    // controls forcing a horizontal RenderFlex overflow.
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('sync_devices_add_device')), findsOneWidget);
  });

  testWidgets('lays the cards out in two columns on a wide pane', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1200, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The scaffold harness caps content at 800 points — narrower than two
    // wide-layout cards — so this pumps the pane width directly.
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          width: 1100,
          child: SyncDevicesList(now: () => now),
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          syncDevicesControllerProvider.overrideWith(
            () => _FakeSyncDevicesController([
              currentDevice,
              const SyncDeviceInfo(
                deviceId: 'OTHER',
                displayName: 'Old laptop',
                isCurrentDevice: false,
                verified: true,
              ),
            ]),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final first = tester.getRect(find.byType(DeviceCard).first);
    final second = tester.getRect(find.byType(DeviceCard).last);
    // Side by side, not stacked: a wide detail pane must not render the
    // roster as full-width rows with most of the canvas empty.
    expect(second.left, greaterThan(first.right));
  });

  testWidgets('keeps a single column where two would cramp the cards', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(600, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    final first = tester.getRect(find.byType(DeviceCard).first);
    final second = tester.getRect(find.byType(DeviceCard).last);
    expect(second.top, greaterThan(first.bottom));
  });

  group('just-joined hand-off banner', () {
    Future<ProviderContainer> pumpWithContainer(
      WidgetTester tester, {
      required List<SyncDeviceInfo> initial,
    }) async {
      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          syncDevicesControllerProvider.overrideWith(
            () => _FakeSyncDevicesController(initial),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            SingleChildScrollView(child: SyncDevicesList(now: () => now)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return container;
    }

    const joinedPhone = SyncDeviceInfo(
      deviceId: 'NEWPHONE',
      displayName: 'Pixel 9 Pro',
      isCurrentDevice: false,
      verified: false,
    );
    const verifiedPhone = SyncDeviceInfo(
      deviceId: 'NEWPHONE',
      displayName: 'Pixel 9 Pro',
      isCurrentDevice: false,
      verified: true,
    );

    testWidgets('appears when a device verifies while the roster is open', (
      tester,
    ) async {
      // The moment the Add-device sheet used to own — and lost the instant
      // it was closed. The roster is where the hand-off must survive.
      final container = await pumpWithContainer(
        tester,
        initial: [currentDevice, joinedPhone],
      );
      expect(
        find.byKey(const Key('sync_devices_just_joined')),
        findsNothing,
      );

      container
          .read(syncDevicesControllerProvider.notifier)
          .state = const AsyncData<List<SyncDeviceInfo>>([
        currentDevice,
        verifiedPhone,
      ]);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('sync_devices_just_joined')),
        findsOneWidget,
      );
      expect(find.textContaining('Pixel 9 Pro'), findsWidgets);
      // Both hand-off actions ride on the banner.
      expect(
        find.byKey(const Key('sync_devices_send_settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sync_devices_send_messages')),
        findsOneWidget,
      );
    });

    testWidgets('Send settings opens the room-wide settings hand-off', (
      tester,
    ) async {
      // The banner's whole point: the action that used to die with the
      // Add-device sheet must actually open the hand-off from here.
      final container = await pumpWithContainer(
        tester,
        initial: [currentDevice, joinedPhone],
      );
      container
          .read(syncDevicesControllerProvider.notifier)
          .state = const AsyncData<List<SyncDeviceInfo>>([
        currentDevice,
        verifiedPhone,
      ]);
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('sync_devices_send_settings')),
      );
      await tester.tap(find.byKey(const Key('sync_devices_send_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final context = tester.element(find.byType(SyncDevicesList));
      expect(
        find.text(context.messages.syncEntitiesConfirm),
        findsOneWidget,
      );
    });

    testWidgets('Send message history opens the re-sync hand-off', (
      tester,
    ) async {
      final container = await pumpWithContainer(
        tester,
        initial: [currentDevice, joinedPhone],
      );
      container
          .read(syncDevicesControllerProvider.notifier)
          .state = const AsyncData<List<SyncDeviceInfo>>([
        currentDevice,
        verifiedPhone,
      ]);
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('sync_devices_send_messages')),
      );
      await tester.tap(find.byKey(const Key('sync_devices_send_messages')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ReSyncModalContent), findsOneWidget);
    });

    testWidgets('stays away for a roster that was already verified', (
      tester,
    ) async {
      // A device that was verified before the list opened is old news; the
      // banner is for the fresh arrival, not a permanent fixture.
      await pumpWithContainer(
        tester,
        initial: [currentDevice, verifiedPhone],
      );

      expect(
        find.byKey(const Key('sync_devices_just_joined')),
        findsNothing,
      );
    });

    testWidgets('offers the hand-off again for a second fresh device', (
      tester,
    ) async {
      // Latching only the first arrival — or keeping a dismissal across
      // devices — silently drops the hand-off for every device paired
      // after it in the same roster session.
      const secondJoined = SyncDeviceInfo(
        deviceId: 'TABLET',
        displayName: 'Pixel Tablet',
        isCurrentDevice: false,
        verified: false,
      );
      const secondVerified = SyncDeviceInfo(
        deviceId: 'TABLET',
        displayName: 'Pixel Tablet',
        isCurrentDevice: false,
        verified: true,
      );

      final container = await pumpWithContainer(
        tester,
        initial: [currentDevice, joinedPhone, secondJoined],
      );
      container
          .read(syncDevicesControllerProvider.notifier)
          .state = const AsyncData<List<SyncDeviceInfo>>([
        currentDevice,
        verifiedPhone,
        secondJoined,
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Pixel 9 Pro'), findsWidgets);

      await tester.tap(
        find.byKey(const Key('sync_devices_just_joined_dismiss')),
      );
      await tester.pump();

      container
          .read(syncDevicesControllerProvider.notifier)
          .state = const AsyncData<List<SyncDeviceInfo>>([
        currentDevice,
        verifiedPhone,
        secondVerified,
      ]);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('sync_devices_just_joined')),
        findsOneWidget,
      );
      expect(find.textContaining('Pixel Tablet'), findsWidgets);
    });

    testWidgets('can be dismissed and stays dismissed', (tester) async {
      final container = await pumpWithContainer(
        tester,
        initial: [currentDevice, joinedPhone],
      );
      container
          .read(syncDevicesControllerProvider.notifier)
          .state = const AsyncData<List<SyncDeviceInfo>>([
        currentDevice,
        verifiedPhone,
      ]);
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('sync_devices_just_joined_dismiss')),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('sync_devices_just_joined')),
        findsNothing,
      );

      // A later roster refresh must not resurrect it.
      container
          .read(syncDevicesControllerProvider.notifier)
          .state = const AsyncData<List<SyncDeviceInfo>>([
        currentDevice,
        verifiedPhone,
      ]);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('sync_devices_just_joined')),
        findsNothing,
      );
    });
  });

  testWidgets('Add device opens the pairing sheet', (tester) async {
    // The roster is the only route to the handover code, so the button has to
    // actually reach AddDeviceModal rather than merely render.
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'rotated-pw',
      ),
    );
    when(
      () => mockMatrixService.syncRoomId,
    ).thenReturn('!room123:example.com');

    await pumpList(
      tester,
      controller: () => _FakeSyncDevicesController([currentDevice]),
    );

    await tester.tap(find.byKey(const Key('sync_devices_add_device')));
    // Discrete pumps: the sheet's waiting strip spins forever, so
    // pumpAndSettle never returns.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AddDeviceView), findsOneWidget);
    expect(find.byType(AddDeviceActionBar), findsOneWidget);
  });
}
