import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/notifications/state/notification_inbox_controller.dart';
import 'package:lotti/features/notifications/ui/widgets/notification_bell.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockNotificationRepository repository;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    repository = MockNotificationRepository();
    if (getIt.isRegistered<NotificationRepository>()) {
      getIt.unregister<NotificationRepository>();
    }
    getIt.registerSingleton<NotificationRepository>(repository);
    when(() => repository.markActedOn(any())).thenAnswer((_) async => null);
    when(() => repository.retract(any())).thenAnswer((_) async => null);
  });

  tearDown(() {
    if (getIt.isRegistered<NotificationRepository>()) {
      getIt.unregister<NotificationRepository>();
    }
  });

  testWidgets(
    'renders the empty bell icon when no unseen notifications are pending',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          overrides: [
            unseenNotificationCountProvider.overrideWith(_ZeroUnseen.new),
            inboxNotificationsProvider.overrideWith(_EmptyInbox.new),
          ],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);
      // Badge ('2', '9+', etc.) should be absent when count == 0.
      expect(find.textContaining(RegExp(r'^\d')), findsNothing);
    },
  );

  testWidgets(
    'renders the active bell icon and badge when there are unseen alerts',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          overrides: [
            unseenNotificationCountProvider.overrideWith(() => _CountUnseen(3)),
            inboxNotificationsProvider.overrideWith(_EmptyInbox.new),
          ],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets(
    'caps the badge at 9+ when unseen count is greater than 9',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          overrides: [
            unseenNotificationCountProvider.overrideWith(
              () => _CountUnseen(42),
            ),
            inboxNotificationsProvider.overrideWith(_EmptyInbox.new),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('9+'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the bell opens the popover and shows the inbox rows',
    (tester) async {
      final entity = _makeNotification(
        id: 'first',
        title: 'Two tasks need review',
        body: 'Tap to open',
      );
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          overrides: [
            unseenNotificationCountProvider.overrideWith(() => _CountUnseen(1)),
            inboxNotificationsProvider.overrideWith(
              () => _StaticInbox([entity]),
            ),
          ],
        ),
      );
      // Flush the FutureProvider so the bell switches to the active icon.
      await tester.pump();

      await tester.tap(find.byIcon(Icons.notifications_active_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Two tasks need review'), findsOneWidget);
      expect(find.text('Tap to open'), findsOneWidget);
    },
  );

  testWidgets(
    'dismiss icon retracts the row through NotificationRepository',
    (tester) async {
      final entity = _makeNotification(
        id: 'retract-me',
        title: 'Goodbye',
        body: '',
      );
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          overrides: [
            unseenNotificationCountProvider.overrideWith(() => _CountUnseen(1)),
            inboxNotificationsProvider.overrideWith(
              () => _StaticInbox([entity]),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.notifications_active_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      verify(() => repository.retract('retract-me')).called(1);
    },
  );

  testWidgets(
    'shows the empty-state copy when the inbox is empty',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          overrides: [
            unseenNotificationCountProvider.overrideWith(_ZeroUnseen.new),
            inboxNotificationsProvider.overrideWith(_EmptyInbox.new),
          ],
        ),
      );

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();

      expect(find.text("You're all caught up."), findsOneWidget);
    },
  );

  testWidgets(
    'long-pressing a row also retracts it',
    (tester) async {
      final entity = _makeNotification(
        id: 'long-retract',
        title: 'Hold to dismiss',
        body: '',
      );
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          overrides: [
            unseenNotificationCountProvider.overrideWith(() => _CountUnseen(1)),
            inboxNotificationsProvider.overrideWith(
              () => _StaticInbox([entity]),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.notifications_active_rounded));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Hold to dismiss'));
      await tester.pump();

      verify(() => repository.retract('long-retract')).called(1);
    },
  );

  testWidgets(
    'falls back to the error copy when the inbox future fails',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          overrides: [
            unseenNotificationCountProvider.overrideWith(_ZeroUnseen.new),
            inboxNotificationsProvider.overrideWith(_FailingInbox.new),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load notifications."),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping a row marks it acted-on and dismisses the popover',
    (tester) async {
      // Force desktop layout so `openLinkedTaskDetail` goes through
      // NavService (a registered mock) instead of pushing a MaterialPageRoute
      // for the still-missing TaskDetailsPage.
      final navService = MockNavService();
      if (getIt.isRegistered<NavService>()) getIt.unregister<NavService>();
      getIt.registerSingleton<NavService>(navService);
      addTearDown(() {
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
      });
      when(
        () => navService.pushDesktopTaskDetail(any()),
      ).thenAnswer((_) {});

      final entity = _makeNotification(
        id: 'act-on-me',
        title: 'Review',
        body: 'Take action',
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
          overrides: [
            unseenNotificationCountProvider.overrideWith(() => _CountUnseen(1)),
            inboxNotificationsProvider.overrideWith(
              () => _StaticInbox([entity]),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.notifications_active_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pump();

      verify(() => repository.markActedOn('act-on-me')).called(1);
      verify(
        () => navService.pushDesktopTaskDetail('task-act-on-me'),
      ).called(1);
    },
  );

  testWidgets(
    'markActedOn failure is reported and navigation still proceeds',
    (tester) async {
      final navService = MockNavService();
      if (getIt.isRegistered<NavService>()) getIt.unregister<NavService>();
      getIt.registerSingleton<NavService>(navService);
      addTearDown(() {
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
      });
      when(
        () => navService.pushDesktopTaskDetail(any()),
      ).thenAnswer((_) {});

      when(
        () => repository.markActedOn(any()),
      ).thenThrow(StateError('mark-acted-boom'));

      final entity = _makeNotification(
        id: 'mark-failure',
        title: 'Will fail',
        body: '',
      );

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
          overrides: [
            unseenNotificationCountProvider.overrideWith(() => _CountUnseen(1)),
            inboxNotificationsProvider.overrideWith(
              () => _StaticInbox([entity]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.notifications_active_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Will fail'));
      await tester.pump();

      verify(() => repository.markActedOn('mark-failure')).called(1);
      // Navigation runs even when markActedOn throws.
      verify(
        () => navService.pushDesktopTaskDetail('task-mark-failure'),
      ).called(1);
      // FlutterError.reportError should have been called with the exception.
      expect(
        errors.where((e) => e.exception.toString().contains('mark-acted-boom')),
        isNotEmpty,
      );
    },
  );

  testWidgets(
    'retract failure is reported and the popover stays open',
    (tester) async {
      when(
        () => repository.retract(any()),
      ).thenThrow(StateError('retract-boom'));

      final entity = _makeNotification(
        id: 'retract-failure',
        title: 'Cannot dismiss',
        body: '',
      );

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const NotificationBell(),
          overrides: [
            unseenNotificationCountProvider.overrideWith(() => _CountUnseen(1)),
            inboxNotificationsProvider.overrideWith(
              () => _StaticInbox([entity]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.notifications_active_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      verify(() => repository.retract('retract-failure')).called(1);
      expect(
        errors.where((e) => e.exception.toString().contains('retract-boom')),
        isNotEmpty,
      );
      // Popover must still be present — the row text remains findable.
      expect(find.text('Cannot dismiss'), findsOneWidget);
    },
  );
}

NotificationEntity _makeNotification({
  required String id,
  required String title,
  required String body,
}) {
  final now = DateTime.utc(2026, 5, 17, 10);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: now,
      updatedAt: now,
      scheduledFor: now,
      vectorClock: const VectorClock({'host-A': 1}),
      originatingHostId: 'host-A',
    ),
    linkedTaskId: 'task-$id',
    suggestionCount: 1,
    title: title,
    body: body,
  );
}

class _ZeroUnseen extends UnseenNotificationCount {
  @override
  Future<int> build() async => 0;
}

class _CountUnseen extends UnseenNotificationCount {
  _CountUnseen(this._count);
  final int _count;

  @override
  Future<int> build() async => _count;
}

class _EmptyInbox extends InboxNotifications {
  @override
  Future<List<NotificationEntity>> build() async => const [];
}

class _FailingInbox extends InboxNotifications {
  @override
  Future<List<NotificationEntity>> build() async {
    throw StateError('boom');
  }
}

class _StaticInbox extends InboxNotifications {
  _StaticInbox(this._items);
  final List<NotificationEntity> _items;

  @override
  Future<List<NotificationEntity>> build() async => _items;
}
