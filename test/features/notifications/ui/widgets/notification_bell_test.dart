import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/notifications/state/notification_inbox_controller.dart';
import 'package:lotti/features/notifications/ui/widgets/notification_bell.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Registers a stubbed [MockNavService] for tests that route desktop task
/// detail through `getIt<NavService>()`; the file-level `tearDownTestGetIt`
/// removes it again.
MockNavService _registerNavService() {
  final navService = MockNavService();
  getIt.registerSingleton<NavService>(navService);
  when(() => navService.pushDesktopTaskDetail(any())).thenAnswer((_) {});
  return navService;
}

void main() {
  late MockNotificationRepository repository;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() async {
    repository = MockNotificationRepository();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NotificationRepository>(repository);
      },
    );
    when(() => repository.markSeen(any())).thenAnswer((_) async => null);
    when(() => repository.markActedOn(any())).thenAnswer((_) async => null);
    when(
      () => repository.markTaskSuggestionsActedOn(any()),
    ).thenAnswer((_) async => const []);
    when(() => repository.retract(any())).thenAnswer((_) async => null);
    when(
      () => repository.retractTaskSuggestionsForTask(any()),
    ).thenAnswer((_) async => const []);
  });

  tearDown(tearDownTestGetIt);

  group('resolvePopoverWidth', () {
    test('returns the preferred width on a roomy desktop window', () {
      expect(
        NotificationBell.resolvePopoverWidth(1400),
        NotificationBell.popoverPreferredWidth,
      );
    });

    test(
      'shrinks to fit a mobile portrait screen with margins on each side',
      () {
        // iPhone 13 mini portrait — should drop below the preferred width
        // but stay above the floor, with the configured margin on each side.
        expect(
          NotificationBell.resolvePopoverWidth(375),
          375 - NotificationBell.popoverScreenMargin * 2,
        );
      },
    );

    test('pins to the floor at the exact lower boundary', () {
      // available == popoverMinWidth exactly → the <= comparison takes the
      // floor branch rather than returning the (equal) available width.
      const exactBoundary =
          NotificationBell.popoverMinWidth +
          NotificationBell.popoverScreenMargin * 2;
      expect(
        NotificationBell.resolvePopoverWidth(exactBoundary),
        NotificationBell.popoverMinWidth,
      );
    });

    test('snaps to the floor on absurdly narrow viewports', () {
      // A 280 px viewport would push the available width below the floor;
      // the resolver pins to popoverMinWidth so the layout stays legible.
      expect(
        NotificationBell.resolvePopoverWidth(280),
        NotificationBell.popoverMinWidth,
      );
    });
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

      verify(
        () => repository.retractTaskSuggestionsForTask('task-retract-me'),
      ).called(1);
    },
  );

  testWidgets(
    'dismiss icon uses row-level retract for non-suggestion notifications',
    (tester) async {
      final entity = _makeOverdueNotification(
        id: 'overdue-retract',
        title: 'Overdue',
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

      verify(() => repository.retract('overdue-retract')).called(1);
      verifyNever(() => repository.retractTaskSuggestionsForTask(any()));
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

      verify(
        () => repository.retractTaskSuggestionsForTask('task-long-retract'),
      ).called(1);
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
    'tapping a suggestion row marks it seen and opens suggestions',
    (tester) async {
      // Force desktop layout so `openLinkedTaskDetail` goes through
      // NavService (a registered mock) instead of pushing a MaterialPageRoute
      // for the still-missing TaskDetailsPage.
      final navService = _registerNavService();

      final entity = _makeNotification(
        id: 'act-on-me',
        title: 'Review',
        body: 'Take action',
      );
      final container = ProviderContainer(
        overrides: [
          unseenNotificationCountProvider.overrideWith(() => _CountUnseen(1)),
          inboxNotificationsProvider.overrideWith(
            () => _StaticInbox([entity]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _makeBellHarness(
          container: container,
          mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.notifications_active_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pump();

      verify(() => repository.markSeen('act-on-me')).called(1);
      verifyNever(() => repository.markActedOn(any()));
      verifyNever(() => repository.markTaskSuggestionsActedOn(any()));
      verify(
        () => navService.pushDesktopTaskDetail('task-act-on-me'),
      ).called(1);
      final intent = container.read(
        taskFocusControllerProvider(id: 'task-act-on-me'),
      );
      expect(intent, isNotNull);
      expect(intent!.target, TaskFocusTarget.suggestions);
    },
  );

  testWidgets(
    'tapping a non-suggestion row marks only that row seen',
    (tester) async {
      final navService = _registerNavService();

      final entity = _makeOverdueNotification(
        id: 'overdue-act-on-me',
        title: 'Overdue task',
        body: 'Open task',
      );
      final container = ProviderContainer(
        overrides: [
          unseenNotificationCountProvider.overrideWith(() => _CountUnseen(1)),
          inboxNotificationsProvider.overrideWith(
            () => _StaticInbox([entity]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _makeBellHarness(
          container: container,
          mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.notifications_active_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overdue task'));
      await tester.pump();

      verify(() => repository.markSeen('overdue-act-on-me')).called(1);
      verifyNever(() => repository.markActedOn(any()));
      verifyNever(() => repository.markTaskSuggestionsActedOn(any()));
      verify(
        () => navService.pushDesktopTaskDetail('task-overdue-act-on-me'),
      ).called(1);
      expect(
        container.read(
          taskFocusControllerProvider(id: 'task-overdue-act-on-me'),
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'markSeen failure is reported and navigation still proceeds',
    (tester) async {
      final navService = _registerNavService();

      when(
        () => repository.markSeen(any()),
      ).thenAnswer((_) async => throw StateError('mark-seen-boom'));

      final entity = _makeNotification(
        id: 'mark-failure',
        title: 'Will fail',
        body: '',
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
      await tester.tap(find.text('Will fail'));
      await tester.pump();

      verify(
        () => repository.markSeen('mark-failure'),
      ).called(1);
      verifyNever(() => repository.markActedOn(any()));
      verifyNever(() => repository.markTaskSuggestionsActedOn(any()));
      // Navigation runs even when markSeen throws.
      verify(
        () => navService.pushDesktopTaskDetail('task-mark-failure'),
      ).called(1);
      // FlutterError.reportError should have been called with the exception.
      expect(tester.takeException().toString(), contains('mark-seen-boom'));
    },
  );

  testWidgets(
    'retract failure is reported and the popover stays open',
    (tester) async {
      when(
        () => repository.retractTaskSuggestionsForTask(any()),
      ).thenThrow(StateError('retract-boom'));

      final entity = _makeNotification(
        id: 'retract-failure',
        title: 'Cannot dismiss',
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

      verify(
        () => repository.retractTaskSuggestionsForTask('task-retract-failure'),
      ).called(1);
      expect(tester.takeException().toString(), contains('retract-boom'));
      // Popover must still be present — the row text remains findable.
      expect(find.text('Cannot dismiss'), findsOneWidget);
    },
  );
}

Widget _makeBellHarness({
  required ProviderContainer container,
  required MediaQueryData mediaQueryData,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      data: mediaQueryData,
      child: MaterialApp(
        theme: resolveTestTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 800,
                maxWidth: 800,
              ),
              child: const NotificationBell(),
            ),
          ),
        ),
      ),
    ),
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

NotificationEntity _makeOverdueNotification({
  required String id,
  required String title,
  required String body,
}) {
  final now = DateTime.utc(2026, 5, 17, 10);
  return NotificationEntity.taskOverdue(
    meta: NotificationMeta(
      id: id,
      createdAt: now,
      updatedAt: now,
      scheduledFor: now,
      vectorClock: const VectorClock({'host-A': 1}),
      originatingHostId: 'host-A',
    ),
    linkedTaskId: 'task-$id',
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
