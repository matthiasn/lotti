import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockMatrixService matrixService;
  late ProviderContainer container;

  const deviceA = SyncDeviceInfo(
    deviceId: 'A',
    isCurrentDevice: true,
    verified: true,
  );
  const deviceB = SyncDeviceInfo(
    deviceId: 'B',
    isCurrentDevice: false,
    verified: false,
  );

  setUp(() {
    matrixService = MockMatrixService();
    container = ProviderContainer(
      overrides: [matrixServiceProvider.overrideWithValue(matrixService)],
    );
    addTearDown(container.dispose);
  });

  test('build exposes the service device list', () async {
    when(
      () => matrixService.getSyncDevices(),
    ).thenAnswer((_) async => const [deviceA]);

    final devices = await container.read(
      syncDevicesControllerProvider.future,
    );

    expect(devices, const [deviceA]);
  });

  test(
    'refresh swaps in the newly fetched list without a loading state',
    () async {
      when(
        () => matrixService.getSyncDevices(),
      ).thenAnswer((_) async => const [deviceA]);
      // Keep the provider alive across the refresh.
      final sub = container.listen(
        syncDevicesControllerProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(syncDevicesControllerProvider.future);

      when(
        () => matrixService.getSyncDevices(),
      ).thenAnswer((_) async => const [deviceA, deviceB]);

      await container.read(syncDevicesControllerProvider.notifier).refresh();

      final state = container.read(syncDevicesControllerProvider);
      expect(state.value, const [deviceA, deviceB]);
    },
  );

  test(
    'refresh lets an in-flight initial load settle first so the older '
    'snapshot can never overwrite the fresh fetch',
    () async {
      final initialFetch = Completer<List<SyncDeviceInfo>>();
      var calls = 0;
      when(() => matrixService.getSyncDevices()).thenAnswer((_) {
        calls++;
        // First call: the (stale) initial build. Later calls: fresh state.
        if (calls == 1) return initialFetch.future;
        return Future.value(const [deviceA]);
      });

      final sub = container.listen(
        syncDevicesControllerProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      // Kick off the initial build, then request a refresh while it is
      // still pending — as a deletion's callback would.
      final refreshDone = container
          .read(syncDevicesControllerProvider.notifier)
          .refresh();

      // The stale snapshot (still containing the ghost) arrives late.
      initialFetch.complete(const [deviceA, deviceB]);
      final succeeded = await refreshDone;

      expect(succeeded, isTrue);
      final state = container.read(syncDevicesControllerProvider);
      expect(
        state.value,
        const [deviceA],
        reason: 'the fresh fetch must win over the older initial snapshot',
      );
    },
  );

  test(
    'an invalidation-triggered rebuild wins over a slower manual refresh '
    'started earlier',
    () async {
      // Sequence: initial load → slow manual refresh (stale snapshot) →
      // invalidation (e.g. a verification completing) rebuilds with fresh
      // data → the stale manual result must be discarded, not published.
      final slowManualFetch = Completer<List<SyncDeviceInfo>>();
      var calls = 0;
      when(() => matrixService.getSyncDevices()).thenAnswer((_) {
        calls++;
        if (calls == 1) return Future.value(const [deviceA, deviceB]);
        if (calls == 2) return slowManualFetch.future;
        return Future.value(const [deviceA]);
      });

      final sub = container.listen(
        syncDevicesControllerProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(syncDevicesControllerProvider.future);

      final refreshDone = container
          .read(syncDevicesControllerProvider.notifier)
          .refresh();

      // A verification-completion path invalidates the provider while the
      // manual refresh is still in flight; the rebuild fetches fresh data.
      container.invalidate(syncDevicesControllerProvider);
      await container.read(syncDevicesControllerProvider.future);
      expect(
        container.read(syncDevicesControllerProvider).value,
        const [deviceA],
      );

      // The stale manual snapshot arrives last — and must be dropped: the
      // notifier it belonged to was recreated by the invalidation.
      slowManualFetch.complete(const [deviceA, deviceB]);
      final succeeded = await refreshDone;

      // Superseded is not a failure: the roster IS fresh via the rebuild,
      // so the UI must not show a load-failed toast.
      expect(succeeded, isTrue);
      expect(
        container.read(syncDevicesControllerProvider).value,
        const [deviceA],
        reason:
            'a rebuilt provider must not be overwritten by a refresh '
            'started on the previous notifier generation',
      );
    },
  );

  test('a failing refresh keeps the previously loaded list', () async {
    when(
      () => matrixService.getSyncDevices(),
    ).thenAnswer((_) async => const [deviceA]);
    final sub = container.listen(
      syncDevicesControllerProvider,
      (_, _) {},
    );
    addTearDown(sub.close);
    await container.read(syncDevicesControllerProvider.future);

    when(() => matrixService.getSyncDevices()).thenThrow(Exception('offline'));

    await container.read(syncDevicesControllerProvider.notifier).refresh();

    final state = container.read(syncDevicesControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.value, const [deviceA]);
  });
}
