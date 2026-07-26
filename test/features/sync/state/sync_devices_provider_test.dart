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
