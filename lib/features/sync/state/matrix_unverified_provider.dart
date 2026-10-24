import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';

/// Exposes the current set of unverified Matrix devices for the
/// device-verification UI, sourced from `MatrixService.getUnverifiedDevices`.
final AsyncNotifierProvider<MatrixUnverifiedController, List<SyncDeviceInfo>>
matrixUnverifiedControllerProvider =
    AsyncNotifierProvider.autoDispose<
      MatrixUnverifiedController,
      List<SyncDeviceInfo>
    >(
      MatrixUnverifiedController.new,
      name: 'matrixUnverifiedControllerProvider',
    );

class MatrixUnverifiedController extends AsyncNotifier<List<SyncDeviceInfo>> {
  @override
  Future<List<SyncDeviceInfo>> build() async {
    return ref.watch(matrixServiceProvider).getUnverifiedDevices();
  }
}
