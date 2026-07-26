import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/providers/service_providers.dart';

/// Exposes every session on the sync account for the device-management UI,
/// sourced from `MatrixService.getSyncDevices`. Refresh by invalidating —
/// after a verification, a deletion, or on user request.
final AsyncNotifierProvider<SyncDevicesController, List<SyncDeviceInfo>>
syncDevicesControllerProvider =
    AsyncNotifierProvider.autoDispose<
      SyncDevicesController,
      List<SyncDeviceInfo>
    >(
      SyncDevicesController.new,
      name: 'syncDevicesControllerProvider',
    );

class SyncDevicesController extends AsyncNotifier<List<SyncDeviceInfo>> {
  /// Bumped on every [build] so a manual refresh that straddles an
  /// invalidation can recognize it has been superseded.
  int _generation = 0;

  @override
  Future<List<SyncDeviceInfo>> build() async {
    _generation++;
    return ref.watch(matrixServiceProvider).getSyncDevices();
  }

  /// Re-fetches the device list while keeping the last data on screen —
  /// background refreshes must not swap an established list for a loading
  /// shell. Returns whether the fetch succeeded so the UI can surface a
  /// failed refresh instead of silently eating the tap.
  Future<bool> refresh() async {
    // Let an in-flight (initial or invalidated) build settle first: its
    // older snapshot must never complete after — and overwrite — the fresh
    // fetch below.
    if (state.isLoading) {
      try {
        await future;
      } catch (_) {
        // Failures surface through state; the re-fetch below still runs.
      }
      if (!ref.mounted) return false;
    }
    final generation = _generation;
    final result = await AsyncValue.guard(
      () => ref.read(matrixServiceProvider).getSyncDevices(),
    );
    if (!ref.mounted) return false;
    // An invalidation (e.g. a completed verification) rebuilt the provider
    // while this fetch was in flight: the rebuild's snapshot is newer, so
    // this one must be discarded rather than published over it.
    if (generation != _generation) return false;
    // Keep showing the previous list rather than replacing it with an error.
    if (result.hasError && state.hasValue) return false;
    state = result;
    return !result.hasError;
  }
}
