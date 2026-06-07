import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/dashboards/state/chart_scale_controller.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
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
        // With the default phone screen width (390 < 450) short labels are used.
        await tester.ensureVisible(find.text('30d'));
        await tester.tap(find.text('30d'));
        await tester.pump(const Duration(seconds: 1));

        // After setState the control must reflect the new selection
        final updated = tester.widget<TimeSpanSegmentedControl>(
          find.byType(TimeSpanSegmentedControl),
        );
        expect(updated.timeSpanDays, 30);
      },
    );

    testWidgets(
      'transformation controller listener propagates scale to barWidthControllerProvider',
      (tester) async {
        when(
          () => mockPersistenceLogic.createMeasurementEntry(
            data: any(named: 'data'),
            private: false,
          ),
        ).thenAnswer((_) async => null);

        // Track calls to updateScale via a capturing override of the notifier.
        final scalesReceived = <double>[];
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DashboardPage(dashboardId: testDashboardConfig.id),
            overrides: [
              barWidthControllerProvider.overrideWith(
                () => _CapturingBarWidthController(
                  onScaleUpdate: scalesReceived.add,
                ),
              ),
            ],
          ),
        );

        await tester.pump(const Duration(seconds: 1));

        // DashboardPage creates the TransformationController in initState and
        // hands it down to DashboardWidget, which forwards it to every chart's
        // fl_chart interactive viewer. Grab that exact controller from the
        // rendered DashboardWidget so we can drive it the same way fl_chart's
        // pinch gesture would. A synthetic two-pointer pinch on the chart does
        // not propagate through fl_chart's internal viewer in the headless test
        // environment, so we mutate the shared controller directly instead.
        final dashboardWidget = tester.widget<DashboardWidget>(
          find.byType(DashboardWidget),
        );
        final controller = dashboardWidget.transformationController;
        expect(controller, isNotNull);

        // Apply a horizontal pinch-out (2x scale on the x-axis). Setting the
        // controller value fires the listener registered by DashboardPage in
        // initState, which calls updateScale → scalesReceived is populated.
        controller!.value = Matrix4.identity()..scaleByDouble(2, 1, 1, 1);
        await tester.pump(const Duration(seconds: 1));

        // The listener must have fired: the captured scale is the x-axis factor
        // we applied (> 0, and equal to 2.0 for this pinch-out).
        expect(scalesReceived, isNotEmpty);
        for (final s in scalesReceived) {
          expect(s, greaterThan(0));
        }
        expect(scalesReceived.last, 2.0);
      },
    );
  });
}

/// A [BarWidthController] variant that records every [updateScale] call,
/// allowing tests to verify the DashboardPage listener fires correctly.
class _CapturingBarWidthController extends BarWidthController {
  _CapturingBarWidthController({required this.onScaleUpdate});

  final void Function(double scale) onScaleUpdate;

  @override
  void updateScale(Matrix4 scale) {
    super.updateScale(scale);
    onScaleUpdate(scale.row0.x);
  }
}
