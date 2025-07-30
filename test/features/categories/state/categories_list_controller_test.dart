import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  group('CategoriesListController', () {
    late MockCategoryRepository mockRepository;

    setUp(() {
      mockRepository = MockCategoryRepository();
    });

    CategoryDefinition createTestCategory({
      String? id,
      String name = 'Test Category',
      String? color,
      bool private = false,
      bool active = true,
    }) {
      return CategoryDefinition(
        id: id ?? const Uuid().v4(),
        name: name,
        color: color ?? '#0000FF',
        private: private,
        active: active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
      );
    }

    test('initial state is loading', () {
      when(() => mockRepository.watchCategories()).thenAnswer(
        (_) => const Stream.empty(),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(categoriesListControllerProvider);

      expect(state, const AsyncValue<List<CategoryDefinition>>.loading());
    });

    test('loads categories from repository', () async {
      final categories = [
        createTestCategory(name: 'Category 1'),
        createTestCategory(name: 'Category 2'),
      ];
      final completer = Completer<void>();

      when(() => mockRepository.watchCategories()).thenAnswer(
        (_) => Stream.value(categories),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Listen for state changes
      container.listen(
        categoriesListControllerProvider,
        (_, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Wait for the stream to emit
      await completer.future.timeout(const Duration(seconds: 1));

      final state = container.read(categoriesListControllerProvider);

      expect(state.hasValue, isTrue);
      expect(state.value, equals(categories));
    });

    test('handles loading error', () async {
      final error = Exception('Failed to load categories');
      final completer = Completer<void>();

      when(() => mockRepository.watchCategories()).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.error(error),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Listen for state changes
      container.listen(
        categoriesListControllerProvider,
        (_, next) {
          if (next.hasError && !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Wait for the error to be processed
      await completer.future.timeout(const Duration(seconds: 1));

      final state = container.read(categoriesListControllerProvider);

      expect(state.hasError, isTrue);
      expect(state.error, equals(error));
    });

    test('updates state when categories change', () async {
      final categories1 = [createTestCategory(name: 'Category 1')];
      final categories2 = [
        createTestCategory(name: 'Category 1'),
        createTestCategory(name: 'Category 2'),
      ];

      final streamController =
          StreamController<List<CategoryDefinition>>.broadcast();
      when(() => mockRepository.watchCategories()).thenAnswer(
        (_) => streamController.stream,
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(() async {
        await streamController.close();
        container.dispose();
      });

      // Listen for state changes
      final states = <AsyncValue<List<CategoryDefinition>>>[];
      container.listen(
        categoriesListControllerProvider,
        (prev, next) => states.add(next),
        fireImmediately: true,
      );

      // Wait a bit for initial state
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Emit first set of categories
      streamController.add(categories1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Emit second set of categories
      streamController.add(categories2);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should have loading, data1, data2
      expect(states.length, greaterThanOrEqualTo(3));
      expect(states.first.isLoading, isTrue);
      expect(states[1].value, equals(categories1));
      expect(states[2].value, equals(categories2));
    });

    test('deletes category successfully', () async {
      final categoryId = const Uuid().v4();
      final categories = [createTestCategory(id: categoryId)];

      when(() => mockRepository.watchCategories()).thenAnswer(
        (_) => Stream.value(categories),
      );
      when(() => mockRepository.deleteCategory(categoryId)).thenAnswer(
        (_) async {},
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final controller =
          container.read(categoriesListControllerProvider.notifier);
      await controller.deleteCategory(categoryId);

      verify(() => mockRepository.deleteCategory(categoryId)).called(1);
    });

    test('handles delete error', () async {
      final categoryId = const Uuid().v4();
      final categories = [createTestCategory(id: categoryId)];
      final deleteError = Exception('Delete failed');
      final completer = Completer<void>();

      when(() => mockRepository.watchCategories()).thenAnswer(
        (_) => Stream.value(categories),
      );
      when(() => mockRepository.deleteCategory(categoryId)).thenThrow(
        deleteError,
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Listen for state changes
      var hasLoadedInitial = false;
      container.listen(
        categoriesListControllerProvider,
        (_, next) {
          if (next.hasValue && !hasLoadedInitial) {
            hasLoadedInitial = true;
          } else if (next.hasError &&
              hasLoadedInitial &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Wait for initial load
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final controller =
          container.read(categoriesListControllerProvider.notifier);
      await controller.deleteCategory(categoryId);

      // Wait for error state
      await completer.future.timeout(const Duration(seconds: 1));

      final state = container.read(categoriesListControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals(deleteError));
    });
  });

  group('categoriesStreamProvider', () {
    late MockCategoryRepository mockRepository;

    setUp(() {
      mockRepository = MockCategoryRepository();
    });

    test('provides categories stream from repository', () async {
      final categories = [
        CategoryDefinition(
          id: const Uuid().v4(),
          name: 'Test Category',
          color: '#FF0000',
          private: false,
          active: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockRepository.watchCategories()).thenAnswer(
        (_) => Stream.value(categories),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        categoriesStreamProvider.future,
      );

      expect(result, equals(categories));
      verify(() => mockRepository.watchCategories()).called(1);
    });

    test('propagates errors from repository', () async {
      final error = Exception('Stream error');

      when(() => mockRepository.watchCategories()).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.error(error),
      );

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(categoriesStreamProvider.future),
        throwsA(error),
      );
    });
  });
}
