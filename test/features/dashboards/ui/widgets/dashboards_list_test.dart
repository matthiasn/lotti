import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_card.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

DashboardDefinition _makeDashboard({
  required String id,
  required String name,
  String description = '',
}) {
  return DashboardDefinition(
    id: id,
    name: name,
    description: description,
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
      await tester.pump();

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
      await tester.pump();

      expect(find.byType(DashboardCard), findsNothing);
    });

    testWidgets('uses DesignSystemListItem with dividers', (tester) async {
      final dashboards = [
        _makeDashboard(id: '1', name: 'Alpha'),
        _makeDashboard(id: '2', name: 'Beta'),
        _makeDashboard(id: '3', name: 'Gamma'),
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
      await tester.pump();

      // Each DashboardCard renders a DesignSystemListItem
      expect(find.byType(DesignSystemListItem), findsNWidgets(3));
    });

    testWidgets('displays dashboard description as subtitle', (tester) async {
      final dashboards = [
        _makeDashboard(
          id: '1',
          name: 'Body',
          description: 'Body measurements',
        ),
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
      await tester.pump();

      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Body measurements'), findsOneWidget);
    });

    testWidgets('wraps items in a grouped card with design-token background', (
      tester,
    ) async {
      final dashboards = [
        _makeDashboard(id: '1', name: 'Health'),
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
      await tester.pump();

      // The DashboardsList wraps cards in a DecoratedBox whose BoxDecoration
      // uses the design-token background color. Find the specific DecoratedBox
      // that is an ancestor of the DashboardCard.
      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(DashboardCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );

      final boxDecoration = decoratedBox.decoration as BoxDecoration;
      final tokens = tester.element(find.byType(DashboardsList)).designTokens;
      expect(boxDecoration.color, tokens.colors.background.level02);
      expect(
        boxDecoration.border,
        Border.all(color: tokens.colors.decorative.level01),
      );
      // The same radius clips the rows, so the last divider cannot poke out.
      expect(
        tester
            .widget<ClipRRect>(
              find
                  .ancestor(
                    of: find.byType(DashboardCard),
                    matching: find.byType(ClipRRect),
                  )
                  .first,
            )
            .borderRadius,
        boxDecoration.borderRadius,
      );
    });

    testWidgets('shows chevron trailing icon on each item', (tester) async {
      final dashboards = [
        _makeDashboard(id: '1', name: 'Metrics'),
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
      await tester.pump();

      expect(
        find.byIcon(LottiIcons.chevronRight),
        findsOneWidget,
      );
    });
  });
}
