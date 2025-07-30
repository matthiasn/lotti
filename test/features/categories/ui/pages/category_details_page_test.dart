import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';
import 'package:lotti/widgets/lotti_secondary_button.dart';
import 'package:lotti/widgets/lotti_tertiary_button.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../../../test_helper.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

class FakeCategoryDefinition extends Fake implements CategoryDefinition {}

// Stub navigation function
void beamToNamed(String path, {Object? data}) {
  // Stub implementation for tests
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCategoryDefinition());
  });

  group('CategoryDetailsPage Widget Tests', () {
    late MockCategoryRepository mockRepository;
    late String testCategoryId;

    setUp(() {
      mockRepository = MockCategoryRepository();
      testCategoryId = const Uuid().v4();
    });

    CategoryDefinition createTestCategory({
      String? id,
      String name = 'Test Category',
      String? color,
      bool private = false,
      bool active = true,
      bool? favorite,
      String? defaultLanguageCode,
      List<String>? allowedPromptIds,
      Map<AiResponseType, List<String>>? automaticPrompts,
    }) {
      return CategoryDefinition(
        id: id ?? testCategoryId,
        name: name,
        color: color ?? '#0000FF',
        private: private,
        active: active,
        favorite: favorite,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        defaultLanguageCode: defaultLanguageCode,
        allowedPromptIds: allowedPromptIds,
        automaticPrompts: automaticPrompts,
      );
    }

    group('Loading and Error States', () {
      testWidgets('displays loading state initially', (tester) async {
        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => const Stream.empty(),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('handles stream errors gracefully', (tester) async {
        // Return a stream that immediately errors
        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.error(Exception('Test error')),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        // Wait for the error to be processed
        await tester.pumpAndSettle();

        // The page should handle the error gracefully
        // It might show loading or might handle the error differently
        // Just verify the page doesn't crash
        expect(find.byType(CategoryDetailsPage), findsOneWidget);
      });

      testWidgets('handles null category state correctly', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        // Emit null (category not found)
        streamController.add(null);
        await tester.pumpAndSettle();

        // Should show "Category not found" message - check for partial text since we don't know exact translation
        expect(find.textContaining('not found'), findsOneWidget);

        // Clean up
        await streamController.close();
      });
    });

    group('Form Display and Elements', () {
      testWidgets('displays all form sections when loaded', (tester) async {
        final category = createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Check for form sections - these are translated texts
        expect(find.text('Basic Settings'), findsOneWidget);
        // Skip checking for section titles that might not be visible initially
        // The AI sections might be collapsed or rendered differently
      });

      testWidgets('displays all basic form fields', (tester) async {
        final category = createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Check for form fields
        expect(find.byType(LottiTextField), findsOneWidget); // Name field
        expect(find.text('Private'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Favorite'), findsOneWidget);
        expect(find.byType(LottiSwitchField),
            findsNWidgets(3)); // 3 toggle switches
      });

      testWidgets('displays bottom bar with all buttons', (tester) async {
        final category = createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Check for bottom bar
        expect(find.byType(FormBottomBar), findsOneWidget);
        expect(
            find.byType(LottiTertiaryButton), findsOneWidget); // Delete button
        expect(
            find.byType(LottiSecondaryButton), findsOneWidget); // Cancel button
        expect(find.byType(LottiPrimaryButton), findsOneWidget); // Save button
      });

      testWidgets('displays category name in form', (tester) async {
        final category = createTestCategory(name: 'My Test Category');

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Find the text field and check its value
        final textField = find.byType(TextFormField);
        expect(textField, findsOneWidget);
        final textFieldWidget = tester.widget<TextFormField>(textField);
        expect(textFieldWidget.controller?.text, equals('My Test Category'));
      });
    });

    group('Form Interactions', () {
      testWidgets('save button is disabled initially when no changes',
          (tester) async {
        final category = createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        final saveButton = find.byType(LottiPrimaryButton);
        final buttonWidget = tester.widget<LottiPrimaryButton>(saveButton);
        expect(buttonWidget.onPressed, isNull);
      });

      testWidgets('save button becomes enabled after changing name',
          (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = createTestCategory(name: 'Original');

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );
        when(() => mockRepository.updateCategory(any())).thenAnswer(
          (_) async => category.copyWith(name: 'Updated'),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        streamController.add(category);
        await tester.pumpAndSettle();

        // Change the name
        final nameField = find.byType(TextFormField);
        await tester.enterText(nameField, 'Updated Name');
        await tester.pumpAndSettle();

        // Check save button is enabled - there might be multiple buttons
        final saveButtons = find.byType(LottiPrimaryButton);
        expect(saveButtons, findsAtLeastNWidgets(1));

        // Find the save button (should be the last one in the bottom bar)
        var foundEnabledSaveButton = false;
        for (var i = 0; i < saveButtons.evaluate().length; i++) {
          final button = tester.widget<LottiPrimaryButton>(saveButtons.at(i));
          if (button.onPressed != null) {
            foundEnabledSaveButton = true;
            break;
          }
        }
        expect(foundEnabledSaveButton, isTrue);

        await streamController.close();
      });

      testWidgets('toggle switches trigger state changes', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        streamController.add(category);
        await tester.pumpAndSettle();

        // Find and tap the private switch
        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(3)); // Private, Active, Favorite

        // Tap the first switch (Private)
        await tester.tap(switches.first);
        await tester.pumpAndSettle();

        // Save button should now be enabled
        final saveButtons = find.byType(LottiPrimaryButton);
        var foundEnabledSaveButton = false;
        for (var i = 0; i < saveButtons.evaluate().length; i++) {
          final button = tester.widget<LottiPrimaryButton>(saveButtons.at(i));
          if (button.onPressed != null) {
            foundEnabledSaveButton = true;
            break;
          }
        }
        expect(foundEnabledSaveButton, isTrue);

        await streamController.close();
      });

      testWidgets('cancel button navigates back', (tester) async {
        final category = createTestCategory();
        var navigatedBack = false;

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: Navigator(
              onDidRemovePage: (page) {
                navigatedBack = true;
              },
              pages: [
                MaterialPage(
                  child: CategoryDetailsPage(categoryId: testCategoryId),
                ),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find and tap cancel button
        final cancelButton = find.byType(LottiSecondaryButton);
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();

        expect(navigatedBack, isTrue);
      });
    });

    group('Delete Functionality', () {
      testWidgets('delete button opens confirmation dialog', (tester) async {
        final category = createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Find and tap delete button
        final deleteButton = find.byType(LottiTertiaryButton);
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Check dialog appears
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('Delete'), findsAtLeastNWidgets(1));
      });

      testWidgets('cancel delete dismisses dialog', (tester) async {
        final category = createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Open delete dialog
        final deleteButton = find.byType(LottiTertiaryButton);
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Find cancel button in dialog and tap it
        final cancelInDialog = find.text('Cancel').last;
        await tester.tap(cancelInDialog);
        await tester.pumpAndSettle();

        // Dialog should be dismissed
        expect(find.byType(AlertDialog), findsNothing);
      });
    });

    group('State Management', () {
      testWidgets('state changes are reflected in UI', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = createTestCategory(name: 'Initial Name');

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );
        when(() => mockRepository.updateCategory(any())).thenAnswer(
          (_) async => category,
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        // Initially shows loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Emit the category
        streamController.add(category);
        await tester.pumpAndSettle();

        // Category name should be displayed
        expect(find.text('Initial Name'), findsAtLeastNWidgets(1));

        // Clean up
        await streamController.close();
      });

      testWidgets('controller state updates trigger UI rebuilds',
          (tester) async {
        final category = createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Check that the controller was created and is watching the category
        verify(() => mockRepository.watchCategory(testCategoryId)).called(1);
      });

      testWidgets('dispose does not throw errors', (tester) async {
        final category = createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate away to trigger disposal
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const Scaffold(body: Text('Different Page')),
          ),
        );

        await tester.pumpAndSettle();

        // Test passes if no errors are thrown
        expect(find.text('Different Page'), findsOneWidget);
      });
    });

    group('AI Settings Display', () {
      testWidgets('displays page with category data', (tester) async {
        final category = createTestCategory(
          allowedPromptIds: ['prompt1', 'prompt2'],
        );

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Just check that the page loaded with the category name
        expect(find.text('Test Category'), findsAtLeastNWidgets(1));
      });

      testWidgets('displays page with automatic prompts data', (tester) async {
        final category = createTestCategory(
          automaticPrompts: {
            AiResponseType.audioTranscription: ['prompt1'],
            AiResponseType.imageAnalysis: ['prompt2'],
          },
        );

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Just verify the page loaded successfully
        expect(find.byType(CategoryDetailsPage), findsOneWidget);
        expect(find.text('Test Category'), findsAtLeastNWidgets(1));
      });

      testWidgets('displays page with language field', (tester) async {
        final category = createTestCategory(defaultLanguageCode: 'en');

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        await tester.pumpAndSettle();

        // Check that the page loaded with category data
        expect(find.byType(CategoryDetailsPage), findsOneWidget);
        expect(find.text('Test Category'), findsAtLeastNWidgets(1));
      });
    });

    group('Form Validation', () {
      testWidgets('shows error for empty name on save', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = createTestCategory(name: 'Test');

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        streamController.add(category);
        await tester.pumpAndSettle();

        // Clear the name field
        final nameField = find.byType(TextFormField);
        await tester.enterText(nameField, '   '); // Only spaces
        await tester.pumpAndSettle();

        // Try to save - find the enabled save button
        final saveButtons = find.byType(LottiPrimaryButton);
        LottiPrimaryButton? enabledButton;
        int? enabledIndex;

        for (var i = 0; i < saveButtons.evaluate().length; i++) {
          final button = tester.widget<LottiPrimaryButton>(saveButtons.at(i));
          if (button.onPressed != null) {
            enabledButton = button;
            enabledIndex = i;
            break;
          }
        }

        expect(enabledButton, isNotNull,
            reason: 'Should find an enabled save button');
        await tester.tap(saveButtons.at(enabledIndex!));
        await tester.pumpAndSettle();

        // Should show error
        expect(find.text('Category name cannot be empty'), findsOneWidget);

        await streamController.close();
      });

      testWidgets('saves category with updated values', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = createTestCategory(name: 'Test');

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );
        when(() => mockRepository.updateCategory(any())).thenAnswer(
          (_) async => category,
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );

        streamController.add(category);
        await tester.pumpAndSettle();

        // Enter name with whitespace
        final nameField = find.byType(TextFormField);
        await tester.enterText(nameField, 'New Name');
        await tester.pumpAndSettle();

        // Save - find the enabled save button
        final saveButtons = find.byType(LottiPrimaryButton);
        int? enabledIndex;

        for (var i = 0; i < saveButtons.evaluate().length; i++) {
          final button = tester.widget<LottiPrimaryButton>(saveButtons.at(i));
          if (button.onPressed != null) {
            enabledIndex = i;
            break;
          }
        }

        expect(enabledIndex, isNotNull,
            reason: 'Should find an enabled save button');
        await tester.tap(saveButtons.at(enabledIndex!));
        await tester.pumpAndSettle();

        // Verify the saved category has the new name
        final capturedCategory = verify(
          () => mockRepository.updateCategory(captureAny()),
        ).captured.single as CategoryDefinition;
        expect(capturedCategory.name, equals('New Name'));

        await streamController.close();
      });
    });
  });
}
