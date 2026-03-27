import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';

void main() {
  group('matrix barrel export', () {
    test('re-exports all expected types', () {
      // Verify that the barrel file re-exports key types.
      // If any export is missing, this file will fail to compile.
      expect(MatrixService, isNotNull);
      expect(MatrixSessionManager, isNotNull);
      expect(MatrixStats, isNotNull);
      expect(SyncRoomManager, isNotNull);
    });
  });
}
