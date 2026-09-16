import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/notifications/model/notification_kind_flags.dart';
import 'package:lotti/features/notifications/preferences/notification_preference_effects.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb journalDb;
  late MockNotificationService notificationService;
  late MockNotificationScheduler scheduler;
  late MockDomainLogger logger;
  late NotificationPreferenceEffects effects;

  ConfigFlag flag(String name, {required bool status}) =>
      ConfigFlag(name: name, description: 'd', status: status);

  HabitDefinition habit(String id, {bool active = true}) => HabitDefinition(
    id: id,
    name: id,
    description: '',
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
    vectorClock: null,
    active: active,
    private: false,
  );

  setUp(() {
    journalDb = MockJournalDb();
    notificationService = MockNotificationService();
    scheduler = MockNotificationScheduler();
    logger = MockDomainLogger();
    when(notificationService.updateBadge).thenAnswer((_) async {});
    when(notificationService.cancelAllNotifications).thenAnswer((_) async {});
    when(
      () => notificationService.cancelNotification(any()),
    ).thenAnswer((_) async {});
    when(
      () => notificationService.scheduleHabitNotification(
        any(),
        daysToAdd: any(named: 'daysToAdd'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => scheduler.reconcile(now: any(named: 'now')),
    ).thenAnswer((_) async {});
    when(
      () => journalDb.getAllHabitDefinitionsAllPrivate(),
    ).thenAnswer((_) async => [habit('walk'), habit('read', active: false)]);
    effects = NotificationPreferenceEffects(
      journalDb: journalDb,
      notificationService: () => notificationService,
      scheduler: () => scheduler,
      logger: logger,
    );
  });

  void verifyNoReconcile() =>
      verifyNever(() => scheduler.reconcile(now: any(named: 'now')));

  group('the master switch', () {
    test('on: badge, then the rows, then every active habit', () async {
      await effects.apply(flag(enableNotificationsFlag, status: true));

      verifyInOrder([
        notificationService.updateBadge,
        () => scheduler.reconcile(now: any(named: 'now')),
        () => notificationService.scheduleHabitNotification(
          habit('walk'),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      ]);
      verifyNever(
        () => notificationService.scheduleHabitNotification(
          habit('read', active: false),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      );
      verifyNever(notificationService.cancelAllNotifications);
    });

    test('off: sweeps every alarm, then clears the badge', () async {
      await effects.apply(flag(enableNotificationsFlag, status: false));

      // The zero-badge post is itself a notification; sweeping after it
      // would take it down again and leave the count on the icon.
      verifyInOrder([
        notificationService.cancelAllNotifications,
        notificationService.updateBadge,
      ]);
      verifyNoReconcile();
    });
  });

  group('the per-kind switches', () {
    for (final name in notificationRowKindFlags) {
      test('$name reconciles the rows and touches nothing else', () async {
        await effects.apply(flag(name, status: false));

        verify(
          () => scheduler.reconcile(now: any(named: 'now')),
        ).called(1);
        verifyNever(notificationService.updateBadge);
        verifyNever(notificationService.cancelAllNotifications);
      });
    }

    test(
      "habit reminders off cancel every habit's alarm, archived too",
      () async {
        await effects.apply(flag(notifyHabitRemindersFlag, status: false));

        verify(
          () => notificationService.cancelNotification('walk'.hashCode),
        ).called(1);
        verify(
          () => notificationService.cancelNotification('read'.hashCode),
        ).called(1);
        verifyNoReconcile();
      },
    );

    test('habit reminders on re-arm every active habit', () async {
      await effects.apply(flag(notifyHabitRemindersFlag, status: true));

      verify(
        () => notificationService.scheduleHabitNotification(
          habit('walk'),
          daysToAdd: any(named: 'daysToAdd'),
        ),
      ).called(1);
      verifyNever(() => notificationService.cancelNotification(any()));
    });

    test('the badge switch refreshes the icon only', () async {
      await effects.apply(flag(showTaskBadgeFlag, status: false));

      verify(notificationService.updateBadge).called(1);
      verifyNoReconcile();
      verifyNever(notificationService.cancelAllNotifications);
    });
  });

  test('a flag that is no notification preference does nothing', () async {
    await effects.apply(flag('private', status: true));
    await effects.apply(flag(notifyAgentCopyFlag, status: true));

    verifyNoReconcile();
    verifyNever(notificationService.updateBadge);
    verifyNever(notificationService.cancelAllNotifications);
    verifyNever(() => journalDb.getAllHabitDefinitionsAllPrivate());
  });

  group('failures are contained and logged', () {
    test('a sweep failure still clears the badge', () async {
      when(
        notificationService.cancelAllNotifications,
      ).thenThrow(StateError('channel'));

      await expectLater(
        effects.apply(flag(enableNotificationsFlag, status: false)),
        completes,
      );

      verify(notificationService.updateBadge).called(1);
      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'notificationPreference.cancelAll',
        ),
      ).called(1);
    });

    test('a habit read failure does not escape', () async {
      when(
        () => journalDb.getAllHabitDefinitionsAllPrivate(),
      ).thenThrow(StateError('db gone'));

      await expectLater(
        effects.apply(flag(notifyHabitRemindersFlag, status: true)),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'notificationPreference.habitReminders',
        ),
      ).called(1);
    });

    test('the service is resolved only when a step needs it', () async {
      // The service is registered lazily so a sandboxed build never
      // materialises the platform plugin just to store a flag.
      var resolutions = 0;
      final lazy = NotificationPreferenceEffects(
        journalDb: journalDb,
        notificationService: () {
          resolutions++;
          return notificationService;
        },
        scheduler: () => scheduler,
        logger: logger,
      );

      await lazy.apply(flag(notifyGoalAlertsFlag, status: false));
      expect(resolutions, 0);

      await lazy.apply(flag(showTaskBadgeFlag, status: false));
      expect(resolutions, 1);
    });
  });
}
