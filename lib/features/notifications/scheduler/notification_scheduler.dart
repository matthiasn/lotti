import 'dart:convert';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/consts.dart';

class NotificationScheduler {
  /// [notificationServiceProvider] is invoked the first time the scheduler
  /// needs to talk to the OS notification plugin. Wrapping the lookup in a
  /// thunk keeps `NotificationService` lazy: it is not materialised at app
  /// startup just to wire up the scheduler, so sandboxed builds (e.g. flatpak)
  /// where the plugin may fail to register stay startable.
  NotificationScheduler({
    required NotificationsDb notificationsDb,
    required NotificationService Function() notificationServiceProvider,
    required JournalDb journalDb,
  }) : _notificationsDb = notificationsDb,
       _notificationServiceProvider = notificationServiceProvider,
       _journalDb = journalDb;

  final NotificationsDb _notificationsDb;
  final NotificationService Function() _notificationServiceProvider;
  final JournalDb _journalDb;

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
    final enabled = await _journalDb.getConfigFlag(enableSyncedAlertsFlag);
    if (!enabled ||
        entity.meta.deletedAt != null ||
        entity.meta.seenAt != null) {
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

  Future<void> cancel(String id) {
    return _notificationService.cancelNotification(notificationIdFor(id));
  }

  Future<void> reconcile({DateTime? now}) async {
    final enabled = await _journalDb.getConfigFlag(enableSyncedAlertsFlag);
    final effectiveNow = now ?? DateTime.now();
    final due = await _notificationsDb.dueNow(effectiveNow);
    final upcoming = await _notificationsDb.upcoming(effectiveNow);

    if (!enabled) {
      // Flag was turned off after rows were scheduled at the OS level.
      // Cancel them so stale alerts cannot still fire.
      for (final entity in [...due, ...upcoming]) {
        await cancel(entity.id);
      }
      return;
    }

    for (final entity in due) {
      await schedule(entity, now: effectiveNow);
    }
    for (final entity in upcoming) {
      await schedule(entity, now: effectiveNow);
    }
  }

  String? _deepLinkFor(NotificationEntity entity) {
    final linkedId = entity.linkedEntityId;
    return linkedId == null ? null : '/tasks/$linkedId';
  }
}
