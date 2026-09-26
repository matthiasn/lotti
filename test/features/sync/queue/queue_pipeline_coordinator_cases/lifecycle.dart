part of '../queue_pipeline_coordinator_test.dart';

extension _QueueLifecycleCases on _QueueCoordinatorTestSetup {
  void registerStart() {
    test(
      'start seeds the marker, prunes strays, starts worker + bridge',
      () async {
        final coordinator = build();
        await coordinator.start();
        expect(coordinator.isRunning, isTrue);
        verify(() => seeder.seedIfAbsent(roomId)).called(1);
        verify(() => queue.pruneStrandedEntries(roomId)).called(1);
        verify(worker.start).called(1);
        verify(bridge.start).called(1);
        await coordinator.stop();
      },
    );
  }

  void registerStartUnwind() {
    test(
      'startup unwind waits for response admission before stopping worker',
      () async {
        final startGate = Completer<void>();
        final enqueueGate = Completer<EnqueueResult>();
        when(worker.start).thenAnswer((_) => startGate.future);
        when(
          () => queue.enqueueLive(any()),
        ).thenAnswer((_) => enqueueGate.future);
        final coordinator = build();
        final startFuture = coordinator.start();
        var startFinished = false;
        final result = expectLater(
          startFuture,
          throwsStateError,
        ).then((_) => startFinished = true);
        await pumpEventQueue();
        deliverPayload(buildEvent(EventTypes.Message));
        await pumpEventQueue();
        verify(() => queue.enqueueLive(any())).called(1);
        startGate.completeError(StateError('worker failed'));
        await pumpEventQueue();
        try {
          expect(startFinished, isFalse);
          verifyNever(worker.stop);
          verifyNever(bridge.stop);
        } finally {
          enqueueGate.complete(EnqueueResult.empty);
          await result;
        }
        verify(worker.stop).called(1);
        verify(bridge.stop).called(1);
        expect(coordinator.isRunning, isFalse);
        when(worker.start).thenAnswer((_) async {});
        await coordinator.start();
        expect(coordinator.isRunning, isTrue);
        await coordinator.stop();
      },
    );

    test(
      'start() unwind awaits an in-flight attachment-path flush before '
      'tearing down and leaves the coordinator retryable',
      () async {
        final bench = _GladosBench();
        addTearDown(bench.dispose);
        final attachmentIndex = _SyncPathAttachmentIndex();
        final updateNotifications = MockUpdateNotifications();
        final flushGate = Completer<void>();

        when(
          () => bench.queue.resurrectByPaths(any()),
        ).thenAnswer((_) => flushGate.future.then((_) => 0));

        late QueuePipelineCoordinator coordinator;
        var updateStreamAccesses = 0;
        when(() => updateNotifications.updateStream).thenAnswer((_) {
          updateStreamAccesses++;
          if (updateStreamAccesses == 1) {
            // _attachmentPathSub is live at this point in start(). Land a
            // path synchronously and force the debounced flush to start (it
            // parks on flushGate); the returned stream then fails start()'s
            // listen() so the unwind runs with _attachmentPathFlushInFlight
            // non-null.
            attachmentIndex.ctl.add('/attachments/a.json');
            unawaited(coordinator.flushPendingPathResurrectionsForTest());
            return _ThrowingSubscribeStream();
          }
          return const Stream<Set<String>>.empty();
        });

        coordinator = bench.buildCoordinator(
          attachmentIndex: attachmentIndex,
          updateNotifications: updateNotifications,
        );

        final startFuture = coordinator.start();
        // Let start() reach the unwind's `await pendingFlush`.
        await pumpEventQueue();
        // The unwind is parked on the flush; the failure has not
        // propagated yet and the worker has not been torn down.
        verifyNever(bench.worker.stop);

        flushGate.complete();
        await expectLater(startFuture, throwsStateError);

        // The flush completed before teardown and teardown ran fully.
        verify(
          () => bench.queue.resurrectByPaths(['/attachments/a.json']),
        ).called(1);
        verify(bench.bridge.stop).called(1);
        verify(bench.worker.stop).called(1);
        expect(coordinator.isRunning, isFalse);

        // The unwind left a retryable coordinator: a second start()
        // (with updateStream now healthy) succeeds.
        await coordinator.start();
        expect(coordinator.isRunning, isTrue);
        await coordinator.stop();
        await attachmentIndex.ctl.close();
      },
    );
  }

  void registerShutdown() {
    test(
      'stop(drainFirst: true) drains until empty before tearing down (F7)',
      () async {
        final bridgeStopped = Completer<void>();
        final drained = Completer<int>();
        final workerStopped = Completer<void>();
        final stages = <String>[];
        when(bridge.stop).thenAnswer((_) async {
          stages.add('bridge stopping');
          await bridgeStopped.future;
          stages.add('bridge stopped');
        });
        when(worker.drainToCompletion).thenAnswer((_) async {
          stages.add('draining');
          final count = await drained.future;
          stages.add('drained');
          return count;
        });
        when(() => queue.stats()).thenAnswer((_) async {
          stages.add('queue empty');
          return const QueueStats(
            total: 0,
            byProducer: {},
            oldestEnqueuedAt: null,
          );
        });
        when(worker.stop).thenAnswer((_) async {
          stages.add('worker stopping');
          await workerStopped.future;
          stages.add('worker stopped');
        });
        when(queue.dispose).thenAnswer((_) async {
          stages.add('queue disposed');
        });

        final coordinator = build();
        await coordinator.start();
        expect(coordinator.isRunning, isTrue);
        var stopDone = false;
        unawaited(
          coordinator.stop(drainFirst: true).then((_) => stopDone = true),
        );
        try {
          await pumpEventQueue();
          expect(stages, ['bridge stopping']);
          expect(stopDone, isFalse);

          bridgeStopped.complete();
          await pumpEventQueue();
          expect(stages, ['bridge stopping', 'bridge stopped', 'draining']);
          expect(stopDone, isFalse);
          verifyNever(worker.stop);
          verifyNever(queue.dispose);

          drained.complete(1);
          await pumpEventQueue();
          expect(stages, [
            'bridge stopping',
            'bridge stopped',
            'draining',
            'drained',
            'queue empty',
            'worker stopping',
          ]);
          expect(stopDone, isFalse);
          verifyNever(queue.dispose);

          workerStopped.complete();
          await pumpEventQueue();
          expect(stages, [
            'bridge stopping',
            'bridge stopped',
            'draining',
            'drained',
            'queue empty',
            'worker stopping',
            'worker stopped',
            'queue disposed',
          ]);
          expect(stopDone, isTrue);
          expect(coordinator.isRunning, isFalse);
        } finally {
          if (!bridgeStopped.isCompleted) bridgeStopped.complete();
          if (!drained.isCompleted) drained.complete(0);
          if (!workerStopped.isCompleted) workerStopped.complete();
          await pumpEventQueue();
        }
      },
    );

    test('stop without drainFirst skips drainToCompletion', () async {
      final coordinator = build();
      await coordinator.start();
      await coordinator.stop();

      verifyNever(worker.drainToCompletion);
      verify(() => worker.stop()).called(1);
    });

    for (final failingStage in ['bridge', 'drain', 'worker']) {
      test(
        'stop completes cleanup after an asynchronous $failingStage failure',
        () async {
          final failure = StateError('$failingStage teardown failed');
          final stages = <String>[];
          when(bridge.stop).thenAnswer((_) async {
            stages.add('bridge');
            if (failingStage == 'bridge') throw failure;
          });
          when(() => queue.stats()).thenAnswer((_) async {
            stages.add('drain');
            if (failingStage == 'drain') throw failure;
            return const QueueStats(
              total: 0,
              byProducer: {},
              oldestEnqueuedAt: null,
            );
          });
          when(worker.stop).thenAnswer((_) async {
            stages.add('worker');
            if (failingStage == 'worker') throw failure;
          });
          when(queue.dispose).thenAnswer((_) async => stages.add('queue'));
          final coordinator = build();
          await coordinator.start();

          await coordinator.stop(drainFirst: true);

          expect(stages, ['bridge', 'drain', 'worker', 'queue']);
          expect(coordinator.isRunning, isFalse);
          verify(
            () => logging.error(
              LogDomain.sync,
              failure,
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'queue.coordinator.stop.$failingStage',
            ),
          ).called(1);

          await coordinator.stop(drainFirst: true);
          expect(stages, ['bridge', 'drain', 'worker', 'queue']);
        },
      );
    }
  }

  void registerBridgeFacade() {
    test('triggerBridge delegates to bridge.bridgeNow', () async {
      when(bridge.bridgeNow).thenAnswer((_) async {});
      final coordinator = build();
      await coordinator.triggerBridge();
      verify(bridge.bridgeNow).called(1);
    });

    test(
      'isBridgeInFlight forwards from the bridge coordinator — this is '
      'the gate the backfill service reads to skip analysis during a walk',
      () {
        when(() => bridge.isBridgeInFlight).thenReturn(true);
        final coordinator = build();
        expect(coordinator.isBridgeInFlight, isTrue);

        when(() => bridge.isBridgeInFlight).thenReturn(false);
        expect(coordinator.isBridgeInFlight, isFalse);
      },
    );

    test(
      'onBridgeCompleted getter/setter forwards to the bridge — backfill '
      'service subscribes through the coordinator facade so the two do '
      'not need to know about each other directly',
      () {
        void callback() {}
        final coordinator = build()..onBridgeCompleted = callback;
        verify(() => bridge.onBridgeCompleted = callback).called(1);

        when(() => bridge.onBridgeCompleted).thenReturn(callback);
        expect(coordinator.onBridgeCompleted, same(callback));
      },
    );
  }

  void registerStartErrors() {
    test('start logs noRoom when there is no current room', () async {
      when(() => roomManager.currentRoomId).thenReturn(null);
      final coordinator = build();
      await coordinator.start();

      verifyNever(() => seeder.seedIfAbsent(any()));
      verify(
        () => logging.log(
          any<LogDomain>(),
          any<String>(that: contains('queue.coordinator.start.noRoom')),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).called(1);
      expect(coordinator.isRunning, isTrue);
      await coordinator.stop();
    });

    test('start swallows seeder errors and continues', () async {
      when(
        () => seeder.seedIfAbsent(any()),
      ).thenThrow(StateError('seed failed'));
      final coordinator = build();
      await coordinator.start();

      expect(coordinator.isRunning, isTrue);
      verify(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(
            named: 'subDomain',
            that: contains('start.seed'),
          ),
        ),
      ).called(1);
      await coordinator.stop();
    });

    test(
      'start unwinds when worker.start throws and leaves coordinator stopped',
      () async {
        when(worker.start).thenThrow(StateError('worker died'));
        final coordinator = build();

        await expectLater(coordinator.start(), throwsA(isA<StateError>()));
        expect(coordinator.isRunning, isFalse);
        verify(bridge.stop).called(1);
        verify(() => worker.stop()).called(1);
      },
    );
  }

  void registerQueueFacade() {
    test('queue getter exposes the underlying InboundQueue', () {
      final coordinator = build();
      expect(coordinator.queue, same(queue));
    });
  }

  void registerPendingShutdownAndDefaultLifecycle() {
    test('stop swallows drain errors and still tears down', () async {
      when(
        worker.drainToCompletion,
      ).thenThrow(StateError('drain blew up'));
      when(() => queue.stats()).thenAnswer(
        (_) async => const QueueStats(
          total: 0,
          byProducer: {},
          oldestEnqueuedAt: null,
        ),
      );
      final coordinator = build();
      await coordinator.start();
      await coordinator.stop(drainFirst: true);

      verify(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain', that: contains('drain')),
        ),
      ).called(greaterThanOrEqualTo(1));
      verify(() => worker.stop()).called(1);
      verify(() => queue.dispose()).called(1);
    });

    test(
      'stop() waits for an in-flight live enqueue before disposing the '
      'queue — a producer mid-insert when shutdown begins must finish its '
      'write so disposal never races a live enqueueLive() call',
      () async {
        // Gate enqueueLive on a completer so the tracked future stays in
        // `_inFlightEnqueues` across the start of stop().
        final enqueueGate = Completer<EnqueueResult>();
        when(
          () => queue.enqueueLive(any()),
        ).thenAnswer((_) => enqueueGate.future);

        final coordinator = build();
        await coordinator.start();

        deliverPayload(buildEvent(EventTypes.Message));
        // Let _handleLiveEvent run through _safeEnqueue so the
        // gated enqueueLive future is registered in _inFlightEnqueues.
        await pumpEventQueue();
        verify(() => queue.enqueueLive(any())).called(1);

        var stopDone = false;
        final stopFuture = coordinator.stop().then((_) => stopDone = true);
        await pumpEventQueue();
        // stop() is parked on Future.wait(_inFlightEnqueues) — the queue
        // must not be disposed while the enqueue is still in flight.
        expect(
          stopDone,
          isFalse,
          reason: 'stop must await the in-flight enqueue',
        );
        verifyNever(() => queue.dispose());

        // Release the enqueue; stop() can now drain the in-flight set and
        // proceed to teardown.
        enqueueGate.complete(EnqueueResult.empty);
        await stopFuture;

        expect(stopDone, isTrue);
        verify(() => queue.dispose()).called(1);
        expect(coordinator.isRunning, isFalse);
      },
    );

    test(
      'coordinator built without overrides drives a real start/stop '
      'lifecycle: the default QueueMarkerSeeder seeds the live syncDb '
      'marker from legacy settings and isRunning flips true then false',
      () async {
        // No override collaborators: the coordinator builds its own
        // InboundQueue, InboundWorker, BridgeCoordinator, and QueueMarkerSeeder
        // against the real in-memory databases.
        when(() => sessionManager.client).thenReturn(client);
        // The default seeder reads the legacy marker from settings; supply a
        // value so a successful seed is observable as a queue_markers row.
        when(
          () => settingsDb.itemByKey(lastReadMatrixEventId),
        ).thenAnswer((_) async => r'$legacy-anchor');
        when(
          () => settingsDb.itemByKey(lastReadMatrixEventTs),
        ).thenAnswer((_) async => '7000');
        // Keep the fire-and-forget startup bridge a clean no-op (noRoom)
        // rather than letting it attempt a real /messages walk.
        when(() => client.getRoomById(roomId)).thenReturn(null);

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
        );

        expect(coordinator.isRunning, isFalse);

        await coordinator.start();
        expect(coordinator.isRunning, isTrue);

        // The default seeder ran against the real syncDb during start() and
        // migrated the legacy marker — proving the default collaborator was
        // wired with the live databases, not a stub.
        final marker = await (syncDb.select(
          syncDb.queueMarkers,
        )..where((t) => t.roomId.equals(roomId))).getSingle();
        expect(marker.lastAppliedEventId, r'$legacy-anchor');
        expect(marker.lastAppliedTs, 7000);

        await coordinator.stop();
        expect(coordinator.isRunning, isFalse);
      },
    );
  }

  void registerStartupRecoveryAndDrainDeadlines() {
    group('P1 fixes', () {
      test(
        'start() fires a background bridge pass for startup catch-up',
        () async {
          final coordinator = build();
          await coordinator.start();
          // The unawaited safeStartupBridge microtask needs to settle.
          await pumpEventQueue();

          verify(bridge.bridgeNow).called(1);
          await coordinator.stop();
        },
      );

      test(
        'start() skips startup bridge when there is no current room',
        () async {
          when(() => roomManager.currentRoomId).thenReturn(null);
          final coordinator = build();
          await coordinator.start();
          await pumpEventQueue();

          verifyNever(bridge.bridgeNow);
          await coordinator.stop();
        },
      );

      test(
        'start() swallows startup bridge errors with a captured exception',
        () async {
          when(bridge.bridgeNow).thenThrow(StateError('bridge broke'));
          final coordinator = build();
          await coordinator.start();
          await pumpEventQueue();

          verify(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('startupBridge'),
              ),
            ),
          ).called(1);
          await coordinator.stop();
        },
      );

      test(
        'onRoomChanged seeds the new room and prunes stranded rows',
        () async {
          final coordinator = build();
          await coordinator.onRoomChanged('!other:example.org');

          verify(() => seeder.seedIfAbsent('!other:example.org')).called(1);
          verify(
            () => queue.pruneStrandedEntries('!other:example.org'),
          ).called(1);
        },
      );

      test(
        'onRoomChanged swallows seeder errors and still logs the event',
        () async {
          when(
            () => seeder.seedIfAbsent(any()),
          ).thenThrow(StateError('seed failed'));

          final coordinator = build();
          await coordinator.onRoomChanged('!other:example.org');

          verify(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('onRoomChanged'),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'drainUntilEmpty waits for the retry deadline before draining again',
        () {
          fakeAsync((async) {
            final retryAt = clock.now().add(const Duration(seconds: 2));
            var drainCalls = 0;
            when(worker.drainToCompletion).thenAnswer((_) async {
              drainCalls++;
              return drainCalls == 1 ? 0 : 2;
            });
            when(() => queue.stats()).thenAnswer(
              (_) async => QueueStats(
                total: drainCalls == 1 ? 2 : 0,
                byProducer: const {},
                oldestEnqueuedAt: null,
              ),
            );
            when(() => queue.earliestReadyAt()).thenAnswer(
              (_) async => retryAt.millisecondsSinceEpoch,
            );
            final coordinator = build();
            var done = false;
            unawaited(
              coordinator
                  .drainUntilEmpty(timeout: const Duration(seconds: 5))
                  .then((_) => done = true),
            );
            async.flushMicrotasks();
            expect(drainCalls, 1);
            expect(done, isFalse);

            async.elapse(const Duration(milliseconds: 1999));
            expect(drainCalls, 1);
            expect(done, isFalse);

            async.elapse(const Duration(milliseconds: 1));
            expect(drainCalls, 2);
            expect(done, isTrue);
            verify(() => queue.stats()).called(2);
            verify(() => queue.earliestReadyAt()).called(1);

            async.elapse(const Duration(seconds: 5));
            expect(drainCalls, 2);
            expect(async.pendingTimers, isEmpty);
          }, initialTime: DateTime.utc(2024, 3, 15));
        },
      );

      for (final readyIn in [null, const Duration(seconds: 2)]) {
        test(
          'drainUntilEmpty stops at the timeout with '
          '${readyIn == null ? 'no ready time' : 'a later retry deadline'}',
          () {
            fakeAsync((async) {
              when(() => queue.stats()).thenAnswer(
                (_) async => const QueueStats(
                  total: 5,
                  byProducer: {},
                  oldestEnqueuedAt: null,
                ),
              );
              final retryAt = readyIn == null
                  ? null
                  : clock.now().add(readyIn).millisecondsSinceEpoch;
              when(
                () => queue.earliestReadyAt(),
              ).thenAnswer((_) async => retryAt);
              final coordinator = build();
              var done = false;
              unawaited(
                coordinator
                    .drainUntilEmpty(timeout: const Duration(milliseconds: 50))
                    .then((_) => done = true),
              );
              async.flushMicrotasks();
              expect(done, isFalse);

              async.elapse(const Duration(milliseconds: 49));
              expect(done, isFalse);
              verifyNever(
                () => logging.log(
                  LogDomain.sync,
                  'queue.coordinator.drainUntilEmpty.timeout remaining=5',
                  subDomain: 'queue.coordinator',
                ),
              );

              async.elapse(const Duration(milliseconds: 1));
              expect(done, isTrue);
              verify(
                () => logging.log(
                  LogDomain.sync,
                  'queue.coordinator.drainUntilEmpty.timeout remaining=5',
                  subDomain: 'queue.coordinator',
                ),
              ).called(1);
              verify(worker.drainToCompletion).called(1);
              verify(() => queue.stats()).called(1);
              verify(() => queue.earliestReadyAt()).called(1);

              async.elapse(const Duration(seconds: 3));
              verifyNever(worker.drainToCompletion);
              expect(async.pendingTimers, isEmpty);
            }, initialTime: DateTime.utc(2024, 3, 15));
          },
        );
      }
    });
  }
}
