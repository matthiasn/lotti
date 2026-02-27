import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

MockSyncDatabase mockSyncDatabaseWithCount(int count) {
  final mock = MockSyncDatabase();
  when(mock.close).thenAnswer((_) async {});

  when(mock.watchOutboxCount).thenAnswer(
    (_) => Stream<int>.fromIterable([count]),
  );

  when(() => mock.getDailyOutboxVolume(days: any(named: 'days')))
      .thenAnswer((_) async => <OutboxDailyVolume>[]);

  return mock;
}
