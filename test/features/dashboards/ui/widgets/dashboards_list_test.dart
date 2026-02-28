import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_card.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_list.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

DashboardDefinition _makeDashboard({
  required String id,
  required String name,
}) {
  return DashboardDefinition(
    id: id,
    name: name,
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
}

void main() {
  late MockEntitiesCacheService mockCache;

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        mockCache = MockEntitiesCacheService();
        when(() => mockCache.getCategoryById(any())).thenReturn(null);
        getIt.registerSingleton<EntitiesCacheService>(mockCache);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('DashboardsList', () {
    testWidgets('renders DashboardCard for each dashboard', (tester) async {
      final dashboards = [
        _makeDashboard(id: '1', name: 'Health'),
        _makeDashboard(id: '2', name: 'Fitness'),
      ];

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SizedBox(
            height: 600,
            child: CustomScrollView(
              slivers: [DashboardsList()],
            ),
          ),
          overrides: [
            filteredSortedDashboardsProvider.overrideWith(
              (ref) => dashboards,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardCard), findsNWidgets(2));
      expect(find.text('Health'), findsOneWidget);
      expect(find.text('Fitness'), findsOneWidget);
    });

    testWidgets('renders empty when no dashboards', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SizedBox(
            height: 600,
            child: CustomScrollView(
              slivers: [DashboardsList()],
            ),
          ),
          overrides: [
            filteredSortedDashboardsProvider.overrideWith((ref) => []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardCard), findsNothing);
    });
  });
}
