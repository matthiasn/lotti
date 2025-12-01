import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_details_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../test_utils.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

class FakeCategoryDefinition extends Fake implements CategoryDefinition {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCategoryDefinition());
  });

  group('CategoryDetailsController', () {
    late MockCategoryRepository mockRepository;
    late String testCategoryId;

    setUp(() {
      mockRepository = MockCategoryRepository();
      testCategoryId = const Uuid().v4();
    });

    test('initial state is loading', () {
      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => const Stream.empty(),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );
      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.isLoading, isTrue);
      expect(state.category, isNull);
      expect(state.isSaving, isFalse);
      expect(state.hasChanges, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('loads category from repository', () async {
      final category = CategoryTestUtils.createTestCategory();
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Listen for state changes
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      // Wait for the category to load (short guard)
      await completer.future.timeout(const Duration(milliseconds: 100));

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.isLoading, isFalse);
      expect(state.category, equals(category));
      expect(state.hasChanges, isFalse);

      subscription.close();
    });

    test('handles loading error', () async {
      final error = Exception('Failed to load');
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.error(error),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Listen for state changes
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.errorMessage != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      // Wait for the error to be processed (short guard)
      await completer.future.timeout(const Duration(milliseconds: 100));

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.isLoading, isFalse);
      expect(state.errorMessage, equals('Failed to load category data.'));

      subscription.close();
    });

    test('detects changes in form fields', () async {
      final category = CategoryTestUtils.createTestCategory();
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Test name change
      controller.updateFormField(name: 'New Name');
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .hasChanges,
        isTrue,
      );
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .category
            ?.name,
        equals('New Name'),
      );

      // Test color change
      controller.updateFormField(color: '#00FF00');
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .hasChanges,
        isTrue,
      );
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .category
            ?.color,
        equals('#00FF00'),
      );

      // Test boolean changes
      controller.updateFormField(private: true);
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .hasChanges,
        isTrue,
      );

      controller.updateFormField(active: false);
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .hasChanges,
        isTrue,
      );

      controller.updateFormField(favorite: true);
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .hasChanges,
        isTrue,
      );

      // Test language code change
      controller.updateFormField(defaultLanguageCode: 'de');
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .hasChanges,
        isTrue,
      );
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .category
            ?.defaultLanguageCode,
        equals('de'),
      );

      subscription.close();
    });

    test('no changes when setting same values', () async {
      final category = CategoryTestUtils.createTestCategory(
        name: 'Test',
        color: '#FF0000',
        private: true,
      );
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Set same values
      controller.updateFormField(
        name: 'Test',
        color: '#FF0000',
        private: true,
      );

      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .hasChanges,
        isFalse,
      );

      subscription.close();
    });

    test('updates allowed prompt IDs', () async {
      final category =
          CategoryTestUtils.createTestCategory(allowedPromptIds: ['prompt1']);
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Update allowed prompt IDs
      controller.updateAllowedPromptIds(['prompt1', 'prompt2']);

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.hasChanges, isTrue);
      expect(state.category?.allowedPromptIds, equals(['prompt1', 'prompt2']));

      // Test setting empty list
      controller.updateAllowedPromptIds([]);
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .category
            ?.allowedPromptIds,
        isNull,
      );

      subscription.close();
    });

    test('updates speech dictionary', () async {
      final category = CategoryTestUtils.createTestCategory(
        speechDictionary: ['term1'],
      );
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Update speech dictionary
      controller.updateSpeechDictionary(['term1', 'term2', 'term3']);

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.hasChanges, isTrue);
      expect(
        state.category?.speechDictionary,
        equals(['term1', 'term2', 'term3']),
      );

      // Test setting empty list converts to null
      controller.updateSpeechDictionary([]);
      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .category
            ?.speechDictionary,
        isNull,
      );

      subscription.close();
    });

    test('no changes when setting same speech dictionary', () async {
      final category = CategoryTestUtils.createTestCategory(
        speechDictionary: ['term1', 'term2'],
      );
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Set same values
      controller.updateSpeechDictionary(['term1', 'term2']);

      expect(
        container
            .read(categoryDetailsControllerProvider(testCategoryId))
            .hasChanges,
        isFalse,
      );

      subscription.close();
    });

    test('updates automatic prompts', () async {
      final category = CategoryTestUtils.createTestCategory();
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Add automatic prompt
      controller.updateAutomaticPrompts(
        AiResponseType.audioTranscription,
        ['prompt1'],
      );

      var state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.hasChanges, isTrue);
      expect(
        state.category?.automaticPrompts?[AiResponseType.audioTranscription],
        equals(['prompt1']),
      );

      // Remove prompt
      controller.updateAutomaticPrompts(
        AiResponseType.audioTranscription,
        [],
      );

      state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );
      expect(
        state.category?.automaticPrompts
                ?.containsKey(AiResponseType.audioTranscription) ??
            false,
        isFalse,
      );

      subscription.close();
    });

    test('saves changes successfully', () async {
      final category = CategoryTestUtils.createTestCategory(name: 'Original');
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );
      when(() => mockRepository.getCategoryById(testCategoryId)).thenAnswer(
        (_) async => category,
      );
      when(() => mockRepository.updateCategory(any())).thenAnswer(
        (_) async => category.copyWith(name: 'Updated'),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Make a change
      controller.updateFormField(name: 'Updated');

      // Save
      await controller.saveChanges();

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.isSaving, isFalse);
      expect(state.hasChanges, isFalse);
      expect(state.errorMessage, isNull);

      verify(() => mockRepository.updateCategory(any())).called(1);

      subscription.close();
    });

    test('validates name is not empty', () async {
      final category = CategoryTestUtils.createTestCategory(name: 'Original');
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Set empty name
      controller.updateFormField(name: '   ');

      await controller.saveChanges();

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.errorMessage, equals('Category name cannot be empty'));
      expect(state.isSaving, isFalse);

      verifyNever(() => mockRepository.updateCategory(any()));

      subscription.close();
    });

    test('handles save error', () async {
      final category = CategoryTestUtils.createTestCategory(name: 'Original');
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );
      when(() => mockRepository.getCategoryById(testCategoryId)).thenAnswer(
        (_) async => category,
      );
      when(() => mockRepository.updateCategory(any())).thenThrow(
        Exception('Save failed'),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      controller.updateFormField(name: 'Updated');
      await controller.saveChanges();

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.errorMessage,
          equals('Failed to update category. Please try again.'));
      expect(state.isSaving, isFalse);
      expect(state.hasChanges, isTrue); // Changes remain

      subscription.close();
    });

    test('does nothing when no changes', () async {
      final category = CategoryTestUtils.createTestCategory();
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      await controller.saveChanges();

      verifyNever(() => mockRepository.updateCategory(any()));

      subscription.close();
    });

    test('deletes category successfully', () async {
      final category = CategoryTestUtils.createTestCategory();
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );
      when(() => mockRepository.deleteCategory(testCategoryId)).thenAnswer(
        (_) async {},
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      await controller.deleteCategory();

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.isSaving, isFalse);
      expect(state.errorMessage, isNull);

      verify(() => mockRepository.deleteCategory(testCategoryId)).called(1);

      subscription.close();
    });

    test('handles delete error', () async {
      final category = CategoryTestUtils.createTestCategory();
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );
      when(() => mockRepository.deleteCategory(testCategoryId)).thenThrow(
        Exception('Delete failed'),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      await controller.deleteCategory();

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      expect(state.errorMessage,
          equals('Failed to delete category. Please try again.'));
      expect(state.isSaving, isFalse);

      subscription.close();
    });

    test(
        'saveChanges merges remote correctionExamples when user has unsaved edits',
        () async {
      // Simulate scenario where user has unsaved name edits while background
      // correction capture has added new examples to the remote category
      const testId = 'test-category-id';
      final originalCategory = CategoryTestUtils.createTestCategory(
        id: testId,
        name: 'Original Name',
        correctionExamples: [
          ChecklistCorrectionExample(
            before: 'original before',
            after: 'original after',
            capturedAt: DateTime(2025),
          ),
        ],
      );

      // Remote category has a new correction example added in background
      final remoteCategory = originalCategory.copyWith(
        correctionExamples: [
          ChecklistCorrectionExample(
            before: 'original before',
            after: 'original after',
            capturedAt: DateTime(2025),
          ),
          ChecklistCorrectionExample(
            before: 'new before',
            after: 'new after',
            capturedAt: DateTime(2025),
          ),
        ],
      );

      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testId))
          .thenAnswer((_) => Stream.value(originalCategory));
      when(() => mockRepository.getCategoryById(testId))
          .thenAnswer((_) async => remoteCategory);
      when(() => mockRepository.updateCategory(any()))
          .thenAnswer((_) async => remoteCategory);

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // User makes local edits (name change)
      controller.updateFormField(name: 'Updated Name');

      expect(
        container.read(categoryDetailsControllerProvider(testId)).hasChanges,
        isTrue,
      );

      // Save should fetch latest and merge correctionExamples
      await controller.saveChanges();

      // Verify updateCategory was called with merged correctionExamples
      final captured = verify(() => mockRepository.updateCategory(captureAny()))
          .captured
          .single as CategoryDefinition;

      // Should have the user's name change
      expect(captured.name, equals('Updated Name'));
      // Should have merged the remote correctionExamples (2 examples)
      expect(captured.correctionExamples, hasLength(2));
      expect(captured.correctionExamples![1].before, equals('new before'));

      subscription.close();
    });

    test('saveChanges preserves user deletions while adding background captures',
        () async {
      const testId = 'merge-deletions-test';
      final completer = Completer<void>();

      // Original category has 2 examples
      final example1 = ChecklistCorrectionExample(
        before: 'example1',
        after: 'EXAMPLE1',
        capturedAt: DateTime(2025),
      );
      final example2 = ChecklistCorrectionExample(
        before: 'example2',
        after: 'EXAMPLE2',
        capturedAt: DateTime(2025),
      );
      final originalCategory = CategoryTestUtils.createTestCategory(
        id: testId,
        correctionExamples: [example1, example2],
      );

      // Background capture adds example3 while user was editing
      final example3 = ChecklistCorrectionExample(
        before: 'background',
        after: 'BACKGROUND',
        capturedAt: DateTime(2025),
      );
      final remoteCategory = originalCategory.copyWith(
        correctionExamples: [example1, example2, example3],
      );

      when(() => mockRepository.watchCategory(testId))
          .thenAnswer((_) => Stream.value(originalCategory));
      when(() => mockRepository.getCategoryById(testId))
          .thenAnswer((_) async => remoteCategory);
      when(() => mockRepository.updateCategory(any()))
          .thenAnswer((_) async => remoteCategory);

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        categoryDetailsControllerProvider(testId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // User deletes example1 (index 0)
      controller.deleteCorrectionExampleAt(0);

      // Verify user now sees only example2
      final stateAfterDelete = container.read(
        categoryDetailsControllerProvider(testId),
      );
      expect(stateAfterDelete.category?.correctionExamples, hasLength(1));
      expect(
        stateAfterDelete.category?.correctionExamples!.first.before,
        equals('example2'),
      );

      // Save should merge: keep example2, add example3, but NOT restore example1
      await controller.saveChanges();

      final captured = verify(() => mockRepository.updateCategory(captureAny()))
          .captured
          .single as CategoryDefinition;

      // Should have example2 (kept) and example3 (background addition)
      // but NOT example1 (user deleted it)
      expect(captured.correctionExamples, hasLength(2));
      expect(
        captured.correctionExamples!.any((e) => e.before == 'example1'),
        isFalse,
        reason: 'User deletion of example1 should be preserved',
      );
      expect(
        captured.correctionExamples!.any((e) => e.before == 'example2'),
        isTrue,
        reason: 'example2 should be kept',
      );
      expect(
        captured.correctionExamples!.any((e) => e.before == 'background'),
        isTrue,
        reason: 'Background addition should be included',
      );

      subscription.close();
    });

    test(
        'deleteCorrectionExampleAt removes example at index from pending category',
        () async {
      final exampleToDelete = ChecklistCorrectionExample(
        before: 'delete me',
        after: 'deleted',
        capturedAt: DateTime(2025),
      );
      final exampleToKeep = ChecklistCorrectionExample(
        before: 'keep me',
        after: 'kept',
        capturedAt: DateTime(2025),
      );

      final category = CategoryTestUtils.createTestCategory(
        correctionExamples: [exampleToDelete, exampleToKeep],
      );
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Delete the first example (index 0)
      controller.deleteCorrectionExampleAt(0);

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      // Should have changes and only one example left
      expect(state.hasChanges, isTrue);
      expect(state.category?.correctionExamples, hasLength(1));
      expect(
          state.category?.correctionExamples!.first.before, equals('keep me'));

      subscription.close();
    });

    test('deleteCorrectionExampleAt sets null when last example deleted',
        () async {
      final onlyExample = ChecklistCorrectionExample(
        before: 'only',
        after: 'one',
        capturedAt: DateTime(2025),
      );

      final category = CategoryTestUtils.createTestCategory(
        correctionExamples: [onlyExample],
      );
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Delete the only example (index 0)
      controller.deleteCorrectionExampleAt(0);

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      // Should have changes and null correctionExamples
      expect(state.hasChanges, isTrue);
      expect(state.category?.correctionExamples, isNull);

      subscription.close();
    });

    test('deleteCorrectionExampleAt ignores invalid index', () async {
      final example = ChecklistCorrectionExample(
        before: 'test',
        after: 'TEST',
        capturedAt: DateTime(2025),
      );

      final category = CategoryTestUtils.createTestCategory(
        correctionExamples: [example],
      );
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Try to delete at invalid indices
      controller
        ..deleteCorrectionExampleAt(-1)
        ..deleteCorrectionExampleAt(5);

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      // Should have no changes - examples remain unchanged
      expect(state.hasChanges, isFalse);
      expect(state.category?.correctionExamples, hasLength(1));

      subscription.close();
    });

    test('deleteCorrectionExampleAt handles duplicates correctly', () async {
      // Create two identical examples
      final duplicateExample = ChecklistCorrectionExample(
        before: 'same',
        after: 'SAME',
        capturedAt: DateTime(2025),
      );

      final category = CategoryTestUtils.createTestCategory(
        correctionExamples: [duplicateExample, duplicateExample],
      );
      final completer = Completer<void>();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        categoryDetailsControllerProvider(testCategoryId),
        (_, next) {
          if (!next.isLoading &&
              next.category != null &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final controller = container.read(
        categoryDetailsControllerProvider(testCategoryId).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      // Delete only the first duplicate (index 0)
      controller.deleteCorrectionExampleAt(0);

      final state = container.read(
        categoryDetailsControllerProvider(testCategoryId),
      );

      // Should have one example left (the second duplicate was not deleted)
      expect(state.hasChanges, isTrue);
      expect(state.category?.correctionExamples, hasLength(1));
      expect(state.category?.correctionExamples!.first.before, equals('same'));

      subscription.close();
    });

    test('disposes stream subscription', () async {
      final streamController =
          StreamController<CategoryDefinition?>.broadcast();

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => streamController.stream,
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      )..read(
          categoryDetailsControllerProvider(testCategoryId).notifier,
        );

      // Add a value and yield once to ensure subscription is active (no real wait)
      streamController.add(CategoryTestUtils.createTestCategory());
      await Future<void>.delayed(Duration.zero);

      // Dispose the controller
      container.dispose();

      // Verify stream can be closed without errors
      await streamController.close();
    });
  });
}
