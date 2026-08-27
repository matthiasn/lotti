import 'dart:convert';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/services/notification_service.dart';

class NotificationScheduler {
  /// [_notificationServiceProvider] is invoked the first time the scheduler
  /// needs to talk to the OS notification plugin. Wrapping the lookup in a
  /// thunk keeps `NotificationService` lazy: it is not materialised at app
  /// startup just to wire up the scheduler, so sandboxed builds (e.g. flatpak)
  /// where the plugin may fail to register stay startable.
  NotificationScheduler({
    required this._notificationsDb,
    required this._notificationServiceProvider,
  });

  final NotificationsDb _notificationsDb;
  final NotificationService Function() _notificationServiceProvider;

  NotificationService get _notificationService =>
      _notificationServiceProvider();

  static const int _fnvOffsetBasis32 = 0x811c9dc5;
  static const int _fnvPrime32 = 0x01000193;
  static const int _mask31 = 0x7fffffff;

  static int notificationIdFor(String id) {
    var hash = _fnvOffsetBasis32;
    for (final byte in utf8.encode(id)) {
      hash ^= byte;
      hash = (hash * _fnvPrime32) & 0xffffffff;
    }
    return hash & _mask31;
  }

  Future<void> schedule(NotificationEntity entity, {DateTime? now}) async {
    final notificationId = notificationIdFor(entity.id);
    if (entity.meta.deletedAt != null ||
        entity.meta.seenAt != null ||
        entity.meta.actedOnAt != null) {
      // Match the dueNow/upcoming queries: rows acted on (regardless of seen
      // state) are no longer schedulable, so cancel any stale OS-level alert.
      await _notificationService.cancelNotification(notificationId);
      return;
    }

    final effectiveNow = now ?? DateTime.now();
    if (!entity.meta.scheduledFor.isAfter(effectiveNow)) {
      await _notificationService.showNotificationNow(
        title: entity.title,
        body: entity.body,
        notificationId: notificationId,
        showOnMobile: true,
        showOnDesktop: true,
        deepLink: _deepLinkFor(entity),
      );
      return;
    }

    await _notificationService.scheduleNotificationAt(
      title: entity.title,
      body: entity.body,
      notifyAt: entity.meta.scheduledFor,
      notificationId: notificationId,
      showOnMobile: true,
      showOnDesktop: true,
      deepLink: _deepLinkFor(entity),
    );
  }

  /// Re-arms OS alarms that the operating system lost but the database kept.
  ///
  /// An alarm set before an app update, a reinstall, or (on Android) a reboot
  /// is gone, while the durable row describing it still sits in
  /// `notifications.sqlite`. [schedule] is only ever called on a write — so
  /// without this a reminder armed weeks ahead silently stops existing at the
  /// OS level. The same gap exists for rows written while the
  /// `enable_notifications` flag was off (the platform calls are gated on it),
  /// which is why flipping that flag on also runs this.
  ///
  /// **Only future rows.** A row that is already due needs no alarm: it is by
  /// definition sitting in the inbox, on the device the user is holding.
  /// Re-announcing it would mean an OS banner *per launch*, forever — showing
  /// a notification does not mark the row, and with no tap handler wired the
  /// only way to clear one is the in-app bell. That turns every unacknowledged
  /// alert into a permanent startup nag.
  ///
  /// The query already filters to unseen/unacted/undeleted rows, so a row the
  /// user dealt with on any device is never revived. [NotificationService] is
  /// resolved lazily by [schedule], so an empty inbox costs one indexed query
  /// and does **not** materialise the platform plugin.
  Future<void> reconcile({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    for (final entity in await _notificationsDb.upcoming(effectiveNow)) {
      await schedule(entity, now: effectiveNow);
    }
  }

  /// Where tapping the OS notification should land.
  ///
  /// Exhaustive over the union rather than reading `linkedEntityId`: that
  /// getter answers "some entity" for every variant, and routing a
  /// relationship id into `/tasks/` produced a dead route rather than a
  /// visible error.
  String? _deepLinkFor(NotificationEntity entity) => switch (entity) {
    TaskSuggestionNotification(:final linkedTaskId) => '/tasks/$linkedTaskId',
    TaskOverdueNotification(:final linkedTaskId) => '/tasks/$linkedTaskId',
    RelationshipCheckInNotification(:final linkedRelationshipId) =>
      '/people/$linkedRelationshipId',
    HabitAutoCompletedNotification() => '/habits',
  };
}
