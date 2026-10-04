import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:matrix/matrix.dart';

/// Exposes the current set of unverified Matrix devices for the
/// device-verification UI, sourced from `MatrixService.getUnverifiedDevices`.
final AsyncNotifierProvider<MatrixUnverifiedController, List<DeviceKeys>>
matrixUnverifiedControllerProvider =
    AsyncNotifierProvider.autoDispose<
      MatrixUnverifiedController,
      List<DeviceKeys>
    >(
      MatrixUnverifiedController.new,
      name: 'matrixUnverifiedControllerProvider',
    );

class MatrixUnverifiedController extends AsyncNotifier<List<DeviceKeys>> {
  @override
  Future<List<DeviceKeys>> build() async {
    return ref.watch(matrixServiceProvider).getUnverifiedDevices();
  }
}
