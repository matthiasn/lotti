// Minimal interface to unify V1 and V2 sync pipelines.
// Implementations should be lightweight and idempotent.
abstract class SyncPipeline {
  Future<void> initialize();
  Future<void> start();
  Future<void> dispose();
}
