import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/settings/ui/widgets/dashboards/dashboard_definition_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('DashboardDefinitionCard Widget Tests - ', () {
    final mockEntitiesCacheService = MockEntitiesCacheService();

    setUp(() {
      getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    });
    tearDown(getIt.reset);

    const testName = 'test dashboard name';
    const testDescription = 'test description';
    final testDateTime = DateTime.fromMillisecondsSinceEpoch(0);

    final testItem = DashboardDefinition(
      description: testDescription,
      createdAt: testDateTime,
      updatedAt: testDateTime,
      vectorClock: null,
      id: 'some-id',
      private: false,
      version: '1',
      lastReviewed: testDateTime,
      active: true,
      items: [],
      name: testName,
    );

    testWidgets('displays test dashboard card', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardDefinitionCard(dashboard: testItem),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testName), findsOneWidget);
      expect(find.byIcon(MdiIcons.security), findsNothing);
    });

    testWidgets('displays test dashboard card with private icon',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardDefinitionCard(
            dashboard: testItem.copyWith(private: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testName), findsOneWidget);
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });

    testWidgets('displays test dashboard card with private icon & review time',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardDefinitionCard(
            dashboard: testItem.copyWith(
              private: true,
              reviewAt: DateTime(0, 0, 0, 7),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testName), findsOneWidget);
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });
  });
}
