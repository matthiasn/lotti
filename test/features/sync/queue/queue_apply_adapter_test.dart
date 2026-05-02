import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/queue_apply_adapter.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class _MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class _MockRoom extends Mock implements Room {}

class _MockPreparedSyncEvent extends Mock implements PreparedSyncEvent {}

class _MockEvent extends Mock implements Event {}

InboundQueueEntry _buildEntry({
  required String eventId,
  required String roomId,
  required int originTsMs,
}) {
  final content = <String, dynamic>{'msgtype': syncMessageType};
  final json = <String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': EventTypes.Message,
    'sender': '@tester:example.org',
    'content': content,
  };
  return InboundQueueEntry(
    queueId: 1,
    eventId: eventId,
    roomId: roomId,
    originTs: originTsMs,
    producer: InboundEventProducer.live,
    enqueuedAt: originTsMs,
    attempts: 0,
    leaseUntil: 0,
    rawJson: jsonEncode(json),
  );
}

void main() {
  late _MockSyncEventProcessor processor;
  late JournalDb journalDb;
  late MockLoggingService logging;
  late _MockRoom room;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_MockEvent());
    registerFallbackValue(_MockPreparedSyncEvent());
  });

  setUp(() {
    processor = _MockSyncEventProcessor();
    journalDb = JournalDb(inMemoryDatabase: true);
    logging = MockLoggingService();
    room = _MockRoom();
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
    final entry = _buildEntry(
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
      final entry = _buildEntry(
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
    final entry = _buildEntry(
      eventId: r'$ok',
      roomId: '!r',
      originTsMs: 1,
    );
    final prepared = _MockPreparedSyncEvent();
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
    final entry = _buildEntry(
      eventId: r'$fsApply',
      roomId: '!r',
      originTsMs: 1,
    );
    final prepared = _MockPreparedSyncEvent();
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
      final entry = _buildEntry(
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
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    },
  );

  group('pendingAttachment classification', () {
    test(
      'prepare throwing the "attachment descriptor not yet available" '
      'FileSystemException maps to pendingAttachment so the queue '
      'backs off on the human-scale ladder instead of the sub-second '
      'retriable curve',
      () async {
        final entry = _buildEntry(
          eventId: r'$waitsForDescriptor',
          roomId: '!r',
          originTsMs: 1,
        );
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenThrow(
          const FileSystemException('attachment descriptor not yet available'),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.pendingAttachment);
      },
    );

    test(
      'prepare throwing PathNotFoundException inside /audio/ maps to '
      'pendingAttachment — the standard signature for a sync event '
      'that arrived before its attachment JSON landed on disk',
      () async {
        final entry = _buildEntry(
          eventId: r'$audioRace',
          roomId: '!r',
          originTsMs: 1,
        );
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenThrow(
          const PathNotFoundException(
            '/Users/test/Documents/audio/2026-04-21/foo.m4a.json',
            OSError('No such file or directory', 2),
          ),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.pendingAttachment);
      },
    );

    test(
      'prepare throwing PathNotFoundException inside /agent_entities/ '
      'also maps to pendingAttachment so agent-entity payload races '
      'share the same long-ladder retry path',
      () async {
        final entry = _buildEntry(
          eventId: r'$agentRace',
          roomId: '!r',
          originTsMs: 1,
        );
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenThrow(
          const PathNotFoundException(
            '/Users/test/Documents/agent_entities/abc.json',
            OSError('No such file or directory', 2),
          ),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.pendingAttachment);
      },
    );

    test(
      'an unrelated FileSystemException (path outside attachment '
      'directories) stays retriable, not pendingAttachment — the '
      'classification must not accidentally promote every IO '
      'failure to the long retry ladder',
      () async {
        final entry = _buildEntry(
          eventId: r'$genericIo',
          roomId: '!r',
          originTsMs: 1,
        );
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenThrow(
          const FileSystemException(
            'unrelated disk error',
            '/tmp/something-else.log',
          ),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.retriable);
      },
    );

    test(
      'apply-step throwing "attachment descriptor not yet available" '
      'also maps to pendingAttachment so the decoded payload still '
      'waits for its JSON on the long ladder',
      () async {
        final entry = _buildEntry(
          eventId: r'$applyWaitsForDescriptor',
          roomId: '!r',
          originTsMs: 1,
        );
        final prepared = _MockPreparedSyncEvent();
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenAnswer((_) async => prepared);
        when(
          () => processor.apply(
            prepared: prepared,
            journalDb: journalDb,
          ),
        ).thenThrow(
          const FileSystemException('attachment descriptor not yet available'),
        );

        final outcome = await build().bind()(entry, room);
        expect(outcome, ApplyOutcome.pendingAttachment);
      },
    );
  });

  group('batch-parallel prepare', () {
    test(
      'prepareBatch fans prepare out via Future.wait so the slowest '
      'entry — not the sum of all prepares — is the batch critical '
      'path',
      () async {
        final a = _buildEntry(eventId: r'$a', roomId: '!r:x', originTsMs: 1);
        final b = _buildEntry(eventId: r'$b', roomId: '!r:x', originTsMs: 2);
        final c = _buildEntry(eventId: r'$c', roomId: '!r:x', originTsMs: 3);

        // Each prepare call holds open for 100 ms. Sequential prepare
        // would take ~300 ms; parallel prepare caps at ~100 ms plus
        // tiny scheduling overhead.
        final prepared = _MockPreparedSyncEvent();
        when(() => processor.prepare(event: any(named: 'event'))).thenAnswer((
          _,
        ) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return prepared;
        });

        final adapter = build();
        final stopwatch = Stopwatch()..start();
        await adapter.bindPrepareBatch()([a, b, c], room);
        stopwatch.stop();

        // 200 ms window leaves plenty of headroom for CI jitter but
        // still fails decisively if prepare went sequential (≥300 ms).
        expect(
          stopwatch.elapsed,
          lessThan(const Duration(milliseconds: 200)),
          reason:
              'prepare ran sequentially (${stopwatch.elapsedMilliseconds}ms)',
        );
        verify(() => processor.prepare(event: any(named: 'event'))).called(3);
      },
    );

    test(
      'apply consumes the cached prepared payload so prepare runs '
      'exactly once when the caller invoked prepareBatch first',
      () async {
        final entry = _buildEntry(
          eventId: r'$cached',
          roomId: '!r:x',
          originTsMs: 1,
        );

        final prepared = _MockPreparedSyncEvent();
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenAnswer((_) async => prepared);
        when(
          () => processor.apply(prepared: prepared, journalDb: journalDb),
        ).thenAnswer((_) async => null);

        final adapter = build();
        await adapter.bindPrepareBatch()([entry], room);
        final outcome = await adapter.bind()(entry, room);

        expect(outcome, ApplyOutcome.applied);
        // Exactly one prepare: batched ahead of time. No inline
        // re-prepare in the apply phase.
        verify(() => processor.prepare(event: any(named: 'event'))).called(1);
        verify(
          () => processor.apply(
            prepared: prepared,
            journalDb: journalDb,
          ),
        ).called(1);
      },
    );

    test(
      'apply falls back to inline prepare when the cached entry is '
      'missing — a prepareBatch that skipped an eventId must not '
      'silently drop its apply',
      () async {
        final batched = _buildEntry(
          eventId: r'$batched',
          roomId: '!r:x',
          originTsMs: 1,
        );
        final late = _buildEntry(
          eventId: r'$late',
          roomId: '!r:x',
          originTsMs: 2,
        );

        final prepared = _MockPreparedSyncEvent();
        when(
          () => processor.prepare(event: any(named: 'event')),
        ).thenAnswer((_) async => prepared);
        when(
          () => processor.apply(prepared: prepared, journalDb: journalDb),
        ).thenAnswer((_) async => null);

        final adapter = build();
        // prepareBatch only covers `batched` — `late` has no cache
        // entry when apply runs.
        await adapter.bindPrepareBatch()([batched], room);

        final first = await adapter.bind()(batched, room);
        final second = await adapter.bind()(late, room);
        expect(first, ApplyOutcome.applied);
        expect(second, ApplyOutcome.applied);

        // Two prepare calls total: one batched, one inline fallback.
        verify(() => processor.prepare(event: any(named: 'event'))).called(2);
      },
    );

    test(
      'a cached terminal outcome from prepareBatch is surfaced by '
      'apply without re-preparing — e.g. pendingAttachment caught at '
      'prepare time must not trigger a second prepare during apply',
      () async {
        final entry = _buildEntry(
          eventId: r'$pending',
          roomId: '!r:x',
          originTsMs: 1,
        );

        // Prepare throws the sentinel FileSystemException that the
        // adapter classifies as pendingAttachment.
        when(() => processor.prepare(event: any(named: 'event'))).thenThrow(
          const FileSystemException('attachment descriptor not yet available'),
        );

        final adapter = build();
        await adapter.bindPrepareBatch()([entry], room);
        final outcome = await adapter.bind()(entry, room);

        expect(outcome, ApplyOutcome.pendingAttachment);
        // Exactly one prepare: the batched one. Apply consumed the
        // cached terminal outcome instead of re-trying. No apply was
        // ever attempted — the stubbed `processor.apply` was never
        // configured, so calling it would have thrown.
        verify(() => processor.prepare(event: any(named: 'event'))).called(1);
      },
    );

    test(
      'prepareBatch with an empty entry list is a no-op — safe for '
      'a worker that happens to peek an empty batch',
      () async {
        await build().bindPrepareBatch()(const [], room);
        verifyNever(() => processor.prepare(event: any(named: 'event')));
      },
    );
  });

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
        final entry = _buildEntry(
          eventId: r'$bypass-wrap',
          roomId: '!r',
          originTsMs: 1,
        );
        final prepared = _MockPreparedSyncEvent();
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
        final entry = _buildEntry(
          eventId: r'$throws',
          roomId: '!r',
          originTsMs: 1,
        );
        final prepared = _MockPreparedSyncEvent();
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
