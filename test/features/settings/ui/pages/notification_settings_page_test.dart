import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/settings/ui/pages/notification_settings_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_toggle_list.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// The kind switches in the order the page lists them, badge last.
const List<String> _kindFlags = [
  notifyTaskSuggestionsFlag,
  notifyCheckInRemindersFlag,
  notifyGoalAlertsFlag,
  notifyHabitRemindersFlag,
  notifyHabitAutoCompletionsFlag,
  notifyDayPlanOutcomesFlag,
  notifySyncConflictsFlag,
  showTaskBadgeFlag,
];

void main() {
  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistenceLogic;

  setUpAll(() => registerFallbackValue(fallbackConfigFlag));

  ConfigFlag flag(String name, {required bool status}) =>
      ConfigFlag(name: name, description: name, status: status);

  /// Every switch the page knows, master and kinds alike, minus [omit].
  Set<ConfigFlag> flags({
    bool master = true,
    bool kinds = true,
    Set<String> omit = const {},
  }) => {
    if (!omit.contains(enableNotificationsFlag))
      flag(enableNotificationsFlag, status: master),
    for (final name in _kindFlags)
      if (!omit.contains(name)) flag(name, status: kinds),
  };

  void stubFlags(Stream<Set<ConfigFlag>> stream) =>
      when(() => mockDb.watchConfigFlags()).thenAnswer((_) => stream);

  setUp(() {
    mockDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    final activity = MockUserActivityService();
    final updates = MockUpdateNotifications();
    when(activity.updateActivity).thenReturn(null);
    when(
      () => updates.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(
      () => mockPersistenceLogic.setConfigFlag(any()),
    ).thenAnswer((_) async {});
    stubFlags(Stream.value(flags()));

    GetIt.I
      ..pushNewScope()
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<UserActivityService>(activity)
      ..registerSingleton<UpdateNotifications>(updates)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    ensureThemingServicesRegistered();
  });

  tearDown(() => GetIt.I.popScope());

  Future<void> pumpPage(
    WidgetTester tester, {
    Widget child = const NotificationSettingsPage(),
  }) async {
    // Tall enough for every row to be on screen without scrolling.
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(makeTestableWidgetWithScaffold(child));
    await tester.pump();
    // Flush SliverBoxAdapterPage's fade-in so no timer is left pending.
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder rowOf(String name) => find.byKey(ValueKey(name));

  DesignSystemToggle toggleOf(WidgetTester tester, String name) =>
      tester.widget(
        find.descendant(
          of: rowOf(name),
          matching: find.byType(DesignSystemToggle),
        ),
      );

  List<List<String>> listedRows(WidgetTester tester) => [
    for (final list in tester.widgetList<SettingsToggleList>(
      find.byType(SettingsToggleList),
    ))
      [for (final row in list.rows) (row.key! as ValueKey<String>).value],
  ];

  testWidgets('renders the page title and delegates to the body', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byType(NotificationSettingsBody), findsOneWidget);
  });

  testWidgets('lists the master switch alone, then one row per kind', (
    tester,
  ) async {
    await pumpPage(tester);

    // Linux has no icon badge, so the badge row is not offered here.
    expect(listedRows(tester), [
      [enableNotificationsFlag],
      _kindFlags.where((f) => f != showTaskBadgeFlag).toList(),
    ]);
    expect(find.text('Allow notifications'), findsOneWidget);
    expect(find.text('Goal alerts'), findsOneWidget);
    expect(find.text('When a goal slips off track.'), findsOneWidget);
  });

  testWidgets('each switch shows its flag', (tester) async {
    stubFlags(
      Stream.value({
        flag(enableNotificationsFlag, status: true),
        flag(notifyGoalAlertsFlag, status: false),
        flag(notifySyncConflictsFlag, status: true),
      }),
    );
    await pumpPage(tester);

    expect(toggleOf(tester, enableNotificationsFlag).value, isTrue);
    expect(toggleOf(tester, notifyGoalAlertsFlag).value, isFalse);
    expect(toggleOf(tester, notifySyncConflictsFlag).value, isTrue);
  });

  for (final (platform, offered) in [
    (TargetPlatform.iOS, true),
    (TargetPlatform.macOS, true),
    (TargetPlatform.android, false),
    (TargetPlatform.linux, false),
  ]) {
    testWidgets('$platform: badge switch offered is $offered', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await pumpPage(tester, child: const NotificationSettingsBody());

        // Only where the platform has an icon to put a count on.
        expect(
          rowOf(showTaskBadgeFlag),
          offered ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Task count on the app icon'),
          offered ? findsOneWidget : findsNothing,
        );
      } finally {
        // The widget binding checks this is back to null before the test
        // body returns, which is earlier than tearDown runs.
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('the master switch writes enable_notifications', (
    tester,
  ) async {
    stubFlags(Stream.value(flags(master: false)));
    await pumpPage(tester);

    await tester.tap(
      find.descendant(
        of: rowOf(enableNotificationsFlag),
        matching: find.byType(DesignSystemToggle),
      ),
    );
    await tester.pump();

    verify(
      () => mockPersistenceLogic.setConfigFlag(
        flag(enableNotificationsFlag, status: true),
      ),
    ).called(1);
  });

  testWidgets('a kind switch writes its own flag', (tester) async {
    await pumpPage(tester);

    await tester.tap(
      find.descendant(
        of: rowOf(notifyGoalAlertsFlag),
        matching: find.byType(DesignSystemToggle),
      ),
    );
    await tester.pump();

    verify(
      () => mockPersistenceLogic.setConfigFlag(
        flag(notifyGoalAlertsFlag, status: false),
      ),
    ).called(1);
  });

  testWidgets('tapping a kind row flips it the same way', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Sync conflicts'));
    await tester.pump();

    verify(
      () => mockPersistenceLogic.setConfigFlag(
        flag(notifySyncConflictsFlag, status: false),
      ),
    ).called(1);
  });

  testWidgets(
    'kind switches are greyed and inert while notifications are off',
    (
      tester,
    ) async {
      stubFlags(Stream.value(flags(master: false)));
      await pumpPage(tester);

      // Still listed — the user can see what switching on would let through —
      // but neither the switch nor the row does anything.
      for (final name in _kindFlags.where((f) => f != showTaskBadgeFlag)) {
        expect(toggleOf(tester, name).enabled, isFalse, reason: name);
      }
      expect(toggleOf(tester, enableNotificationsFlag).enabled, isTrue);

      await tester.tap(find.text('Goal alerts'));
      await tester.pump();

      verifyNever(() => mockPersistenceLogic.setConfigFlag(any()));
    },
  );

  testWidgets('kind switches are live while notifications are on', (
    tester,
  ) async {
    await pumpPage(tester);

    for (final name in _kindFlags.where((f) => f != showTaskBadgeFlag)) {
      expect(toggleOf(tester, name).enabled, isTrue, reason: name);
    }
  });

  testWidgets('a kind whose flag has not been seeded is left out', (
    tester,
  ) async {
    stubFlags(Stream.value(flags(omit: {notifyGoalAlertsFlag})));
    await pumpPage(tester);

    expect(rowOf(notifyGoalAlertsFlag), findsNothing);
    expect(listedRows(tester).last, hasLength(6));
  });

  testWidgets('shows nothing until the flags arrive', (tester) async {
    stubFlags(const Stream.empty());
    await pumpPage(tester);

    expect(find.byType(SettingsToggleList), findsNothing);
    expect(find.text('Alert me about'), findsNothing);
  });

  testWidgets('shows nothing when the master flag is missing', (
    tester,
  ) async {
    stubFlags(Stream.value(flags(omit: {enableNotificationsFlag})));
    await pumpPage(tester);

    expect(find.byType(SettingsToggleList), findsNothing);
  });

  testWidgets('omits the kinds section when no kind flag exists', (
    tester,
  ) async {
    stubFlags(Stream.value({flag(enableNotificationsFlag, status: true)}));
    await pumpPage(tester);

    expect(listedRows(tester), [
      [enableNotificationsFlag],
    ]);
    expect(find.text('Alert me about'), findsNothing);
  });

  testWidgets('explains the switches in plain words', (tester) async {
    await pumpPage(tester);

    expect(
      find.text(
        "Alerts arrive through your device's notifications. Choose what is "
        'worth one; everything still lands in the bell inside Lotti.',
      ),
      findsOneWidget,
    );
    expect(find.text('Alert me about'), findsOneWidget);
    expect(
      find.text(
        'Switching a kind off only stops its alerts. Its entries still '
        'appear in the bell.',
      ),
      findsOneWidget,
    );
  });
}
