import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Tracks fire-and-forget startup work (MatrixService.init, the one-time
/// sequence-log migration, the node-profile broadcast) so an in-app profile
/// switch can wait for it — bounded — before tearing the service generation
/// down. Without this, a switch right after boot could dispose services out
/// from under their own startup futures.
class StartupTasks {
  final List<Future<void>> _tracked = [];

  /// Registers [future] as startup work. A failure is recorded under the
  /// general domain (so the "why did sync never start" diagnostic survives)
  /// and then contained — tracking must never rethrow into settle.
  void track(Future<void> future) {
    _tracked.add(
      future.catchError((Object error, StackTrace stackTrace) {
        if (getIt.isRegistered<DomainLogger>()) {
          getIt<DomainLogger>().error(
            LogDomain.general,
            error,
            stackTrace: stackTrace,
            subDomain: 'startupTasks',
          );
        }
      }),
    );
  }

  /// Waits for all tracked work, bounded by [timeout]. Late work past the
  /// bound is abandoned to its own error handling.
  Future<void> settle({Duration timeout = const Duration(seconds: 5)}) async {
    if (_tracked.isEmpty) return;
    await Future.wait(
      _tracked,
    ).timeout(timeout, onTimeout: () => const []).then((_) {});
  }
}
