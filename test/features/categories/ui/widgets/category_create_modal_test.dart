import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  late MockCategoryRepository mockRepository;

  setUp(() {
    mockRepository = MockCategoryRepository();
    registerFallbackValue(FakeCategoryDefinition());
  });

  Widget createTestWidget({
    required void Function(CategoryDefinition) onCategoryCreated,
    String initialName = 'Test Category',
    String? initialColor,
  }) {
    return ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: WidgetTestBench(
        child: CategoryCreateModal(
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
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final category = CategoryDefinition(
        id: 'test-id',
        name: invocation.namedArguments[const Symbol('name')] as String,
        color: invocation.namedArguments[const Symbol('color')] as String,
        createdAt: testDate,
        updatedAt: testDate,
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
      final testDate = DateTime(2024, 3, 15, 10, 30);
      return CategoryDefinition(
        id: 'test-id',
        name: invocation.namedArguments[const Symbol('name')] as String,
        color: invocation.namedArguments[const Symbol('color')] as String,
        createdAt: testDate,
        updatedAt: testDate,
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

  testWidgets(
    'shows an error toast when saving with an empty name and does not '
    'call the repository',
    (tester) async {
      final createdCategories = <CategoryDefinition>[];

      await tester.pumpWidget(
        createTestWidget(
          initialName: '   ',
          onCategoryCreated: createdCategories.add,
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      );
      expect(createdCategories, isEmpty);
      expect(find.textContaining('Category name is required'), findsOneWidget);
    },
  );

  testWidgets(
    'shows an error toast when the repository throws and keeps the modal open',
    (tester) async {
      when(
        () => mockRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      ).thenThrow(Exception('DB offline'));

      final createdCategories = <CategoryDefinition>[];

      await tester.pumpWidget(
        createTestWidget(
          initialName: 'Broken',
          onCategoryCreated: createdCategories.add,
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(createdCategories, isEmpty);
      expect(
        find.textContaining('Failed to create category'),
        findsOneWidget,
      );
      // Modal stays mounted so the user can fix and retry.
      expect(find.byType(CategoryCreateModal), findsOneWidget);
    },
  );
}
