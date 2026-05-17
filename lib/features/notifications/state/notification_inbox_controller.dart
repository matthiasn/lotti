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
@Riverpod(keepAlive: true)
class UnseenNotificationCount extends _$UnseenNotificationCount {
  StreamSubscription<Set<String>>? _sub;

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
    final next = await _fetch();
    if (next != state.value) {
      state = AsyncData(next);
    }
  }
}

/// Sorted list of notifications that belong in the inbox popover.
///
/// "Inbox-worthy" means the same predicate `dueNotificationRows` /
/// `upcomingNotificationRows` apply at the SQL layer: still unseen, unacted,
/// and not deleted. The two streams are concatenated due-first then upcoming,
/// matching the visual ordering users expect (overdue alerts on top).
@Riverpod(keepAlive: true)
class InboxNotifications extends _$InboxNotifications {
  StreamSubscription<Set<String>>? _sub;

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
    final next = await _fetch();
    state = AsyncData(next);
  }
}
