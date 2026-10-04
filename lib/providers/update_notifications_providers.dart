import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Optional UpdateNotifications service from GetIt.
final maybeUpdateNotificationsProvider = Provider<UpdateNotifications?>(
  maybeUpdateNotifications,
  name: 'maybeUpdateNotificationsProvider',
);
UpdateNotifications? maybeUpdateNotifications(Ref ref) {
  if (!getIt.isRegistered<UpdateNotifications>()) {
    return null;
  }
  return getIt<UpdateNotifications>();
}

/// Required UpdateNotifications service for agent runtime wiring.
final updateNotificationsProvider = Provider<UpdateNotifications>(
  updateNotifications,
  name: 'updateNotificationsProvider',
);
UpdateNotifications updateNotifications(Ref ref) {
  final notifications = ref.watch(maybeUpdateNotificationsProvider);
  if (notifications == null) {
    throw StateError('UpdateNotifications is not registered in GetIt');
  }
  return notifications;
}
