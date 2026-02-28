import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockEntitiesCacheService mockCache;
  late MockHealthImport mockHealthImport;

  setUp(() async {
    mockHealthImport = MockHealthImport();
    when(() => mockHealthImport.getWorkoutsHealthDataDelta())
        .thenAnswer((_) async {});
    when(() => mockHealthImport.fetchHealthDataDelta(any()))
        .thenAnswer((_) async {});

    await setUpTestGetIt(
      additionalSetup: () {
        mockCache = MockEntitiesCacheService();
        when(() => mockCache.getCategoryById(any())).thenReturn(null);
        when(() => mockCache.getDashboardById(any())).thenReturn(null);
        getIt
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<HealthImport>(mockHealthImport);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('DashboardWidget', () {
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 15);

    testWidgets('renders nothing when dashboard is null', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWidget(
            dashboardId: 'non-existent',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            dashboardByIdProvider('non-existent').overrideWith((ref) => null),
          ],
        ),
      );
      await tester.pump();

      // DashboardWidget returns SizedBox.shrink() when dashboard is null
      expect(
        find.descendant(
          of: find.byType(DashboardWidget),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 0 && w.height == 0,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders dashboard description', (tester) async {
      final dashboard = DashboardDefinition(
        id: 'test-id',
        name: 'Test Dashboard',
        description: 'A test description',
        items: [],
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        private: false,
        version: '',
        lastReviewed: DateTime(2024, 3, 15),
        active: true,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWidget(
            dashboardId: 'test-id',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            dashboardByIdProvider('test-id').overrideWith((ref) => dashboard),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('A test description'), findsOneWidget);
    });

    testWidgets('shows title when showTitle is true', (tester) async {
      final dashboard = DashboardDefinition(
        id: 'test-id',
        name: 'My Dashboard',
        description: '',
        items: [],
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        private: false,
        version: '',
        lastReviewed: DateTime(2024, 3, 15),
        active: true,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWidget(
            dashboardId: 'test-id',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            showTitle: true,
          ),
          overrides: [
            dashboardByIdProvider('test-id').overrideWith((ref) => dashboard),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('My Dashboard'), findsOneWidget);
    });

    testWidgets('renders story time not-implemented text', (tester) async {
      final dashboard = DashboardDefinition(
        id: 'test-id',
        name: 'With Story',
        description: '',
        items: [
          const DashboardStoryTimeItem(
            storyTagId: 'story-tag-1',
            color: '#00FF00',
          ),
        ],
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        private: false,
        version: '',
        lastReviewed: DateTime(2024, 3, 15),
        active: true,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWidget(
            dashboardId: 'test-id',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          overrides: [
            dashboardByIdProvider('test-id').overrideWith((ref) => dashboard),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.text('Story Time Chart currently not implemented'),
        findsOneWidget,
      );
    });
  });
}
