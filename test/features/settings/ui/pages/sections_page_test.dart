import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/sections_page.dart';
import 'package:lotti/features/settings/ui/widgets/config_flag_toggle_list.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// A stored row for every section flag, plus two flags that belong to the
/// Config Flags page. The strays are the point: a real database hands this
/// page every flag there is, and the page has to pick.
Set<ConfigFlag> _storedFlags({Set<String> on = const {}}) => {
  for (final name in sectionFlags)
    ConfigFlag(
      name: name,
      description: 'raw description for $name',
      status: on.contains(name),
    ),
  const ConfigFlag(
    name: privateFlag,
    description: 'raw private',
    status: true,
  ),
  const ConfigFlag(
    name: enableLoggingFlag,
    description: 'raw logging',
    status: false,
  ),
};

/// The localized (title, description) pair each section row must render,
/// resolved through the same accessor production code uses so the assertions
/// are tied to the real ARB values rather than to a copy of them.
(String, String) _labelsFor(String flagName, AppLocalizations m) =>
    switch (flagName) {
      enableDailyOsPageFlag => (
        m.configFlagEnableDailyOs,
        m.configFlagEnableDailyOsDescription,
      ),
      enableProjectsFlag => (
        m.configFlagEnableProjects,
        m.configFlagEnableProjectsDescription,
      ),
      enableUnifiedGoalsFlag => (
        m.configFlagEnableUnifiedGoals,
        m.configFlagEnableUnifiedGoalsDescription,
      ),
      enableHabitsPageFlag => (
        m.configFlagEnableHabitsPage,
        m.configFlagEnableHabitsPageDescription,
      ),
      enableDashboardsPageFlag => (
        m.configFlagEnableDashboardsPage,
        m.configFlagEnableDashboardsPageDescription,
      ),
      enableRelationshipsFlag => (
        m.configFlagEnableRelationships,
        m.configFlagEnableRelationshipsDescription,
      ),
      enableEventsFlag => (
        m.configFlagEnableEvents,
        m.configFlagEnableEventsDescription,
      ),
      _ => throw StateError('unexpected section flag: $flagName'),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJournalDb mockDb;
  late MockUserActivityService mockUserActivityService;
  late MockPersistenceLogic mockPersistenceLogic;
  final mockUpdateNotifications = MockUpdateNotifications();

  setUpAll(() {
    registerFallbackValue(fallbackConfigFlag);
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockUserActivityService = MockUserActivityService();
    mockPersistenceLogic = MockPersistenceLogic();

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );
    when(() => mockDb.watchConfigFlags()).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([
        _storedFlags(on: {enableHabitsPageFlag}),
      ]),
    );
    when(() => mockUserActivityService.updateActivity()).thenReturn(null);
    when(
      () => mockPersistenceLogic.setConfigFlag(any()),
    ).thenAnswer((_) async {});

    GetIt.I
      ..pushNewScope()
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<UserActivityService>(mockUserActivityService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    await GetIt.I.popScope();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const SectionsPage()),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('SectionsPage', () {
    testWidgets('renders one row per section flag and nothing else', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(
        find.byType(DesignSystemListItem),
        findsNWidgets(sectionFlags.length),
      );

      final context = tester.element(find.byType(SectionsPage));
      // The two non-section flags the stream also carries stay on Config
      // Flags — a stored value with two homes is the bug this page would
      // otherwise introduce.
      expect(find.text(context.messages.configFlagPrivate), findsNothing);
      expect(find.text(context.messages.configFlagEnableLogging), findsNothing);
    });

    testWidgets('titles and descriptions come from the localized catalog', (
      tester,
    ) async {
      await pumpPage(tester);
      final messages = tester.element(find.byType(SectionsPage)).messages;

      for (final flagName in sectionFlags) {
        final (title, description) = _labelsFor(flagName, messages);
        expect(find.text(title), findsOneWidget, reason: '$flagName title');
        expect(
          find.text(description),
          findsOneWidget,
          reason: '$flagName description',
        );
        expect(
          find.text('raw description for $flagName'),
          findsNothing,
          reason: '$flagName must not leak its raw DB description',
        );
      }
    });

    testWidgets('rows are ordered the way the navigation they build is', (
      tester,
    ) async {
      await pumpPage(tester);
      final messages = tester.element(find.byType(SectionsPage)).messages;

      // Row order is `sectionFlags`, which mirrors `NavService._tabSpecs`:
      // Daily OS, Projects, Goals, Habits, Dashboards, People, Events. A
      // list that disagreed with the sidebar it produces would read as
      // arbitrary.
      final renderedTitles = tester
          .widgetList<DesignSystemListItem>(find.byType(DesignSystemListItem))
          .map((row) => row.title)
          .toList();
      expect(renderedTitles, [
        for (final flagName in sectionFlags) _labelsFor(flagName, messages).$1,
      ]);
    });

    testWidgets('each toggle shows the stored status', (tester) async {
      await pumpPage(tester);
      final messages = tester.element(find.byType(SectionsPage)).messages;

      DesignSystemToggle toggleFor(String flagName) => tester.widget(
        find.descendant(
          of: find.widgetWithText(
            DesignSystemListItem,
            _labelsFor(flagName, messages).$1,
          ),
          matching: find.byType(DesignSystemToggle),
        ),
      );

      // Only Habits is on in the fixture.
      expect(toggleFor(enableHabitsPageFlag).value, isTrue);
      expect(toggleFor(enableProjectsFlag).value, isFalse);
    });

    testWidgets('tapping a section row persists the flip', (tester) async {
      await pumpPage(tester);
      final messages = tester.element(find.byType(SectionsPage)).messages;

      await tester.tap(
        find.widgetWithText(
          DesignSystemListItem,
          _labelsFor(enableProjectsFlag, messages).$1,
        ),
      );
      await tester.pump();

      verify(
        () => mockPersistenceLogic.setConfigFlag(
          const ConfigFlag(
            name: enableProjectsFlag,
            description: 'raw description for $enableProjectsFlag',
            status: true,
          ),
        ),
      ).called(1);
    });

    testWidgets('explains what turning a section off does', (tester) async {
      await pumpPage(tester);
      final context = tester.element(find.byType(SectionsPage));
      // The page carries the reassurance that hiding a section is not
      // deleting its data — the question a toggle labelled "Enable Habits
      // page" cannot answer on its own.
      expect(find.text(context.messages.settingsSectionsIntro), findsOneWidget);
    });

    testWidgets('renders nothing rather than throwing before the first frame', (
      tester,
    ) async {
      // `watchConfigFlags` emits nothing on the first frame in production;
      // the page must render an empty card, not look up a missing name.
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => const Stream<Set<ConfigFlag>>.empty(),
      );
      await pumpPage(tester);

      expect(find.byType(ConfigFlagToggleList), findsNothing);
      expect(find.byType(DesignSystemListItem), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('section flags and config flags partition the flag set', () {
    test('no flag has two homes', () {
      // Rendering one stored value on two pages would let a user toggle it
      // in one place and see the other disagree until a rebuild.
      expect(
        sectionFlags.toSet().intersection(
          FlagsBody.defaultDisplayedItems.toSet(),
        ),
        isEmpty,
      );
    });

    test('every section flag is distinct and non-empty', () {
      expect(sectionFlags.toSet().length, sectionFlags.length);
      for (final name in sectionFlags) {
        expect(name, isNotEmpty);
      }
    });
  });
}
