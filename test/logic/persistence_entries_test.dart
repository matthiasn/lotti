import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
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

  group('createLink linkType -', () {
    setUp(() {
      when(
        () => vectorClockService.getNextVectorClock(),
      ).thenAnswer((_) async => const VectorClock({'host': 1}));
      when(
        () => mocks.journalDb.upsertEntryLink(any()),
      ).thenAnswer((_) async => 1);
    });

    test('defaults to a BasicLink and never queries the cycle guard', () async {
      final created = await entries.createLink(fromId: 'a', toId: 'b');

      expect(created, isTrue);
      verifyNever(
        () => mocks.journalDb.typedLinksForTaskIds(
          any(),
          types: any(named: 'types'),
        ),
      );
      final persisted =
          verify(
                () => mocks.journalDb.upsertEntryLink(captureAny()),
              ).captured.single
              as EntryLink;
      expect(persisted, isA<BasicLink>());
    });

    test(
      'a non-blocks linkType skips the cycle guard and persists that variant',
      () async {
        final created = await entries.createLink(
          fromId: 'a',
          toId: 'b',
          linkType: EntryLinkType.followsUp,
        );

        expect(created, isTrue);
        verifyNever(
          () => mocks.journalDb.typedLinksForTaskIds(
            any(),
            types: any(named: 'types'),
          ),
        );
        final persisted =
            verify(
                  () => mocks.journalDb.upsertEntryLink(captureAny()),
                ).captured.single
                as EntryLink;
        expect(persisted, isA<FollowsUpLink>());
      },
    );

    test(
      'rejects a direct self-block without querying the database',
      () async {
        final created = await entries.createLink(
          fromId: 'same',
          toId: 'same',
          linkType: EntryLinkType.blocks,
        );

        expect(created, isFalse);
        verifyNever(
          () => mocks.journalDb.typedLinksForTaskIds(
            any(),
            types: any(named: 'types'),
          ),
        );
        verifyNever(() => mocks.journalDb.upsertEntryLink(any()));
      },
    );

    test(
      'creates a BlocksLink when no existing chain closes a cycle',
      () async {
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            any(),
            types: any(named: 'types'),
          ),
        ).thenAnswer((_) async => <EntryLink>[]);

        final created = await entries.createLink(
          fromId: 'a',
          toId: 'b',
          linkType: EntryLinkType.blocks,
        );

        expect(created, isTrue);
        final persisted =
            verify(
                  () => mocks.journalDb.upsertEntryLink(captureAny()),
                ).captured.single
                as EntryLink;
        expect(persisted, isA<BlocksLink>());
      },
    );

    test(
      'rejects a blocks edge that would immediately close a 1-hop cycle',
      () async {
        // b already blocks a, so creating a-blocks-b would close the loop.
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'b'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer(
          (_) async => [
            EntryLink.blocks(
              id: 'existing',
              fromId: 'b',
              toId: 'a',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );

        final created = await entries.createLink(
          fromId: 'a',
          toId: 'b',
          linkType: EntryLinkType.blocks,
        );

        expect(created, isFalse);
        verifyNever(() => mocks.journalDb.upsertEntryLink(any()));
      },
    );

    test(
      'rejects a blocks edge that would close a transitive 2-hop cycle',
      () async {
        // b blocks c, and c already blocks a, so a-blocks-b would close the
        // loop two hops out.
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'b'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer(
          (_) async => [
            EntryLink.blocks(
              id: 'hop-1',
              fromId: 'b',
              toId: 'c',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'c'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer(
          (_) async => [
            EntryLink.blocks(
              id: 'hop-2',
              fromId: 'c',
              toId: 'a',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );

        final created = await entries.createLink(
          fromId: 'a',
          toId: 'b',
          linkType: EntryLinkType.blocks,
        );

        expect(created, isFalse);
        verifyNever(() => mocks.journalDb.upsertEntryLink(any()));
      },
    );

    test(
      'ignores an inbound link where the frontier task is only the target, '
      'not the source of the blocks edge',
      () async {
        // 'x' blocks 'b' -- 'b' is the target here, not the source, so the
        // outward-only traversal from 'b' must skip it rather than treating
        // 'x' as something 'b' blocks.
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'b'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer(
          (_) async => [
            EntryLink.blocks(
              id: 'irrelevant-inbound',
              fromId: 'x',
              toId: 'b',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );

        final created = await entries.createLink(
          fromId: 'a',
          toId: 'b',
          linkType: EntryLinkType.blocks,
        );

        expect(created, isTrue);
      },
    );

    test(
      'deduplicates a target reached from two frontier nodes in the same '
      'hop instead of re-querying it twice',
      () async {
        // b blocks both c and d; c and d both block e -- e must be queried
        // exactly once as the next frontier, not twice.
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'b'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer(
          (_) async => [
            EntryLink.blocks(
              id: 'b-blocks-c',
              fromId: 'b',
              toId: 'c',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
            EntryLink.blocks(
              id: 'b-blocks-d',
              fromId: 'b',
              toId: 'd',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'c', 'd'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer(
          (_) async => [
            EntryLink.blocks(
              id: 'c-blocks-e',
              fromId: 'c',
              toId: 'e',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
            EntryLink.blocks(
              id: 'd-blocks-e',
              fromId: 'd',
              toId: 'e',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'e'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer((_) async => <EntryLink>[]);

        final created = await entries.createLink(
          fromId: 'a',
          toId: 'b',
          linkType: EntryLinkType.blocks,
        );

        expect(created, isTrue);
        verify(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'e'},
            types: {'BlocksLink'},
          ),
        ).called(1);
      },
    );
  });
}
