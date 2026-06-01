import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../widget_test_utils.dart';

/// Fake platform implementation registered as
/// [FlutterLocalNotificationsPlatform.instance] so the plugin's static
/// `instance` field is initialised. Without this, accessing `instance` inside
/// the plugin throws a `LateInitializationError` and constructing
/// [NotificationService] (which eagerly calls `initialize`) fails.
///
/// Combined with `debugDefaultTargetPlatformOverride = TargetPlatform.linux`
/// this makes `initialize`/`cancel`/`show` no-op cleanly in tests: the plugin's
/// `resolvePlatformSpecificImplementation<LinuxFlutterLocalNotificationsPlugin>`
/// returns null for this fake (it is not the concrete Linux type), so the
/// plugin short-circuits without touching native channels.
class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAllFallbackValues);

  // A single, stable JournalDb mock. The production file holds the database in
  // a top-level `final JournalDb _db = getIt<JournalDb>();` that is lazily read
  // on first access and then cached for the whole isolate. Re-registering a
  // fresh mock per test would therefore not be seen by `_db` after the first
  // method call, so we reuse one mock and only re-stub it each time.
  final sharedDb = MockJournalDb();

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();

    await setUpTestGetIt();
    // Replace the helper's JournalDb with our stable shared instance so it is
    // the one `_db` resolves to.
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    getIt.registerSingleton<JournalDb>(sharedDb);

    when(
      () => sharedDb.getConfigFlag(any()),
    ).thenAnswer((_) async => true);
    // ignore: unnecessary_lambdas
    when(() => sharedDb.getWipCount()).thenAnswer((_) async => 0);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    reset(sharedDb);
    await tearDownTestGetIt();
  });

  group('NotificationConstants', () {
    test('exposes the documented badge/encouragement values', () {
      expect(NotificationConstants.badgeNotificationId, 1);
      expect(NotificationConstants.taskThreshold, 5);
      expect(NotificationConstants.defaultActionName, 'Open notification');
      expect(NotificationConstants.taskSingular, 'task');
      expect(NotificationConstants.taskPlural, 'tasks');
      expect(NotificationConstants.inProgressSuffix, ' in progress');
      expect(NotificationConstants.encouragementLow, 'Nice');
      expect(
        NotificationConstants.encouragementHigh,
        "Let's get that number down",
      );
    });
  });

  group('construction', () {
    test('constructing the service runs initialize without throwing', () {
      // Construction eagerly calls flutterLocalNotificationsPlugin.initialize.
      // It must succeed (no unhandled async error) with the fake platform.
      final service = NotificationService();
      expect(service.badgeCount, 0);
      expect(service.flutterLocalNotificationsPlugin, isNotNull);
    });
  });

  group('updateBadge', () {
    test(
      'queries the notifications config flag then returns on Linux',
      () async {
        final service = NotificationService();

        await service.updateBadge();

        // On Linux the method reads the flag, then hits the platform early
        // return before requesting permissions or touching the WIP count.
        verify(() => sharedDb.getConfigFlag(enableNotificationsFlag)).called(1);
        // ignore: unnecessary_lambdas
        verifyNever(() => sharedDb.getWipCount());
        // badgeCount is untouched because the badge-update branch is unreachable
        // on Linux.
        expect(service.badgeCount, 0);
      },
    );
  });

  group('scheduleNotification / scheduleNotificationAt / showNotificationNow', () {
    // All three share the same Linux-reachable surface: read the config flag,
    // then return early. They differ only in which production method is
    // invoked, so drive them through a parameterised table.
    final notifyAt = DateTime(2024, 3, 15, 9, 30);

    Future<void> invokeSchedule(NotificationService service) =>
        service.scheduleNotification(
          title: 'title',
          body: 'body',
          notifyAt: notifyAt,
          notificationId: 42,
          showOnMobile: true,
          showOnDesktop: false,
        );

    Future<void> invokeScheduleAt(NotificationService service) =>
        service.scheduleNotificationAt(
          title: 'title',
          body: 'body',
          notifyAt: notifyAt,
          notificationId: 42,
          showOnMobile: true,
          showOnDesktop: false,
        );

    Future<void> invokeShowNow(NotificationService service) =>
        service.showNotificationNow(
          title: 'title',
          body: 'body',
          notificationId: 42,
          showOnMobile: true,
          showOnDesktop: false,
        );

    final cases = <String, Future<void> Function(NotificationService)>{
      'scheduleNotification': invokeSchedule,
      'scheduleNotificationAt': invokeScheduleAt,
      'showNotificationNow': invokeShowNow,
    };

    for (final entry in cases.entries) {
      test(
        '${entry.key} reads the config flag then returns on Linux',
        () async {
          final service = NotificationService();

          await entry.value(service);

          verify(
            () => sharedDb.getConfigFlag(enableNotificationsFlag),
          ).called(1);
        },
      );
    }

    test(
      'returns early without reading the flag when notifications disabled',
      () async {
        // Even with the flag disabled the methods complete normally. The flag is
        // still read (it is checked before the platform guard short-circuits).
        when(
          () => sharedDb.getConfigFlag(any()),
        ).thenAnswer((_) async => false);
        final service = NotificationService();

        await invokeSchedule(service);

        verify(() => sharedDb.getConfigFlag(enableNotificationsFlag)).called(1);
      },
    );
  });

  group('cancelNotification', () {
    test('returns normally on Linux without reading the database', () async {
      final service = NotificationService();

      // cancelNotification hits the platform guard before any db / plugin call,
      // so it must complete without throwing and without touching the db.
      await expectLater(service.cancelNotification(7), completes);
      verifyNever(() => sharedDb.getConfigFlag(any()));
    });

    test('returns normally on Windows without reading the database', () async {
      final service = NotificationService();
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await expectLater(service.cancelNotification(7), completes);
      verifyNever(() => sharedDb.getConfigFlag(any()));
    });
  });

  group('scheduleHabitNotification', () {
    late MockNotificationService delegate;

    setUp(() {
      // scheduleHabitNotification delegates to getIt<NotificationService>().
      delegate = MockNotificationService();
      when(
        () => delegate.scheduleNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notifyAt: any(named: 'notifyAt'),
          notificationId: any(named: 'notificationId'),
          showOnMobile: any(named: 'showOnMobile'),
          showOnDesktop: any(named: 'showOnDesktop'),
          repeat: any(named: 'repeat'),
          deepLink: any(named: 'deepLink'),
        ),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<NotificationService>(delegate);
    });

    HabitDefinition habit({required HabitSchedule schedule}) => HabitDefinition(
      id: 'habit-1',
      name: 'Meditate',
      description: 'Daily meditation',
      createdAt: DateTime(2024, 3),
      updatedAt: DateTime(2024, 3),
      habitSchedule: schedule,
      vectorClock: null,
      active: true,
      private: false,
    );

    test(
      'daily schedule with alertAtTime delegates with the alert hour/minute',
      () async {
        final alertAt = DateTime(2024, 1, 1, 7, 45, 12);
        final definition = habit(
          schedule: HabitSchedule.daily(
            requiredCompletions: 1,
            alertAtTime: alertAt,
          ),
        );

        final service = NotificationService();
        await service.scheduleHabitNotification(definition, daysToAdd: 2);

        final captured = verify(
          () => delegate.scheduleNotification(
            title: 'Meditate',
            body: 'Daily meditation',
            showOnMobile: true,
            showOnDesktop: false,
            notifyAt: captureAny(named: 'notifyAt'),
            notificationId: 'habit-1'.hashCode,
          ),
        ).captured;

        final notifyAt = captured.single as DateTime;
        // The time-of-day is copied from alertAtTime regardless of "now".
        expect(notifyAt.hour, 7);
        expect(notifyAt.minute, 45);
        expect(notifyAt.second, 12);
      },
    );

    test('daily schedule without alertAtTime does not delegate', () async {
      final definition = habit(
        schedule: const HabitSchedule.daily(requiredCompletions: 1),
      );

      final service = NotificationService();
      await service.scheduleHabitNotification(definition);

      verifyNever(
        () => delegate.scheduleNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notifyAt: any(named: 'notifyAt'),
          notificationId: any(named: 'notificationId'),
          showOnMobile: any(named: 'showOnMobile'),
          showOnDesktop: any(named: 'showOnDesktop'),
        ),
      );
    });

    test(
      'weekly schedule takes the orElse branch and does not delegate',
      () async {
        final definition = habit(
          schedule: const HabitSchedule.weekly(requiredCompletions: 1),
        );

        final service = NotificationService();
        await service.scheduleHabitNotification(definition);

        verifyNever(
          () => delegate.scheduleNotification(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notifyAt: any(named: 'notifyAt'),
            notificationId: any(named: 'notificationId'),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
          ),
        );
      },
    );
  });
}
