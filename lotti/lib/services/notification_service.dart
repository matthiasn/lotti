import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static Future<void> schedule({
    required String title,
    required String body,
    Duration duration = const Duration(seconds: 10),
  }) async {
    tz.initializeTimeZones();
    final String currentTimeZone =
        await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    final JournalDb _journalDb = getIt<JournalDb>();
    int counter = await _journalDb.getCountImportFlagEntries();

    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(duration),
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
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
  }
}
