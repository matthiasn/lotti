import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/consts.dart';

void main() {
  group('config flag constants', () {
    test('flag keys keep their persisted string values', () {
      // These strings are persisted in the settings DB — renaming a constant
      // silently orphans every stored flag, so pin the representative set.
      expect(privateFlag, 'private');
      expect(enableNotificationsFlag, 'enable_notifications');
      expect(recordLocationFlag, 'record_location');
      expect(enableMatrixFlag, 'enable_matrix');
      expect(enableLoggingFlag, 'enable_logging');
      expect(enableHabitsPageFlag, 'enable_habits_page');
      expect(enableDashboardsPageFlag, 'enable_dashboards_page');
      expect(enableEmbeddingsFlag, 'enable_embeddings');
      expect(enableVectorSearchFlag, 'enable_vector_search');
      expect(logSlowQueriesFlag, 'log_slow_queries');
    });

    test('scroll alignment default stays in the upper third', () {
      expect(kDefaultScrollAlignment, 0.3);
    });
  });
}
