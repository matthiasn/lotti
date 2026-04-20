import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_catch_up.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_live_scan.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_signals.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart' as matrix_utils;
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockCatchUp extends Mock implements MatrixStreamCatchUpCoordinator {}

class _MockLiveScan extends Mock implements MatrixStreamLiveScanController {}

class _MockRoom extends Mock implements Room {}

class _MockTimeline extends Mock implements Timeline {}

class _MockClient extends Mock implements Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late _MockSessionManager sessionManager;
  late _MockRoomManager roomManager;
  late MockLoggingService loggingService;
  late MetricsCounters metrics;
  late _MockCatchUp catchUp;
  late _MockLiveScan liveScan;
  late MatrixStreamSignalBinder binder;
  late _MockClient client;
  late matrix_utils.CachedStreamController<SyncUpdate> onSyncController;

  setUp(() {
    sessionManager = _MockSessionManager();
    roomManager = _MockRoomManager();
    loggingService = MockLoggingService();
    stubLoggingService(loggingService);
    metrics = MetricsCounters(collect: true);
    catchUp = _MockCatchUp();
    liveScan = _MockLiveScan();
    client = _MockClient();
    onSyncController = matrix_utils.CachedStreamController<SyncUpdate>();
    when(() => sessionManager.client).thenReturn(client);
    when(() => client.onSync).thenReturn(onSyncController);

    binder = MatrixStreamSignalBinder(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: loggingService,
      metrics: metrics,
      collectMetrics: true,
      catchUpCoordinator: catchUp,
      liveScanController: liveScan,
      withInstance: (msg) => 'inst: $msg',
    );
  });

  tearDown(() async {
    await onSyncController.close();
  });

  group('MatrixStreamSignalBinder', () {
    test('can be constructed', () {
      expect(binder, isNotNull);
    });

    group('start', () {
      test('subscribes to timeline events filtered by room', () async {
        final controller = StreamController<Event>.broadcast();
        addTearDown(controller.close);

        when(
          () => sessionManager.timelineEvents,
        ).thenAnswer((_) => controller.stream);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => roomManager.currentRoom).thenReturn(null);
        when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
        when(() => catchUp.handleClientStreamSignal()).thenReturn(false);
        when(() => liveScan.scheduleLiveScan()).thenReturn(null);

        await binder.start(lastProcessedEventId: null);

        // Emit an event for the wrong room
        final wrongRoomEvent = _createMockEvent('!other:room');
        controller.add(wrongRoomEvent);

        // Give stream time to process
        await Future<void>.delayed(Duration.zero);

        // Should not trigger any processing for wrong room
        verifyNever(() => catchUp.handleFirstStreamEvent());
      });

      test('delegates to catch-up when signal returns true', () async {
        final controller = StreamController<Event>.broadcast();
        addTearDown(controller.close);

        when(
          () => sessionManager.timelineEvents,
        ).thenAnswer((_) => controller.stream);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => roomManager.currentRoom).thenReturn(null);
        when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
        when(() => catchUp.handleClientStreamSignal()).thenReturn(true);
        when(() => liveScan.scheduleLiveScan()).thenReturn(null);

        await binder.start(lastProcessedEventId: null);

        final event = _createMockEvent('!room:server');
        controller.add(event);
        await Future<void>.delayed(Duration.zero);

        verify(() => catchUp.handleFirstStreamEvent()).called(1);
        verify(() => catchUp.handleClientStreamSignal()).called(1);
        // When catch-up handles the signal, live scan should NOT be called
        verifyNever(() => liveScan.scheduleLiveScan());
      });
    });

    group('start.catchUpRetry', () {
      test(
        'schedules the 150ms follow-up when a marker exists and initial '
        'catch-up has not converged',
        () async {
          fakeAsync((async) {
            final controller = StreamController<Event>.broadcast();
            addTearDown(controller.close);

            final room = _MockRoom();
            final timeline = _MockTimeline();
            when(
              () => sessionManager.timelineEvents,
            ).thenAnswer((_) => controller.stream);
            when(() => roomManager.currentRoomId).thenReturn('!room:s');
            when(() => roomManager.currentRoom).thenReturn(room);
            when(
              () => room.getTimeline(
                onNewEvent: any<void Function()?>(named: 'onNewEvent'),
                onInsert: any<void Function(int)?>(named: 'onInsert'),
                onChange: any<void Function(int)?>(named: 'onChange'),
                onRemove: any<void Function(int)?>(named: 'onRemove'),
                onUpdate: any<void Function()?>(named: 'onUpdate'),
              ),
            ).thenAnswer((_) async => timeline);
            when(timeline.cancelSubscriptions).thenAnswer((_) {});
            when(
              () => liveScan.scheduleRescan(any<Duration>()),
            ).thenReturn(null);
            // Initial catch-up has not converged when start() runs AND when
            // the 150ms timer fires; the retry must run.
            when(() => catchUp.initialCatchUpReady).thenReturn(false);
            when(
              () => catchUp.runGuardedCatchUp(any<String>()),
            ).thenAnswer((_) async {});

            unawaited(binder.start(lastProcessedEventId: r'$marker'));
            async
              ..flushMicrotasks()
              ..elapse(const Duration(milliseconds: 200))
              ..flushMicrotasks();

            verify(
              () => catchUp.runGuardedCatchUp('start.catchUpRetry'),
            ).called(1);

            unawaited(binder.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'does not schedule the retry at all when initial catch-up is '
        'already ready at start() time',
        () async {
          fakeAsync((async) {
            final controller = StreamController<Event>.broadcast();
            addTearDown(controller.close);

            final room = _MockRoom();
            final timeline = _MockTimeline();
            when(
              () => sessionManager.timelineEvents,
            ).thenAnswer((_) => controller.stream);
            when(() => roomManager.currentRoomId).thenReturn('!room:s');
            when(() => roomManager.currentRoom).thenReturn(room);
            when(
              () => room.getTimeline(
                onNewEvent: any<void Function()?>(named: 'onNewEvent'),
                onInsert: any<void Function(int)?>(named: 'onInsert'),
                onChange: any<void Function(int)?>(named: 'onChange'),
                onRemove: any<void Function(int)?>(named: 'onRemove'),
                onUpdate: any<void Function()?>(named: 'onUpdate'),
              ),
            ).thenAnswer((_) async => timeline);
            when(timeline.cancelSubscriptions).thenAnswer((_) {});
            when(
              () => liveScan.scheduleRescan(any<Duration>()),
            ).thenReturn(null);
            when(() => catchUp.initialCatchUpReady).thenReturn(true);

            unawaited(binder.start(lastProcessedEventId: r'$marker'));
            async
              ..flushMicrotasks()
              ..elapse(const Duration(milliseconds: 200))
              ..flushMicrotasks();

            verifyNever(() => catchUp.runGuardedCatchUp(any<String>()));

            unawaited(binder.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test(
        'inner guard skips the delayed runGuardedCatchUp when the initial '
        'catch-up converges during the 150ms window',
        () async {
          fakeAsync((async) {
            final controller = StreamController<Event>.broadcast();
            addTearDown(controller.close);

            final room = _MockRoom();
            final timeline = _MockTimeline();
            when(
              () => sessionManager.timelineEvents,
            ).thenAnswer((_) => controller.stream);
            when(() => roomManager.currentRoomId).thenReturn('!room:s');
            when(() => roomManager.currentRoom).thenReturn(room);
            when(
              () => room.getTimeline(
                onNewEvent: any<void Function()?>(named: 'onNewEvent'),
                onInsert: any<void Function(int)?>(named: 'onInsert'),
                onChange: any<void Function(int)?>(named: 'onChange'),
                onRemove: any<void Function(int)?>(named: 'onRemove'),
                onUpdate: any<void Function()?>(named: 'onUpdate'),
              ),
            ).thenAnswer((_) async => timeline);
            when(timeline.cancelSubscriptions).thenAnswer((_) {});
            when(
              () => liveScan.scheduleRescan(any<Duration>()),
            ).thenReturn(null);
            // Sequence: false at start() (schedules the 150ms retry) then
            // true when the delayed callback fires (inner guard bails).
            var readyCalls = 0;
            when(() => catchUp.initialCatchUpReady).thenAnswer((_) {
              readyCalls += 1;
              return readyCalls > 1;
            });

            unawaited(binder.start(lastProcessedEventId: r'$marker'));
            async
              ..flushMicrotasks()
              ..elapse(const Duration(milliseconds: 200))
              ..flushMicrotasks();

            // initialCatchUpReady is consulted once at scheduling time and
            // once inside the delayed callback; if either short-circuits,
            // runGuardedCatchUp must not fire.
            verifyNever(() => catchUp.runGuardedCatchUp(any<String>()));

            unawaited(binder.dispose());
            async.flushMicrotasks();
          });
        },
      );
    });

    test('dispose cancels subscription', () async {
      final controller = StreamController<Event>.broadcast();
      addTearDown(controller.close);

      when(
        () => sessionManager.timelineEvents,
      ).thenAnswer((_) => controller.stream);
      when(() => roomManager.currentRoomId).thenReturn('!room:s');
      when(() => roomManager.currentRoom).thenReturn(null);
      when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
      when(() => catchUp.handleClientStreamSignal()).thenReturn(true);

      await binder.start(lastProcessedEventId: null);
      await binder.dispose();

      // Emit after disposal and verify no binder callbacks are invoked
      controller.add(_createMockEvent('!room:s'));
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => catchUp.handleFirstStreamEvent());
    });

    group('Phase 0 diagnostics', () {
      const roomId = '!room:server';

      Future<void> startWithNoRoom() async {
        when(
          () => sessionManager.timelineEvents,
        ).thenAnswer((_) => const Stream<Event>.empty());
        when(() => roomManager.currentRoomId).thenReturn(roomId);
        when(() => roomManager.currentRoom).thenReturn(null);
        await binder.start(lastProcessedEventId: null);
      }

      SyncUpdate limitedSync({
        String forRoomId = roomId,
        String? prevBatch = 'pb-1',
        int eventCount = 0,
        bool? limited = true,
      }) {
        return SyncUpdate(
          nextBatch: 'nb',
          rooms: RoomsUpdate(
            join: {
              forRoomId: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  limited: limited,
                  prevBatch: prevBatch,
                  events: List<MatrixEvent>.generate(
                    eventCount,
                    (i) => MatrixEvent(
                      type: 'm.room.message',
                      eventId: '\$e$i',
                      senderId: '@u:s',
                      originServerTs: DateTime(2026, 4, 20),
                      roomId: forRoomId,
                      content: const <String, Object?>{},
                    ),
                  ),
                ),
              ),
            },
          ),
        );
      }

      test(
        'sync.limited: logs sinceMs=initial on first limited sync',
        () async {
          await startWithNoRoom();

          onSyncController.add(limitedSync(eventCount: 3));
          await Future<void>.delayed(Duration.zero);

          final captured = verify(
            () => loggingService.captureEvent(
              captureAny<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'sync.limited',
            ),
          ).captured;
          expect(captured, hasLength(1));
          final body = captured.single as String;
          expect(body, contains('roomId=$roomId'));
          expect(body, contains('prevBatch=pb-1'));
          expect(body, contains('eventCount=3'));
          expect(body, contains('sinceMs=initial'));
        },
      );

      test(
        'sync.limited: logs numeric sinceMs on subsequent limited sync',
        () async {
          await startWithNoRoom();

          // First emission: non-limited, advances _lastSyncAt.
          onSyncController.add(limitedSync(limited: false));
          await Future<void>.delayed(Duration.zero);
          // Second emission: limited.
          onSyncController.add(limitedSync());
          await Future<void>.delayed(Duration.zero);

          final captured = verify(
            () => loggingService.captureEvent(
              captureAny<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'sync.limited',
            ),
          ).captured;
          expect(captured, hasLength(1));
          final body = captured.single as String;
          expect(body, matches(RegExp(r'sinceMs=\d+')));
          expect(body, isNot(contains('sinceMs=initial')));
        },
      );

      test(
        'sync.limited: ignored when currentRoomId is null',
        () async {
          when(
            () => sessionManager.timelineEvents,
          ).thenAnswer((_) => const Stream<Event>.empty());
          when(() => roomManager.currentRoomId).thenReturn(null);
          when(() => roomManager.currentRoom).thenReturn(null);
          await binder.start(lastProcessedEventId: null);

          onSyncController.add(limitedSync());
          await Future<void>.delayed(Duration.zero);

          verifyNever(
            () => loggingService.captureEvent(
              any<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'sync.limited',
            ),
          );
        },
      );

      test(
        'sync.limited: ignored when update is for a different room',
        () async {
          await startWithNoRoom();

          onSyncController.add(limitedSync(forRoomId: '!other:server'));
          await Future<void>.delayed(Duration.zero);

          verifyNever(
            () => loggingService.captureEvent(
              any<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'sync.limited',
            ),
          );
        },
      );

      test(
        'sync.limited: ignored when timeline.limited is false',
        () async {
          await startWithNoRoom();

          onSyncController.add(limitedSync(limited: false));
          await Future<void>.delayed(Duration.zero);

          verifyNever(
            () => loggingService.captureEvent(
              any<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'sync.limited',
            ),
          );
        },
      );

      test(
        'sync.limited: stream errors route through captureException',
        () async {
          await startWithNoRoom();

          onSyncController.addError(StateError('boom'), StackTrace.current);
          await Future<void>.delayed(Duration.zero);

          verify(
            () => loggingService.captureException(
              any<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'sync.limited.stream',
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            ),
          ).called(1);
        },
      );

      test(
        'sync.limited: dispose cancels the onSync subscription',
        () async {
          await startWithNoRoom();
          await binder.dispose();

          onSyncController.add(limitedSync());
          await Future<void>.delayed(Duration.zero);

          verifyNever(
            () => loggingService.captureEvent(
              any<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'sync.limited',
            ),
          );
        },
      );

      test(
        'onTimelineEvent.ordering: emits summary every 100 events and resets',
        () async {
          final controller = StreamController<Event>.broadcast();
          addTearDown(controller.close);
          when(
            () => sessionManager.timelineEvents,
          ).thenAnswer((_) => controller.stream);
          when(() => roomManager.currentRoomId).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(null);
          when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
          when(() => catchUp.handleClientStreamSignal()).thenReturn(false);
          when(() => liveScan.scheduleLiveScan()).thenReturn(null);

          await binder.start(lastProcessedEventId: null);

          for (var i = 0; i < 100; i++) {
            controller.add(
              _createMockEvent(
                roomId,
                originServerTs: DateTime(2026, 4, 20).add(Duration(seconds: i)),
              ),
            );
          }
          await Future<void>.delayed(Duration.zero);

          final captured = verify(
            () => loggingService.captureEvent(
              captureAny<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'onTimelineEvent.ordering',
            ),
          ).captured;
          expect(captured, hasLength(1));
          expect(captured.single, contains('events=100'));
          expect(captured.single, contains('reorderings=0'));
          expect(captured.single, contains('sameTs=0'));

          // 99 more events → counters reset, no new summary until the 100th.
          for (var i = 0; i < 99; i++) {
            controller.add(
              _createMockEvent(
                roomId,
                originServerTs: DateTime(2026, 4, 21).add(Duration(seconds: i)),
              ),
            );
          }
          await Future<void>.delayed(Duration.zero);
          verifyNever(
            () => loggingService.captureEvent(
              any<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'onTimelineEvent.ordering',
            ),
          );
        },
      );

      test(
        'onTimelineEvent.ordering: counts strict reorderings and same-ts ties',
        () async {
          final controller = StreamController<Event>.broadcast();
          addTearDown(controller.close);
          when(
            () => sessionManager.timelineEvents,
          ).thenAnswer((_) => controller.stream);
          when(() => roomManager.currentRoomId).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(null);
          when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
          when(() => catchUp.handleClientStreamSignal()).thenReturn(false);
          when(() => liveScan.scheduleLiveScan()).thenReturn(null);

          await binder.start(lastProcessedEventId: null);

          // Construct 100 events: 95 ascending, then 3 same-ts as prev,
          // then 2 strict reorderings (older ts than prev).
          final base = DateTime(2026, 4, 20);
          final timestamps = <DateTime>[
            for (var i = 0; i < 95; i++) base.add(Duration(seconds: i)),
            base.add(const Duration(seconds: 94)),
            base.add(const Duration(seconds: 94)),
            base.add(const Duration(seconds: 94)),
            base.add(const Duration(seconds: 10)),
            base.add(const Duration(seconds: 5)),
          ];
          for (final ts in timestamps) {
            controller.add(_createMockEvent(roomId, originServerTs: ts));
          }
          await Future<void>.delayed(Duration.zero);

          final captured = verify(
            () => loggingService.captureEvent(
              captureAny<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'onTimelineEvent.ordering',
            ),
          ).captured;
          expect(captured, hasLength(1));
          expect(captured.single, contains('events=100'));
          expect(captured.single, contains('reorderings=2'));
          expect(captured.single, contains('sameTs=3'));
        },
      );

      test(
        'onTimelineEvent.ordering: does not advance on wrong-room events',
        () async {
          final controller = StreamController<Event>.broadcast();
          addTearDown(controller.close);
          when(
            () => sessionManager.timelineEvents,
          ).thenAnswer((_) => controller.stream);
          when(() => roomManager.currentRoomId).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(null);
          when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
          when(() => catchUp.handleClientStreamSignal()).thenReturn(false);
          when(() => liveScan.scheduleLiveScan()).thenReturn(null);

          await binder.start(lastProcessedEventId: null);

          // 100 events for the wrong room — all filtered before the ordering
          // tracker, so no summary should fire.
          for (var i = 0; i < 100; i++) {
            controller.add(
              _createMockEvent(
                '!other:server',
                originServerTs: DateTime(2026, 4, 20).add(Duration(seconds: i)),
              ),
            );
          }
          await Future<void>.delayed(Duration.zero);

          verifyNever(
            () => loggingService.captureEvent(
              any<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'onTimelineEvent.ordering',
            ),
          );
        },
      );

      test(
        'start(): resets ordering and sync-gap state between runs',
        () async {
          final controller = StreamController<Event>.broadcast();
          addTearDown(controller.close);
          when(
            () => sessionManager.timelineEvents,
          ).thenAnswer((_) => controller.stream);
          when(() => roomManager.currentRoomId).thenReturn(roomId);
          when(() => roomManager.currentRoom).thenReturn(null);
          when(() => catchUp.handleFirstStreamEvent()).thenReturn(false);
          when(() => catchUp.handleClientStreamSignal()).thenReturn(false);
          when(() => liveScan.scheduleLiveScan()).thenReturn(null);

          await binder.start(lastProcessedEventId: null);
          for (var i = 0; i < 50; i++) {
            controller.add(
              _createMockEvent(
                roomId,
                originServerTs: DateTime(2026, 4, 20).add(Duration(seconds: i)),
              ),
            );
          }
          // First non-limited sync establishes a prev timestamp that start()
          // must discard.
          onSyncController.add(limitedSync(limited: false));
          await Future<void>.delayed(Duration.zero);

          // Re-start: counters and _lastSyncAt reset.
          await binder.start(lastProcessedEventId: null);

          // 50 more timeline events — below the threshold; no summary.
          for (var i = 0; i < 50; i++) {
            controller.add(
              _createMockEvent(
                roomId,
                originServerTs: DateTime(2026, 4, 21).add(Duration(seconds: i)),
              ),
            );
          }
          // New limited sync — must log sinceMs=initial, not a number, since
          // _lastSyncAt was cleared by start().
          onSyncController.add(limitedSync());
          await Future<void>.delayed(Duration.zero);

          verifyNever(
            () => loggingService.captureEvent(
              any<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'onTimelineEvent.ordering',
            ),
          );
          final captured = verify(
            () => loggingService.captureEvent(
              captureAny<Object>(),
              domain: 'MATRIX_SYNC',
              subDomain: 'sync.limited',
            ),
          ).captured;
          expect(captured, hasLength(1));
          expect(captured.single, contains('sinceMs=initial'));
        },
      );
    });

    group('suppressLiveIngestion (Phase-2 queue pipeline active)', () {
      test(
        'does not subscribe to timelineEvents or schedule scans',
        () async {
          final suppressed = MatrixStreamSignalBinder(
            sessionManager: sessionManager,
            roomManager: roomManager,
            loggingService: loggingService,
            metrics: metrics,
            collectMetrics: true,
            catchUpCoordinator: catchUp,
            liveScanController: liveScan,
            withInstance: (msg) => 'inst: $msg',
            suppressLiveIngestion: true,
          );

          final controller = StreamController<Event>.broadcast();
          addTearDown(controller.close);
          when(
            () => sessionManager.timelineEvents,
          ).thenAnswer((_) => controller.stream);
          when(() => roomManager.currentRoomId).thenReturn('!room:server');
          when(() => roomManager.currentRoom).thenReturn(_MockRoom());

          expect(suppressed.suppressLiveIngestion, isTrue);
          await suppressed.start(lastProcessedEventId: r'$x');

          // Emit a live event — it must NOT reach scheduleLiveScan,
          // handleClientStreamSignal, or handleFirstStreamEvent because
          // the queue pipeline owns live ingestion in this mode.
          controller.add(_createMockEvent('!room:server'));
          await Future<void>.delayed(Duration.zero);

          verifyNever(() => liveScan.scheduleLiveScan());
          verifyNever(() => catchUp.handleClientStreamSignal());
          verifyNever(() => catchUp.handleFirstStreamEvent());
        },
      );

      test(
        'still attaches the onSync limited=true diagnostic (Phase-0)',
        () async {
          final suppressed = MatrixStreamSignalBinder(
            sessionManager: sessionManager,
            roomManager: roomManager,
            loggingService: loggingService,
            metrics: metrics,
            collectMetrics: true,
            catchUpCoordinator: catchUp,
            liveScanController: liveScan,
            withInstance: (msg) => 'inst: $msg',
            suppressLiveIngestion: true,
          );

          when(() => roomManager.currentRoomId).thenReturn('!room:server');
          when(
            () => sessionManager.timelineEvents,
          ).thenAnswer((_) => const Stream.empty());

          await suppressed.start(lastProcessedEventId: null);

          // Feed one limited=true sync — the diagnostic must still emit.
          final limited = SyncUpdate(
            nextBatch: 'next',
            rooms: RoomsUpdate(
              join: {
                '!room:server': JoinedRoomUpdate(
                  timeline: TimelineUpdate(
                    limited: true,
                    prevBatch: 'pb',
                    events: const <MatrixEvent>[],
                  ),
                ),
              },
            ),
          );
          onSyncController.add(limited);
          await Future<void>.delayed(Duration.zero);

          final limitedCalls = verify(
            () => loggingService.captureEvent(
              captureAny<String>(that: contains('sync.limited')),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
            ),
          ).captured;
          expect(limitedCalls, isNotEmpty);
        },
      );
    });
  });
}

Event _createMockEvent(String roomId, {DateTime? originServerTs}) {
  final event = _MockEvent();
  when(() => event.roomId).thenReturn(roomId);
  when(
    () => event.originServerTs,
  ).thenReturn(originServerTs ?? DateTime(2026, 4, 20));
  return event;
}

class _MockEvent extends Mock implements Event {}
