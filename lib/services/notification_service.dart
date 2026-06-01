import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:timezone/timezone.dart';

class NotificationConstants {
  const NotificationConstants._();

  static const int badgeNotificationId = 1;
  static const int taskThreshold = 5;
  static const String defaultActionName = 'Open notification';
  static const String taskSingular = 'task';
  static const String taskPlural = 'tasks';
  static const String inProgressSuffix = ' in progress';
  static const String encouragementLow = 'Nice';
  static const String encouragementHigh = "Let's get that number down";
}

final JournalDb _db = getIt<JournalDb>();

bool get _skipNotificationsOnCurrentPlatform =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

class NotificationService {
  NotificationService() {
    try {
      flutterLocalNotificationsPlugin.initialize(
        settings: const InitializationSettings(
          linux: LinuxInitializationSettings(
            defaultActionName: NotificationConstants.defaultActionName,
          ),
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
    } catch (e) {
      // Gracefully handle notification initialization failure in flatpak
      getIt<DomainLogger>().error(
        LogDomain.notifications,
        e,
        subDomain: 'initialization',
      );
    }
  }

  int badgeCount = 0;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _requestPermissions() async {
    if (_skipNotificationsOnCurrentPlatform) {
      return;
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(
          alert: true,
          badge: true,
        );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(
          alert: true,
          badge: true,
        );
  }

  Future<void> updateBadge() async {
    final notifyEnabled = await _db.getConfigFlag(enableNotificationsFlag);

    if (_skipNotificationsOnCurrentPlatform) {
      return;
    }

    await _requestPermissions();

    final count = await _db.getWipCount();

    if (count == badgeCount) {
      return;
    } else {
      badgeCount = count;
    }

    await flutterLocalNotificationsPlugin.cancel(
      id: NotificationConstants.badgeNotificationId,
    );

    if (badgeCount == 0 || !notifyEnabled) {
      await flutterLocalNotificationsPlugin.show(
        id: NotificationConstants.badgeNotificationId,
        title: '',
        body: '',
        notificationDetails: NotificationDetails(
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
      final title =
          '$badgeCount ${badgeCount == 1 ? NotificationConstants.taskSingular : NotificationConstants.taskPlural}${NotificationConstants.inProgressSuffix}';
      final body = badgeCount < NotificationConstants.taskThreshold
          ? NotificationConstants.encouragementLow
          : NotificationConstants.encouragementHigh;

      await flutterLocalNotificationsPlugin.show(
        id: NotificationConstants.badgeNotificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
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

    if (!notifyEnabled || _skipNotificationsOnCurrentPlatform) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
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
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
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

  Future<void> scheduleNotificationAt({
    required String title,
    required String body,
    required DateTime notifyAt,
    required int notificationId,
    required bool showOnMobile,
    required bool showOnDesktop,
    String? deepLink,
  }) async {
    final notifyEnabled = await _db.getConfigFlag(enableNotificationsFlag);

    if (!notifyEnabled || _skipNotificationsOnCurrentPlatform) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
    final localTimezone = await getLocalTimezone();
    final location = getLocation(localTimezone);
    final scheduledDate = TZDateTime.from(notifyAt, location);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
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
      payload: deepLink,
      androidScheduleMode: AndroidScheduleMode.exact,
    );
  }

  Future<void> showNotificationNow({
    required String title,
    required String body,
    required int notificationId,
    required bool showOnMobile,
    required bool showOnDesktop,
    String? deepLink,
  }) async {
    final notifyEnabled = await _db.getConfigFlag(enableNotificationsFlag);

    if (!notifyEnabled || _skipNotificationsOnCurrentPlatform) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);

    await flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
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
      payload: deepLink,
    );
  }

  Future<void> cancelNotification(int notificationId) async {
    if (_skipNotificationsOnCurrentPlatform) {
      return;
    }

    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
  }
}
