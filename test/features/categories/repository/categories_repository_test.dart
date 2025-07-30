import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockJournalDb extends Mock implements JournalDb {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class FakeCategoryDefinition extends Fake implements CategoryDefinition {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCategoryDefinition());
  });

  group('CategoryRepository', () {
    late MockPersistenceLogic mockPersistenceLogic;
    late MockJournalDb mockJournalDb;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late CategoryRepository repository;

    setUp(() {
      mockPersistenceLogic = MockPersistenceLogic();
      mockJournalDb = MockJournalDb();
      mockEntitiesCacheService = MockEntitiesCacheService();

      // Reset getIt and register mocks
      if (getIt.isRegistered<PersistenceLogic>()) {
        getIt.unregister<PersistenceLogic>();
      }
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      if (getIt.isRegistered<EntitiesCacheService>()) {
        getIt.unregister<EntitiesCacheService>();
      }

      getIt
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

      repository = CategoryRepository(
        mockPersistenceLogic,
        mockJournalDb,
        mockEntitiesCacheService,
      );
    });

    tearDown(() {
      if (getIt.isRegistered<PersistenceLogic>()) {
        getIt.unregister<PersistenceLogic>();
      }
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      if (getIt.isRegistered<EntitiesCacheService>()) {
        getIt.unregister<EntitiesCacheService>();
      }
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
      DateTime? deletedAt,
    }) {
      return CategoryDefinition(
        id: id ?? const Uuid().v4(),
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
        deletedAt: deletedAt,
      );
    }

    group('watchCategories', () {
      test('emits categories from database', () async {
        final category1 = createTestCategory(name: 'Category 1');
        final category2 = createTestCategory(name: 'Category 2');
        final categories = [category1, category2];

        when(() => mockJournalDb.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        final result = await repository.watchCategories().first;

        expect(result, equals(categories));
        verify(() => mockJournalDb.watchCategories()).called(1);
      });

      test('emits updated categories when database changes', () async {
        final category1 = createTestCategory(name: 'Category 1');
        final category2 = createTestCategory(name: 'Category 2');
        final category3 = createTestCategory(name: 'Category 3');

        final controller = StreamController<List<CategoryDefinition>>();
        when(() => mockJournalDb.watchCategories()).thenAnswer(
          (_) => controller.stream,
        );

        final results = <List<CategoryDefinition>>[];
        final subscription = repository.watchCategories().listen(results.add);

        controller.add([category1, category2]);
        await Future<void>.delayed(Duration.zero);
        controller.add([category1, category2, category3]);
        await Future<void>.delayed(Duration.zero);

        expect(results, hasLength(2));
        expect(results[0], hasLength(2));
        expect(results[1], hasLength(3));

        await subscription.cancel();
        await controller.close();
      });
    });

    group('watchCategory', () {
      test('emits specific category from database', () async {
        final category = createTestCategory();

        when(() => mockJournalDb.watchCategoryById(category.id)).thenAnswer(
          (_) => Stream.value(category),
        );

        final result = await repository.watchCategory(category.id).first;

        expect(result, equals(category));
        verify(() => mockJournalDb.watchCategoryById(category.id)).called(1);
      });

      test('emits null when category not found', () async {
        when(() => mockJournalDb.watchCategoryById('non-existent-id'))
            .thenAnswer(
          (_) => Stream<CategoryDefinition?>.value(null),
        );

        final result = await repository.watchCategory('non-existent-id').first;

        expect(result, isNull);
      });

      test('emits updated category when it changes', () async {
        final categoryId = const Uuid().v4();
        final category1 = createTestCategory(id: categoryId, name: 'Original');
        final category2 = createTestCategory(id: categoryId, name: 'Updated');

        final controller = StreamController<CategoryDefinition?>();
        when(() => mockJournalDb.watchCategoryById(categoryId)).thenAnswer(
          (_) => controller.stream,
        );

        final results = <CategoryDefinition?>[];
        final subscription =
            repository.watchCategory(categoryId).listen(results.add);

        controller.add(category1);
        await Future<void>.delayed(Duration.zero);
        controller.add(category2);
        await Future<void>.delayed(Duration.zero);

        expect(results, hasLength(2));
        expect(results[0]?.name, equals('Original'));
        expect(results[1]?.name, equals('Updated'));

        await subscription.cancel();
        await controller.close();
      });
    });

    group('createCategory', () {
      test('creates category with provided values', () async {
        const name = 'New Category';
        const color = '#FF0000';

        when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .thenAnswer((_) async => 1);

        final result = await repository.createCategory(
          name: name,
          color: color,
        );

        expect(result.name, equals(name));
        expect(result.color, equals(color));
        expect(result.private, isFalse);
        expect(result.active, isTrue);
        expect(result.favorite, isNull);
        expect(result.defaultLanguageCode, isNull);
        expect(result.allowedPromptIds, isNull);
        expect(result.automaticPrompts, isNull);

        final captured = verify(
                () => mockPersistenceLogic.upsertEntityDefinition(captureAny()))
            .captured
            .single as CategoryDefinition;
        expect(captured.name, equals(name));
        expect(captured.color, equals(color));
      });

      test('generates unique ID for new category', () async {
        when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .thenAnswer((_) async => 1);

        final result1 = await repository.createCategory(
          name: 'Category 1',
          color: '#FF0000',
        );
        final result2 = await repository.createCategory(
          name: 'Category 2',
          color: '#00FF00',
        );

        expect(result1.id, isNotEmpty);
        expect(result2.id, isNotEmpty);
        expect(result1.id, isNot(equals(result2.id)));
      });
    });

    group('getCategoryById', () {
      test('returns category from cache service', () async {
        final category = createTestCategory();

        when(() => mockEntitiesCacheService.getCategoryById(category.id))
            .thenReturn(category);

        final result = await repository.getCategoryById(category.id);

        expect(result, equals(category));
        verify(() => mockEntitiesCacheService.getCategoryById(category.id))
            .called(1);
      });

      test('returns null when category not found in cache', () async {
        when(() => mockEntitiesCacheService.getCategoryById('non-existent-id'))
            .thenReturn(null);

        final result = await repository.getCategoryById('non-existent-id');

        expect(result, isNull);
        verify(() =>
                mockEntitiesCacheService.getCategoryById('non-existent-id'))
            .called(1);
      });
    });

    group('updateCategory', () {
      test('updates category via persistence logic', () async {
        final category = createTestCategory(name: 'Updated Category');

        when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .thenAnswer((_) async => 1);

        final result = await repository.updateCategory(category);

        expect(result.name, equals(category.name));
        expect(result.updatedAt.isAfter(category.updatedAt), isTrue);

        verify(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .called(1);
      });

      test('preserves all fields during update', () async {
        final category = createTestCategory(
          name: 'Test',
          color: '#123456',
          private: true,
          active: false,
          favorite: true,
          defaultLanguageCode: 'de',
          allowedPromptIds: ['prompt1', 'prompt2'],
          automaticPrompts: {
            AiResponseType.audioTranscription: ['prompt3'],
            AiResponseType.imageAnalysis: ['prompt4'],
          },
        );

        when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .thenAnswer((_) async => 1);

        await repository.updateCategory(category);

        final captured = verify(
                () => mockPersistenceLogic.upsertEntityDefinition(captureAny()))
            .captured
            .single as CategoryDefinition;

        expect(captured.name, equals(category.name));
        expect(captured.color, equals(category.color));
        expect(captured.private, equals(category.private));
        expect(captured.active, equals(category.active));
        expect(captured.favorite, equals(category.favorite));
        expect(
            captured.defaultLanguageCode, equals(category.defaultLanguageCode));
        expect(captured.allowedPromptIds, equals(category.allowedPromptIds));
        expect(captured.automaticPrompts, equals(category.automaticPrompts));
      });
    });

    group('deleteCategory', () {
      test('successfully soft deletes category by setting deletedAt timestamp',
          () async {
        const categoryId = 'test-id-123';
        final existingCategory = createTestCategory(
          id: categoryId,
          name: 'Category to Delete',
        );

        // Mock category exists
        when(() => mockEntitiesCacheService.getCategoryById(categoryId))
            .thenReturn(existingCategory);

        when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .thenAnswer((_) async => 1);

        await repository.deleteCategory(categoryId);

        // Verify upsertEntityDefinition was called with the deleted category
        final captured = verify(
                () => mockPersistenceLogic.upsertEntityDefinition(captureAny()))
            .captured
            .single as CategoryDefinition;

        // Verify the category has deletedAt set
        expect(captured.id, equals(categoryId));
        expect(captured.name, equals('Category to Delete'));
        expect(captured.deletedAt, isNotNull);
        expect(captured.deletedAt?.difference(DateTime.now()).inSeconds.abs(),
            lessThan(5)); // Within 5 seconds
        expect(captured.updatedAt, isNotNull);
        expect(captured.updatedAt.difference(DateTime.now()).inSeconds.abs(),
            lessThan(5)); // Within 5 seconds
      });

      test('does nothing when category ID does not exist', () async {
        const nonExistentId = 'non-existent-id';

        // Mock category doesn't exist
        when(() => mockEntitiesCacheService.getCategoryById(nonExistentId))
            .thenReturn(null);

        await repository.deleteCategory(nonExistentId);

        // Verify that upsertEntityDefinition was never called
        verifyNever(() => mockPersistenceLogic.upsertEntityDefinition(any()));
      });

      test('propagates errors from persistence logic during deletion',
          () async {
        const categoryId = 'test-id-456';
        final existingCategory = createTestCategory(
          id: categoryId,
          name: 'Category with Error',
        );
        final error = Exception('Delete error');

        // Mock category exists
        when(() => mockEntitiesCacheService.getCategoryById(categoryId))
            .thenReturn(existingCategory);

        // Mock persistence logic throws error
        when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .thenThrow(error);

        expect(
          () => repository.deleteCategory(categoryId),
          throwsA(error),
        );
      });

      test('preserves other category properties when soft deleting', () async {
        const categoryId = 'test-id-789';
        final existingCategory = createTestCategory(
          id: categoryId,
          name: 'Category with Properties',
          color: '#FF0000',
          private: true,
          active: false,
          favorite: true,
          defaultLanguageCode: 'en',
          allowedPromptIds: ['prompt1', 'prompt2'],
          automaticPrompts: {
            AiResponseType.taskSummary: ['prompt1'],
          },
        );

        // Mock category exists
        when(() => mockEntitiesCacheService.getCategoryById(categoryId))
            .thenReturn(existingCategory);

        when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .thenAnswer((_) async => 1);

        await repository.deleteCategory(categoryId);

        // Verify all properties are preserved except deletedAt and updatedAt
        final captured = verify(
                () => mockPersistenceLogic.upsertEntityDefinition(captureAny()))
            .captured
            .single as CategoryDefinition;

        expect(captured.id, equals(categoryId));
        expect(captured.name, equals('Category with Properties'));
        expect(captured.color, equals('#FF0000'));
        expect(captured.private, isTrue);
        expect(captured.active, isFalse);
        expect(captured.favorite, isTrue);
        expect(captured.defaultLanguageCode, equals('en'));
        expect(captured.allowedPromptIds, equals(['prompt1', 'prompt2']));
        expect(
            captured.automaticPrompts,
            equals({
              AiResponseType.taskSummary: ['prompt1']
            }));
        expect(captured.deletedAt, isNotNull);
        expect(captured.updatedAt, isNotNull);
      });
    });

    group('error handling', () {
      test('watchCategories propagates errors from database', () async {
        final error = Exception('Database error');
        when(() => mockJournalDb.watchCategories()).thenAnswer(
          (_) => Stream<List<CategoryDefinition>>.error(error),
        );

        expect(
          repository.watchCategories(),
          emitsError(error),
        );
      });

      test('createCategory propagates errors from persistence logic', () async {
        final error = Exception('Create error');
        when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .thenThrow(error);

        expect(
          () => repository.createCategory(name: 'Test', color: '#000000'),
          throwsA(error),
        );
      });

      test('updateCategory propagates errors from persistence logic', () async {
        final error = Exception('Update error');
        final category = createTestCategory();
        when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
            .thenThrow(error);

        expect(
          () => repository.updateCategory(category),
          throwsA(error),
        );
      });
    });
  });
}
