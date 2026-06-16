/// Minimal lifecycle contract shared by the sync pipeline implementations.
/// Implementations should be lightweight and each method idempotent.
abstract class SyncPipeline {
  /// One-time setup (load persisted markers, prepare the room) before
  /// streaming begins. A second call is a no-op.
  Future<void> initialize();

  /// Begins consuming events / attaching the live signal bindings. Assumes
  /// [initialize] has run.
  Future<void> start();

  /// Tears down subscriptions and bindings established by [start].
  Future<void> dispose();
}
