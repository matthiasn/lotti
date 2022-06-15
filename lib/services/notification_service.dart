import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:timezone/standalone.dart' as tz;

final JournalDb _db = getIt<JournalDb>();

class NotificationService {
  NotificationService() {
    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        macOS: MacOSInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        ),
        iOS: IOSInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        ),
      ),
      onSelectNotification: onSelectNotification,
    );
  }

  int badgeCount = 0;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> onSelectNotification(String? payload) async {
    if (payload != null) {
      await getIt<AppRouter>().pushNamed(payload);
    }

    final details =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (details?.payload != null) {
      await getIt<AppRouter>().pushNamed('${details?.payload}');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isWindows || Platform.isLinux) {
      return;
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> updateBadge() async {
    final notifyEnabled = await _db.getConfigFlag('enable_notifications');

    if (Platform.isWindows || Platform.isLinux) {
      return;
    }

    await _requestPermissions();

    final count = await _db.getWipCount();

    if (count == badgeCount) {
      return;
    } else {
      badgeCount = count;
    }

    await flutterLocalNotificationsPlugin.cancel(1);

    if (badgeCount == 0) {
      await flutterLocalNotificationsPlugin.show(
        1,
        '',
        '',
        NotificationDetails(
          iOS: IOSNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            badgeNumber: badgeCount,
          ),
          macOS: MacOSNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            badgeNumber: badgeCount,
          ),
        ),
      );

      return;
    } else {
      final title = '$badgeCount task${badgeCount == 1 ? '' : 's'} in progress';
      final body = badgeCount < 5 ? 'Nice' : "Let's get that number down";

      await flutterLocalNotificationsPlugin.show(
        1,
        title,
        body,
        NotificationDetails(
          iOS: IOSNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            badgeNumber: badgeCount,
          ),
          macOS: MacOSNotificationDetails(
            presentAlert: notifyEnabled,
            presentBadge: true,
            badgeNumber: badgeCount,
          ),
        ),
      );
    }
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime notifyAt,
    required int notificationId,
    String? deepLink,
  }) async {
    if (Platform.isWindows || Platform.isLinux) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(notificationId);
    final now = DateTime.now();
    final scheduledDate = tz.TZDateTime(
      tz.getLocation('Europe/Berlin'),
      now.year,
      now.month,
      now.day,
      notifyAt.hour,
      notifyAt.minute,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        iOS: IOSNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        macOS: MacOSNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      androidAllowWhileIdle: true,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: deepLink,
    );
  }

  Future<void> showNotification({
    required String title,
    required String body,
    required int notificationId,
    String? deepLink,
  }) async {
    if (Platform.isWindows || Platform.isLinux) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(notificationId);

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      const NotificationDetails(
        iOS: IOSNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        macOS: MacOSNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: deepLink,
    );
  }
}
