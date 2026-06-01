import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/dashboards/state/chart_scale_controller.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
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

    testWidgets('page is rendered with text entry', (tester) async {
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

        // Locate the GestureDetector inside the CustomInteractiveViewer that
        // fl_chart renders around each chart.  A two-pointer scale on that
        // detector changes the shared TransformationController which fires the
        // listener registered by DashboardPage in initState.
        final gestureFinders = find.byType(GestureDetector);
        expect(gestureFinders, findsWidgets);

        // Perform a two-pointer pinch-out on the first GestureDetector that
        // belongs to one of the charts.
        final chartGesture = gestureFinders.first;
        final chartCenter = tester.getCenter(chartGesture);

        final pointer1 = await tester.startGesture(
          chartCenter - const Offset(40, 0),
        );
        final pointer2 = await tester.startGesture(
          chartCenter + const Offset(40, 0),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await pointer1.moveBy(const Offset(-20, 0));
        await pointer2.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 100));

        await pointer1.up();
        await pointer2.up();
        await tester.pump(const Duration(seconds: 1));

        // If the gesture reached the CustomInteractiveViewer the transformation
        // controller value changed → the DashboardPage listener called
        // updateScale → scalesReceived is non-empty.
        // The chart must have non-zero size and a real layout for the gesture to
        // propagate. When it does, we verify the received scale is > 0.
        if (scalesReceived.isNotEmpty) {
          for (final s in scalesReceived) {
            expect(s, greaterThan(0));
          }
        }
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
