import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/state/conflict_notification_observer.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

Conflict _conflict(String id) => Conflict(
  id: id,
  createdAt: DateTime(2024, 3, 15, 14),
  updatedAt: DateTime(2024, 3, 15, 14),
  serialized: '{}',
  schemaVersion: 1,
  status: ConflictStatus.unresolved.index,
);

void main() {
  // The default-locale path resolves through WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb db;
  late MockNotificationService notifications;
  late ConflictNotificationObserver observer;
  final l10n = AppLocalizationsEn();

  void stubNotify() {
    when(
      () => notifications.showNotificationNow(
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationId: any(named: 'notificationId'),
        showOnMobile: any(named: 'showOnMobile'),
        showOnDesktop: any(named: 'showOnDesktop'),
        deepLink: any(named: 'deepLink'),
      ),
    ).thenAnswer((_) async {});
  }

  setUp(() {
    db = MockJournalDb();
    notifications = MockNotificationService();
    stubNotify();
    observer = ConflictNotificationObserver(
      db: db,
      notificationService: notifications,
      messages: AppLocalizationsEn.new,
    );
  });

  void verifyNeverNotified() => verifyNever(
    () => notifications.showNotificationNow(
      title: any(named: 'title'),
      body: any(named: 'body'),
      notificationId: any(named: 'notificationId'),
      showOnMobile: any(named: 'showOnMobile'),
      showOnDesktop: any(named: 'showOnDesktop'),
      deepLink: any(named: 'deepLink'),
    ),
  );

  test('does not alert for conflicts already present at startup', () {
    observer.handleSnapshot([_conflict('a')]);
    verifyNeverNotified();
  });

  test('alerts when a new conflict appears, with the total count', () {
    observer
      ..handleSnapshot(const []) // prime
      ..handleSnapshot([_conflict('a')]);

    verify(
      () => notifications.showNotificationNow(
        title: l10n.conflictNotificationTitle,
        body: l10n.conflictNotificationBody(1),
        notificationId: ConflictNotificationObserver.notificationId,
        showOnMobile: true,
        showOnDesktop: true,
        deepLink: ConflictNotificationObserver.deepLink,
      ),
    ).called(1);
  });

  test('coalesces a burst of new conflicts into a single alert', () {
    observer
      ..handleSnapshot(const []) // prime
      ..handleSnapshot([_conflict('a'), _conflict('b'), _conflict('c')]);

    verify(
      () => notifications.showNotificationNow(
        title: any(named: 'title'),
        body: l10n.conflictNotificationBody(3),
        notificationId: any(named: 'notificationId'),
        showOnMobile: any(named: 'showOnMobile'),
        showOnDesktop: any(named: 'showOnDesktop'),
        deepLink: any(named: 'deepLink'),
      ),
    ).called(1);
  });

  test('does not alert when no new conflict id appears', () {
    observer
      ..handleSnapshot([_conflict('a')]) // prime with one existing
      ..handleSnapshot([_conflict('a')]) // unchanged
      ..handleSnapshot(const []); // one resolved, none new
    verifyNeverNotified();
  });

  group('default dependencies resolve from getIt', () {
    setUp(() {
      if (getIt.isRegistered<JournalDb>()) getIt.unregister<JournalDb>();
      if (getIt.isRegistered<NotificationService>()) {
        getIt.unregister<NotificationService>();
      }
      getIt
        ..registerSingleton<JournalDb>(db)
        ..registerSingleton<NotificationService>(notifications);
    });

    tearDown(() {
      if (getIt.isRegistered<JournalDb>()) getIt.unregister<JournalDb>();
      if (getIt.isRegistered<NotificationService>()) {
        getIt.unregister<NotificationService>();
      }
    });

    test(
      'falls back to getIt for the db/notifier and the device locale for copy',
      () {
        // No db, notifier or messages passed: the db comes from getIt, the
        // notifier resolves lazily from getIt on first alert, and the copy
        // comes from the device-locale resolver (en in the test host).
        ConflictNotificationObserver()
          ..handleSnapshot(const []) // prime
          ..handleSnapshot([_conflict('a')]);

        verify(
          () => notifications.showNotificationNow(
            title: l10n.conflictNotificationTitle,
            body: l10n.conflictNotificationBody(1),
            notificationId: ConflictNotificationObserver.notificationId,
            showOnMobile: true,
            showOnDesktop: true,
            deepLink: ConflictNotificationObserver.deepLink,
          ),
        ).called(1);
      },
    );

    testWidgets('an unsupported device locale falls back to English copy', (
      tester,
    ) async {
      // 'xx' is not a shipped translation, so the resolver takes the
      // AppLocalizationsEn() fallback rather than lookupAppLocalizations.
      tester.platformDispatcher.localeTestValue = const Locale('xx');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      ConflictNotificationObserver()
        ..handleSnapshot(const []) // prime
        ..handleSnapshot([_conflict('a')]);

      verify(
        () => notifications.showNotificationNow(
          title: l10n.conflictNotificationTitle,
          body: l10n.conflictNotificationBody(1),
          notificationId: ConflictNotificationObserver.notificationId,
          showOnMobile: true,
          showOnDesktop: true,
          deepLink: ConflictNotificationObserver.deepLink,
        ),
      ).called(1);
    });
  });

  test('start subscribes to the unresolved stream; dispose cancels', () async {
    final controller = StreamController<List<Conflict>>();
    when(
      () => db.watchConflicts(ConflictStatus.unresolved),
    ).thenAnswer((_) => controller.stream);

    observer.start();
    controller
      ..add(const []) // prime
      ..add([_conflict('x')]);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => notifications.showNotificationNow(
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationId: any(named: 'notificationId'),
        showOnMobile: any(named: 'showOnMobile'),
        showOnDesktop: any(named: 'showOnDesktop'),
        deepLink: any(named: 'deepLink'),
      ),
    ).called(1);

    await observer.dispose();
    expect(controller.hasListener, isFalse);
    await controller.close();
  });
}
