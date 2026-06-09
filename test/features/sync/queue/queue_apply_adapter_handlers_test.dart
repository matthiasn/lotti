import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/queue_apply_adapter.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import 'queue_apply_adapter_test_helpers.dart';

void main() {
  late AdapterMockSyncEventProcessor processor;
  late JournalDb journalDb;
  late MockDomainLogger logging;
  late MockRoom room;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(MockEvent());
    registerFallbackValue(AdapterMockPreparedSyncEvent());
  });

  setUp(() {
    processor = AdapterMockSyncEventProcessor();
    journalDb = JournalDb(inMemoryDatabase: true);
    logging = MockDomainLogger();
    room = MockRoom();
    when(() => room.id).thenReturn('!r:example.org');
  });

  tearDown(() async {
    await journalDb.close();
  });

  QueueApplyAdapter build() => QueueApplyAdapter(
    processor: processor,
    journalDb: journalDb,
    logging: logging,
  );

  glados.Glados(
    glados.any.adapterScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'generated prepare/apply matrices classify outcomes with or without cache',
    (scenario) async {
      final localProcessor = AdapterMockSyncEventProcessor();
      final localJournalDb = JournalDb(inMemoryDatabase: true);
      final localLogging = MockDomainLogger();
      final localRoom = MockRoom();
      when(() => localRoom.id).thenReturn('!r:example.org');
      final entry = hBuildEntry(
        eventId: '\$generated-${scenario.slot}',
        roomId: '!r',
        originTsMs: scenario.slot + 1,
      );
      final prepared = AdapterMockPreparedSyncEvent();

      try {
        switch (scenario.prepareOutcome) {
          case GeneratedAdapterPrepareOutcome.ready:
            when(
              () => localProcessor.prepare(event: any(named: 'event')),
            ).thenAnswer((_) async => prepared);
            when(() => prepared.syncMessage).thenReturn(scenario.syncMessage());
            switch (scenario.applyOutcome) {
              case GeneratedAdapterApplyOutcome.applied:
                when(
                  () => localProcessor.apply(
                    prepared: prepared,
                    journalDb: localJournalDb,
                  ),
                ).thenAnswer((_) async => null);
              case GeneratedAdapterApplyOutcome.pendingDescriptor:
              case GeneratedAdapterApplyOutcome.pendingPath:
              case GeneratedAdapterApplyOutcome.retriableIo:
              case GeneratedAdapterApplyOutcome.retriableThrow:
                when(
                  () => localProcessor.apply(
                    prepared: prepared,
                    journalDb: localJournalDb,
                  ),
                ).thenThrow(scenario.applyException());
            }
          case GeneratedAdapterPrepareOutcome.nullPrepared:
            when(
              () => localProcessor.prepare(event: any(named: 'event')),
            ).thenAnswer((_) async => null);
          case GeneratedAdapterPrepareOutcome.pendingDescriptor:
          case GeneratedAdapterPrepareOutcome.pendingPath:
          case GeneratedAdapterPrepareOutcome.retriableIo:
          case GeneratedAdapterPrepareOutcome.permanentThrow:
            when(
              () => localProcessor.prepare(event: any(named: 'event')),
            ).thenThrow(scenario.prepareException());
        }

        final adapter = QueueApplyAdapter(
          processor: localProcessor,
          journalDb: localJournalDb,
          logging: localLogging,
        );
        if (scenario.usePrepareBatch) {
          await adapter.bindPrepareBatch()([entry], localRoom);
        }

        final outcome = await adapter.bind()(entry, localRoom);
        expect(outcome, scenario.expectedOutcome, reason: '$scenario');
        verify(
          () => localProcessor.prepare(event: any(named: 'event')),
        ).called(1);
        if (scenario.prepareReady) {
          verify(
            () => localProcessor.apply(
              prepared: prepared,
              journalDb: localJournalDb,
            ),
          ).called(1);
        } else {
          verifyNever(
            () => localProcessor.apply(
              prepared: any(named: 'prepared'),
              journalDb: localJournalDb,
            ),
          );
        }
      } finally {
        await localJournalDb.close();
      }
    },
    tags: 'glados',
  );

  test('undeserialisable rawJson maps to permanentSkip', () async {
    const entry = InboundQueueEntry(
      queueId: 1,
      eventId: r'$bad',
      roomId: '!r',
      originTs: 1,
      producer: InboundEventProducer.live,
      enqueuedAt: 1,
      attempts: 0,
      leaseUntil: 0,
      rawJson: 'not-json',
    );
    final outcome = await build().bind()(entry, room);
    expect(outcome, ApplyOutcome.permanentSkip);
  });

  test('prepare returning null maps to permanentSkip', () async {
    final entry = hBuildEntry(
      eventId: r'$none',
      roomId: '!r',
      originTsMs: 1,
    );
    when(
      () => processor.prepare(event: any(named: 'event')),
    ).thenAnswer((_) async => null);
    final outcome = await build().bind()(entry, room);
    expect(outcome, ApplyOutcome.permanentSkip);
    verifyNever(
      () => processor.apply(
        prepared: any(named: 'prepared'),
        journalDb: journalDb,
      ),
    );
  });

  test(
    'FileSystemException during prepare maps to retriable',
    () async {
      final entry = hBuildEntry(
        eventId: r'$fs',
        roomId: '!r',
        originTsMs: 1,
      );
      when(
        () => processor.prepare(event: any(named: 'event')),
      ).thenThrow(const FileSystemException('down'));
      final outcome = await build().bind()(entry, room);
      expect(outcome, ApplyOutcome.retriable);
    },
  );

  test('successful prepare + apply maps to applied', () async {
    final entry = hBuildEntry(
      eventId: r'$ok',
      roomId: '!r',
      originTsMs: 1,
    );
    final prepared = AdapterMockPreparedSyncEvent();
    when(
      () => processor.prepare(event: any(named: 'event')),
    ).thenAnswer((_) async => prepared);
    when(
      () => processor.apply(
        prepared: any(named: 'prepared'),
        journalDb: journalDb,
      ),
    ).thenAnswer((_) async => null);

    final outcome = await build().bind()(entry, room);
    expect(outcome, ApplyOutcome.applied);
    verify(
      () => processor.apply(
        prepared: prepared,
        journalDb: journalDb,
      ),
    ).called(1);
  });

  test('FileSystemException during apply maps to retriable', () async {
    final entry = hBuildEntry(
      eventId: r'$fsApply',
      roomId: '!r',
      originTsMs: 1,
    );
    final prepared = AdapterMockPreparedSyncEvent();
    when(
      () => processor.prepare(event: any(named: 'event')),
    ).thenAnswer((_) async => prepared);
    when(
      () => processor.apply(
        prepared: any(named: 'prepared'),
        journalDb: journalDb,
      ),
    ).thenThrow(const FileSystemException('disk full'));

    final outcome = await build().bind()(entry, room);
    expect(outcome, ApplyOutcome.retriable);
  });

  test(
    'generic exception during prepare maps to permanentSkip',
    () async {
      final entry = hBuildEntry(
        eventId: r'$preparePermanent',
        roomId: '!r',
        originTsMs: 1,
      );
      when(
        () => processor.prepare(event: any(named: 'event')),
      ).thenThrow(StateError('logic bug'));

      final outcome = await build().bind()(entry, room);
      expect(outcome, ApplyOutcome.permanentSkip);
      verify(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).called(1);
    },
  );

  group('writesJournalDb classifies sync payload families', () {
    // These tests pin the per-variant outcome of the adapter's
    // wrap-or-bypass decision. The wrap path costs the journal writer
    // lock for the whole `apply` duration; misclassifying a
    // non-journal payload as wrapped silently re-introduces the
    // reader-stall regression we just fixed (super-slow log showed
    // hundreds of ms of queued reads behind unrelated sync applies).
    // Misclassifying a journal-writing payload as bypass would split
    // the journal upsert + linked_entries writes across two
    // transactions and break atomicity on a mid-apply crash. Locking
    // the table down per-variant means a future `SyncMessage` factory
    // without a corresponding case here will fail compilation rather
    // than silently inheriting a wrong default.

    bool wraps(SyncMessage message) =>
        QueueApplyAdapter.writesJournalDbForTesting(message);

    test('SyncJournalEntity bypasses outer wrap (owns its own narrow tx)', () {
      const message = SyncMessage.journalEntity(
        id: 'entity-id',
        jsonPath: '/entity.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
      );
      expect(wraps(message), isFalse);
    });

    test('SyncEntryLink wraps — writes to linked_entries (JournalDb)', () {
      final link = EntryLink.basic(
        id: 'link-id',
        fromId: 'from',
        toId: 'to',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      );
      expect(wraps(message), isTrue);
    });

    test(
      'SyncEntityDefinition wraps — writes to *_definitions (JournalDb)',
      () {
        final message = SyncMessage.entityDefinition(
          entityDefinition: measurableWater,
          status: SyncEntryStatus.initial,
        );
        expect(wraps(message), isTrue);
      },
    );

    test('SyncAiConfig bypasses outer wrap (writes to ai_config_db)', () {
      final message = SyncMessage.aiConfig(
        aiConfig: fallbackAiConfig,
        status: SyncEntryStatus.initial,
      );
      expect(wraps(message), isFalse);
    });

    test('SyncAiConfigDelete bypasses outer wrap (ai_config_db)', () {
      const message = SyncMessage.aiConfigDelete(id: 'cfg-id');
      expect(wraps(message), isFalse);
    });

    test('SyncConfigFlag wraps — writes to config_flags (JournalDb)', () {
      const message = SyncMessage.configFlag(
        name: 'enableDailyOs',
        description: 'Enable DailyOS Page?',
        status: true,
      );
      expect(wraps(message), isTrue);
    });

    test('SyncThemingSelection bypasses outer wrap (settings_db)', () {
      const message = SyncMessage.themingSelection(
        lightThemeName: 'light',
        darkThemeName: 'dark',
        themeMode: 'system',
        updatedAt: 1,
        status: SyncEntryStatus.initial,
      );
      expect(wraps(message), isFalse);
    });

    test('SyncBackfillRequest wraps conservatively', () {
      const message = SyncMessage.backfillRequest(
        entries: <BackfillRequestEntry>[],
        requesterId: 'host-1',
      );
      expect(wraps(message), isTrue);
    });

    test('SyncBackfillResponse wraps conservatively', () {
      const message = SyncMessage.backfillResponse(
        hostId: 'host-1',
        counter: 1,
        deleted: false,
        unresolvable: false,
      );
      expect(wraps(message), isTrue);
    });

    test('SyncAgentEntity bypasses outer wrap (agent_db)', () {
      const message = SyncMessage.agentEntity(
        status: SyncEntryStatus.initial,
        jsonPath: '/agent_entities/a1.json',
      );
      expect(wraps(message), isFalse);
    });

    test('SyncAgentLink bypasses outer wrap (agent_db)', () {
      const message = SyncMessage.agentLink(
        status: SyncEntryStatus.initial,
        jsonPath: '/agent_links/l1.json',
      );
      expect(wraps(message), isFalse);
    });

    test('SyncAgentBundle bypasses outer wrap (agent_db loop)', () {
      const message = SyncMessage.agentBundle(
        agentId: 'agent-1',
        wakeRunKey: 'wake-1',
      );
      expect(wraps(message), isFalse);
    });

    test('SyncNotification bypasses outer wrap (notifications_db)', () {
      const message = SyncMessage.notification(
        id: 'notification-id',
        jsonPath: '/notifications/notification-id.json',
        vectorClock: VectorClock({'host-1': 1}),
        originatingHostId: 'host-1',
      );
      expect(wraps(message), isFalse);
    });

    test(
      'SyncNotificationStateUpdate bypasses outer wrap (notifications_db)',
      () {
        const message = SyncMessage.notificationStateUpdate(
          id: 'notification-id',
          vectorClock: VectorClock({'host-1': 1}),
          originatingHostId: 'host-1',
        );
        expect(wraps(message), isFalse);
      },
    );

    test('SyncOutboxBundle wraps — unpacks into journal/linked_entries', () {
      const message = SyncMessage.outboxBundle(
        children: <SyncMessage>[],
      );
      expect(wraps(message), isTrue);
    });
  });

  group('apply respects the writesJournalDb classifier', () {
    test(
      'a journalEntity-shaped payload bypasses the outer transaction wrap '
      'so cross-DB awaits inside `apply` (sync-sequence log, pre-write '
      'reads) do not hold the journal writer lock',
      () async {
        final entry = hBuildEntry(
          eventId: r'$bypass-wrap',
          roomId: '!r',
          originTsMs: 1,
        );
        final prepared = AdapterMockPreparedSyncEvent();
        const message = SyncMessage.journalEntity(
          id: 'entity-id',
          jsonPath: '/entity.json',
          vectorClock: null,
          status: SyncEntryStatus.initial,
        );
        when(() => prepared.syncMessage).thenReturn(message);
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenAnswer((_) async => prepared);
        when(
          () => processor.apply(
            prepared: any(named: 'prepared'),
            journalDb: journalDb,
          ),
        ).thenAnswer((_) async => null);

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.applied);
        // The classifier introspected the prepared payload; the apply
        // still ran. We do not assert on transaction state directly
        // because the JournalDb is in-memory and a transaction wrap is
        // observable only via the writer lock — but the predicate test
        // group above pins the wrap/bypass decision per variant.
        verify(() => prepared.syncMessage).called(1);
      },
    );

    test(
      'a payload that throws when its syncMessage is read falls back to '
      'the safe wrapped path — the existing test mocks rely on this so '
      'the change cannot retroactively break them',
      () async {
        final entry = hBuildEntry(
          eventId: r'$throws',
          roomId: '!r',
          originTsMs: 1,
        );
        final prepared = AdapterMockPreparedSyncEvent();
        // No stub for syncMessage → mocktail throws on access.
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenAnswer((_) async => prepared);
        when(
          () => processor.apply(
            prepared: any(named: 'prepared'),
            journalDb: journalDb,
          ),
        ).thenAnswer((_) async => null);

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.applied);
      },
    );
  });
}
