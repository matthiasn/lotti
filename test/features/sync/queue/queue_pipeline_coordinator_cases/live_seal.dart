part of '../queue_pipeline_coordinator_test.dart';

/// Sealing live arrivals: `queue_live_seal.dart`, `SyncEnd` and `SealDone`
/// in `specs/tla/InboundQueue.tla`.
extension _LiveSealCases on _QueueCoordinatorTestSetup {
  void registerLiveSeal() {
    group('live seal', () {
      SyncUpdate syncUpdate({required bool limited}) => SyncUpdate(
        nextBatch: 'next',
        rooms: RoomsUpdate(
          join: {
            roomId: JoinedRoomUpdate(
              timeline: TimelineUpdate(limited: limited, events: const []),
            ),
          },
        ),
      );

      Future<QueuePipelineCoordinator> started() async {
        final coordinator = build();
        await coordinator.start();
        // The start claim is covered by catch_up_claims; count from here.
        clearInteractions(queue);
        return coordinator;
      }

      Future<void> finishResponse(
        QueuePipelineCoordinator coordinator, [
        SyncStatus status = SyncStatus.cleaningUp,
      ]) async {
        statusCtl.add(SyncStatusUpdate(status));
        await coordinator.liveSealsSettled;
      }

      void arrive() => timelineCtl.add(buildEvent('m.room.message'));

      Future<void> deliverSync({required bool limited}) async {
        syncCtl.add(syncUpdate(limited: limited));
        // CachedStreamController delivers asynchronously.
        await pumpEventQueue();
      }

      void verifyNoClaim() => verifyNever(
        () => queue.claimAboveMarker(
          roomId: any<String>(named: 'roomId'),
          readAppliedTs: any(named: 'readAppliedTs'),
          walkLocal: any(named: 'walkLocal'),
        ),
      );

      test('a response that was not limited releases the hold without a '
          'claim, persisting any retained floor first', () async {
        final coordinator = await started();
        arrive();
        await deliverSync(limited: false);

        await finishResponse(coordinator);

        verifyNoClaim();
        verifyInOrder([
          () => queue.ensureResumeFloorPersisted(roomId),
          () => queue.catchUpMarker(roomId),
        ]);
        await coordinator.stop();
      });

      test('a limited response claims the gap above the held marker before '
          'the marker catches up', () async {
        final coordinator = await started();
        arrive();
        await deliverSync(limited: true);

        await finishResponse(coordinator);

        verifyInOrder([
          () => queue.claimAboveMarker(
            roomId: roomId,
            readAppliedTs: any(named: 'readAppliedTs'),
            walkLocal: any(named: 'walkLocal'),
          ),
          () => queue.catchUpMarker(roomId),
        ]);
        await coordinator.stop();
      });

      test('onSync, processing and finished never seal: the SDK emits them '
          'from synthetic passes inside a real response, too', () async {
        final coordinator = await started();
        arrive();
        await deliverSync(limited: false);
        statusCtl
          ..add(const SyncStatusUpdate(SyncStatus.waitingForResponse))
          ..add(const SyncStatusUpdate(SyncStatus.processing))
          ..add(const SyncStatusUpdate(SyncStatus.finished));
        await coordinator.liveSealsSettled;

        verifyNever(() => queue.catchUpMarker(any()));
        verifyNever(() => queue.ensureResumeFloorPersisted(any()));
        await coordinator.stop();
      });

      test('a sync error seals conservatively: its response may have '
          'delivered part of a limited slice before failing', () async {
        final coordinator = await started();
        arrive();

        await finishResponse(coordinator, SyncStatus.error);

        verifyInOrder([
          () => queue.claimAboveMarker(
            roomId: roomId,
            readAppliedTs: any(named: 'readAppliedTs'),
            walkLocal: any(named: 'walkLocal'),
          ),
          () => queue.catchUpMarker(roomId),
        ]);
        await coordinator.stop();
      });

      test('a claim that throws keeps the hold, and the next seal claims '
          'again', () async {
        final coordinator = await started();
        var attempts = 0;
        when(
          () => queue.claimAboveMarker(
            roomId: any<String>(named: 'roomId'),
            readAppliedTs: any(named: 'readAppliedTs'),
            walkLocal: any(named: 'walkLocal'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw StateError('database is locked');
        });
        arrive();
        await deliverSync(limited: true);

        await finishResponse(coordinator);
        verifyNever(() => queue.catchUpMarker(any()));

        // The next response was not limited, but the failed claim is owed.
        await deliverSync(limited: false);
        await finishResponse(coordinator);

        expect(attempts, 2);
        verify(() => queue.catchUpMarker(roomId)).called(1);
        await coordinator.stop();
      });

      test('an event arriving while a limited seal is claiming stays held '
          'until a later seal covers it', () async {
        final coordinator = await started();
        final claimGate = Completer<void>();
        when(
          () => queue.claimAboveMarker(
            roomId: any<String>(named: 'roomId'),
            readAppliedTs: any(named: 'readAppliedTs'),
            walkLocal: any(named: 'walkLocal'),
          ),
        ).thenAnswer((_) => claimGate.future);
        arrive();
        await deliverSync(limited: true);
        statusCtl.add(const SyncStatusUpdate(SyncStatus.cleaningUp));
        await pumpEventQueue();

        // The next response's event arrives mid-claim.
        arrive();
        claimGate.complete();
        await coordinator.liveSealsSettled;
        verifyNever(() => queue.catchUpMarker(any()));

        await finishResponse(coordinator);
        verify(() => queue.catchUpMarker(roomId)).called(1);
        await coordinator.stop();
      });

      test('seals run one at a time: a quick seal waits for a limited one '
          'still claiming', () async {
        final coordinator = await started();
        final claimGate = Completer<void>();
        when(
          () => queue.claimAboveMarker(
            roomId: any<String>(named: 'roomId'),
            readAppliedTs: any(named: 'readAppliedTs'),
            walkLocal: any(named: 'walkLocal'),
          ),
        ).thenAnswer((_) => claimGate.future);
        arrive();
        await deliverSync(limited: true);
        statusCtl.add(const SyncStatusUpdate(SyncStatus.cleaningUp));
        await deliverSync(limited: false);
        statusCtl.add(const SyncStatusUpdate(SyncStatus.cleaningUp));
        await pumpEventQueue();

        verifyNever(() => queue.ensureResumeFloorPersisted(any()));

        claimGate.complete();
        await coordinator.liveSealsSettled;
        verify(() => queue.ensureResumeFloorPersisted(roomId)).called(1);
        await coordinator.stop();
      });
    });
  }
}
