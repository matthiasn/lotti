// ignore_for_file: cascade_invocations

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockEvent extends Mock implements Event {}

class _FakeTimeline extends Fake implements Timeline {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_FakeTimeline());
  });

  test('addPending/contains handle both path variants', () {
    final logging = MockLoggingService();
    final index = AttachmentIndex(logging: logging);
    final roomManager = MockSyncRoomManager();
    final manager = DescriptorCatchUpManager(
      logging: logging,
      attachmentIndex: index,
      roomManager: roomManager,
      scheduleLiveScan: () {},
      retryNow: () async {},
    )..addPending('/a/b.json');

    expect(manager.contains('/a/b.json'), isTrue);
    expect(manager.contains('a/b.json'), isTrue);
  });

  test('removeIfPresent clears both variants', () {
    final logging = MockLoggingService();
    final index = AttachmentIndex(logging: logging);
    final roomManager = MockSyncRoomManager();
    final manager = DescriptorCatchUpManager(
      logging: logging,
      attachmentIndex: index,
      roomManager: roomManager,
      scheduleLiveScan: () {},
      retryNow: () async {},
    )..addPending('/x/y.json');

    expect(manager.contains('/x/y.json'), isTrue);
    expect(manager.contains('x/y.json'), isTrue);
    final removed = manager.removeIfPresent('x/y.json');
    expect(removed, isTrue);
    expect(manager.contains('/x/y.json'), isFalse);
    expect(manager.contains('x/y.json'), isFalse);
  });

  test('timer-driven run occurs only after stable delay', () {
    fakeAsync((async) {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final index = AttachmentIndex(logging: logging);
      final roomManager = MockSyncRoomManager();
      final room = MockRoom();
      final timeline = MockTimeline();
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => roomManager.currentRoom).thenReturn(room);

      final manager = DescriptorCatchUpManager(
        logging: logging,
        attachmentIndex: index,
        roomManager: roomManager,
        scheduleLiveScan: () {},
        retryNow: () async {},
        now: () =>
            DateTime.fromMillisecondsSinceEpoch(async.elapsed.inMilliseconds),
      )..addPending('p.json');

      // Before 2s, no run
      async.elapse(const Duration(milliseconds: 1500));
      expect(manager.runs, 0);
      // After 2s, a run happens
      async.elapse(const Duration(milliseconds: 700));
      expect(manager.runs, 1);
    });
  });

  test('changing pending within delay defers run until next stable window', () {
    fakeAsync((async) {
      final logging = MockLoggingService();
      final index = AttachmentIndex(logging: logging);
      final roomManager = MockSyncRoomManager();
      final room = MockRoom();
      final timeline = MockTimeline();
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => roomManager.currentRoom).thenReturn(room);

      final manager = DescriptorCatchUpManager(
        logging: logging,
        attachmentIndex: index,
        roomManager: roomManager,
        scheduleLiveScan: () {},
        retryNow: () async {},
        now: () =>
            DateTime.fromMillisecondsSinceEpoch(async.elapsed.inMilliseconds),
      )..addPending('p.json');

      // Change pending late in the window; should reset the delay
      async.elapse(const Duration(milliseconds: 1500));
      manager.addPending('q.json');
      async.elapse(const Duration(milliseconds: 500)); // total 2s since start
      expect(manager.runs, 0);
      async.elapse(const Duration(milliseconds: 500)); // 1s after change
      expect(manager.runs, 0);
      async.elapse(const Duration(milliseconds: 1000)); // now stable
      expect(manager.runs, 1);
    });
  });

  test('no room: run is skipped and counters unchanged', () async {
    final logging = MockLoggingService();
    final index = AttachmentIndex(logging: logging);
    final roomManager = MockSyncRoomManager();
    when(() => roomManager.currentRoom).thenReturn(null);

    var liveScanCalls = 0;
    var retryNowCalls = 0;
    final manager = DescriptorCatchUpManager(
      logging: logging,
      attachmentIndex: index,
      roomManager: roomManager,
      scheduleLiveScan: () => liveScanCalls++,
      retryNow: () async => retryNowCalls++,
      now: DateTime.now,
    );
    await manager.debugRunNow();
    expect(manager.runs, 0);
    expect(liveScanCalls, 0);
    expect(retryNowCalls, 0);
  });

  test('no pending hits: does not trigger callbacks', () async {
    final logging = MockLoggingService();
    final index = AttachmentIndex(logging: logging);
    final roomManager = MockSyncRoomManager();
    final room = MockRoom();
    final timeline = MockTimeline();
    final ev = MockEvent();
    when(() => ev.content).thenReturn(<String, dynamic>{});
    when(() => timeline.events).thenReturn(<Event>[ev]);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => timeline);
    when(() => roomManager.currentRoom).thenReturn(room);

    var liveScanCalls = 0;
    var retryNowCalls = 0;
    final manager = DescriptorCatchUpManager(
      logging: logging,
      attachmentIndex: index,
      roomManager: roomManager,
      scheduleLiveScan: () => liveScanCalls++,
      retryNow: () async => retryNowCalls++,
      now: DateTime.now,
    )..addPending('x.json');
    await manager.debugRunNow();
    expect(manager.runs, 1);
    expect(liveScanCalls, 0);
    expect(retryNowCalls, 0);
  });

  test('cancelSubscriptions exception is logged and suppressed', () async {
    final logging = MockLoggingService();
    when(() => logging.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);
    final index = AttachmentIndex(logging: logging);
    final roomManager = MockSyncRoomManager();
    final room = MockRoom();
    final timeline = MockTimeline();
    when(() => timeline.events).thenReturn(<Event>[]);
    // ignore:unnecessary_lambdas
    when(() => timeline.cancelSubscriptions()).thenThrow(Exception('boom'));
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => timeline);
    when(() => roomManager.currentRoom).thenReturn(room);

    final manager = DescriptorCatchUpManager(
      logging: logging,
      attachmentIndex: index,
      roomManager: roomManager,
      scheduleLiveScan: () {},
      retryNow: () async {},
      now: DateTime.now,
    );
    await manager.debugRunNow();
    expect(manager.runs, 1);
    verify(() => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: 'descriptorCatchUp.cleanup',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).called(1);
  });

  test(
      'rapid add/remove during async run schedules another run after stable window',
      () {
    fakeAsync((async) {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final index = AttachmentIndex(logging: logging);
      final roomManager = MockSyncRoomManager();
      final room = MockRoom();
      final timeline = MockTimeline();
      when(() => timeline.events).thenReturn(<Event>[]);
      // Delay getTimeline to simulate async work during which pending changes occur
      when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return timeline;
        },
      );
      when(() => roomManager.currentRoom).thenReturn(room);

      final manager = DescriptorCatchUpManager(
        logging: logging,
        attachmentIndex: index,
        roomManager: roomManager,
        scheduleLiveScan: () {},
        retryNow: () async {},
        now: () =>
            DateTime.fromMillisecondsSinceEpoch(async.elapsed.inMilliseconds),
      )..addPending('a.json');

      // Wait past stability window to kick off first run
      async.elapse(const Duration(seconds: 2));
      expect(manager.runs, 0);

      // While run is in-flight, change pending to reset stability
      async.elapse(const Duration(milliseconds: 100));
      manager.addPending('b.json');

      // Allow first run to complete
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();
      // Ensure any queued timers/microtasks progress
      async.elapse(Duration.zero);
      async.flushMicrotasks();
      expect(manager.runs, 1);

      // Next run should be scheduled and occur only after another stable window
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      async.elapse(Duration.zero);
      async.flushMicrotasks();
      expect(manager.runs, 1);
      async.elapse(const Duration(seconds: 1));
      // Allow the second run's async getTimeline to complete
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();
      async.elapse(Duration.zero);
      async.flushMicrotasks();
      expect(manager.runs, 2);
    });
  });

  test('_runCatchUp exception is logged (timer path)', () {
    fakeAsync((async) {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final index = AttachmentIndex(logging: logging);
      final roomManager = MockSyncRoomManager();
      final room = MockRoom();
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenThrow(Exception('snapshot error'));
      when(() => roomManager.currentRoom).thenReturn(room);

      final manager = DescriptorCatchUpManager(
        logging: logging,
        attachmentIndex: index,
        roomManager: roomManager,
        scheduleLiveScan: () {},
        retryNow: () async {},
        now: () =>
            DateTime.fromMillisecondsSinceEpoch(async.elapsed.inMilliseconds),
      )..addPending('x.json');

      // Trigger timer
      async
        ..elapse(const Duration(seconds: 2))
        // Allow microtasks to run
        ..flushMicrotasks();

      // Exception should be logged; runs should remain 0 since early failure
      verify(() => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'descriptorCatchUp',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).called(greaterThanOrEqualTo(1));
      expect(manager.runs, 0);
    });
  });

  test('does not run catch-up concurrently (in-flight guard)', () {
    fakeAsync((async) {
      final logging = MockLoggingService();
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      final index = AttachmentIndex(logging: logging);
      final roomManager = MockSyncRoomManager();
      final room = MockRoom();
      final timeline = MockTimeline();
      when(() => timeline.events).thenReturn(<Event>[]);

      var concurrent = 0;
      var maxConcurrent = 0;
      when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer(
        (_) async {
          concurrent++;
          if (concurrent > maxConcurrent) maxConcurrent = concurrent;
          // Keep this run in-flight for a bit
          await Future<void>.delayed(const Duration(milliseconds: 500));
          concurrent--;
          return timeline;
        },
      );
      when(() => roomManager.currentRoom).thenReturn(room);

      final manager = DescriptorCatchUpManager(
        logging: logging,
        attachmentIndex: index,
        roomManager: roomManager,
        scheduleLiveScan: () {},
        retryNow: () async {},
        now: () =>
            DateTime.fromMillisecondsSinceEpoch(async.elapsed.inMilliseconds),
      )..addPending('a.json');

      // Trigger first run
      async
        ..elapse(const Duration(seconds: 2))
        // While first run is in progress, add another pending to request another pass
        ..elapse(const Duration(milliseconds: 100));
      manager.addPending('b.json');

      // Let first run finish and the subsequent scheduled run occur
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();
      async.elapse(Duration.zero);
      async.flushMicrotasks();
      // After completion, another stable window elapses and a second run should happen
      async.elapse(const Duration(seconds: 2));
      // Allow the second run's async getTimeline to complete
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();
      async.elapse(Duration.zero);
      async.flushMicrotasks();

      expect(manager.runs, greaterThanOrEqualTo(2));
      expect(maxConcurrent, 1);
    });
  });
  // Additional behavior is covered indirectly by MatrixStreamConsumer tests.
}
// ignore_for_file:
