import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';

/// A simple wrapper around a real broadcast stream controller that exposes the
/// same [updateStream] getter as [UpdateNotifications], but without debouncing.
class TestNotifications implements UpdateNotifications {
  final _controller = StreamController<Set<String>>.broadcast();

  @override
  Stream<Set<String>> get updateStream => _controller.stream;

  void emit(Set<String> ids) {
    _controller.add(ids);
  }

  @override
  void notify(Set<String> affectedIds, {bool fromSync = false}) {
    emit(affectedIds);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  late TestNotifications notifications;

  setUp(() {
    notifications = TestNotifications();
  });

  tearDown(() async {
    await notifications.dispose();
  });

  group('notificationDrivenStream', () {
    test('emits initial fetch result on first listen', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final stream = notificationDrivenStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async {
            fetchCount++;
            return ['a', 'b', 'c'];
          },
        );

        final results = <List<String>>[];
        final sub = stream.listen(results.add);

        async.flushMicrotasks();
        expect(results, [
          ['a', 'b', 'c'],
        ]);
        expect(fetchCount, 1);

        sub.cancel();
      });
    });

    test('re-emits on matching notification', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final stream = notificationDrivenStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async {
            fetchCount++;
            return ['result_$fetchCount'];
          },
        );

        final results = <List<String>>[];
        final sub = stream.listen(results.add);

        // Wait for initial emission
        async.flushMicrotasks();
        expect(results, hasLength(1));
        expect(results.first, ['result_1']);

        // Fire matching notification
        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();

        expect(results, hasLength(2));
        expect(results[1], ['result_2']);

        sub.cancel();
      });
    });

    test('does not emit on non-matching notification', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final stream = notificationDrivenStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async {
            fetchCount++;
            return ['result_$fetchCount'];
          },
        );

        final results = <List<String>>[];
        final sub = stream.listen(results.add);

        async.flushMicrotasks();
        expect(results, hasLength(1));

        // Fire non-matching notification
        notifications.emit({'OTHER_KEY'});
        async.flushMicrotasks();

        expect(results, hasLength(1));
        expect(fetchCount, 1);

        sub.cancel();
      });
    });

    test('reacts to any key in multi-key set', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final stream = notificationDrivenStream<String>(
          notifications: notifications,
          notificationKeys: {'KEY_A', 'KEY_B'},
          fetcher: () async {
            fetchCount++;
            return ['result_$fetchCount'];
          },
        );

        final results = <List<String>>[];
        final sub = stream.listen(results.add);

        async.flushMicrotasks();
        expect(results, hasLength(1));

        // Fire KEY_A
        notifications.emit({'KEY_A'});
        async.flushMicrotasks();
        expect(results, hasLength(2));

        // Fire KEY_B
        notifications.emit({'KEY_B'});
        async.flushMicrotasks();
        expect(results, hasLength(3));

        sub.cancel();
      });
    });

    test('serializes fetches - concurrent notifications coalesce', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final fetchCompleter = Completer<List<String>>();

        final stream = notificationDrivenStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async {
            fetchCount++;
            if (fetchCount == 1) {
              return fetchCompleter.future;
            }
            return ['result_$fetchCount'];
          },
        );

        final results = <List<String>>[];
        final sub = stream.listen(results.add);

        // Initial fetch starts (blocked on completer)
        async.flushMicrotasks();
        expect(fetchCount, 1);

        // Fire multiple notifications while initial fetch is in progress
        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();
        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();
        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();

        // Still only one fetch in progress
        expect(fetchCount, 1);

        // Complete the initial fetch
        fetchCompleter.complete(['initial']);
        async.flushMicrotasks();

        // Should have done exactly 2 fetches: initial + one coalesced refetch
        expect(fetchCount, 2);
        expect(results, hasLength(2));
        expect(results[0], ['initial']);
        expect(results[1], ['result_2']);

        sub.cancel();
      });
    });

    test('emits error but keeps stream alive', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final stream = notificationDrivenStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async {
            fetchCount++;
            if (fetchCount == 2) {
              throw Exception('fetch failed');
            }
            return ['result_$fetchCount'];
          },
        );

        final results = <List<String>>[];
        final errors = <Object>[];
        final sub = stream.listen(results.add, onError: errors.add);

        // Initial fetch succeeds
        async.flushMicrotasks();
        expect(results, hasLength(1));

        // Second fetch fails
        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();
        expect(errors, hasLength(1));

        // Third fetch succeeds - stream is still alive
        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();
        expect(results, hasLength(2));
        expect(results[1], ['result_3']);

        sub.cancel();
      });
    });

    test('pending refetch fires after error recovery', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final blockingCompleter = Completer<List<String>>();

        final stream = notificationDrivenStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async {
            fetchCount++;
            if (fetchCount == 1) {
              return blockingCompleter.future;
            }
            if (fetchCount == 2) {
              throw Exception('transient error');
            }
            return ['recovered_$fetchCount'];
          },
        );

        final results = <List<String>>[];
        final errors = <Object>[];
        final sub = stream.listen(results.add, onError: errors.add);

        // Initial fetch starts (blocked)
        async.flushMicrotasks();
        expect(fetchCount, 1);

        // Fire notification while initial fetch is blocked → sets pending
        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();

        // Complete the initial fetch → triggers pending refetch (which fails)
        blockingCompleter.complete(['initial']);
        async.flushMicrotasks();

        expect(results, [
          ['initial'],
        ]);
        expect(errors, hasLength(1));
        expect(fetchCount, 2);

        // Fire another notification → stream is still alive after error
        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();

        expect(results, hasLength(2));
        expect(results[1], ['recovered_3']);

        sub.cancel();
      });
    });

    test('does not emit when controller is closed during fetch', () {
      fakeAsync((async) {
        final completer = Completer<List<String>>();
        final stream = notificationDrivenStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async => completer.future,
        );

        final results = <List<String>>[];
        final sub = stream.listen(results.add);
        async.flushMicrotasks();

        // Cancel subscription (triggers onCancel → closes controller)
        sub.cancel();

        // Complete fetch after controller is closed → should not throw
        completer.complete(['too_late']);
        async.flushMicrotasks();

        expect(results, isEmpty);
      });
    });

    test('cleans up subscription on cancel', () {
      fakeAsync((async) {
        final stream = notificationDrivenStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async => ['data'],
        );

        final sub = stream.listen((_) {});
        async.flushMicrotasks();

        sub.cancel();

        // After cancelling, emitting should not trigger a fetch.
        // The important thing is that cancel() doesn't throw.
      });
    });
  });

  group('notificationDrivenItemStream', () {
    test('emits initial fetch result on first listen', () {
      fakeAsync((async) {
        final stream = notificationDrivenItemStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async => 'single_item',
        );

        final results = <String?>[];
        final sub = stream.listen(results.add);

        async.flushMicrotasks();
        expect(results, ['single_item']);

        sub.cancel();
      });
    });

    test('emits null when fetcher returns null', () {
      fakeAsync((async) {
        final stream = notificationDrivenItemStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async => null,
        );

        final results = <String?>[];
        final sub = stream.listen(results.add);

        async.flushMicrotasks();
        expect(results, [null]);

        sub.cancel();
      });
    });

    test('re-emits on matching notification', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final stream = notificationDrivenItemStream<String>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async {
            fetchCount++;
            return 'item_$fetchCount';
          },
        );

        final results = <String?>[];
        final sub = stream.listen(results.add);

        async.flushMicrotasks();
        expect(results, ['item_1']);

        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();
        expect(results, ['item_1', 'item_2']);

        sub.cancel();
      });
    });
  });

  group('notificationDrivenMapStream', () {
    test('emits initial fetch result on first listen', () {
      fakeAsync((async) {
        final stream = notificationDrivenMapStream<String, int>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async => {'a': 1, 'b': 2},
        );

        final results = <Map<String, int>>[];
        final sub = stream.listen(results.add);

        async.flushMicrotasks();
        expect(results, [
          {'a': 1, 'b': 2},
        ]);

        sub.cancel();
      });
    });

    test('re-emits on matching notification', () {
      fakeAsync((async) {
        var fetchCount = 0;
        final stream = notificationDrivenMapStream<String, int>(
          notifications: notifications,
          notificationKeys: {'TEST_KEY'},
          fetcher: () async {
            fetchCount++;
            return {'count': fetchCount};
          },
        );

        final results = <Map<String, int>>[];
        final sub = stream.listen(results.add);

        async.flushMicrotasks();
        expect(results, hasLength(1));
        expect(results.first, {'count': 1});

        notifications.emit({'TEST_KEY'});
        async.flushMicrotasks();
        expect(results, hasLength(2));
        expect(results[1], {'count': 2});

        sub.cancel();
      });
    });
  });
}
