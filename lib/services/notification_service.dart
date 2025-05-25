import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:timezone/timezone.dart';

final JournalDb _db = getIt<JournalDb>();

class NotificationService {
  NotificationService() {
    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        macOS: DarwinInitializationSettings(
          requestSoundPermission: false,
        ),
        iOS: DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        ),
      ),
    );
  }

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
        );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
        );
  }

  Future<void> updateBadge() async {
    final notifyEnabled = await _db.getConfigFlag(enableNotificationsFlag);

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
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            badgeNumber: badgeCount,
          ),
          macOS: DarwinNotificationDetails(
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
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            badgeNumber: badgeCount,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: notifyEnabled,
            presentBadge: true,
            badgeNumber: badgeCount,
          ),
        ),
      );
    }
  }

  Future<void> scheduleHabitNotification(
    HabitDefinition habitDefinition, {
    int daysToAdd = 0,
  }) async {
    final alertAtTime = habitDefinition.habitSchedule.maybeMap(
      daily: (d) => d.alertAtTime,
      orElse: () => null,
    );

    if (alertAtTime != null) {
      final notifyAt = DateTime.now()
          .add(
            Duration(days: daysToAdd),
          )
          .copyWith(
            hour: alertAtTime.hour,
            minute: alertAtTime.minute,
            second: alertAtTime.second,
          );

      await getIt<NotificationService>().scheduleNotification(
        title: habitDefinition.name,
        body: habitDefinition.description,
        showOnMobile: true,
        showOnDesktop: false,
        notifyAt: notifyAt,
        notificationId: habitDefinition.id.hashCode,
      );
    }
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime notifyAt,
    required int notificationId,
    required bool showOnMobile,
    required bool showOnDesktop,
    bool repeat = false,
    String? deepLink,
  }) async {
    final notifyEnabled = await _db.getConfigFlag(enableNotificationsFlag);

    if (!notifyEnabled || Platform.isWindows || Platform.isLinux) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(notificationId);
    final now = DateTime.now();
    final localTimezone = await getLocalTimezone();
    final location = getLocation(localTimezone);

    final scheduledDate = TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      notifyAt.hour,
      notifyAt.minute,
      notifyAt.second,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        iOS: showOnMobile
            ? const DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
                presentBanner: true,
                interruptionLevel: InterruptionLevel.timeSensitive,
              )
            : null,
        macOS: showOnDesktop
            ? DarwinNotificationDetails(
                presentAlert: true,
                presentBanner: true,
                subtitle: title,
                interruptionLevel: InterruptionLevel.timeSensitive,
              )
            : null,
      ),
      matchDateTimeComponents: repeat ? DateTimeComponents.time : null,
      payload: deepLink,
      androidScheduleMode: AndroidScheduleMode.exact,
    );
  }

  Future<void> cancelNotification(int notificationId) async {
    if (Platform.isWindows || Platform.isLinux) {
      return;
    }

    await flutterLocalNotificationsPlugin.cancel(notificationId);
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
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: deepLink,
    );
  }
}
