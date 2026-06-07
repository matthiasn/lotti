import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboards_list_page.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();

  group('DashboardDefinitionPage Widget Tests - ', () {
    setUpAll(registerAllFallbackValues);

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      when(
        mockJournalDb.getAllCategories,
      ).thenAnswer((_) async => [categoryMindfulness]);

      final mockNavService = MockNavService();
      when(() => mockNavService.isDesktopMode).thenReturn(false);
      when(
        () => mockNavService.desktopSelectedDashboardId,
      ).thenReturn(ValueNotifier<String?>(null));
      when(
        () => mockNavService.desktopShowTimeAnalysis,
      ).thenReturn(ValueNotifier<bool>(false));

      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockJournalDb)
            ..registerSingleton<UserActivityService>(UserActivityService())
            ..registerSingleton<EntitiesCacheService>(
              MockEntitiesCacheService(),
            )
            ..registerSingleton<NavService>(mockNavService);
        },
      );
    });
    tearDown(tearDownTestGetIt);

    testWidgets('dashboard list page is displayed with two test dashboards', (
      tester,
    ) async {
      when(mockJournalDb.getAllDashboards).thenAnswer(
        (_) async => [testDashboardConfig, emptyTestDashboardConfig],
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(mockJournalDb.getAllDashboards).called(1);

      // finds text in dashboard card
      expect(find.text(testDashboardName), findsOneWidget);

      final categoryFilterFinder = find.byKey(
        const Key('dashboard_category_filter'),
      );
      expect(categoryFilterFinder, findsOneWidget);

      await tester.tap(categoryFilterFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('page shows title from localization', (tester) async {
      when(mockJournalDb.getAllDashboards).thenAnswer(
        (_) async => [testDashboardConfig],
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The page should show the Insights title (renamed from "Dashboards"
      // to match the Figma nav label).
      expect(find.textContaining('Insights'), findsAtLeast(1));
    });

    testWidgets('dashboards are sorted alphabetically by name', (tester) async {
      final dashboardZ = testDashboardConfig.copyWith(
        id: 'dashboard-z',
        name: 'Zebra Dashboard',
      );
      final dashboardA = testDashboardConfig.copyWith(
        id: 'dashboard-a',
        name: 'Alpha Dashboard',
      );

      when(mockJournalDb.getAllDashboards).thenAnswer(
        (_) async => [dashboardZ, dashboardA],
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Alpha should appear before Zebra
      final alphaFinder = find.text('Alpha Dashboard');
      final zebraFinder = find.text('Zebra Dashboard');

      expect(alphaFinder, findsOneWidget);
      expect(zebraFinder, findsOneWidget);

      // Verify ordering by checking positions
      final alphaPosition = tester.getCenter(alphaFinder);
      final zebraPosition = tester.getCenter(zebraFinder);
      expect(alphaPosition.dy, lessThan(zebraPosition.dy));
    });

    testWidgets('filter modal shows category chips', (tester) async {
      when(mockJournalDb.getAllDashboards).thenAnswer(
        (_) async => [testDashboardConfig],
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap filter button to open modal
      final categoryFilterFinder = find.byKey(
        const Key('dashboard_category_filter'),
      );
      await tester.tap(categoryFilterFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Modal should show category chip
      expect(find.text(categoryMindfulness.name), findsOneWidget);
    });

    testWidgets('tapping category chip toggles filter selection', (
      tester,
    ) async {
      final dashboardWithCategory = testDashboardConfig.copyWith(
        categoryId: categoryMindfulness.id,
      );
      final dashboardWithoutCategory = emptyTestDashboardConfig.copyWith(
        categoryId: null,
      );

      when(mockJournalDb.getAllDashboards).thenAnswer(
        (_) async => [dashboardWithCategory, dashboardWithoutCategory],
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both dashboards should be visible initially
      expect(find.text(testDashboardName), findsOneWidget);
      expect(find.text('Test Dashboard #2 - empty'), findsOneWidget);

      // Open filter modal
      final categoryFilterFinder = find.byKey(
        const Key('dashboard_category_filter'),
      );
      await tester.tap(categoryFilterFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Tap the category chip to filter
      final categoryChip = find.text(categoryMindfulness.name);
      expect(categoryChip, findsOneWidget);
      await tester.tap(categoryChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Close the modal
      await tester.tapAt(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Only dashboard with category should be visible
      expect(find.text(testDashboardName), findsOneWidget);
      expect(find.text('Test Dashboard #2 - empty'), findsNothing);
    });

    testWidgets('only active dashboards are displayed', (tester) async {
      final activeDashboard = testDashboardConfig.copyWith(active: true);
      final inactiveDashboard = emptyTestDashboardConfig.copyWith(
        active: false,
        name: 'Inactive Dashboard',
      );

      when(mockJournalDb.getAllDashboards).thenAnswer(
        (_) async => [activeDashboard, inactiveDashboard],
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardsListPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Only active dashboard should be visible
      expect(find.text(testDashboardName), findsOneWidget);
      expect(find.text('Inactive Dashboard'), findsNothing);
    });

    testWidgets(
      'renders desktop split layout with empty detail pane',
      (tester) async {
        when(mockJournalDb.getAllDashboards).thenAnswer(
          (_) async => [testDashboardConfig],
        );

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const DashboardsListPage(),
            mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(DesktopDetailEmptyState), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.width == 540,
          ),
          findsOneWidget,
        );
        expect(find.text(testDashboardName), findsOneWidget);
      },
    );

    testWidgets(
      'renders desktop split layout with selected dashboard detail',
      (tester) async {
        when(mockJournalDb.getAllDashboards).thenAnswer(
          (_) async => [testDashboardConfig],
        );
        final mockEntitiesCacheService =
            getIt<EntitiesCacheService>() as MockEntitiesCacheService;
        when(
          () => mockEntitiesCacheService.getDashboardById(
            testDashboardConfig.id,
          ),
        ).thenReturn(testDashboardConfig);

        final navService = getIt<NavService>() as MockNavService;
        final selectedNotifier = ValueNotifier<String?>(
          testDashboardConfig.id,
        );
        when(
          () => navService.desktopSelectedDashboardId,
        ).thenReturn(selectedNotifier);

        // Suppress overflow errors from the detail page — we only need the
        // code path in DashboardsListPage to be exercised.
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          final message = details.exceptionAsString();
          if (message.contains('overflowed')) return;
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const DashboardsListPage(),
            mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
          ),
        );
        await tester.pump();

        // Verify the selected-dashboard branch is taken (DashboardPage
        // renders, not the empty state placeholder).
        expect(find.byType(DesktopDetailEmptyState), findsNothing);
        expect(find.byType(DashboardPage), findsOneWidget);

        // Dispose and flush pending timers from flutter_animate.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'desktop pinned Time Analysis entry renders and beams to '
      '/dashboards/time on tap',
      (tester) async {
        when(
          mockJournalDb.getAllDashboards,
        ).thenAnswer((_) async => [testDashboardConfig]);

        final beamed = <String>[];
        beamToNamedOverride = beamed.add;
        addTearDown(() => beamToNamedOverride = null);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const DashboardsListPage(),
            mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Time Analysis'), findsOneWidget);
        expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);

        await tester.tap(find.text('Time Analysis'));
        await tester.pump();

        expect(beamed, ['/dashboards/time']);
      },
    );

    testWidgets(
      'desktop detail pane renders TimeAnalysisPage when '
      'desktopShowTimeAnalysis is set',
      (tester) async {
        when(
          mockJournalDb.getAllDashboards,
        ).thenAnswer((_) async => [testDashboardConfig]);

        final navService = getIt<NavService>() as MockNavService;
        when(
          () => navService.desktopShowTimeAnalysis,
        ).thenReturn(ValueNotifier<bool>(true));

        final insightsRepository = MockInsightsRepository();
        when(
          () => insightsRepository.fetchTimeRows(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer((_) async => []);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const DashboardsListPage(),
            mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
            overrides: [
              insightsRepositoryProvider.overrideWithValue(
                insightsRepository,
              ),
              maybeUpdateNotificationsProvider.overrideWith((ref) => null),
              categoriesStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The merged-listenable switch resolves to the Time Analysis pane,
        // not a dashboard or the empty state.
        expect(find.byType(TimeAnalysisPage), findsOneWidget);
        expect(find.byType(DashboardPage), findsNothing);
        expect(find.byType(DesktopDetailEmptyState), findsNothing);

        // The pinned entry reflects the active state with the filled icon.
        expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      },
    );

    testWidgets('mobile layout has no pinned Time Analysis entry', (
      tester,
    ) async {
      when(
        mockJournalDb.getAllDashboards,
      ).thenAnswer((_) async => [testDashboardConfig]);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const DashboardsListPage(),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Time Analysis'), findsNothing);
    });

    testWidgets('dragging divider updates list pane width', (tester) async {
      when(mockJournalDb.getAllDashboards).thenAnswer(
        (_) async => [testDashboardConfig],
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const DashboardsListPage(),
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ResizableDivider), findsOneWidget);

      final dividerCenter = tester.getCenter(find.byType(ResizableDivider));
      await tester.dragFrom(dividerCenter, const Offset(50, 0));
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == defaultListPaneWidth + 50,
        ),
      );
      expect(sizedBox.width, defaultListPaneWidth + 50);
    });
  });
}
