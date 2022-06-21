import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/inbox_service.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncConfigService extends Mock implements SyncConfigService {}

class MockSyncInboxService extends Mock implements SyncInboxService {}

class MockOutboxService extends Mock implements OutboxService {}

class MockSyncConfigCubit extends Mock implements SyncConfigCubit {}

MockSyncConfigCubit mockSyncConfigCubitWithState(SyncConfigState state) {
  final mock = MockSyncConfigCubit();
  when(() => mock.state).thenReturn(state);

  when(mock.close).thenAnswer((_) async {});

  when(() => mock.stream).thenAnswer(
    (_) => Stream<SyncConfigState>.fromIterable([state]),
  );

  return mock;
}
