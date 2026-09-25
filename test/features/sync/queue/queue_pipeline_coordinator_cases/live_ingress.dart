part of '../queue_pipeline_coordinator_test.dart';

extension _LiveIngressCases on _QueueCoordinatorTestSetup {
  void registerLiveIngress() {
    test(
      'encrypted live event lowers the durable floor and is skipped',
      () async {
        final coordinator = build();
        await coordinator.start();

        timelineCtl.add(buildEvent(EventTypes.Encrypted));
        await pumpEventQueue();

        verifyNever(() => queue.enqueueLive(any()));
        verify(
          () => queue.lowerResumeFloor(roomId: roomId, originTs: 1234),
        ).called(1);
        await coordinator.stop();
      },
    );

    test(
      'plain live event enters the queue without lowering a floor',
      () async {
        final coordinator = build();
        await coordinator.start();
        verifyStartClaim();

        timelineCtl.add(buildEvent(EventTypes.Message));
        await pumpEventQueue();

        verify(() => queue.enqueueLive(any())).called(1);
        verifyNever(
          () => queue.lowerResumeFloor(
            roomId: any<String>(named: 'roomId'),
            originTs: any<int>(named: 'originTs'),
          ),
        );
        await coordinator.stop();
      },
    );

    test(
      'a room switch during attachment processing drops the old-room event',
      () async {
        final attachmentStarted = Completer<Event>();
        final releaseAttachment = Completer<void>();
        final ingestor = _FakeAttachmentIngestor(
          firstProcessed: attachmentStarted,
          processGate: releaseAttachment.future,
        );
        final coordinator = build(attachmentIngestor: ingestor);
        await coordinator.start();
        verifyStartClaim();
        final event = buildEvent(EventTypes.Message);

        timelineCtl.add(event);
        expect(await attachmentStarted.future, same(event));

        when(
          () => roomManager.currentRoomId,
        ).thenReturn('!replacement:example.org');
        await coordinator.onRoomChanged('!replacement:example.org');
        releaseAttachment.complete();
        await pumpEventQueue();

        verifyNever(() => queue.enqueueLive(any()));
        verifyNever(
          () => queue.lowerResumeFloor(
            roomId: any<String>(named: 'roomId'),
            originTs: any<int>(named: 'originTs'),
          ),
        );
        await coordinator.stop();
      },
    );

    test(
      'a live-handler error is logged without an uncaught cleanup future',
      () async {
        when(
          () => queue.lowerResumeFloor(
            roomId: roomId,
            originTs: 1234,
          ),
        ).thenThrow(StateError('floor write failed'));
        final uncaught = <Object>[];

        await runZonedGuarded(
          () async {
            final coordinator = build();
            await coordinator.start();
            timelineCtl.add(buildEvent(EventTypes.Encrypted));
            await pumpEventQueue();
            await coordinator.stop();
            await pumpEventQueue();
          },
          (error, _) => uncaught.add(error),
        );

        expect(uncaught, isEmpty);
        verify(
          () => logging.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any<String>(
              named: 'subDomain',
              that: endsWith('.liveSub'),
            ),
          ),
        ).called(1);
      },
    );

    test(
      'live event for a different room is ignored',
      () async {
        final coordinator = build();
        await coordinator.start();
        verifyStartClaim();

        final foreign = MockEvent();
        when(() => foreign.eventId).thenReturn(r'$other');
        when(() => foreign.roomId).thenReturn('!someOtherRoom:example.org');
        when(() => foreign.type).thenReturn(EventTypes.Message);
        timelineCtl.add(foreign);
        await pumpEventQueue();

        verifyNever(() => queue.enqueueLive(any()));
        verifyNever(
          () => queue.lowerResumeFloor(
            roomId: any<String>(named: 'roomId'),
            originTs: any<int>(named: 'originTs'),
          ),
        );
        await coordinator.stop();
      },
    );

    test(
      'self-echo suppression logs once per interval and resets the counter',
      () async {
        final bench = _GladosBench();
        addTearDown(bench.dispose);
        final logMessages = <String>[];
        when(
          () => bench.logging.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((invocation) {
          logMessages.add(invocation.positionalArguments[1] as String);
        });
        when(() => bench.roomManager.currentRoomId).thenReturn(roomId);
        when(
          () => bench.queue.enqueueLive(any()),
        ).thenAnswer((_) async => EnqueueResult.empty);
        when(
          () => bench.queue.lowerResumeFloor(
            roomId: any<String>(named: 'roomId'),
            originTs: any<int>(named: 'originTs'),
          ),
        ).thenAnswer((_) async {});

        final coordinator = bench.buildCoordinator(
          sentEventRegistry: bench.sentEventRegistry,
        );

        Event selfEcho(String id) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(() => e.roomId).thenReturn(roomId);
          when(() => e.type).thenReturn(EventTypes.Message);
          when(() => e.status).thenReturn(EventStatus.synced);
          bench.sentEventRegistry.register(id);
          return e;
        }

        Iterable<String> suppressionLogs() =>
            logMessages.where((m) => m.contains('selfEchoSuppressed'));

        var current = DateTime.utc(2026);
        await withClock(Clock(() => current), () async {
          await coordinator.start();
          verify(
            () => bench.queue.lowerResumeFloor(roomId: roomId, originTs: 1),
          ).called(1);

          // First suppressed echo: no previous flush -> logs count=1 and
          // starts the suppression window.
          bench.timelineCtl.add(selfEcho(r'$echo-1'));
          await pumpEventQueue();
          expect(suppressionLogs(), hasLength(1));
          expect(suppressionLogs().single, contains('count=1'));

          // Echoes inside the 30s window accumulate silently.
          bench.timelineCtl.add(selfEcho(r'$echo-2'));
          bench.timelineCtl.add(selfEcho(r'$echo-3'));
          await pumpEventQueue();
          expect(suppressionLogs(), hasLength(1));

          // First echo after the window flushes the accumulated count and
          // resets the counter.
          current = current.add(const Duration(seconds: 31));
          bench.timelineCtl.add(selfEcho(r'$echo-4'));
          await pumpEventQueue();
          expect(suppressionLogs(), hasLength(2));
          expect(suppressionLogs().last, contains('count=3'));

          // Suppressed events never reach the floor or the queue.
          verifyNever(
            () => bench.queue.lowerResumeFloor(
              roomId: any<String>(named: 'roomId'),
              originTs: any<int>(named: 'originTs'),
            ),
          );
          verifyNever(() => bench.queue.enqueueLive(any()));

          await coordinator.stop();
        });
      },
    );
  }

  void registerEnqueueFailure() {
    test(
      'a live enqueue that throws is logged, lowers the floor to the event '
      'and requests a bridge pass (FailedEnqueueLowersFloor in '
      'InboundQueue.tla: the live stream never redelivers the event, so '
      'swallowing the error lost it once a later event moved the anchor)',
      () async {
        when(
          () => queue.enqueueLive(any()),
        ).thenThrow(StateError('queue closed'));
        final coordinator = build();
        await coordinator.start();
        verifyStartClaim();
        verify(bridge.bridgeNow).called(1);

        timelineCtl.add(buildEvent(EventTypes.Message));
        await pumpEventQueue();

        verify(
          () => queue.lowerResumeFloor(roomId: roomId, originTs: 1234),
        ).called(1);
        verify(bridge.bridgeNow).called(1);

        verify(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any<String>(
              named: 'subDomain',
              that: contains('enqueue'),
            ),
          ),
        ).called(1);
        await coordinator.stop();
      },
    );
  }

  void registerAttachmentIngestor() {
    group('attachment ingestor hook', () {
      test(
        'every live event for the current room is routed through '
        'AttachmentIngestor.process so descriptor JSONs land on disk '
        'alongside the queue-pipeline enqueue',
        () async {
          final ingestor = _FakeAttachmentIngestor();

          final coordinator = QueuePipelineCoordinator(
            syncDb: syncDb,
            settingsDb: settingsDb,
            journalDb: journalDb,
            sessionManager: sessionManager,
            roomManager: roomManager,
            eventProcessor: processor,
            sequenceLogService: sequenceLog,
            activityGate: null,
            logging: logging,
            attachmentIngestor: ingestor,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          timelineCtl.add(buildEvent(EventTypes.Message));
          await pumpEventQueue();

          expect(ingestor.processCalls, hasLength(1));
          // `scheduleDownload` must be `true` so the coordinator routes
          // through the async download queue — an in-line save path would
          // block the live handler under bursty load.
          expect(ingestor.processCalls.single[#scheduleDownload], isTrue);

          await coordinator.stop();
        },
      );

      test(
        'when AttachmentIngestor.process throws, the failure is logged '
        'and the queue enqueue still happens — a broken ingestor must '
        'not strand incoming sync-payload events',
        () async {
          final ingestor = _FakeAttachmentIngestor(shouldThrow: true);
          final ingestorFailureLogged = Completer<void>();
          when(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('attachmentIngestor'),
              ),
            ),
          ).thenAnswer((_) {
            if (!ingestorFailureLogged.isCompleted) {
              ingestorFailureLogged.complete();
            }
          });

          final coordinator = QueuePipelineCoordinator(
            syncDb: syncDb,
            settingsDb: settingsDb,
            journalDb: journalDb,
            sessionManager: sessionManager,
            roomManager: roomManager,
            eventProcessor: processor,
            sequenceLogService: sequenceLog,
            activityGate: null,
            logging: logging,
            attachmentIngestor: ingestor,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          timelineCtl.add(buildEvent(EventTypes.Message));
          await ingestorFailureLogged.future;

          // The enqueue path still fires despite the ingestor throwing.
          verify(() => queue.enqueueLive(any())).called(1);
          verify(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('attachmentIngestor'),
              ),
            ),
          ).called(1);

          await coordinator.stop();
        },
      );
    });
  }

  void registerSelfEchoSuppression() {
    group('self-echo suppression', () {
      test(
        'events this device just sent are consumed from the SentEventRegistry '
        'and never reach the queue — without this the live handler would '
        're-enqueue every outbox message as it echoes back through Matrix',
        () async {
          final registry = SentEventRegistry();
          final ingestor = _FakeAttachmentIngestor();
          final coordinator = QueuePipelineCoordinator(
            syncDb: syncDb,
            settingsDb: settingsDb,
            journalDb: journalDb,
            sessionManager: sessionManager,
            roomManager: roomManager,
            eventProcessor: processor,
            sequenceLogService: sequenceLog,
            activityGate: null,
            logging: logging,
            attachmentIngestor: ingestor,
            sentEventRegistry: registry,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          final echoed = MockEvent();
          when(() => echoed.eventId).thenReturn(r'$self-echo');
          when(() => echoed.roomId).thenReturn(roomId);
          when(() => echoed.type).thenReturn(EventTypes.Message);
          when(() => echoed.status).thenReturn(EventStatus.synced);
          registry.register(r'$self-echo');

          timelineCtl.add(echoed);
          await pumpEventQueue();

          // Neither the queue nor the attachment ingestor should see the
          // event — it's ours and already on disk.
          verifyNever(() => queue.enqueueLive(any()));
          expect(ingestor.processCalls, isEmpty);

          await coordinator.stop();
        },
      );

      test(
        'peer events (not in the SentEventRegistry) still flow through — '
        'suppression must not drop messages from other devices',
        () async {
          final registry = SentEventRegistry();
          final coordinator = QueuePipelineCoordinator(
            syncDb: syncDb,
            settingsDb: settingsDb,
            journalDb: journalDb,
            sessionManager: sessionManager,
            roomManager: roomManager,
            eventProcessor: processor,
            sequenceLogService: sequenceLog,
            activityGate: null,
            logging: logging,
            sentEventRegistry: registry,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          final peer = MockEvent();
          when(() => peer.eventId).thenReturn(r'$peer-event');
          when(() => peer.roomId).thenReturn(roomId);
          when(() => peer.type).thenReturn(EventTypes.Message);
          when(() => peer.status).thenReturn(EventStatus.synced);
          final enqueued = Completer<void>();
          when(() => queue.enqueueLive(peer)).thenAnswer((_) async {
            if (!enqueued.isCompleted) {
              enqueued.complete();
            }
            return EnqueueResult.empty;
          });

          timelineCtl.add(peer);
          await enqueued.future;

          verify(() => queue.enqueueLive(peer)).called(1);

          await coordinator.stop();
        },
      );

      test(
        'pre-sync fake-sync emissions (status=sending / sent / error) are '
        'dropped at the live-handler ingress — Matrix SDK 7.0.0 fires '
        '_handleFakeSync twice on every send (pending + optimistic), both '
        'with a non-synced status, and both race past the SentEventRegistry '
        'because the sender registers the real id only after sendEvent '
        'returns. Filtering by status before the registry check is the '
        'only way to guarantee these do not reach the queue.',
        () async {
          final registry = SentEventRegistry();
          final coordinator = QueuePipelineCoordinator(
            syncDb: syncDb,
            settingsDb: settingsDb,
            journalDb: journalDb,
            sessionManager: sessionManager,
            roomManager: roomManager,
            eventProcessor: processor,
            sequenceLogService: sequenceLog,
            activityGate: null,
            logging: logging,
            sentEventRegistry: registry,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          // Pending fake-sync: transaction id (not server-assigned),
          // status=sending — would otherwise bypass the registry entirely
          // because the registry never learns the transaction id.
          final pending = MockEvent();
          when(() => pending.eventId).thenReturn('m1761234567890-txn-id');
          when(() => pending.roomId).thenReturn(roomId);
          when(() => pending.type).thenReturn(EventTypes.Message);
          when(() => pending.status).thenReturn(EventStatus.sending);

          // Optimistic fake-sync: real `$...` id, status=sent — the
          // registry is empty on this tick because the sender's
          // register() call has not run yet (it runs after sendEvent
          // returns, which is after this fake-sync fires).
          final optimistic = MockEvent();
          when(() => optimistic.eventId).thenReturn(r'$server-assigned-id');
          when(() => optimistic.roomId).thenReturn(roomId);
          when(() => optimistic.type).thenReturn(EventTypes.Message);
          when(() => optimistic.status).thenReturn(EventStatus.sent);

          // Error fake-sync: send failed mid-flight.
          final errored = MockEvent();
          when(() => errored.eventId).thenReturn('m-errored-txn');
          when(() => errored.roomId).thenReturn(roomId);
          when(() => errored.type).thenReturn(EventTypes.Message);
          when(() => errored.status).thenReturn(EventStatus.error);

          timelineCtl
            ..add(pending)
            ..add(optimistic)
            ..add(errored);
          await pumpEventQueue();

          // None of these should reach the queue — they are
          // SDK-generated fake-sync emissions, not real inbound events.
          verifyNever(() => queue.enqueueLive(any()));

          await coordinator.stop();
        },
      );
    });
  }
}
