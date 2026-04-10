import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_card.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

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

  group('DashboardCard', () {
    final dashboard = DashboardDefinition(
      id: 'test-dashboard-id',
      name: 'Health Overview',
      description: 'Track your health metrics',
      items: [],
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
      private: false,
      version: '',
      lastReviewed: DateTime(2024, 3, 15),
      active: true,
    );

    testWidgets('displays dashboard name', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardCard(dashboard: dashboard, showDivider: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Health Overview'), findsOneWidget);
    });

    testWidgets('displays dashboard description as subtitle', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardCard(dashboard: dashboard, showDivider: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track your health metrics'), findsOneWidget);
    });

    testWidgets('does not show subtitle when description is empty', (
      tester,
    ) async {
      final emptyDesc = DashboardDefinition(
        id: 'test-id',
        name: 'Empty',
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
        makeTestableWidget(
          DashboardCard(dashboard: emptyDesc, showDivider: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Empty'), findsOneWidget);
      // The subtitle Text widget should not be created
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == '',
        ),
        findsNothing,
      );
    });

    testWidgets('renders as DesignSystemListItem with chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardCard(dashboard: dashboard, showDivider: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemListItem), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('shows divider when showDivider is true', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardCard(dashboard: dashboard, showDivider: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('does not show divider when showDivider is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardCard(dashboard: dashboard, showDivider: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsNothing);
    });
  });
}
