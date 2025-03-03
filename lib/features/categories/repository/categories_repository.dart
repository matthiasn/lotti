import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:uuid/uuid.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(getIt<PersistenceLogic>());
});

class CategoriesRepository {
  CategoriesRepository(this._persistenceLogic);

  final PersistenceLogic _persistenceLogic;
  final _uuid = const Uuid();

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
      active: true, // The persistence logic will handle the vector clock
    );

    await _persistenceLogic.upsertEntityDefinition(category);
    return category;
  }
}
