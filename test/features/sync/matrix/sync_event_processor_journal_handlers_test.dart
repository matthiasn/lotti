// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(registerSyncProcessorFallbacks);
  setUp(setUpProcessorMocks);

  group('SyncEventProcessor - Embedded Entry Links', () {
    test(
      'processes embedded links after successful journal entity update',
      () async {
        final link1 = EntryLink.basic(
          id: 'link-1',
          fromId: 'entry-id',
          toId: 'category-1',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          vectorClock: null,
        );
        final link2 = EntryLink.basic(
          id: 'link-2',
          fromId: 'entry-id',
          toId: 'category-2',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          vectorClock: null,
        );

        final message = SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: '/entry.json',
          vectorClock: null,
          status: SyncEntryStatus.initial,
          entryLinks: [link1, link2],
        );

        when(
          () => journalEntityLoader.load(jsonPath: '/entry.json'),
        ).thenAnswer((_) async => fallbackJournalEntity);
        when(() => event.text).thenReturn(encodeMessage(message));
        when(() => journalDb.upsertEntryLink(link1)).thenAnswer((_) async => 1);
        when(() => journalDb.upsertEntryLink(link2)).thenAnswer((_) async => 1);

        await processor.process(event: event, journalDb: journalDb);

        // Verify both links were upserted
        verify(() => journalDb.upsertEntryLink(link1)).called(1);
        verify(() => journalDb.upsertEntryLink(link2)).called(1);

        // Verify logging for each embedded link
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: contains(
                'apply entryLink.embedded from=${link1.fromId} to=${link1.toId}',
              ),
            ),
            subDomain: 'processor.apply.entryLink.embedded',
          ),
        ).called(1);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: contains(
                'apply entryLink.embedded from=${link2.fromId} to=${link2.toId}',
              ),
            ),
            subDomain: 'processor.apply.entryLink.embedded',
          ),
        ).called(1);

        // Verify summary log includes embedded links count
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('embeddedLinks=2/2')),
            subDomain: 'processor.apply',
          ),
        ).called(1);

        // Verify notifications sent for all affected IDs from both links
        verify(
          () => updateNotifications.notify(
            {link1.fromId, link1.toId, link2.toId},
            fromSync: true,
          ),
        ).called(1);
      },
    );

    test('processes embedded links even when entity update is skipped', () async {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'entry-id',
        toId: 'category-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );

      final message = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entry.json',
        vectorClock: const VectorClock({'old': 1}),
        status: SyncEntryStatus.initial,
        entryLinks: [link],
      );

      // Create an entry with newer vector clock so update is skipped
      final newerEntry = JournalEntry(
        meta: Metadata(
          id: 'entry-id',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'new': 2}),
        ),
        entryText: const EntryText(plainText: 'newer'),
      );

      when(
        () => journalEntityLoader.load(
          jsonPath: '/entry.json',
          incomingVectorClock: const VectorClock({'old': 1}),
        ),
      ).thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));
      when(
        () => journalDb.journalEntityById('entry-id'),
      ).thenAnswer((_) async => newerEntry);
      when(
        () => journalDb.updateJournalEntity(any<JournalEntity>()),
      ).thenAnswer(
        (_) async => JournalUpdateResult.skipped(
          reason: JournalUpdateSkipReason.olderOrEqual,
        ),
      );
      when(() => journalDb.upsertEntryLink(link)).thenAnswer((_) async => 1);

      await processor.process(event: event, journalDb: journalDb);

      // Verify link WAS upserted even though entity update was skipped.
      // EntryLinks have their own vector clock for conflict resolution,
      // so they should be processed regardless of journal entity status.
      // This prevents gray calendar entries that rely on links for color lookup.
      verify(() => journalDb.upsertEntryLink(link)).called(1);

      // Verify logging for embedded link processing
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: contains(
              'apply entryLink.embedded from=${link.fromId} to=${link.toId}',
            ),
          ),
          subDomain: 'processor.apply.entryLink.embedded',
        ),
      ).called(1);

      // Verify summary shows 1 embedded link processed
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('embeddedLinks=1/1')),
          subDomain: 'processor.apply',
        ),
      ).called(1);

      // Verify notification sent for affected IDs from link
      verify(
        () => updateNotifications.notify(
          {link.fromId, link.toId},
          fromSync: true,
        ),
      ).called(1);
    });

    test(
      'embedded link failure inside the journal-entity apply path aborts '
      'the transaction so the entity row never lands without its links — '
      'redelivery routes the same event to the duplicate path which does '
      'NOT retry link upserts, so a swallowed failure here would leave '
      'permanently missing edges',
      () async {
        final link1 = EntryLink.basic(
          id: 'link-1',
          fromId: 'entry-id',
          toId: 'category-1',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          vectorClock: null,
        );
        final link2 = EntryLink.basic(
          id: 'link-2',
          fromId: 'entry-id',
          toId: 'category-2',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          vectorClock: null,
        );

        final message = SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: '/entry.json',
          vectorClock: null,
          status: SyncEntryStatus.initial,
          entryLinks: [link1, link2],
        );

        when(
          () => journalEntityLoader.load(jsonPath: '/entry.json'),
        ).thenAnswer((_) async => fallbackJournalEntity);
        when(() => event.text).thenReturn(encodeMessage(message));

        // First link fails, second would succeed — but the loop must
        // bail on the first failure and let the transaction roll back.
        when(
          () => journalDb.upsertEntryLink(link1),
        ).thenThrow(Exception('Database error'));
        when(() => journalDb.upsertEntryLink(link2)).thenAnswer((_) async => 1);

        await expectLater(
          processor.process(event: event, journalDb: journalDb),
          throwsA(isA<Exception>()),
        );

        // The first link was attempted (and threw); the second was
        // NOT — the loop exits on rethrow.
        verify(() => journalDb.upsertEntryLink(link1)).called(1);
        verifyNever(() => journalDb.upsertEntryLink(link2));

        // The link-level capture still ran before the rethrow so the
        // failure shows up in domain logs.
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Exception>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'apply.entryLink.embedded',
          ),
        ).called(1);
      },
    );

    test('processes empty embedded links list', () async {
      const message = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entry.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
        entryLinks: [],
      );

      when(
        () => journalEntityLoader.load(jsonPath: '/entry.json'),
      ).thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      // Verify no links were upserted
      verifyNever(() => journalDb.upsertEntryLink(any()));

      // Verify summary shows 0/0 embedded links
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('embeddedLinks=0/0')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
    });

    test('skips link processing when linkRows is 0 (no-op upsert)', () async {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'entry-id',
        toId: 'category-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );

      final message = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entry.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
        entryLinks: [link],
      );

      when(
        () => journalEntityLoader.load(jsonPath: '/entry.json'),
      ).thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(link)).thenAnswer((_) async => 0);

      await processor.process(event: event, journalDb: journalDb);

      // Verify link upsert was attempted
      verify(() => journalDb.upsertEntryLink(link)).called(1);

      // Verify no log for link application (rows was 0)
      verifyNever(
        () => loggingService.log(
          any<LogDomain>(),
          any<String>(that: contains('apply entryLink.embedded')),
          subDomain: 'processor.apply.entryLink.embedded',
        ),
      );

      // Verify summary shows 0 processed (since linkRows was 0)
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('embeddedLinks=0/1')),
          subDomain: 'processor.apply',
        ),
      ).called(1);

      // Verify notifications were still sent for affected IDs
      verify(
        () => updateNotifications.notify(
          {link.fromId, link.toId},
          fromSync: true,
        ),
      ).called(1);
    });

    test('syncs collapsed state from remote embedded link', () async {
      final incomingLink = EntryLink.basic(
        id: 'link-collapsed',
        fromId: 'entry-id',
        toId: 'category-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
        vectorClock: null,
        collapsed: true,
      );

      final message = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entry.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
        entryLinks: [incomingLink],
      );

      when(
        () => journalEntityLoader.load(jsonPath: '/entry.json'),
      ).thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));
      when(
        () => journalDb.upsertEntryLink(any<EntryLink>()),
      ).thenAnswer((_) async => 1);

      await processor.process(event: event, journalDb: journalDb);

      // Verify the upserted link has collapsed=true from the incoming link
      final capturedLink =
          verify(
                () => journalDb.upsertEntryLink(captureAny<EntryLink>()),
              ).captured.single
              as EntryLink;
      expect(capturedLink.id, 'link-collapsed');
      expect(capturedLink.collapsed, isTrue);
      expect(capturedLink.updatedAt, DateTime(2025, 1, 2));
    });
  });

  group('EntryLink sequence log recording -', () {
    late MockSyncSequenceLogService mockSequenceService;

    setUp(() {
      mockSequenceService = MockSyncSequenceLogService();
    });

    test(
      'records entry link in sequence log when vectorClock and originatingHostId present',
      () async {
        const vc = VectorClock({'host-A': 5});
        final link = EntryLink.basic(
          id: 'seq-link-1',
          fromId: 'from-1',
          toId: 'to-1',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: vc,
        );
        final message = SyncMessage.entryLink(
          entryLink: link,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-A',
        );

        when(
          () => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          ),
        ).thenAnswer((_) async => []);

        final processorWithSeq = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSequenceService,
        );

        when(() => event.text).thenReturn(encodeMessage(message));
        when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

        await processorWithSeq.process(event: event, journalDb: journalDb);

        verify(
          () => mockSequenceService.recordReceivedEntryLink(
            linkId: 'seq-link-1',
            vectorClock: vc,
            originatingHostId: 'host-A',
          ),
        ).called(1);
      },
    );

    test(
      'logs gap detection when recordReceivedEntryLink returns gaps',
      () async {
        const vc = VectorClock({'host-B': 10});
        final link = EntryLink.basic(
          id: 'seq-link-gaps',
          fromId: 'from-gap',
          toId: 'to-gap',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: vc,
        );
        final message = SyncMessage.entryLink(
          entryLink: link,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-B',
        );

        when(
          () => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          ),
        ).thenAnswer(
          (_) async => [
            (hostId: 'host-B', counter: 8),
            (hostId: 'host-B', counter: 9),
          ],
        );

        final processorWithSeq = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSequenceService,
        );

        when(() => event.text).thenReturn(encodeMessage(message));
        when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

        await processorWithSeq.process(event: event, journalDb: journalDb);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('apply.entryLink.gapsDetected count=2')),
            subDomain: 'processor.gapDetection',
          ),
        ).called(1);
      },
    );

    test('handles recordReceivedEntryLink exceptions gracefully', () async {
      const vc = VectorClock({'host-C': 3});
      final link = EntryLink.basic(
        id: 'seq-link-error',
        fromId: 'from-err',
        toId: 'to-err',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-C',
      );

      when(
        () => mockSequenceService.recordReceivedEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      ).thenThrow(Exception('sequence log error'));

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      // Should not throw - errors are caught and logged
      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Verify exception was logged
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'recordReceived',
        ),
      ).called(1);
    });

    test('skips sequence log when vectorClock is null', () async {
      final link = EntryLink.basic(
        id: 'seq-link-no-vc',
        fromId: 'from-novc',
        toId: 'to-novc',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-D',
      );

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Sequence log should NOT be called
      verifyNever(
        () => mockSequenceService.recordReceivedEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      );
    });

    test('skips sequence log when originatingHostId is null', () async {
      const vc = VectorClock({'host-E': 1});
      final link = EntryLink.basic(
        id: 'seq-link-no-origin',
        fromId: 'from-noorig',
        toId: 'to-noorig',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        // No originatingHostId
      );

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Sequence log should NOT be called
      verifyNever(
        () => mockSequenceService.recordReceivedEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      );
    });

    test('records when rows=0 but link exists locally', () async {
      const vc = VectorClock({'host-F': 7});
      final link = EntryLink.basic(
        id: 'seq-link-exists',
        fromId: 'from-exists',
        toId: 'to-exists',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-F',
      );

      when(
        () => mockSequenceService.recordReceivedEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
        ),
      ).thenAnswer((_) async => []);

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      // rows=0 (no-op upsert)
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 0);
      // But link exists locally
      when(
        () => journalDb.entryLinkById('seq-link-exists'),
      ).thenAnswer((_) async => link);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Sequence log SHOULD be called because link exists
      verify(
        () => mockSequenceService.recordReceivedEntryLink(
          linkId: 'seq-link-exists',
          vectorClock: vc,
          originatingHostId: 'host-F',
        ),
      ).called(1);
    });

    test(
      'skips recording when rows=0 and link does not exist locally',
      () async {
        const vc = VectorClock({'host-G': 2});
        final link = EntryLink.basic(
          id: 'seq-link-missing',
          fromId: 'from-missing',
          toId: 'to-missing',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: vc,
        );
        final message = SyncMessage.entryLink(
          entryLink: link,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-G',
        );

        final processorWithSeq = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSequenceService,
        );

        when(() => event.text).thenReturn(encodeMessage(message));
        // rows=0 (no-op upsert)
        when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 0);
        // Link does NOT exist locally
        when(
          () => journalDb.entryLinkById('seq-link-missing'),
        ).thenAnswer((_) async => null);

        await processorWithSeq.process(event: event, journalDb: journalDb);

        // Sequence log should NOT be called
        verifyNever(
          () => mockSequenceService.recordReceivedEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
          ),
        );
      },
    );

    test('passes coveredVectorClocks to recordReceivedEntryLink', () async {
      const vc = VectorClock({'host-A': 5});
      const coveredClock1 = VectorClock({'host-A': 3});
      const coveredClock2 = VectorClock({'host-A': 4});
      final link = EntryLink.basic(
        id: 'seq-link-covered',
        fromId: 'from-covered',
        toId: 'to-covered',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: vc,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        originatingHostId: 'host-A',
        coveredVectorClocks: [coveredClock1, coveredClock2],
      );

      when(
        () => mockSequenceService.recordReceivedEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
          coveredVectorClocks: any(named: 'coveredVectorClocks'),
        ),
      ).thenAnswer((_) async => []);

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

      await processorWithSeq.process(event: event, journalDb: journalDb);

      verify(
        () => mockSequenceService.recordReceivedEntryLink(
          linkId: 'seq-link-covered',
          vectorClock: vc,
          originatingHostId: 'host-A',
          coveredVectorClocks: [coveredClock1, coveredClock2],
        ),
      ).called(1);
    });
  });
}
