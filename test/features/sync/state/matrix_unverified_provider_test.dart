import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
  });

  group('MatrixUnverifiedController', () {
    test('build returns unverified devices from matrix service', () async {
      final mockDeviceKeys = <SyncDeviceInfo>[];
      when(
        () => mockMatrixService.getUnverifiedDevices(),
      ).thenReturn(mockDeviceKeys);

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      final devices = await container.read(
        matrixUnverifiedControllerProvider.future,
      );

      expect(devices, isEmpty);
      verify(() => mockMatrixService.getUnverifiedDevices()).called(1);
    });
  });
}
