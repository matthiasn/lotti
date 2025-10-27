// Minimal interface to unify sync pipelines.
// Implementations should be lightweight and idempotent.
abstract class SyncPipeline {
  Future<void> initialize();
  Future<void> start();
  Future<void> dispose();
}
