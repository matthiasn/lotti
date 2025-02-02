import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

class MockCategoriesRepository extends Mock implements CategoriesRepository {}

void main() {
  late MockCategoriesRepository mockRepository;

  setUp(() {
    mockRepository = MockCategoriesRepository();
    registerFallbackValue(FakeCategoryDefinition());
  });

  Widget createTestWidget({
    required void Function(CategoryDefinition) onCategoryCreated,
    String initialName = 'Test Category',
    String? initialColor,
  }) {
    return ProviderScope(
      overrides: [
        categoriesRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: createTestApp(
        CategoryCreateModal(
          onCategoryCreated: onCategoryCreated,
          initialName: initialName,
          initialColor: initialColor,
        ),
      ),
    );
  }

  testWidgets('displays initial category name', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        onCategoryCreated: (_) {},
      ),
    );

    expect(find.text('Test Category'), findsOneWidget);
  });

  testWidgets('calls repository and callback when saving', (tester) async {
    final createdCategories = <CategoryDefinition>[];

    when(
      () => mockRepository.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
      ),
    ).thenAnswer((invocation) async {
      final category = CategoryDefinition(
        id: 'test-id',
        name: invocation.namedArguments[const Symbol('name')] as String,
        color: invocation.namedArguments[const Symbol('color')] as String,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
      );
      return category;
    });

    await tester.pumpWidget(
      createTestWidget(
        initialName: 'New Category',
        onCategoryCreated: createdCategories.add,
      ),
    );

    // Find and tap the save button
    final saveButton = find.text('Save');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify repository was called with correct parameters
    verify(
      () => mockRepository.createCategory(
        name: 'New Category',
        color: any(named: 'color'),
      ),
    ).called(1);

    // Verify callback was called
    expect(createdCategories.length, 1);
    expect(createdCategories.first.name, 'New Category');
  });

  testWidgets('can modify category name', (tester) async {
    when(
      () => mockRepository.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
      ),
    ).thenAnswer((invocation) async {
      return CategoryDefinition(
        id: 'test-id',
        name: invocation.namedArguments[const Symbol('name')] as String,
        color: invocation.namedArguments[const Symbol('color')] as String,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
      );
    });

    await tester.pumpWidget(
      createTestWidget(
        initialName: 'Initial Name',
        onCategoryCreated: (_) {},
      ),
    );

    // Find and modify the text field
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'Modified Name');

    // Find and tap the save button
    final saveButton = find.text('Save');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify repository was called with modified name
    verify(
      () => mockRepository.createCategory(
        name: 'Modified Name',
        color: any(named: 'color'),
      ),
    ).called(1);
  });

  testWidgets('closes modal when tapping cancel', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        onCategoryCreated: (_) {},
      ),
    );

    // Find and tap the cancel button
    final cancelButton = find.text('Cancel');
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    // Verify repository was not called
    verifyNever(
      () => mockRepository.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
      ),
    );
  });
}
