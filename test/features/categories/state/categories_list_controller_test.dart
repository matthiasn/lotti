import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../test_utils.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  group('CategoriesListController', () {
    late MockCategoryRepository mockRepository;

    setUp(() {
      mockRepository = MockCategoryRepository();
    });

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
        CategoryTestUtils.createTestCategory(name: 'Category 1'),
        CategoryTestUtils.createTestCategory(name: 'Category 2'),
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

      // Wait for the stream to emit (short guard)
      await completer.future.timeout(const Duration(milliseconds: 100));

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

      // Wait for the error to be processed (short guard)
      await completer.future.timeout(const Duration(milliseconds: 100));

      final state = container.read(categoriesListControllerProvider);

      expect(state.hasError, isTrue);
      expect(state.error, equals(error));
    });

    test('updates state when categories change', () {
      fakeAsync((async) {
        final categories1 = [
          CategoryTestUtils.createTestCategory(name: 'Category 1')
        ];
        final categories2 = [
          CategoryTestUtils.createTestCategory(name: 'Category 1'),
          CategoryTestUtils.createTestCategory(name: 'Category 2'),
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

        // Yield and process initial state
        async.flushMicrotasks();

        // Emit first set of categories and flush microtasks
        streamController.add(categories1);
        async.flushMicrotasks();

        // Emit second set of categories and flush microtasks
        streamController.add(categories2);
        async.flushMicrotasks();

        // Should have loading, data1, data2
        expect(states.length, greaterThanOrEqualTo(3));
        expect(states.first.isLoading, isTrue);
        expect(states[1].value, equals(categories1));
        expect(states[2].value, equals(categories2));
      });
    });

    test('deletes category successfully', () async {
      final categoryId = const Uuid().v4();
      final categories = [CategoryTestUtils.createTestCategory(id: categoryId)];

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

      // Yield once for initial load (no real wait)
      await Future<void>.delayed(Duration.zero);

      final controller =
          container.read(categoriesListControllerProvider.notifier);
      await controller.deleteCategory(categoryId);

      verify(() => mockRepository.deleteCategory(categoryId)).called(1);
    });

    test('handles delete error', () async {
      final categoryId = const Uuid().v4();
      final categories = [CategoryTestUtils.createTestCategory(id: categoryId)];
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

      // Yield once for initial load (no real wait)
      await Future<void>.delayed(Duration.zero);

      final controller =
          container.read(categoriesListControllerProvider.notifier);
      await controller.deleteCategory(categoryId);

      // Wait for error state (short guard)
      await completer.future.timeout(const Duration(milliseconds: 100));

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

    test('provides categories stream from repository', () {
      fakeAsync((async) {
        final categories = [
          CategoryTestUtils.createTestCategory(
            color: '#FF0000',
          ),
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

        // Start listening to trigger subscription
        final subscription = container.listen(
          categoriesStreamProvider,
          (_, __) {},
        );

        // Process microtasks
        async.flushMicrotasks();

        // Emit value after provider is listening
        streamController.add(categories);

        // Wait for the value to be processed
        async.flushMicrotasks();

        final state = container.read(categoriesStreamProvider);
        expect(state.hasValue, isTrue);
        expect(state.value, equals(categories));
        verify(() => mockRepository.watchCategories()).called(1);

        subscription.close();
        streamController.close();
        container.dispose();
      });
    });

    test('propagates errors from repository', () {
      fakeAsync((async) {
        final error = Exception('Stream error');

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

        // Start listening to trigger subscription
        final subscription = container.listen(
          categoriesStreamProvider,
          (_, __) {},
        );

        // Process microtasks
        async.flushMicrotasks();

        // Emit error after provider is listening
        streamController.addError(error);

        // Wait for the error to be processed
        async.flushMicrotasks();

        final state = container.read(categoriesStreamProvider);
        expect(state.hasError, isTrue);
        expect(state.error, equals(error));

        subscription.close();
        streamController.close();
        container.dispose();
      });
    });
  });
}
