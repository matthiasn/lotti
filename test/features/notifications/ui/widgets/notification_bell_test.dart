import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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

const _phoneSize = Size(390, 844);
const _desktopSize = Size(1400, 900);

/// Registers a [MockNavService] so a test can prove the bell never reaches
/// for the desktop detail stack directly — every destination goes through
/// the `beamToNamed` seam. The file-level `tearDownTestGetIt` removes it.
MockNavService _registerNavService() {
  final navService = MockNavService();
  getIt.registerSingleton<NavService>(navService);
  return navService;
}

/// Routes the bell's `beamToNamed` calls into the returned list, restoring
/// the real function on teardown.
List<String> _captureBeams() {
  final beamedTo = <String>[];
  beamToNamedOverride = beamedTo.add;
  addTearDown(() => beamToNamedOverride = null);
  return beamedTo;
}

/// Records every route pushed onto the harness navigator, so a phone-sized
/// test can prove the bell no longer pushes a pageless task page.
class _PushRecordingObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
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

      expect(find.byIcon(LottiIcons.notification), findsOneWidget);
      expect(find.byIcon(LottiIcons.notificationActive), findsNothing);
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

      expect(find.byIcon(LottiIcons.notificationActive), findsOneWidget);
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

      await tester.tap(find.byIcon(LottiIcons.notificationActive));
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

      await tester.tap(find.byIcon(LottiIcons.notificationActive));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LottiIcons.close));
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

      await tester.tap(find.byIcon(LottiIcons.notificationActive));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LottiIcons.close));
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

      await tester.tap(find.byIcon(LottiIcons.notification));
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

      await tester.tap(find.byIcon(LottiIcons.notificationActive));
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
      await tester.tap(find.byIcon(LottiIcons.notification));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load notifications."),
        findsOneWidget,
      );
    },
  );

  group('opening a task row', () {
    testWidgets(
      'a suggestion row on a phone beams to the task route and pushes nothing',
      (tester) async {
        // The regression this guards: the row used to push a pageless
        // MaterialPageRoute onto the tab's Beamer navigator on mobile, which
        // NavService.beamBack and the tab-root reset cannot see — so the task
        // had no way out. Beaming lets TasksLocation build it as a real page.
        final navService = _registerNavService();
        final beamedTo = _captureBeams();
        final observer = _PushRecordingObserver();
        await _openInboxWith(
          tester,
          entity: _makeNotification(id: 'act-on-me', title: 'Review', body: ''),
          size: _phoneSize,
          navigatorObservers: [observer],
        );
        observer.pushed.clear();

        await tester.tap(find.text('Review'));
        await tester.pump();

        expect(beamedTo, ['/tasks/task-act-on-me']);
        expect(observer.pushed, isEmpty);
        verifyNever(() => navService.pushDesktopTaskDetail(any()));
      },
    );

    testWidgets(
      'a suggestion row on desktop beams to the same route rather than '
      'layering the desktop detail stack',
      (tester) async {
        // Selecting the task, like the list pane does, keeps the URL and the
        // persisted route on the task the user is looking at — and works
        // from a tab that is not Tasks, where the detail stack is offstage.
        final navService = _registerNavService();
        final beamedTo = _captureBeams();
        await _openInboxWith(
          tester,
          entity: _makeNotification(id: 'act-on-me', title: 'Review', body: ''),
          size: _desktopSize,
        );

        await tester.tap(find.text('Review'));
        await tester.pump();

        expect(beamedTo, ['/tasks/task-act-on-me']);
        verifyNever(() => navService.pushDesktopTaskDetail(any()));
      },
    );

    testWidgets(
      'a suggestion row publishes the suggestions focus intent before the beam',
      (tester) async {
        // Order matters: a detail page mounted by this very beam reads the
        // intent after load, so it has to be there before the route changes.
        _registerNavService();
        late final ProviderContainer container;
        TaskFocusIntent? intentAtBeam;
        beamToNamedOverride = (_) {
          intentAtBeam = container.read(
            taskFocusControllerProvider('task-act-on-me'),
          );
        };
        addTearDown(() => beamToNamedOverride = null);
        container = await _openInboxWith(
          tester,
          entity: _makeNotification(id: 'act-on-me', title: 'Review', body: ''),
          size: _phoneSize,
        );

        await tester.tap(find.text('Review'));
        await tester.pump();

        expect(intentAtBeam, isNotNull);
        expect(intentAtBeam!.taskId, 'task-act-on-me');
        expect(intentAtBeam!.target, TaskFocusTarget.suggestions);
      },
    );

    testWidgets(
      'an overdue row beams to the task without a focus intent',
      (tester) async {
        final navService = _registerNavService();
        final beamedTo = _captureBeams();
        final observer = _PushRecordingObserver();
        final container = await _openInboxWith(
          tester,
          entity: _makeOverdueNotification(
            id: 'overdue-act-on-me',
            title: 'Overdue task',
            body: 'Open task',
          ),
          size: _phoneSize,
          navigatorObservers: [observer],
        );
        observer.pushed.clear();

        await tester.tap(find.text('Overdue task'));
        await tester.pump();

        expect(beamedTo, ['/tasks/task-overdue-act-on-me']);
        expect(observer.pushed, isEmpty);
        verifyNever(() => navService.pushDesktopTaskDetail(any()));
        // An overdue alert is about the task itself, not its suggestions.
        expect(
          container.read(taskFocusControllerProvider('task-overdue-act-on-me')),
          isNull,
        );
      },
    );

    testWidgets(
      'tapping a task row marks it seen and closes the popover',
      (tester) async {
        _registerNavService();
        _captureBeams();
        await _openInboxWith(
          tester,
          entity: _makeNotification(id: 'act-on-me', title: 'Review', body: ''),
          size: _phoneSize,
        );

        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();

        verify(() => repository.markSeen('act-on-me')).called(1);
        // Opening the target is not acting on the suggestion; the
        // confirmation flow owns that.
        verifyNever(() => repository.markTaskSuggestionsActedOn(any()));
        expect(find.text('Review'), findsNothing);
        expect(find.byType(NotificationBell), findsOneWidget);
      },
    );
  });

  testWidgets(
    'tapping a check-in reminder opens the person, never a task detail',
    (tester) async {
      // Every variant answers `linkedEntityId`, so the row used to hand a
      // relationship id to `openLinkedTaskDetail` and land on a dead task
      // route. Routing switches on the union instead.
      final navService = _registerNavService();
      final beamedTo = _captureBeams();

      final entity = _makeCheckInNotification(
        id: 'anna',
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
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

      await tester.tap(find.byIcon(LottiIcons.notificationActive));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check in with Anna?'));
      await tester.pump();

      expect(beamedTo, ['/people/rel-anna']);
      verifyNever(() => navService.pushDesktopTaskDetail(any()));
      // Opening the person still clears the badge, like every other row.
      verify(() => repository.markSeen('anna')).called(1);
    },
  );

  testWidgets(
    'tapping an auto-completion row opens the habits page',
    (tester) async {
      final navService = _registerNavService();
      final beamedTo = _captureBeams();

      final entity = _makeHabitAutoCompletedNotification(
        id: 'auto-sat',
        title: '✓ Walk done',
        body: 'Checked off automatically from Steps · 7412.',
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

      await tester.tap(find.byIcon(LottiIcons.notificationActive));
      await tester.pumpAndSettle();
      await tester.tap(find.text('✓ Walk done'));
      await tester.pump();

      expect(beamedTo, ['/habits']);
      verifyNever(() => navService.pushDesktopTaskDetail(any()));
      verify(() => repository.markSeen('auto-sat')).called(1);
    },
  );

  testWidgets(
    'dismissing a check-in reminder retracts only that row',
    (tester) async {
      // The suggestion path retracts every open row for the task; a reminder
      // has no such fan-out and must not borrow it.
      final entity = _makeCheckInNotification(
        id: 'anna',
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
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
      await tester.tap(find.byIcon(LottiIcons.notificationActive));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LottiIcons.close));
      await tester.pump();

      verify(() => repository.retract('anna')).called(1);
      verifyNever(() => repository.retractTaskSuggestionsForTask(any()));
    },
  );

  testWidgets(
    'markSeen failure is reported and navigation still proceeds',
    (tester) async {
      final navService = _registerNavService();
      final beamedTo = _captureBeams();

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
      await tester.tap(find.byIcon(LottiIcons.notificationActive));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Will fail'));
      await tester.pump();

      verify(
        () => repository.markSeen('mark-failure'),
      ).called(1);
      verifyNever(() => repository.markTaskSuggestionsActedOn(any()));
      // Navigation runs even when markSeen throws.
      expect(beamedTo, ['/tasks/task-mark-failure']);
      verifyNever(() => navService.pushDesktopTaskDetail(any()));
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
      await tester.tap(find.byIcon(LottiIcons.notificationActive));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LottiIcons.close));
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

/// Pumps the bell hosting a single unseen [entity] at [size] and opens the
/// popover, so a test starts with the row on screen. Returns the container
/// so the test can read what the tap published.
Future<ProviderContainer> _openInboxWith(
  WidgetTester tester, {
  required NotificationEntity entity,
  required Size size,
  List<NavigatorObserver> navigatorObservers = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      unseenNotificationCountProvider.overrideWith(() => _CountUnseen(1)),
      inboxNotificationsProvider.overrideWith(() => _StaticInbox([entity])),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    _makeBellHarness(
      container: container,
      mediaQueryData: MediaQueryData(size: size),
      navigatorObservers: navigatorObservers,
    ),
  );
  await tester.pump();
  await tester.tap(find.byIcon(LottiIcons.notificationActive));
  await tester.pumpAndSettle();
  return container;
}

Widget _makeBellHarness({
  required ProviderContainer container,
  required MediaQueryData mediaQueryData,
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      data: mediaQueryData,
      child: MaterialApp(
        navigatorObservers: navigatorObservers,
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

NotificationEntity _makeCheckInNotification({
  required String id,
  required String title,
  required String body,
}) {
  final now = DateTime.utc(2026, 5, 17, 10);
  return NotificationEntity.relationshipCheckIn(
    meta: NotificationMeta(
      id: id,
      createdAt: now,
      updatedAt: now,
      scheduledFor: now,
      vectorClock: const VectorClock({'host-A': 1}),
      originatingHostId: 'host-A',
    ),
    linkedRelationshipId: 'rel-$id',
    title: title,
    body: body,
  );
}

NotificationEntity _makeHabitAutoCompletedNotification({
  required String id,
  required String title,
  required String body,
}) {
  final now = DateTime.utc(2026, 5, 17, 10);
  return NotificationEntity.habitAutoCompleted(
    meta: NotificationMeta(
      id: id,
      createdAt: now,
      updatedAt: now,
      scheduledFor: now,
      vectorClock: const VectorClock({'host-A': 1}),
      originatingHostId: 'host-A',
    ),
    linkedHabitIds: ['habit-$id'],
    dayKey: '2026-05-17',
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
