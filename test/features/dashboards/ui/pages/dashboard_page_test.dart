import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../utils/utils.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('DashboardPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeMeasurementData());
      ensureMpvInitialized();
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      final mockTimeService = MockTimeService();
      final mockHealthImport = MockHealthImport();

      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([
          {enableDashboardsPageFlag},
        ]),
      );

      final mockUpdateNotifications = MockUpdateNotifications();
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => const Stream.empty());

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<SettingsDb>(SettingsDb(inMemoryDatabase: true))
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<nav_service.NavService>(nav_service.NavService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<UserActivityService>(UserActivityService());

      when(
        () => mockEntitiesCacheService.getDashboardById(
          testDashboardConfig.id,
        ),
      ).thenReturn(testDashboardConfig);

      // when(
      //   () => mockJournalDb.watchWorkouts(
      //     rangeStart: any(named: 'rangeStart'),
      //     rangeEnd: any(named: 'rangeEnd'),
      //   ),
      // ).thenAnswer(
      //   (_) => Stream<List<JournalEntity>>.fromIterable([]),
      // );

      when(
        () => mockHealthImport.fetchHealthDataDelta(any()),
      ).thenAnswer((_) async {});

      when(
        mockHealthImport.getWorkoutsHealthDataDelta,
      ).thenAnswer((_) async {});

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });
    tearDown(getIt.reset);

    testWidgets('renders the dashboard title, time-span control, and charts', (
      tester,
    ) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          private: false,
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardPage(dashboardId: testDashboardConfig.id),
        ),
      );

      await tester.pumpAndSettle();

      // Page chrome: dashboard name as the title, the range selector, and
      // the chart host wired to this dashboard id.
      expect(find.text(testDashboardConfig.name), findsOneWidget);
      expect(find.byType(TimeSpanSegmentedControl), findsOneWidget);

      // The body is hosted inside a SliverToBoxAdapter (unbounded height) and
      // wrapped in SettingsContentArea (a LayoutBuilder). Guard that the
      // content is actually laid out — non-zero size and inset from the page
      // edge — so it can never silently collapse to "header only".
      final controlRect = tester.getRect(
        find.byType(TimeSpanSegmentedControl),
      );
      expect(controlRect.width, greaterThan(0));
      expect(controlRect.height, greaterThan(0));
      expect(
        controlRect.left,
        greaterThan(0),
        reason: 'content must be horizontally inset, not hugging the edge',
      );

      final dashboardWidget = tester.widget<DashboardWidget>(
        find.byType(DashboardWidget),
      );
      expect(dashboardWidget.dashboardId, testDashboardConfig.id);
      // Default 90-day window: rangeStart sits 90 days before rangeEnd.
      expect(
        dashboardWidget.rangeEnd.difference(dashboardWidget.rangeStart).inDays,
        inInclusiveRange(90, 91),
      );
    });

    testWidgets(
      'shows EmptyScaffoldWithTitle and navigates when dashboard not found',
      (tester) async {
        const missingId = 'non-existent-dashboard-id';
        when(
          () => mockEntitiesCacheService.getDashboardById(missingId),
        ).thenReturn(null);

        final capturedPaths = <String>[];
        nav_service.beamToNamedOverride = capturedPaths.add;
        addTearDown(() => nav_service.beamToNamedOverride = null);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const DashboardPage(dashboardId: missingId),
          ),
        );

        await tester.pump(const Duration(seconds: 1));

        // Navigation to dashboards list was requested
        expect(capturedPaths, contains('/dashboards'));

        // The "not found" scaffold is shown with the expected title
        expect(find.byType(EmptyScaffoldWithTitle), findsOneWidget);
        expect(find.text('Dashboard not found'), findsOneWidget);
      },
    );

    testWidgets(
      'TimeSpanSegmentedControl onValueChanged updates selected time span',
      (tester) async {
        when(
          () => mockPersistenceLogic.createMeasurementEntry(
            data: any(named: 'data'),
            private: false,
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DashboardPage(dashboardId: testDashboardConfig.id),
          ),
        );

        await tester.pump(const Duration(seconds: 1));

        // Verify the segmented control renders with the default 90-day selection
        final segmented = tester.widget<TimeSpanSegmentedControl>(
          find.byType(TimeSpanSegmentedControl),
        );
        expect(segmented.timeSpanDays, 90);

        // Tap the 30-day segment to trigger onValueChanged → setState.
        // DsSegmentedToggle stacks an invisible width-reserving ghost label
        // behind the visible one, so '30d' matches two widgets; tap the last
        // (the visible label painted on top) to avoid an occluded-hit warning.
        await tester.ensureVisible(find.text('30d').last);
        await tester.tap(find.text('30d').last);
        await tester.pump(const Duration(seconds: 1));

        // After setState the control must reflect the new selection
        final updated = tester.widget<TimeSpanSegmentedControl>(
          find.byType(TimeSpanSegmentedControl),
        );
        expect(updated.timeSpanDays, 30);
      },
    );

    // A window wide enough (>= the 960px desktop breakpoint) that the page
    // renders its desktop layout. The harness injects MediaQuery from this
    // (tester.view does not drive MediaQuery here), so isDesktopLayout reads
    // this width.
    const desktopMediaQuery = MediaQueryData(size: Size(1280, 1400));

    testWidgets(
      'desktop layout puts the title and picker in one row, with no back button',
      (tester) async {
        when(
          () => mockPersistenceLogic.createMeasurementEntry(
            data: any(named: 'data'),
            private: false,
          ),
        ).thenAnswer((_) async => null);

        tester.view.physicalSize = const Size(1280, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DashboardPage(dashboardId: testDashboardConfig.id),
            mediaQueryData: desktopMediaQuery,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(testDashboardConfig.name), findsOneWidget);
        expect(find.byType(TimeSpanSegmentedControl), findsOneWidget);
        // The edit-definition link.
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
        // The desktop header has no back button (the dashboards list stays
        // visible beside this pane) — this is what sets it apart from mobile.
        expect(find.byType(BackWidget), findsNothing);
        // Title and picker share a single horizontal band (their vertical
        // centers line up), not stacked as on mobile.
        expect(
          tester.getCenter(find.text(testDashboardConfig.name)).dy,
          moreOrLessEquals(
            tester.getCenter(find.byType(TimeSpanSegmentedControl)).dy,
            epsilon: 1,
          ),
        );
      },
    );

    /// Stubs the dashboard-definition editor's reads so it can be pushed
    /// (from the header's edit link) without throwing.
    void stubDefinitionEditor() {
      ensureThemingServicesRegistered();
      when(
        mockJournalDb.getAllCategories,
      ).thenAnswer((_) async => [categoryMindfulness]);
      when(
        mockJournalDb.getAllHabitDefinitions,
      ).thenAnswer((_) async => <HabitDefinition>[]);
      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);
      nav_service.beamToNamedOverride = (_) {};
      addTearDown(() => nav_service.beamToNamedOverride = null);
    }

    testWidgets(
      'tapping edit on desktop opens a clamped side panel; back pops it',
      (tester) async {
        stubDefinitionEditor();

        tester.view.physicalSize = const Size(1280, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DashboardPage(dashboardId: testDashboardConfig.id),
            mediaQueryData: desktopMediaQuery,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(DashboardDefinitionPage), findsOneWidget);
        // The side panel clamps the editor to half the window (max 640px), so
        // it never fills the 1280px width — that's what distinguishes it from
        // the mobile full-screen push.
        expect(
          tester.getSize(find.byType(DashboardDefinitionPage)).width,
          lessThanOrEqualTo(640),
        );

        // The editor was pushed with popOnClose: true, so its header back
        // button pops the route instead of beaming to the settings list. The
        // desktop dashboard header has no back button, so this is the only one.
        await tester.tap(find.byType(BackWidget));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(DashboardDefinitionPage), findsNothing);
      },
    );

    testWidgets(
      'tapping the edit link below the desktop breakpoint pushes full-screen',
      (tester) async {
        stubDefinitionEditor();

        // Below the 960px desktop breakpoint (so the mobile push path runs),
        // but wide enough that the embedded charts' date axis lays out without
        // an unrelated horizontal overflow.
        tester.view.physicalSize = const Size(900, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DashboardPage(dashboardId: testDashboardConfig.id),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(DashboardDefinitionPage), findsOneWidget);
        // A full-screen MaterialPageRoute fills the window width — proving this
        // is the push path, not the width-clamped desktop side panel.
        expect(
          tester.getSize(find.byType(DashboardDefinitionPage)).width,
          greaterThan(640),
        );
      },
    );
  });
}
