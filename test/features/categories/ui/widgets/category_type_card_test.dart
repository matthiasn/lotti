import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_type_card.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

import '../../../../mocks/mocks.dart';

void main() {
  late MockEntitiesCacheService mockEntitiesCacheService;

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(() {
    getIt.unregister<EntitiesCacheService>();
  });

  testWidgets('CategoriesTypeCard displays all elements correctly', (
    WidgetTester tester,
  ) async {
    final testDate = DateTime(2024, 3, 15);
    final category = CategoryDefinition(
      id: 'test-id',
      name: 'Test Category',
      color: '#FF0000',
      private: true,
      favorite: true,
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      active: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryTypeCard(
            category,
            onTap: () {},
          ),
        ),
      ),
    );

    // Verify category name is displayed
    expect(find.text('Test Category'), findsOneWidget);

    // Verify color icon is present
    expect(find.byType(CategoryIconCompact), findsOneWidget);

    // Verify private icon is shown
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == MdiIcons.security,
      ),
      findsOneWidget,
    );

    // Verify favorite star is shown
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == MdiIcons.star,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'CategoriesTypeCard hides private and favorite icons when false',
    (WidgetTester tester) async {
      final testDate = DateTime(2024, 3, 15);
      final category = CategoryDefinition(
        id: 'test-id',
        name: 'Test Category',
        color: '#FF0000',
        private: false,
        favorite: false,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        active: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryTypeCard(
              category,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify category name is displayed
      expect(find.text('Test Category'), findsOneWidget);

      // Verify color icon is present
      expect(find.byType(CategoryIconCompact), findsOneWidget);

      // Verify private icon is not shown
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon == MdiIcons.security,
        ),
        findsNothing,
      );

      // Verify favorite star is not shown
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon == MdiIcons.star,
        ),
        findsNothing,
      );
    },
  );

  testWidgets('forwards taps to onTap', (WidgetTester tester) async {
    final testDate = DateTime(2024, 3, 15);
    final category = CategoryDefinition(
      id: 'test-id',
      name: 'Tappable',
      color: '#FF0000',
      private: false,
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      active: true,
    );
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryTypeCard(
            category,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tappable'));
    expect(taps, 1);
  });

  testWidgets(
    'selected state tints the card background; unselected is transparent',
    (WidgetTester tester) async {
      final testDate = DateTime(2024, 3, 15);
      final category = CategoryDefinition(
        id: 'test-id',
        name: 'Selectable',
        color: '#FF0000',
        private: false,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        active: true,
      );

      for (final selected in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryTypeCard(
                category,
                onTap: () {},
                selected: selected,
              ),
            ),
          ),
        );

        final card = tester.widget<SettingsCard>(find.byType(SettingsCard));
        final context = tester.element(find.byType(SettingsCard));
        expect(
          card.backgroundColor,
          selected
              ? Theme.of(context).colorScheme.outline.withAlpha(55)
              : Colors.transparent,
          reason: 'selected=$selected',
        );
      }
    },
  );
}
