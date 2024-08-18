import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:mocktail/mocktail.dart';

class MockOutboxService extends Mock implements OutboxService {}

class MockSyncDatabase extends Mock implements SyncDatabase {}

MockSyncDatabase mockSyncDatabaseWithCount(int count) {
  final mock = MockSyncDatabase();
  when(mock.close).thenAnswer((_) async {});

  when(mock.watchOutboxCount).thenAnswer(
    (_) => Stream<int>.fromIterable([count]),
  );

  return mock;
}

class MockOutboxCubit extends Mock implements OutboxCubit {}

MockOutboxCubit mockOutboxCubit(OutboxState outboxState) {
  final mock = MockOutboxCubit();
  when(() => mock.state).thenReturn(outboxState);

  when(mock.close).thenAnswer((_) async {});

  when(() => mock.stream).thenAnswer(
    (_) => Stream<OutboxState>.fromIterable([outboxState]),
  );

  return mock;
}
