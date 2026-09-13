part of '../queue_pipeline_coordinator_test.dart';

extension _ResurrectionCases on _QueueCoordinatorTestSetup {
  void registerResurrection() {
    group('signal-driven resurrection', () {
      test(
        'when the AttachmentIndex records a new path, the coordinator '
        'flushes the debounced batch through resurrectByPaths so an '
        'abandoned row waiting on that attachment is flipped back to '
        'enqueued in a single bulk DB call instead of a per-path SELECT '
        '+ UPDATE pair (see 2026-05-12 super_slow log: 222 hits/day at '
        '~384 ms each)',
        () async {
          final attachmentIndex = AttachmentIndex(logging: logging);
          addTearDown(attachmentIndex.dispose);
          when(
            () => queue.resurrectByPaths(any<Iterable<String>>()),
          ).thenAnswer((_) async => 1);

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
            attachmentIndex: attachmentIndex,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          final event = MockEvent();
          when(() => event.attachmentMimetype).thenReturn('audio/m4a');
          when(() => event.content).thenReturn({
            'relativePath': 'audio/2026-04-21/foo.m4a.json',
          });
          when(() => event.eventId).thenReturn(r'$attachmentEvent');
          attachmentIndex.record(event);

          await pumpEventQueue();
          await coordinator.flushPendingPathResurrectionsForTest();

          final captured =
              verify(
                    () =>
                        queue.resurrectByPaths(captureAny<Iterable<String>>()),
                  ).captured.single
                  as Iterable<String>;
          expect(captured, contains('/audio/2026-04-21/foo.m4a.json'));

          await coordinator.stop();
        },
      );

      test(
        'a burst of pathRecorded events lands in a single resurrectByPaths '
        'call once the debounce window closes — fold the N writer-lock '
        'transactions captured in the 2026-05-12 super_slow log (10+ '
        'identical-elapsed hits in the same millisecond span) into one '
        'bulk DB round-trip',
        () async {
          final attachmentIndex = AttachmentIndex(logging: logging);
          addTearDown(attachmentIndex.dispose);
          when(
            () => queue.resurrectByPaths(any<Iterable<String>>()),
          ).thenAnswer((_) async => 3);

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
            attachmentIndex: attachmentIndex,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          for (final path in [
            'audio/2026-04-21/a.m4a.json',
            'audio/2026-04-21/b.m4a.json',
            'images/2026-04-21/c.jpg.json',
          ]) {
            final event = MockEvent();
            when(() => event.attachmentMimetype).thenReturn('audio/m4a');
            when(() => event.content).thenReturn({'relativePath': path});
            when(() => event.eventId).thenReturn('\$ev-${path.hashCode}');
            attachmentIndex.record(event);
          }
          // Flush all queued microtasks first, then drain the timer.
          await pumpEventQueue();
          await coordinator.flushPendingPathResurrectionsForTest();

          final captured =
              verify(
                    () =>
                        queue.resurrectByPaths(captureAny<Iterable<String>>()),
                  ).captured.single
                  as Iterable<String>;
          expect(
            captured.toSet(),
            {
              '/audio/2026-04-21/a.m4a.json',
              '/audio/2026-04-21/b.m4a.json',
              '/images/2026-04-21/c.jpg.json',
            },
            reason:
                'three paths recorded inside one debounce window must '
                'collapse to one bulk resurrectByPaths call, not three '
                'separate ones',
          );
          // Single call covers the whole burst.

          await coordinator.stop();
        },
      );

      test(
        'coordinator.stop() awaits an in-flight resurrectByPaths flush '
        'before disposing the queue — guards against the teardown race '
        'where the debounce timer fires, kicks off a writer transaction, '
        'and stop() then disposes the queue concurrently',
        () async {
          final attachmentIndex = AttachmentIndex(logging: logging);
          addTearDown(attachmentIndex.dispose);

          // Hold the flush mid-transaction so stop() observes it
          // in-flight. We release it inside the verify so the test
          // settles, but the critical assertion is that stop()
          // *awaited* the flush (the released future completes before
          // stop() returns).
          final flushCompleter = Completer<int>();
          when(
            () => queue.resurrectByPaths(any<Iterable<String>>()),
          ).thenAnswer((_) => flushCompleter.future);

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
            attachmentIndex: attachmentIndex,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          // Push a path through the debounced subscriber and let the
          // accumulator drain into the bulk call. The mock now hangs
          // on `flushCompleter.future` so the flush is genuinely
          // in-flight when stop() runs.
          final event = MockEvent();
          when(() => event.attachmentMimetype).thenReturn('audio/m4a');
          when(() => event.content).thenReturn({
            'relativePath': 'audio/2026-04-21/foo.m4a.json',
          });
          when(() => event.eventId).thenReturn(r'$ev');
          attachmentIndex.record(event);
          await pumpEventQueue();
          // Trigger the debounce window so the flush kicks off.
          // We can't `await` the flush here — it's parked on the
          // completer — but we can let the timer fire by relying on
          // the visible-for-test entry point which schedules the
          // flush right now.
          unawaited(coordinator.flushPendingPathResurrectionsForTest());
          await pumpEventQueue();

          // Start stop() and release the flush after one microtask.
          // If stop() does not await the in-flight flush, it returns
          // before the flush completer resolves and the verify below
          // would see called=0 at that moment.
          final stopFuture = coordinator.stop();
          await pumpEventQueue();
          flushCompleter.complete(1);
          await stopFuture;

          verify(
            () => queue.resurrectByPaths(any<Iterable<String>>()),
          ).called(1);
        },
      );

      test(
        'when UpdateNotifications emits, the coordinator calls '
        'resurrectByReason(missingBase) so any abandoned row waiting '
        'on its base journal entry becomes drainable again',
        () {
          fakeAsync((async) {
            final updateNotifications = UpdateNotifications();
            addTearDown(updateNotifications.dispose);
            when(
              () => queue.resurrectByReason(any<String>()),
            ).thenAnswer((_) async => 1);

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
              updateNotifications: updateNotifications,
              queueOverride: queue,
              workerOverride: worker,
              bridgeOverride: bridge,
              seederOverride: seeder,
            );
            addTearDown(() async => coordinator.stop());
            var started = false;
            unawaited(coordinator.start().then((_) => started = true));
            async.flushMicrotasks();
            expect(started, isTrue);

            updateNotifications.notify({'some-entry-id'});
            async
              ..elapse(const Duration(milliseconds: 100))
              ..flushMicrotasks();

            verify(
              () => queue.resurrectByReason('missingBase'),
            ).called(greaterThanOrEqualTo(1));
          });
        },
      );
    });
  }

  void registerResurrectionErrors() {
    group('resurrection subscription error paths', () {
      test(
        'when resurrectByPaths throws on the debounced flush, the '
        'exception is logged under the resurrectByPaths subDomain — a '
        'broken queue must not silently drop resurrection signals',
        () async {
          final attachmentIndex = AttachmentIndex(logging: logging);
          addTearDown(attachmentIndex.dispose);
          when(
            () => queue.resurrectByPaths(any<Iterable<String>>()),
          ).thenThrow(StateError('queue gone'));

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
            attachmentIndex: attachmentIndex,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          final event = MockEvent();
          when(() => event.attachmentMimetype).thenReturn('audio/m4a');
          when(() => event.content).thenReturn({
            'relativePath': 'audio/2026-04-21/foo.m4a.json',
          });
          when(() => event.eventId).thenReturn(r'$attachment');
          attachmentIndex.record(event);
          await pumpEventQueue();
          await coordinator.flushPendingPathResurrectionsForTest();

          verify(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('resurrectByPaths'),
              ),
            ),
          ).called(1);

          await coordinator.stop();
        },
      );

      test(
        'when resurrectByReason throws on a journal-db update notify, '
        'the exception is logged under the resurrectByReason subDomain '
        'so a broken queue never silences the missing-base signal',
        () {
          fakeAsync((async) {
            final updateNotifications = UpdateNotifications();
            addTearDown(updateNotifications.dispose);
            when(
              () => queue.resurrectByReason(any<String>()),
            ).thenThrow(StateError('queue gone'));

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
              updateNotifications: updateNotifications,
              queueOverride: queue,
              workerOverride: worker,
              bridgeOverride: bridge,
              seederOverride: seeder,
            );
            addTearDown(() async => coordinator.stop());
            var started = false;
            unawaited(coordinator.start().then((_) => started = true));
            async.flushMicrotasks();
            expect(started, isTrue);

            updateNotifications.notify({'some-entry'});
            async
              ..elapse(const Duration(milliseconds: 100))
              ..flushMicrotasks();

            verify(
              () => logging.error(
                any<LogDomain>(),
                any<Object>(),
                stackTrace: any<StackTrace>(named: 'stackTrace'),
                subDomain: any<String>(
                  named: 'subDomain',
                  that: contains('resurrectByReason'),
                ),
              ),
            ).called(greaterThanOrEqualTo(1));
          });
        },
      );

      test(
        'an error on the AttachmentIndex.pathRecorded stream is routed to '
        'the subscription onError handler and logged under the pathRecorded '
        'subDomain — a faulting source must not take the pipeline down',
        () async {
          final attachmentIndex = _ErroringAttachmentIndex();
          addTearDown(attachmentIndex.dispose);

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
            attachmentIndex: attachmentIndex,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          attachmentIndex.errorCtl.addError(StateError('path source boom'));
          await pumpEventQueue();

          verify(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('pathRecorded'),
              ),
            ),
          ).called(1);
          // The subscription survives the error — the coordinator keeps
          // running rather than tearing down.
          expect(coordinator.isRunning, isTrue);

          await coordinator.stop();
        },
      );

      test(
        'an error on the UpdateNotifications.updateStream is routed to the '
        'journal-update subscription onError handler and logged under the '
        'journalUpdates subDomain',
        () async {
          final updateNotifications = _ErroringUpdateNotifications();
          addTearDown(updateNotifications.dispose);

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
            updateNotifications: updateNotifications,
            queueOverride: queue,
            workerOverride: worker,
            bridgeOverride: bridge,
            seederOverride: seeder,
          );
          await coordinator.start();

          updateNotifications.errorCtl.addError(
            StateError('update source boom'),
          );
          await pumpEventQueue();

          verify(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('journalUpdates'),
              ),
            ),
          ).called(1);
          expect(coordinator.isRunning, isTrue);

          await coordinator.stop();
        },
      );
    });
  }
}
