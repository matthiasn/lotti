import 'dart:async';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_inbox_controller.g.dart';

/// Reactive count of unseen notifications that should pulse the bell badge.
///
/// Refreshes whenever an entry in `UpdateNotifications.updateStream` contains
/// [inboxNotification] — every notification create / state change / sync apply
/// path already emits that constant via `NotificationRepository._notify` and
/// the matrix sync handlers, so the bell stays in step with the database.
///
/// `_refresh` guards against two failure modes that bit a previous revision:
/// 1. **Unhandled async errors** — wrapped in try/catch and surfaced as
///    `AsyncError` so the consumer (the bell) can render a neutral fallback
///    instead of crashing the listener.
/// 2. **Stale completion order** — concurrent stream events can fan out
///    multiple `_refresh()` calls. An epoch counter discards results from any
///    refresh that finishes after a newer one started, so the latest fetch
///    always wins regardless of database latency.
@Riverpod(keepAlive: true)
class UnseenNotificationCount extends _$UnseenNotificationCount {
  StreamSubscription<Set<String>>? _sub;
  int _refreshEpoch = 0;

  @override
  Future<int> build() async {
    ref.onDispose(() => _sub?.cancel());
    _sub = getIt<UpdateNotifications>().updateStream.listen((affectedIds) {
      if (affectedIds.contains(inboxNotification)) {
        unawaited(_refresh());
      }
    });
    return _fetch();
  }

  Future<int> _fetch() => getIt<NotificationsDb>().unseenCount(DateTime.now());

  Future<void> _refresh() async {
    final epoch = ++_refreshEpoch;
    try {
      final next = await _fetch();
      if (epoch != _refreshEpoch) return;
      if (next != state.value) {
        state = AsyncData(next);
      }
    } catch (error, stackTrace) {
      if (epoch != _refreshEpoch) return;
      state = AsyncError(error, stackTrace);
    }
  }
}

/// Sorted list of notifications that belong in the inbox popover.
///
/// "Inbox-worthy" means the same predicate `dueNotificationRows` /
/// `upcomingNotificationRows` apply at the SQL layer: still unseen, unacted,
/// and not deleted. The two streams are concatenated due-first then upcoming,
/// matching the visual ordering users expect (overdue alerts on top).
///
/// `_refresh` uses the same epoch + try/catch guard as
/// [UnseenNotificationCount] — see that class's doc comment for the reasoning.
@Riverpod(keepAlive: true)
class InboxNotifications extends _$InboxNotifications {
  StreamSubscription<Set<String>>? _sub;
  int _refreshEpoch = 0;

  @override
  Future<List<NotificationEntity>> build() async {
    ref.onDispose(() => _sub?.cancel());
    _sub = getIt<UpdateNotifications>().updateStream.listen((affectedIds) {
      if (affectedIds.contains(inboxNotification)) {
        unawaited(_refresh());
      }
    });
    return _fetch();
  }

  Future<List<NotificationEntity>> _fetch() async {
    final db = getIt<NotificationsDb>();
    final now = DateTime.now();
    final due = await db.dueNow(now);
    final upcoming = await db.upcoming(now);
    return [...due, ...upcoming];
  }

  Future<void> _refresh() async {
    final epoch = ++_refreshEpoch;
    try {
      final next = await _fetch();
      if (epoch != _refreshEpoch) return;
      state = AsyncData(next);
    } catch (error, stackTrace) {
      if (epoch != _refreshEpoch) return;
      state = AsyncError(error, stackTrace);
    }
  }
}
