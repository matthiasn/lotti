import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/descriptor_catch_up_manager.dart';
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

  test('cancelSubscriptions exception is suppressed', () async {
    final logging = MockLoggingService();
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
  });
  // Additional behavior is covered indirectly by MatrixStreamConsumer tests.
}
