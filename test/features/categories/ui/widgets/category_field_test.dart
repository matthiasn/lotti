import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late MockEntitiesCacheService mockCacheService;
  final testCategory = CategoryDefinition(
    id: 'test-id',
    name: 'Test Category',
    color: '#FF0000',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    vectorClock: null,
    private: false,
    active: true,
  );

  setUp(() {
    mockCacheService = MockEntitiesCacheService();
    getIt.registerSingleton<EntitiesCacheService>(mockCacheService);
  });

  tearDown(() {
    getIt.unregister<EntitiesCacheService>();
  });

  Widget createTestWidget({
    required void Function(CategoryDefinition?) onSave,
    String? categoryId,
  }) {
    return WidgetTestBench(
      child: CategoryField(
        categoryId: categoryId,
        onSave: onSave,
      ),
    );
  }

  testWidgets('displays category name when category exists', (tester) async {
    when(() => mockCacheService.getCategoryById('test-id'))
        .thenReturn(testCategory);

    await tester.pumpWidget(
      createTestWidget(
        categoryId: 'test-id',
        onSave: (_) {},
      ),
    );

    expect(find.text('Test Category'), findsOneWidget);
  });

  testWidgets('shows hint text when no category selected', (tester) async {
    when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

    await tester.pumpWidget(
      createTestWidget(
        onSave: (_) {},
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('opens category selection modal when tapped', (tester) async {
    when(() => mockCacheService.getCategoryById(any())).thenReturn(null);
    when(() => mockCacheService.sortedCategories).thenReturn([testCategory]);

    await tester.pumpWidget(
      createTestWidget(
        onSave: (_) {},
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Verify the modal is shown with search field
    expect(find.byType(TextField), findsNWidgets(2)); // Original + search field
    expect(find.text('Test Category'), findsOneWidget);
  });

  testWidgets('can clear selected category', (tester) async {
    bool? savedValue;
    when(() => mockCacheService.getCategoryById('test-id'))
        .thenReturn(testCategory);

    await tester.pumpWidget(
      createTestWidget(
        categoryId: 'test-id',
        onSave: (category) => savedValue = category?.id == 'test-id',
      ),
    );

    // Find and tap the clear button
    final clearButton = find.byIcon(Icons.close_rounded);
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(savedValue, false);
  });

  testWidgets('can search and select category from modal', (tester) async {
    when(() => mockCacheService.getCategoryById(any())).thenReturn(null);
    when(() => mockCacheService.sortedCategories).thenReturn([testCategory]);

    CategoryDefinition? selectedCategory;

    await tester.pumpWidget(
      createTestWidget(
        onSave: (category) => selectedCategory = category,
      ),
    );

    // Open the modal
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Enter search text
    await tester.enterText(
      find.byType(TextField).at(1),
      'Test',
    ); // Second TextField is search
    await tester.pumpAndSettle();

    // Verify filtered results
    expect(find.text('Test Category'), findsOneWidget);

    // Select the category
    await tester.tap(find.text('Test Category'));
    await tester.pumpAndSettle();

    expect(selectedCategory, equals(testCategory));
  });

  testWidgets('shows create category option when search has no matches',
      (tester) async {
    when(() => mockCacheService.getCategoryById(any())).thenReturn(null);
    when(() => mockCacheService.sortedCategories).thenReturn([testCategory]);

    await tester.pumpWidget(
      createTestWidget(
        onSave: (_) {},
      ),
    );

    // Open the modal
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Enter search text that doesn't match any existing category
    await tester.enterText(
      find.byType(TextField).at(1),
      'New Category',
    );
    await tester.pumpAndSettle();

    // Verify create category option is shown
    expect(find.text('New Category'), findsNWidgets(2));
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('displays category icon with correct size', (tester) async {
    when(() => mockCacheService.getCategoryById('test-id'))
        .thenReturn(testCategory);

    await tester.pumpWidget(
      createTestWidget(
        categoryId: 'test-id',
        onSave: (_) {},
      ),
    );

    final icon = tester.widget<CategoryIconCompact>(find.byType(CategoryIconCompact));
    expect(icon.size, equals(CategoryIconConstants.iconSizeMedium));
  });
}
