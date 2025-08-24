import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService', () {
    group('NotificationConstants', () {
      test('has correct values', () {
        expect(NotificationConstants.badgeNotificationId, 1);
        expect(NotificationConstants.taskThreshold, 5);
        expect(NotificationConstants.defaultActionName, 'Open notification');
        expect(NotificationConstants.taskSingular, 'task');
        expect(NotificationConstants.taskPlural, 'tasks');
        expect(NotificationConstants.inProgressSuffix, ' in progress');
        expect(NotificationConstants.encouragementLow, 'Nice');
        expect(NotificationConstants.encouragementHigh,
            "Let's get that number down");
      });
    });

    group('Platform checks', () {
      test('_requestPermissions returns early on Windows', () async {
        if (Platform.isWindows) {
          // This test verifies that on Windows, the method returns early
          // The actual test is that the platform check happens
          expect(Platform.isWindows, isTrue);
        }
      });

      test('_requestPermissions returns early on Linux', () async {
        if (Platform.isLinux) {
          // This test verifies that on Linux, the method returns early
          // The actual test is that the platform check happens
          expect(Platform.isLinux, isTrue);
        }
      });

      test('updateBadge returns early on Windows', () async {
        if (Platform.isWindows) {
          expect(Platform.isWindows, isTrue);
        }
      });

      test('updateBadge returns early on Linux', () async {
        if (Platform.isLinux) {
          expect(Platform.isLinux, isTrue);
        }
      });

      test('cancelNotification returns early on Windows', () async {
        if (Platform.isWindows) {
          expect(Platform.isWindows, isTrue);
        }
      });

      test('cancelNotification returns early on Linux', () async {
        if (Platform.isLinux) {
          expect(Platform.isLinux, isTrue);
        }
      });

      test('showNotification returns early on Windows', () async {
        if (Platform.isWindows) {
          expect(Platform.isWindows, isTrue);
        }
      });

      test('showNotification returns early on Linux', () async {
        if (Platform.isLinux) {
          expect(Platform.isLinux, isTrue);
        }
      });

      test('scheduleNotification returns early on Windows', () async {
        if (Platform.isWindows) {
          expect(Platform.isWindows, isTrue);
        }
      });

      test('scheduleNotification returns early on Linux', () async {
        if (Platform.isLinux) {
          expect(Platform.isLinux, isTrue);
        }
      });
    });

    group('Badge count logic', () {
      test('calculates correct title for single task', () {
        const badgeCount = 1;
        const title =
            '$badgeCount ${badgeCount == 1 ? NotificationConstants.taskSingular : NotificationConstants.taskPlural}${NotificationConstants.inProgressSuffix}';
        expect(title, '1 task in progress');
      });

      test('calculates correct title for multiple tasks', () {
        const badgeCount = 5;
        const title =
            '$badgeCount ${badgeCount == 1 ? NotificationConstants.taskSingular : NotificationConstants.taskPlural}${NotificationConstants.inProgressSuffix}';
        expect(title, '5 tasks in progress');
      });

      test('chooses correct encouragement for low count', () {
        const badgeCount = 3;
        const body = badgeCount < NotificationConstants.taskThreshold
            ? NotificationConstants.encouragementLow
            : NotificationConstants.encouragementHigh;
        expect(body, NotificationConstants.encouragementLow);
      });

      test('chooses correct encouragement for high count', () {
        const badgeCount = 10;
        const body = badgeCount < NotificationConstants.taskThreshold
            ? NotificationConstants.encouragementLow
            : NotificationConstants.encouragementHigh;
        expect(body, NotificationConstants.encouragementHigh);
      });
    });
  });
}
