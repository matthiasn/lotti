import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_type_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late MockEntitiesCacheService mockEntitiesCacheService;

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(() {
    getIt.unregister<EntitiesCacheService>();
  });

  testWidgets('CategoriesTypeCard displays all elements correctly',
      (WidgetTester tester) async {
    final category = CategoryDefinition(
      id: 'test-id',
      name: 'Test Category',
      color: '#FF0000',
      private: true,
      favorite: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      active: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryTypeNavCard(
            category,
            index: 0,
          ),
        ),
      ),
    );

    // Verify category name is displayed
    expect(find.text('Test Category'), findsOneWidget);

    // Verify color icon is present
    expect(find.byType(ColorIcon), findsOneWidget);

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

  testWidgets('CategoriesTypeCard hides private and favorite icons when false',
      (WidgetTester tester) async {
    final category = CategoryDefinition(
      id: 'test-id',
      name: 'Test Category',
      color: '#FF0000',
      private: false,
      favorite: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      active: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryTypeNavCard(
            category,
            index: 0,
          ),
        ),
      ),
    );

    // Verify category name is displayed
    expect(find.text('Test Category'), findsOneWidget);

    // Verify color icon is present
    expect(find.byType(ColorIcon), findsOneWidget);

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
  });

  testWidgets('CategoryColorIcon displays correct color from cache service',
      (WidgetTester tester) async {
    const categoryId = 'test-category-id';
    final category = CategoryDefinition(
      id: categoryId,
      name: 'Test Category',
      color: '#FF0000',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      active: true,
      private: false,
    );

    when(() => mockEntitiesCacheService.getCategoryById(categoryId))
        .thenReturn(category);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CategoryColorIcon('test-category-id'),
        ),
      ),
    );

    expect(find.byType(ColorIcon), findsOneWidget);
    verify(() => mockEntitiesCacheService.getCategoryById(categoryId))
        .called(1);
  });
}
