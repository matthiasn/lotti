import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:uuid/uuid.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(getIt<PersistenceLogic>());
});

class CategoryRepository {
  CategoryRepository(this._persistenceLogic);

  final PersistenceLogic _persistenceLogic;
  final _uuid = const Uuid();

  Stream<List<CategoryDefinition>> watchCategories() {
    return getIt<JournalDb>().watchCategories();
  }

  Stream<CategoryDefinition?> watchCategory(String id) {
    return getIt<JournalDb>().watchCategoryById(id);
  }

  Future<CategoryDefinition?> getCategoryById(String id) async {
    // Use the cached version for efficient synchronous access
    return getIt<EntitiesCacheService>().getCategoryById(id);
  }

  Future<List<CategoryDefinition>> getAllCategories() async {
    final categories = await getIt<JournalDb>().allCategoryDefinitions().get();
    return categoryDefinitionsStreamMapper(categories);
  }

  Future<CategoryDefinition> createCategory({
    required String name,
    required String color,
  }) async {
    final now = DateTime.now();

    final category = CategoryDefinition(
      id: _uuid.v4(),
      name: name,
      color: color,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
      private: false,
      active: true,
    );

    await _persistenceLogic.upsertEntityDefinition(category);
    return category;
  }

  Future<CategoryDefinition> updateCategory(
    CategoryDefinition category,
  ) async {
    final updated = category.copyWith(
      updatedAt: DateTime.now(),
    );

    await _persistenceLogic.upsertEntityDefinition(updated);
    return updated;
  }

  Future<void> deleteCategory(String id) async {
    final category = await getCategoryById(id);
    if (category != null) {
      final deleted = category.copyWith(
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _persistenceLogic.upsertEntityDefinition(deleted);
    }
  }
}
