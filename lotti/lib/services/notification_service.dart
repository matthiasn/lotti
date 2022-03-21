import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:timezone/standalone.dart' as tz;

final JournalDb _db = getIt<JournalDb>();

class NotificationService {
  int badgeCount = 0;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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
    bool notifyEnabled = await _db.getConfigFlag('enable_notifications');

    if (Platform.isWindows || Platform.isLinux) {
      return;
    }

    await _requestPermissions();

    int count = await _db.getWipCount();

    if (count == badgeCount) {
      return;
    } else {
      badgeCount = count;
    }

    flutterLocalNotificationsPlugin.cancel(1);

    if (badgeCount == 0) {
      flutterLocalNotificationsPlugin.show(
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
      String title =
          '$badgeCount task${badgeCount == 1 ? '' : 's'} in progress';
      String body = badgeCount < 5 ? 'Nice' : 'Let\'s get that number down';

      flutterLocalNotificationsPlugin.show(
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
    required notificationId,
    String? deepLink,
  }) async {
    bool notifyEnabled = await _db.getConfigFlag('enable_notifications');

    if (Platform.isWindows || Platform.isLinux) {
      return;
    }

    await _requestPermissions();
    flutterLocalNotificationsPlugin.cancel(notificationId);

    DateTime now = DateTime.now();
    await tz.initializeTimeZone();

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.getLocation('Europe/Berlin'),
      now.year,
      now.month,
      now.day,
      notifyAt.hour,
      notifyAt.minute,
    );

    flutterLocalNotificationsPlugin.zonedSchedule(
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
    );
  }
}
