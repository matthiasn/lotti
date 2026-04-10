import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboards_list_page.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();

  group('DashboardDefinitionPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeDashboardDefinition());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      final mockEntitiesCacheService = MockEntitiesCacheService();
      final mockUpdateNotifications = MockUpdateNotifications();

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => const Stream.empty());

      when(
        mockJournalDb.getAllCategories,
      ).thenAnswer((_) async => [categoryMindfulness]);

      final mockNavService = MockNavService();
      when(() => mockNavService.isDesktopMode).thenReturn(false);
      when(
        () => mockNavService.desktopSelectedDashboardId,
      ).thenReturn(ValueNotifier<String?>(null));

      final mockSettingsDb = MockSettingsDb();
      when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => mockSettingsDb.itemsByKeys(any()),
      ).thenAnswer((_) async => <String, String?>{});
      when(
        () => mockSettingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<NavService>(mockNavService);
    });
    tearDown(getIt.reset);

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

      await tester.pumpAndSettle();

      verify(mockJournalDb.getAllDashboards).called(1);

      // finds text in dashboard card
      expect(find.text(testDashboardName), findsOneWidget);

      final categoryFilterFinder = find.byKey(
        const Key('dashboard_category_filter'),
      );
      expect(categoryFilterFinder, findsOneWidget);

      await tester.tap(categoryFilterFinder);
      await tester.pumpAndSettle();
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

      await tester.pumpAndSettle();

      // The page should show the Dashboards title in the header
      expect(find.textContaining('Dashboards'), findsAtLeast(1));
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

      await tester.pumpAndSettle();

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

      await tester.pumpAndSettle();

      // Tap filter button to open modal
      final categoryFilterFinder = find.byKey(
        const Key('dashboard_category_filter'),
      );
      await tester.tap(categoryFilterFinder);
      await tester.pumpAndSettle();

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

      await tester.pumpAndSettle();

      // Both dashboards should be visible initially
      expect(find.text(testDashboardName), findsOneWidget);
      expect(find.text('Test Dashboard #2 - empty'), findsOneWidget);

      // Open filter modal
      final categoryFilterFinder = find.byKey(
        const Key('dashboard_category_filter'),
      );
      await tester.tap(categoryFilterFinder);
      await tester.pumpAndSettle();

      // Tap the category chip to filter
      final categoryChip = find.text(categoryMindfulness.name);
      expect(categoryChip, findsOneWidget);
      await tester.tap(categoryChip);
      await tester.pumpAndSettle();

      // Close the modal
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

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

      await tester.pumpAndSettle();

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

        await tester.pumpAndSettle();

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
  });
}
