import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockJournalDb extends Mock implements JournalDb {}

class _MockSettingsDb extends Mock implements SettingsDb {}

class _MockEventProcessor extends Mock implements SyncEventProcessor {}

class _MockReadMarkerService extends Mock implements SyncReadMarkerService {}

class _MockSentEventRegistry extends Mock implements SentEventRegistry {}

class _MockClient extends Mock implements Client {}

class _MockTimeline extends Mock implements Timeline {}

void main() {
  setUpAll(() {
    registerFallbackValue(_MockEvent());
    registerFallbackValue(_MockJournalDb());
    registerFallbackValue(
      PreparedSyncEvent.forTesting(
        event: _MockEvent(),
        syncMessage: const SyncMessage.aiConfigDelete(id: 'fallback'),
      ),
    );
  });

  late _MockRoomManager roomManager;
  late LoggingService loggingService;
  late _MockJournalDb journalDb;
  late _MockSettingsDb settingsDb;
  late _MockEventProcessor eventProcessor;
  late _MockReadMarkerService readMarkerService;
  late _MockSentEventRegistry sentEventRegistry;
  late _MockClient client;
  late MetricsCounters metrics;

  setUp(() {
    roomManager = _MockRoomManager();
    loggingService = LoggingService();
    journalDb = _MockJournalDb();
    settingsDb = _MockSettingsDb();
    eventProcessor = _MockEventProcessor();
    readMarkerService = _MockReadMarkerService();
    sentEventRegistry = _MockSentEventRegistry();
    client = _MockClient();
    metrics = MetricsCounters(collect: true);
  });

  MatrixStreamProcessor createProcessor({
    bool collectMetrics = true,
  }) {
    return MatrixStreamProcessor(
      roomManager: roomManager,
      loggingService: loggingService,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: eventProcessor,
      readMarkerService: readMarkerService,
      sentEventRegistry: sentEventRegistry,
      clientProvider: () => client,
      liveTimelineProvider: _MockTimeline.new,
      metricsCounters: metrics,
      collectMetrics: collectMetrics,
    );
  }

  group('MatrixStreamProcessor', () {
    test('can be constructed', () {
      final processor = createProcessor();

      expect(processor, isNotNull);
    });

    test('initial state has null lastProcessedEventId', () {
      final processor = createProcessor();

      expect(processor.lastProcessedEventId, isNull);
    });

    test('initial state has null lastProcessedTs', () {
      final processor = createProcessor();

      expect(processor.lastProcessedTs, isNull);
    });

    test('setLastProcessed updates eventId and timestamp', () {
      final processor = createProcessor()
        ..setLastProcessed(eventId: r'$event1', timestamp: 1000);

      expect(processor.lastProcessedEventId, r'$event1');
      expect(processor.lastProcessedTs, 1000);
    });

    test('wasCompletedSync returns false for unknown id', () {
      final processor = createProcessor();

      expect(processor.wasCompletedSync(r'$unknown'), isFalse);
    });

    test('debugCollectMetrics reflects constructor parameter', () {
      final withMetrics = createProcessor();
      expect(withMetrics.debugCollectMetrics, isTrue);

      final withoutMetrics = createProcessor(collectMetrics: false);
      expect(withoutMetrics.debugCollectMetrics, isFalse);
    });

    test('metrics getter returns MetricsCounters', () {
      final processor = createProcessor();

      expect(processor.metrics, metrics);
    });

    test('metricsSnapshot returns a map', () {
      final processor = createProcessor();
      final snapshot = processor.metricsSnapshot();

      expect(snapshot, isA<Map<String, int>>());
    });

    test('diagnosticsStrings returns map with lastIgnoredCount', () {
      final processor = createProcessor();
      final diag = processor.diagnosticsStrings();

      expect(diag, containsPair('lastIgnoredCount', '0'));
    });

    test('recordConnectivitySignal increments metric', () {
      createProcessor().recordConnectivitySignal();

      expect(metrics.signalConnectivity, 1);
    });

    test('dispose completes without error', () {
      expect(createProcessor().dispose, returnsNormally);
    });

    group('processOrdered', () {
      test('returns early when room is null', () async {
        when(() => roomManager.currentRoom).thenReturn(null);

        final processor = createProcessor();
        final event = _createMockSyncEvent(r'$ev1', 1000);

        // Should complete without error
        await processor.processOrdered([event]);

        // Verify that no processing was attempted.
        verifyNever(() => sentEventRegistry.prune());
      });

      test('returns early for empty list', () async {
        final mockRoom = _MockRoom();
        when(() => roomManager.currentRoom).thenReturn(mockRoom);

        final processor = createProcessor();

        await processor.processOrdered([]);
      });

      test(
        'freeze fix: prepare completes outside the transaction so I/O does '
        'not hold the writer lock',
        () async {
          // P1a regression guard. Before the prepare/apply split, the per-
          // event apply loop awaited network downloads, gzip decodes, and
          // disk reads inside `JournalDb.transaction`. That holds the
          // SQLite writer lock across the full I/O round-trip and blocks
          // user-driven saves — the visible desktop freeze this branch
          // targets.
          //
          // The test stubs `prepare` to await a completer (representing
          // slow attachment I/O) and asserts that the first
          // `journalDb.transaction` call is deferred until *after* prepare
          // has completed for every event in the slice. Apply is stubbed
          // to complete instantly so any future regression that pushes
          // I/O back inside the transaction shows up here.

          final mockRoom = _MockRoom();
          when(() => roomManager.currentRoom).thenReturn(mockRoom);
          when(sentEventRegistry.prune).thenReturn(null);
          when(
            () => sentEventRegistry.consume(any<String>()),
          ).thenReturn(false);
          when(
            () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
          ).thenAnswer((_) async => 1);

          final order = <String>[];
          final prepareGates = <Completer<void>>[
            Completer<void>(),
            Completer<void>(),
            Completer<void>(),
          ];
          var prepareCallIndex = 0;

          when(
            () => eventProcessor.prepare(event: any<Event>(named: 'event')),
          ).thenAnswer((invocation) async {
            final idx = prepareCallIndex++;
            order.add('prepare.begin#$idx');
            await prepareGates[idx].future;
            order.add('prepare.end#$idx');
            final ev = invocation.namedArguments[#event] as Event;
            return PreparedSyncEvent.forTesting(
              event: ev,
              syncMessage: const SyncMessage.aiConfigDelete(id: 'stub'),
            );
          });
          when(
            () => eventProcessor.apply(
              prepared: any<PreparedSyncEvent>(named: 'prepared'),
              journalDb: any<JournalDb>(named: 'journalDb'),
            ),
          ).thenAnswer((_) async {
            order.add('apply');
            return null;
          });
          when(
            () => journalDb.transaction<Null>(any<Future<Null> Function()>()),
          ).thenAnswer((invocation) async {
            order.add('txn.begin');
            final action =
                invocation.positionalArguments.first as Future<void> Function();
            await action();
            order.add('txn.end');
          });

          final events = List<Event>.generate(
            3,
            (i) => _createMockSyncEvent(
              r'$fz'
              '${i + 1}',
              2000 + i,
              content: <String, dynamic>{'msgtype': syncMessageType},
            ),
          );

          final processor = createProcessor();
          final future = processor.processOrdered(events);

          // Pump so the pre-pass can start. Prepares may run concurrently
          // (bounded concurrency), but the transaction MUST NOT have opened
          // yet — if it had, the writer lock would be held across our "I/O".
          await Future<void>.delayed(Duration.zero);
          expect(
            order.any((e) => e.startsWith('prepare.begin')),
            isTrue,
            reason: 'at least one prepare must start during the pre-pass',
          );
          expect(
            order.any((e) => e.startsWith('txn.')),
            isFalse,
            reason:
                'transaction must not open while any prepare is still in '
                'flight; otherwise the writer lock holds across I/O',
          );

          for (final gate in prepareGates) {
            gate.complete();
            await Future<void>.delayed(Duration.zero);
          }
          await future;

          // Full order must have every prepare.end before txn.begin so no
          // I/O ever runs with the writer lock held.
          final txnBegin = order.indexOf('txn.begin');
          expect(
            txnBegin,
            isPositive,
            reason: 'transaction must eventually open',
          );
          final lastPrepareEnd = order.lastIndexWhere(
            (e) => e.startsWith('prepare.end'),
          );
          expect(
            lastPrepareEnd,
            lessThan(txnBegin),
            reason:
                'every prepare.end must occur before txn.begin so no I/O '
                'runs with the writer lock held',
          );
          expect(
            order.where((e) => e == 'apply').length,
            events.length,
            reason: 'each prepared event must be applied',
          );
        },
      );

      test(
        'coalesces per-event writes into a single journalDb transaction',
        () async {
          final txn = _stubCommonProcessOrdered(
            roomManager: roomManager,
            sentEventRegistry: sentEventRegistry,
            settingsDb: settingsDb,
            journalDb: journalDb,
            eventProcessor: eventProcessor,
          );

          final events = List<Event>.generate(
            5,
            (i) => _createMockSyncEvent(
              r'$ev'
              '${i + 1}',
              1000 + i,
              content: <String, dynamic>{'msgtype': syncMessageType},
            ),
          );

          final processor = createProcessor();
          await processor.processOrdered(events);

          expect(
            txn.transactionInvocations,
            1,
            reason: 'slice must commit via a single journalDb transaction',
          );
          expect(
            txn.processCallsInsideTransaction,
            events.length,
            reason: 'every per-event apply must run inside the transaction',
          );
          expect(txn.processCallsOutsideTransaction, 0);
        },
      );

      test(
        'defers _recordCompletedSync until after transaction commits',
        () async {
          final processor = createProcessor();
          var wasCompletedInsideTxn = false;

          final txn = _stubCommonProcessOrdered(
            roomManager: roomManager,
            sentEventRegistry: sentEventRegistry,
            settingsDb: settingsDb,
            journalDb: journalDb,
            eventProcessor: eventProcessor,
            onBeforeCommit: () {
              wasCompletedInsideTxn |= processor.wasCompletedSync(r'$ev1');
            },
          );

          final event = _createMockSyncEvent(
            r'$ev1',
            1000,
            content: <String, dynamic>{'msgtype': syncMessageType},
          );
          await processor.processOrdered([event]);

          expect(txn.transactionInvocations, 1);
          expect(
            wasCompletedInsideTxn,
            isFalse,
            reason: 'completion must not be recorded inside the transaction',
          );
          expect(
            processor.wasCompletedSync(r'$ev1'),
            isTrue,
            reason: 'completion must be recorded after a successful commit',
          );
        },
      );

      test(
        'does not record completion when the transaction throws',
        () async {
          final mockRoom = _MockRoom();
          when(() => roomManager.currentRoom).thenReturn(mockRoom);
          when(sentEventRegistry.prune).thenReturn(null);
          when(
            () => sentEventRegistry.consume(any<String>()),
          ).thenReturn(false);
          when(
            () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
          ).thenAnswer((_) async => 1);
          _stubPrepareApplyPassthrough(eventProcessor);
          when(
            () => eventProcessor.process(
              event: any<Event>(named: 'event'),
              journalDb: any<JournalDb>(named: 'journalDb'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => journalDb.transaction<Null>(any<Future<Null> Function()>()),
          ).thenAnswer((invocation) async {
            final action =
                invocation.positionalArguments.first as Future<void> Function();
            await action();
            // Simulate commit failure after the callback ran. The whole slice
            // rolls back, so any in-memory flags we set inside the callback
            // must NOT be applied to long-lived processor state.
            throw StateError('simulated commit failure');
          });

          final processor = createProcessor();
          final event = _createMockSyncEvent(
            r'$ev1',
            1000,
            content: <String, dynamic>{'msgtype': syncMessageType},
          );

          await expectLater(
            () => processor.processOrdered([event]),
            throwsA(isA<StateError>()),
          );

          expect(
            processor.wasCompletedSync(r'$ev1'),
            isFalse,
            reason:
                'a rolled-back slice must not leave events flagged as completed',
          );
        },
      );

      test(
        'processes valid no-msgtype fallback sync events in the transaction',
        () async {
          final txn = _stubCommonProcessOrdered(
            roomManager: roomManager,
            sentEventRegistry: sentEventRegistry,
            settingsDb: settingsDb,
            journalDb: journalDb,
            eventProcessor: eventProcessor,
          );

          // Base64 of {"runtimeType":"journalEntity"} — classifies as a Lotti
          // sync payload via runtimeType presence, without the `msgtype`
          // header that the primary path keys off.
          const fallbackBody = 'eyJydW50aW1lVHlwZSI6ImpvdXJuYWxFbnRpdHkifQ==';
          final event = _createMockSyncEvent(
            r'$fallbackEv',
            2000,
            content: <String, dynamic>{'body': fallbackBody},
          );

          final processor = createProcessor();
          await processor.processOrdered([event]);

          expect(
            txn.transactionInvocations,
            1,
            reason: 'fallback path must still apply inside a transaction',
          );
          expect(
            txn.processCallsInsideTransaction,
            1,
            reason: 'fallback sync payload must be handed to the processor',
          );
          expect(
            processor.wasCompletedSync(r'$fallbackEv'),
            isTrue,
            reason: 'fallback completion must be recorded after commit',
          );
        },
      );

      test(
        'skips events already flagged as completed by an earlier pass',
        () async {
          final txn = _stubCommonProcessOrdered(
            roomManager: roomManager,
            sentEventRegistry: sentEventRegistry,
            settingsDb: settingsDb,
            journalDb: journalDb,
            eventProcessor: eventProcessor,
          );

          final processor = createProcessor();
          final event = _createMockSyncEvent(
            r'$repeatEv',
            3000,
            content: <String, dynamic>{'msgtype': syncMessageType},
          );

          // First pass records completion after commit.
          await processor.processOrdered([event]);
          expect(processor.wasCompletedSync(r'$repeatEv'), isTrue);
          expect(txn.processCallsInsideTransaction, 1);

          // Second pass must short-circuit — no new process() call, and the
          // skip path must increment its own counter (verified indirectly via
          // the non-increasing processor call count).
          await processor.processOrdered([event]);
          expect(
            txn.processCallsInsideTransaction,
            1,
            reason: 'completed events must not be handed to the processor',
          );
          expect(
            txn.transactionInvocations,
            2,
            reason: 'the slice still opens a transaction to flush side-effects',
          );
        },
      );

      test(
        'commits slices larger than processOrderedChunkSize as multiple '
        'chunks so the writer lock releases between them',
        () async {
          // processOrderedChunkSize = 20; drive 45 events to force 3 chunks
          // (20 + 20 + 5). The test mainly asserts chunk count because that
          // drives the write-lock-release behaviour end users feel as
          // "entry saving works during catch-up".
          final txn = _stubCommonProcessOrdered(
            roomManager: roomManager,
            sentEventRegistry: sentEventRegistry,
            settingsDb: settingsDb,
            journalDb: journalDb,
            eventProcessor: eventProcessor,
          );

          const total = 45;
          final events = List<Event>.generate(
            total,
            (i) => _createMockSyncEvent(
              r'$chunkEv'
              '${i + 1}',
              1000 + i,
              content: <String, dynamic>{'msgtype': syncMessageType},
            ),
          );

          final processor = createProcessor();
          await processor.processOrdered(events);

          expect(
            txn.transactionInvocations,
            3,
            reason:
                '45 events must commit in 3 chunks (20 + 20 + 5) so user '
                'writes can interleave between chunks',
          );
          expect(
            txn.processCallsInsideTransaction,
            total,
            reason: 'every per-event apply must run inside some chunk txn',
          );
          expect(
            txn.processCallsOutsideTransaction,
            0,
            reason: 'no apply may fall outside a transaction',
          );
          // Completion bookkeeping must cover every event across chunks,
          // not just the last chunk. This guards against a regression where
          // completedSyncIds is scoped per-chunk without being merged across.
          for (var i = 1; i <= total; i++) {
            expect(
              processor.wasCompletedSync('\$chunkEv$i'),
              isTrue,
              reason: 'event $i must be marked completed after its chunk',
            );
          }
        },
      );

      test(
        'records chunk completion progressively so an error on a later '
        'chunk does not discard earlier chunks',
        () async {
          // processOrderedChunkSize = 20. If we let chunk 1 commit and fail
          // chunk 2, the events from chunk 1 must stay flagged as completed
          // (their DB writes are already durable), while chunk-2 events must
          // stay un-flagged so a retry path can re-apply them.
          final mockRoom = _MockRoom();
          when(() => roomManager.currentRoom).thenReturn(mockRoom);
          when(sentEventRegistry.prune).thenReturn(null);
          when(
            () => sentEventRegistry.consume(any<String>()),
          ).thenReturn(false);
          when(
            () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
          ).thenAnswer((_) async => 1);
          _stubPrepareApplyPassthrough(eventProcessor);
          when(
            () => eventProcessor.process(
              event: any<Event>(named: 'event'),
              journalDb: any<JournalDb>(named: 'journalDb'),
            ),
          ).thenAnswer((_) async {});

          var txnCalls = 0;
          when(
            () => journalDb.transaction<Null>(any<Future<Null> Function()>()),
          ).thenAnswer((invocation) async {
            txnCalls += 1;
            final action =
                invocation.positionalArguments.first as Future<void> Function();
            await action();
            // Second chunk's commit throws; the processor must propagate.
            if (txnCalls == 2) {
              throw StateError('simulated commit failure on chunk 2');
            }
          });

          final processor = createProcessor();
          final events = List<Event>.generate(
            30,
            (i) => _createMockSyncEvent(
              r'$progEv'
              '${i + 1}',
              2000 + i,
              content: <String, dynamic>{'msgtype': syncMessageType},
            ),
          );

          await expectLater(
            () => processor.processOrdered(events),
            throwsA(isA<StateError>()),
          );

          expect(txnCalls, 2, reason: 'must reach the failing chunk');

          // Chunk 1 (events 1..20) committed successfully and must be
          // marked completed.
          for (var i = 1; i <= 20; i++) {
            expect(
              processor.wasCompletedSync('\$progEv$i'),
              isTrue,
              reason: 'chunk-1 event $i must be durable after its commit',
            );
          }
          // Chunk 2 (events 21..30) rolled back; they must NOT be marked
          // completed, otherwise the retry path would skip them.
          for (var i = 21; i <= 30; i++) {
            expect(
              processor.wasCompletedSync('\$progEv$i'),
              isFalse,
              reason:
                  'rolled-back chunk event $i must stay un-flagged so retry '
                  'can re-apply',
            );
          }
        },
      );

      test(
        'suppresses events the registry marks as our own sends',
        () async {
          final mockRoom = _MockRoom();
          when(() => roomManager.currentRoom).thenReturn(mockRoom);
          when(sentEventRegistry.prune).thenReturn(null);
          when(
            () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
          ).thenAnswer((_) async => 1);
          // This eventId is flagged as something we sent ourselves.
          when(
            () => sentEventRegistry.consume(r'$selfEv'),
          ).thenReturn(true);
          when(
            () => journalDb.transaction<Null>(any<Future<Null> Function()>()),
          ).thenAnswer((invocation) async {
            final action =
                invocation.positionalArguments.first as Future<void> Function();
            await action();
          });

          _stubPrepareApplyPassthrough(eventProcessor);
          var processCalls = 0;
          when(
            () => eventProcessor.process(
              event: any<Event>(named: 'event'),
              journalDb: any<JournalDb>(named: 'journalDb'),
            ),
          ).thenAnswer((_) async {
            processCalls += 1;
          });
          when(
            () => eventProcessor.apply(
              prepared: any<PreparedSyncEvent>(named: 'prepared'),
              journalDb: any<JournalDb>(named: 'journalDb'),
            ),
          ).thenAnswer((_) async {
            processCalls += 1;
            return null;
          });

          final processor = createProcessor();
          final event = _createMockSyncEvent(
            r'$selfEv',
            4000,
            content: <String, dynamic>{'msgtype': syncMessageType},
          );
          await processor.processOrdered([event]);

          expect(
            processCalls,
            0,
            reason: 'suppressed events must not be handed to the processor',
          );
          expect(
            processor.wasCompletedSync(r'$selfEv'),
            isTrue,
            reason:
                'suppressed events are still marked completed so that '
                'overlapping ingestion paths do not reprocess them',
          );
          expect(metrics.selfEventsSuppressed, 1);
        },
      );
    });

    group('retryNow', () {
      test('completes without error when retry tracker is empty', () async {
        final processor = createProcessor();

        await processor.retryNow();
      });
    });
  });
}

class _MockRoom extends Mock implements Room {}

class _StubbedTransaction {
  _StubbedTransaction();

  int transactionInvocations = 0;
  int processCallsInsideTransaction = 0;
  int processCallsOutsideTransaction = 0;

  /// `apply` is the new inside-transaction entry point after the
  /// prepare/apply split. Tests that used to check `processCallsInside…`
  /// should prefer `applyCallsInsideTransaction`.
  int applyCallsInsideTransaction = 0;
  int applyCallsOutsideTransaction = 0;

  int prepareCallsOutsideTransaction = 0;
  int prepareCallsInsideTransaction = 0;
}

/// Installs the common `processOrdered` stub set:
///
/// - `roomManager.currentRoom` returns a live room
/// - `sentEventRegistry.prune` / `.consume` are no-ops
/// - `settingsDb.saveSettingsItem` succeeds
/// - `journalDb.transaction` runs the callback and tracks inside/outside
///   status
/// - `eventProcessor.process` increments the inside/outside counters
///
/// Returns a handle whose counters tests can assert on. Optionally runs
/// [onBeforeCommit] after the callback body finishes but before the
/// transaction itself returns, to assert on transient in-transaction state.
_StubbedTransaction _stubCommonProcessOrdered({
  required _MockRoomManager roomManager,
  required _MockSentEventRegistry sentEventRegistry,
  required _MockSettingsDb settingsDb,
  required _MockJournalDb journalDb,
  required _MockEventProcessor eventProcessor,
  void Function()? onBeforeCommit,
}) {
  final handle = _StubbedTransaction();
  var insideTransaction = false;

  final mockRoom = _MockRoom();
  when(() => roomManager.currentRoom).thenReturn(mockRoom);
  when(sentEventRegistry.prune).thenReturn(null);
  when(() => sentEventRegistry.consume(any<String>())).thenReturn(false);
  when(
    () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
  ).thenAnswer((_) async => 1);

  // Dart infers `T = Null` for `transaction(() async { ... })` when the
  // closure has no explicit return — hence the `<Null>` stub here matches the
  // production invocation.
  when(
    () => journalDb.transaction<Null>(any<Future<Null> Function()>()),
  ).thenAnswer((invocation) async {
    handle.transactionInvocations += 1;
    final action =
        invocation.positionalArguments.first as Future<void> Function();
    insideTransaction = true;
    try {
      await action();
      onBeforeCommit?.call();
    } finally {
      insideTransaction = false;
    }
  });

  // Post prepare/apply split: the pipeline calls `prepare` OUTSIDE the
  // transaction and `apply` INSIDE it. Stubbing both lets tests assert the
  // transaction boundary on the method that actually holds the writer lock
  // (`apply`) while confirming that I/O (`prepare`) stays outside it.
  when(
    () => eventProcessor.prepare(event: any<Event>(named: 'event')),
  ).thenAnswer((invocation) async {
    if (insideTransaction) {
      handle.prepareCallsInsideTransaction += 1;
    } else {
      handle.prepareCallsOutsideTransaction += 1;
    }
    final event = invocation.namedArguments[#event] as Event;
    // A minimal SyncMessage is enough — `apply` is stubbed below so the
    // fake never dispatches on this value.
    return PreparedSyncEvent.forTesting(
      event: event,
      syncMessage: const SyncMessage.aiConfigDelete(id: 'stub'),
    );
  });

  when(
    () => eventProcessor.apply(
      prepared: any<PreparedSyncEvent>(named: 'prepared'),
      journalDb: any<JournalDb>(named: 'journalDb'),
    ),
  ).thenAnswer((_) async {
    if (insideTransaction) {
      handle
        ..applyCallsInsideTransaction += 1
        ..processCallsInsideTransaction += 1;
    } else {
      handle
        ..applyCallsOutsideTransaction += 1
        ..processCallsOutsideTransaction += 1;
    }
    return null;
  });

  // Keep the old `process` stub as a safety net for callers that still hit
  // the back-compat path (e.g. before/after the split is wired).
  when(
    () => eventProcessor.process(
      event: any<Event>(named: 'event'),
      journalDb: any<JournalDb>(named: 'journalDb'),
    ),
  ).thenAnswer((_) async {
    if (insideTransaction) {
      handle.processCallsInsideTransaction += 1;
    } else {
      handle.processCallsOutsideTransaction += 1;
    }
  });

  return handle;
}

/// Installs minimal pass-through stubs for `prepare` and `apply` on tests
/// that build their own ad-hoc transaction stub instead of using
/// [_stubCommonProcessOrdered]. Without these, the pipeline's pre-pass call
/// to `prepare` fails with a mocktail "no matching calls" error and the
/// event is shelved for retry instead of reaching the in-transaction apply.
void _stubPrepareApplyPassthrough(_MockEventProcessor eventProcessor) {
  when(
    () => eventProcessor.prepare(event: any<Event>(named: 'event')),
  ).thenAnswer((invocation) async {
    final event = invocation.namedArguments[#event] as Event;
    return PreparedSyncEvent.forTesting(
      event: event,
      syncMessage: const SyncMessage.aiConfigDelete(id: 'stub'),
    );
  });
  when(
    () => eventProcessor.apply(
      prepared: any<PreparedSyncEvent>(named: 'prepared'),
      journalDb: any<JournalDb>(named: 'journalDb'),
    ),
  ).thenAnswer((_) async => null);
}

Event _createMockSyncEvent(
  String eventId,
  int tsMs, {
  Map<String, dynamic>? content,
  String? text,
}) {
  final event = _MockEvent();
  when(() => event.eventId).thenReturn(eventId);
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(tsMs));
  final effectiveContent = content ?? <String, dynamic>{};
  when(() => event.content).thenReturn(effectiveContent);
  when(() => event.roomId).thenReturn('!room:server');
  when(() => event.type).thenReturn('m.room.message');
  when(() => event.senderId).thenReturn('@user:server');
  // Non-null by construction so the attachment classifier never blows up on a
  // plain sync payload mock. Tests that want an attachment set this via
  // [content].
  when(() => event.attachmentMimetype).thenReturn('');
  // `text` is used by the no-msgtype fallback classifier to detect sync
  // payloads via base64-encoded runtimeType; default to the body field when
  // present so tests can drive both paths from one factory.
  final bodyText =
      text ??
      (effectiveContent['body'] is String
          ? effectiveContent['body'] as String
          : '');
  when(() => event.text).thenReturn(bodyText);
  return event;
}

class _MockEvent extends Mock implements Event {}
