import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/categories/ui/widgets/category_type_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late MockEntitiesCacheService mockEntitiesCacheService;
  final testCategories = [
    CategoryDefinition(
      id: 'cat1',
      name: 'Category 1',
      color: '#FF0000',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      private: false,
      active: true,
      favorite: true,
    ),
    CategoryDefinition(
      id: 'cat2',
      name: 'Category 2',
      color: '#00FF00',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      private: false,
      active: true,
      favorite: false,
    ),
    CategoryDefinition(
      id: 'cat3',
      name: 'Category 3',
      color: '#0000FF',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      private: false,
      active: true,
      favorite: false,
    ),
  ];

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn(testCategories);
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(() {
    getIt.unregister<EntitiesCacheService>();
  });

  testWidgets('displays all categories', (tester) async {
    final selectedCategories = <CategoryDefinition?>[];

    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: selectedCategories.add,
        ),
      ),
    );

    // Verify all categories are displayed
    expect(find.text('Category 1'), findsWidgets);
    expect(find.text('Category 2'), findsOneWidget);
    expect(find.text('Category 3'), findsOneWidget);
  });

  testWidgets('filters categories by search query', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: (_) {},
        ),
      ),
    );

    // Enter search query
    await tester.enterText(find.byType(TextField), 'Category 1');
    await tester.pump();

    // Verify only matching category is displayed
    expect(find.byType(CategoryTypeCard), findsOneWidget);
    expect(find.text('Category 2'), findsNothing);
    expect(find.text('Category 3'), findsNothing);
  });

  testWidgets('callback is called when category is selected', (tester) async {
    final selectedCategories = <CategoryDefinition?>[];

    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: selectedCategories.add,
        ),
      ),
    );

    // Tap on a category
    await tester.tap(find.text('Category 2'));
    await tester.pumpAndSettle();

    // Verify callback was called with correct category
    expect(selectedCategories.length, 1);
    expect(selectedCategories.first?.id, 'cat2');
  });

  testWidgets('displays "clear" option when initialCategoryId is provided',
      (tester) async {
    final selectedCategories = <CategoryDefinition?>[];

    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: selectedCategories.add,
          initialCategoryId: 'cat1',
        ),
      ),
    );

    // Verify clear option is displayed
    expect(find.text('clear'), findsOneWidget);

    // Tap on clear
    await tester.tap(find.text('clear'));
    await tester.pumpAndSettle();

    // Verify callback was called with null
    expect(selectedCategories.length, 1);
    expect(selectedCategories.first, isNull);
  });

  testWidgets('shows "create category" option when search has no matches',
      (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: (_) {},
        ),
      ),
    );

    // Enter search query with no matches
    await tester.enterText(find.byType(TextField), 'New Category');
    await tester.pump();

    // Verify the add option is displayed with the search query as title
    expect(
      find.text('New Category'),
      findsWidgets,
    ); // Once in TextField, once in card
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('separates favorite and other categories', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: (_) {},
        ),
      ),
    );

    // Find all CategoryTypeCard widgets
    final categoryCards = find.byType(CategoryTypeCard);
    expect(categoryCards, findsNWidgets(3));

    // Get the first CategoryTypeCard widget
    final firstCardWidget =
        tester.widget<CategoryTypeCard>(categoryCards.first);
    expect(firstCardWidget.categoryDefinition.favorite, isTrue);
  });
}
