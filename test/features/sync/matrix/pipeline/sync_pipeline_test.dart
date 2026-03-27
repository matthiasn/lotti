import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';

class _TestPipeline extends SyncPipeline {
  bool initialized = false;
  bool started = false;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  group('SyncPipeline', () {
    test('can be implemented and all methods called', () async {
      final pipeline = _TestPipeline();

      await pipeline.initialize();
      expect(pipeline.initialized, isTrue);

      await pipeline.start();
      expect(pipeline.started, isTrue);

      await pipeline.dispose();
      expect(pipeline.disposed, isTrue);
    });
  });
}
