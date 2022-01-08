import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';

class NotificationService {
  static FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> updateBadge() async {
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

    final JournalDb _journalDb = getIt<JournalDb>();
    int counter = await _journalDb.getCountImportFlagEntries();
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
          presentAlert: true,
          presentBadge: true,
          badgeNumber: counter,
        ),
        macOS: MacOSNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          badgeNumber: counter,
        ),
      ),
    );
  }
}
