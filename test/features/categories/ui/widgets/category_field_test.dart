import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
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
    createdAt: DateTime(2024, 3, 15, 10, 30),
    updatedAt: DateTime(2024, 3, 15, 10, 30),
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
    when(
      () => mockCacheService.getCategoryById('test-id'),
    ).thenReturn(testCategory);

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
    when(
      () => mockCacheService.getCategoryById('test-id'),
    ).thenReturn(testCategory);

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

  testWidgets(
    'row tap closes the modal without popping the outer nested route',
    (tester) async {
      // Reproduces the bottom-nav topology: CategoryField lives in a
      // per-tab nested Navigator inside the root MaterialApp Navigator.
      // On phone width the modal opens on the root Navigator
      // (`shouldUseRootNavigatorForBottomSheet`), so popping with the
      // field's outer context would pop the nested route instead of the
      // modal — this test guards against that regression.
      when(() => mockCacheService.getCategoryById(any())).thenReturn(null);
      when(() => mockCacheService.sortedCategories).thenReturn([testCategory]);

      CategoryDefinition? selectedCategory;

      await tester.pumpWidget(
        WidgetTestBench(
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => CategoryField(
                categoryId: null,
                onSave: (category) => selectedCategory = category,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Category'));
      await tester.pumpAndSettle();

      expect(selectedCategory, equals(testCategory));
      // Modal closed.
      expect(find.byType(CategorySelectionModalContent), findsNothing);
      // Outer nested route was NOT popped — the field is still mounted.
      // If the pop had targeted the field's outer context, the nested
      // Navigator's MaterialPageRoute would have been removed and the
      // CategoryField would no longer be in the tree.
      expect(find.byType(CategoryField), findsOneWidget);
    },
  );

  testWidgets('shows create category option when search has no matches', (
    tester,
  ) async {
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
    await tester.pump();

    // Verify create category option is shown
    expect(find.text('New Category'), findsNWidgets(2));
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('displays category icon with correct size', (tester) async {
    when(
      () => mockCacheService.getCategoryById('test-id'),
    ).thenReturn(testCategory);

    await tester.pumpWidget(
      createTestWidget(
        categoryId: 'test-id',
        onSave: (_) {},
      ),
    );

    final icon = tester.widget<CategoryIconCompact>(
      find.byType(CategoryIconCompact),
    );
    expect(icon.size, equals(CategoryIconConstants.iconSizeMedium));
  });
}
