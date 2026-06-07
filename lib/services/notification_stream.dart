import 'dart:async';

import 'package:lotti/services/db_notification.dart';
import 'package:rxdart/rxdart.dart';

/// Generic helper that creates a broadcast stream which fetches data on first
/// listen and re-fetches whenever a matching notification arrives.
///
/// Fetches are serialized: if a notification arrives while a fetch is in
/// progress, one additional fetch is queued and executed after the current one
/// completes.
///
/// [refetchThrottle] caps notification-driven refetch frequency
/// (trailing-edge, so the last change in a burst always lands). Use it for
/// expensive fetchers that don't need sub-second freshness — e.g. active
/// typing emits a notification batch every ~100ms, which would otherwise
/// re-run the fetch on every batch.
Stream<R> _notificationDrivenStream<R>({
  required UpdateNotifications notifications,
  required Set<String> notificationKeys,
  required Future<R> Function() fetcher,
  Duration? refetchThrottle,
}) {
  late StreamController<R> controller;
  StreamSubscription<Set<String>>? sub;
  var fetching = false;
  var pendingRefetch = false;

  Future<void> doFetch() async {
    if (fetching) {
      pendingRefetch = true;
      return;
    }
    fetching = true;
    try {
      final result = await fetcher();
      if (!controller.isClosed) controller.add(result);
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    } finally {
      fetching = false;
      if (pendingRefetch && !controller.isClosed) {
        pendingRefetch = false;
        await doFetch();
      }
    }
  }

  controller = StreamController<R>.broadcast(
    onListen: () {
      doFetch();
      // Filter BEFORE throttling so unrelated tokens neither trigger nor
      // extend the throttle window.
      var updates = notifications.updateStream.where(
        (ids) => ids.any(notificationKeys.contains),
      );
      if (refetchThrottle != null) {
        updates = updates.throttleTime(
          refetchThrottle,
          leading: false,
          trailing: true,
        );
      }
      sub = updates.listen((_) => doFetch());
    },
    onCancel: () {
      sub?.cancel();
      sub = null;
    },
  );

  return controller.stream;
}

/// Creates a broadcast stream that emits an initial fetch result then re-emits
/// whenever any key in [notificationKeys] appears in the
/// [UpdateNotifications] stream.
///
/// The stream is broadcast-safe: multiple listeners can subscribe.
Stream<List<T>> notificationDrivenStream<T>({
  required UpdateNotifications notifications,
  required Set<String> notificationKeys,
  required Future<List<T>> Function() fetcher,
}) => _notificationDrivenStream<List<T>>(
  notifications: notifications,
  notificationKeys: notificationKeys,
  fetcher: fetcher,
);

/// Single-item variant. Same broadcast/serialization semantics.
Stream<T?> notificationDrivenItemStream<T>({
  required UpdateNotifications notifications,
  required Set<String> notificationKeys,
  required Future<T?> Function() fetcher,
  Duration? refetchThrottle,
}) => _notificationDrivenStream<T?>(
  notifications: notifications,
  notificationKeys: notificationKeys,
  fetcher: fetcher,
  refetchThrottle: refetchThrottle,
);

/// Map variant for non-list data (e.g., label usage counts).
Stream<Map<K, V>> notificationDrivenMapStream<K, V>({
  required UpdateNotifications notifications,
  required Set<String> notificationKeys,
  required Future<Map<K, V>> Function() fetcher,
}) => _notificationDrivenStream<Map<K, V>>(
  notifications: notifications,
  notificationKeys: notificationKeys,
  fetcher: fetcher,
);
