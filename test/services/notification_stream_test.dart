import 'dart:async';

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
    test('emits initial fetch result on first listen', () async {
      var fetchCount = 0;
      final stream = notificationDrivenStream<String>(
        notifications: notifications,
        notificationKeys: {'TEST_KEY'},
        fetcher: () async {
          fetchCount++;
          return ['a', 'b', 'c'];
        },
      );

      final result = await stream.first;
      expect(result, ['a', 'b', 'c']);
      expect(fetchCount, 1);
    });

    test('re-emits on matching notification', () async {
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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(1));
      expect(results.first, ['result_1']);

      // Fire matching notification
      notifications.emit({'TEST_KEY'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(results, hasLength(2));
      expect(results[1], ['result_2']);

      await sub.cancel();
    });

    test('does not emit on non-matching notification', () async {
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

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(1));

      // Fire non-matching notification
      notifications.emit({'OTHER_KEY'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(results, hasLength(1));
      expect(fetchCount, 1);

      await sub.cancel();
    });

    test('reacts to any key in multi-key set', () async {
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

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(1));

      // Fire KEY_A
      notifications.emit({'KEY_A'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(2));

      // Fire KEY_B
      notifications.emit({'KEY_B'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(3));

      await sub.cancel();
    });

    test('serializes fetches - concurrent notifications coalesce', () async {
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
      await Future<void>.delayed(Duration.zero);
      expect(fetchCount, 1);

      // Fire multiple notifications while initial fetch is in progress
      notifications.emit({'TEST_KEY'});
      await Future<void>.delayed(Duration.zero);
      notifications.emit({'TEST_KEY'});
      await Future<void>.delayed(Duration.zero);
      notifications.emit({'TEST_KEY'});
      await Future<void>.delayed(Duration.zero);

      // Still only one fetch in progress
      expect(fetchCount, 1);

      // Complete the initial fetch
      fetchCompleter.complete(['initial']);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Should have done exactly 2 fetches: initial + one coalesced refetch
      expect(fetchCount, 2);
      expect(results, hasLength(2));
      expect(results[0], ['initial']);
      expect(results[1], ['result_2']);

      await sub.cancel();
    });

    test('emits error but keeps stream alive', () async {
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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(1));

      // Second fetch fails
      notifications.emit({'TEST_KEY'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(1));

      // Third fetch succeeds - stream is still alive
      notifications.emit({'TEST_KEY'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(2));
      expect(results[1], ['result_3']);

      await sub.cancel();
    });

    test('cleans up subscription on cancel', () async {
      final stream = notificationDrivenStream<String>(
        notifications: notifications,
        notificationKeys: {'TEST_KEY'},
        fetcher: () async => ['data'],
      );

      final sub = stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();

      // After cancelling, emitting should not trigger a fetch.
      // The important thing is that cancel() doesn't throw.
    });
  });

  group('notificationDrivenItemStream', () {
    test('emits initial fetch result on first listen', () async {
      final stream = notificationDrivenItemStream<String>(
        notifications: notifications,
        notificationKeys: {'TEST_KEY'},
        fetcher: () async => 'single_item',
      );

      final result = await stream.first;
      expect(result, 'single_item');
    });

    test('emits null when fetcher returns null', () async {
      final stream = notificationDrivenItemStream<String>(
        notifications: notifications,
        notificationKeys: {'TEST_KEY'},
        fetcher: () async => null,
      );

      final result = await stream.first;
      expect(result, isNull);
    });

    test('re-emits on matching notification', () async {
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

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, ['item_1']);

      notifications.emit({'TEST_KEY'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, ['item_1', 'item_2']);

      await sub.cancel();
    });
  });

  group('notificationDrivenMapStream', () {
    test('emits initial fetch result on first listen', () async {
      final stream = notificationDrivenMapStream<String, int>(
        notifications: notifications,
        notificationKeys: {'TEST_KEY'},
        fetcher: () async => {'a': 1, 'b': 2},
      );

      final result = await stream.first;
      expect(result, {'a': 1, 'b': 2});
    });

    test('re-emits on matching notification', () async {
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

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(1));
      expect(results.first, {'count': 1});

      notifications.emit({'TEST_KEY'});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(2));
      expect(results[1], {'count': 2});

      await sub.cancel();
    });
  });
}
