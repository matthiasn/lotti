import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:matrix/matrix.dart';

class FakeDeviceKeys extends Fake implements DeviceKeys {}

class FakeMatrixUnverifiedController extends MatrixUnverifiedController {
  FakeMatrixUnverifiedController(this.devices);

  final List<DeviceKeys> devices;

  @override
  Future<List<DeviceKeys>> build() async => devices;
}

/// Counts how many times [build] runs so tests can assert that the provider
/// was invalidated (re-built) by code under test.
class CountingMatrixUnverifiedController extends MatrixUnverifiedController {
  CountingMatrixUnverifiedController(this.devices, this.buildCount);

  final List<DeviceKeys> devices;
  final List<int> buildCount;

  @override
  Future<List<DeviceKeys>> build() async {
    buildCount[0]++;
    return devices;
  }
}
