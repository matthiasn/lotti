import 'package:lotti/database/sync_db.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncDatabase extends Mock implements SyncDatabase {}

MockSyncDatabase mockSyncDatabaseWithCount(int count) {
  final mock = MockSyncDatabase();
  when(mock.close).thenAnswer((_) async {});

  when(mock.watchOutboxCount).thenAnswer(
    (_) => Stream<int>.fromIterable([count]),
  );

  return mock;
}
