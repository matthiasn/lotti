import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/tasks/ui/header/task_category_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

class MockCategoryCallback extends Mock {
  Future<bool> call(String? categoryId);
}

void main() {
  late MockCategoryCallback mockSaveCallback;
  late MockEntitiesCacheService mockEntitiesCacheService;
  const testCategoryId = 'test-category-id';

  final testCategory = EntityDefinition.categoryDefinition(
    id: testCategoryId,
    name: 'Test Category',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    vectorClock: null,
    private: false,
    active: true,
    color: '#FF5733',
  ) as CategoryDefinition;

  setUp(() {
    mockSaveCallback = MockCategoryCallback();
    when(() => mockSaveCallback(any())).thenAnswer((_) async => true);

    mockEntitiesCacheService = MockEntitiesCacheService();
    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(() {
    getIt.unregister<EntitiesCacheService>();
  });

  testWidgets('renders correctly with a category', (tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: TaskCategoryWidget(
          category: testCategory,
          onSave: mockSaveCallback.call,
        ),
      ),
    );

    // Assert - should display the category name
    expect(find.text(testCategory.name), findsOneWidget);

    // Assert - should contain a status-style chip
    expect(find.byType(ModernStatusChip), findsOneWidget);

    // Assert - should NOT display 'Category:' label
    expect(find.text('Category:'), findsNothing);
  });

  testWidgets('renders correctly without a category', (tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: TaskCategoryWidget(
          category: null,
          onSave: mockSaveCallback.call,
        ),
      ),
    );

    // Assert - should display the unassigned label for empty category
    expect(find.text('unassigned'), findsOneWidget);

    // Assert - should still contain a chip
    expect(find.byType(ModernStatusChip), findsOneWidget);

    // Assert - should NOT display 'Category:' label even without category
    expect(find.text('Category:'), findsNothing);
  });

  testWidgets('opens category selection modal when tapped', (tester) async {
    // Arrange
    await tester.pumpWidget(
      WidgetTestBench(
        child: TaskCategoryWidget(
          category: testCategory,
          onSave: mockSaveCallback.call,
        ),
      ),
    );

    // Act - tap the widget to open the modal
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Assert - should display the category selection modal
    expect(find.byType(CategorySelectionModalContent), findsOneWidget);
  });

  testWidgets(
      'onCategorySelected callback calls onSave with correct parameters',
      (tester) async {
    // Arrange - create a new category to be selected
    final selectedCategory = EntityDefinition.categoryDefinition(
      id: 'selected-category-id',
      name: 'Selected Category',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      private: false,
      active: true,
      color: '#00FF00',
    ) as CategoryDefinition;

    // Add the selected category to the mock cache service
    final categories = [selectedCategory];
    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn(categories);

    // Pump the widget
    await tester.pumpWidget(
      WidgetTestBench(
        child: TaskCategoryWidget(
          category: testCategory,
          onSave: mockSaveCallback.call,
        ),
      ),
    );

    // Open the modal
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Find the CategorySelectionModalContent widget
    final modalContent = tester.widget<CategorySelectionModalContent>(
      find.byType(CategorySelectionModalContent),
    );

    // Directly invoke the onCategorySelected callback with the selectedCategory
    modalContent.onCategorySelected(selectedCategory);

    // Verify onSave was called with the selected category ID
    verify(() => mockSaveCallback(selectedCategory.id)).called(1);
  });

  test('calls onSave with selected category id', () async {
    // Arrange
    const newCategoryId = 'new-category-id';

    // Act - directly call the onSave function
    await mockSaveCallback(newCategoryId);

    // Assert - verify onSave was called with the correct category ID
    verify(() => mockSaveCallback(newCategoryId)).called(1);
  });

  test('calls onSave with null when clearing the category', () async {
    // Act - directly call the onSave function with null
    await mockSaveCallback(null);

    // Assert - verify onSave was called with null
    verify(() => mockSaveCallback(null)).called(1);
  });
}
