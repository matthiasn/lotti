import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_entries.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import '../widget_test_utils.dart';

/// Mirror test for [PersistenceEntries].
///
/// Covers the two collaborator responsibilities that the facade-level test
/// can only exercise end-to-end:
///   * `createXxxEntry` wrappers must forward to the facade's `*Impl` builders
///     (so a mocked facade records the call), and
///   * [PersistenceEntries.createDbEntity] must fire the `addGeolocation`
///     cross-collaborator call only when `shouldAddGeolocation` is true.
void main() {
  late MockPersistenceLogic logic;
  late MockVectorClockService vectorClockService;
  late MockOutboxService outboxService;
  late MockNotificationService notificationService;
  late MockFts5Db fts5Db;
  late PersistenceEntries entries;
  late TestGetItMocks mocks;

  setUp(() async {
    registerAllFallbackValues();
    vectorClockService = MockVectorClockService();
    outboxService = MockOutboxService();
    notificationService = MockNotificationService();
    fts5Db = MockFts5Db();
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<VectorClockService>(vectorClockService)
          ..registerSingleton<MetadataService>(MockMetadataService())
          ..registerSingleton<OutboxService>(outboxService)
          ..registerSingleton<NotificationService>(notificationService)
          ..registerSingleton<Fts5Db>(fts5Db);
      },
    );
    logic = MockPersistenceLogic();
    entries = PersistenceEntries(logic);

    when(
      () => mocks.journalDb.updateJournalEntity(
        any(),
        overwrite: any(named: 'overwrite'),
        overrideComparison: any(named: 'overrideComparison'),
      ),
    ).thenAnswer((_) async => JournalUpdateResult.applied());
    when(() => mocks.updateNotifications.notify(any())).thenReturn(null);
    when(
      () => vectorClockService.getHost(),
    ).thenAnswer((_) async => 'host');
    when(
      () => outboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});
    when(notificationService.updateBadge).thenAnswer((_) async {});
    when(() => logic.addGeolocation(any())).thenReturn(null);
  });

  tearDown(tearDownTestGetIt);

  test(
    'createWorkoutEntry forwards to the facade createWorkoutEntryImpl',
    () async {
      final workout = testWorkoutRunning;
      when(() => logic.createWorkoutEntryImpl(workout.data)).thenAnswer(
        (_) async => workout,
      );

      final result = await entries.createWorkoutEntry(workout.data);

      expect(result, same(workout));
      verify(() => logic.createWorkoutEntryImpl(workout.data)).called(1);
    },
  );

  test(
    'createDbEntity fires addGeolocation when shouldAddGeolocation is true',
    () async {
      final saved = await entries.createDbEntity(testTextEntry);

      expect(saved, isTrue);
      verify(() => logic.addGeolocation(testTextEntry.meta.id)).called(1);
    },
  );

  test(
    'createDbEntity skips addGeolocation when shouldAddGeolocation is false',
    () async {
      await entries.createDbEntity(
        testTextEntry,
        shouldAddGeolocation: false,
      );

      verifyNever(() => logic.addGeolocation(any()));
    },
  );

  test(
    'createLink burns nothing and returns false when the upsert is a no-op',
    () async {
      when(
        () => vectorClockService.getNextVectorClock(),
      ).thenAnswer((_) async => const VectorClock({'host': 1}));
      when(
        () => mocks.journalDb.upsertEntryLink(any()),
      ).thenAnswer((_) async => 0);

      final created = await entries.createLink(fromId: 'a', toId: 'b');

      expect(created, isFalse);
      verifyNever(() => outboxService.enqueueMessage(any()));
    },
  );
}
