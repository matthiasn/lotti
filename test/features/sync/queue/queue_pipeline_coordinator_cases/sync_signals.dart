part of '../queue_pipeline_coordinator_test.dart';

extension _SyncSignalCases on _QueueCoordinatorTestSetup {
  void registerSyncSignals() {
    test('handles onSync signal: postLoad called on partial room', () async {
      final room = MockRoom();
      when(() => room.partial).thenReturn(true);
      when(room.postLoad).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);

      final coordinator = build();
      await coordinator.start();

      syncCtl.add(SyncUpdate(nextBatch: 'x'));
      // Allow the async listener to fire and the follow-up postLoad future.
      await pumpEventQueue();

      verify(room.postLoad).called(1);
      await coordinator.stop();
    });

    test('overlapping sync signals share one in-flight postLoad', () async {
      final room = MockRoom();
      final postLoadGate = Completer<void>();
      when(() => room.partial).thenReturn(true);
      when(room.postLoad).thenAnswer((_) => postLoadGate.future);
      when(() => roomManager.currentRoom).thenReturn(room);

      final coordinator = build();
      await coordinator.start();

      syncCtl
        ..add(SyncUpdate(nextBatch: 'first'))
        ..add(SyncUpdate(nextBatch: 'second'));
      await pumpEventQueue();

      verify(room.postLoad).called(1);

      postLoadGate.complete();
      await coordinator.stop();
    });

    test(
      'onSync does not call postLoad when room is already non-partial',
      () async {
        final room = MockRoom();
        when(() => room.partial).thenReturn(false);
        when(room.postLoad).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);

        final coordinator = build();
        await coordinator.start();

        syncCtl.add(SyncUpdate(nextBatch: 'x'));
        await pumpEventQueue();

        verifyNever(room.postLoad);
        await coordinator.stop();
      },
    );
  }

  void registerSyncSignalErrors() {
    test('postLoad error drops the marker so a later sync retries', () async {
      final room = MockRoom();
      when(() => room.partial).thenReturn(true);
      when(room.postLoad).thenThrow(StateError('sdk down'));
      when(() => roomManager.currentRoom).thenReturn(room);

      final coordinator = build();
      await coordinator.start();

      syncCtl.add(SyncUpdate(nextBatch: 'x'));
      await pumpEventQueue();

      verify(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(
            named: 'subDomain',
            that: contains('postLoad'),
          ),
        ),
      ).called(1);

      syncCtl.add(SyncUpdate(nextBatch: 'retry'));
      await pumpEventQueue();

      verify(room.postLoad).called(2);
      await coordinator.stop();
    });

    test('onSync error handler logs and does not crash', () async {
      final coordinator = build();
      await coordinator.start();

      syncCtl.addError(StateError('sync broke'), StackTrace.current);
      await pumpEventQueue();

      verify(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain', that: contains('syncSub')),
        ),
      ).called(1);
      await coordinator.stop();
    });
  }
}
