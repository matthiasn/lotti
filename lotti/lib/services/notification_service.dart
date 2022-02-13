import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';

final JournalDb _db = getIt<JournalDb>();

class NotificationService {
  static FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> updateBadge() async {
    bool notifyEnabled = await _db.getConfigFlag('enable_notifications');

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

    int counter = await _db.getCountImportFlagEntries();
    if (counter == 0) {
      flutterLocalNotificationsPlugin.show(
        1,
        '',
        '',
        NotificationDetails(
          iOS: IOSNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            badgeNumber: counter,
          ),
          macOS: MacOSNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            badgeNumber: counter,
          ),
        ),
      );

      return;
    }

    String title = '$counter entr${counter == 1 ? 'y' : 'ies'} flagged import';
    String body = 'Please annotate/review';

    flutterLocalNotificationsPlugin.show(
      1,
      title,
      body,
      NotificationDetails(
        iOS: IOSNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          badgeNumber: counter,
        ),
        macOS: MacOSNotificationDetails(
          presentAlert: notifyEnabled,
          presentBadge: true,
          badgeNumber: counter,
        ),
      ),
    );
  }
}
