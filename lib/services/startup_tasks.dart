/// Tracks fire-and-forget startup work (MatrixService.init, the one-time
/// sequence-log migration) so an in-app profile switch can wait for it —
/// bounded — before tearing the service generation down. Without this, a
/// switch right after boot could dispose services out from under their own
/// startup futures.
class StartupTasks {
  final List<Future<void>> _tracked = [];

  /// Registers [future] as startup work. Errors are already handled (or
  /// deliberately logged) by the work itself; tracking must never rethrow.
  void track(Future<void> future) {
    _tracked.add(future.catchError((Object _) {}));
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
