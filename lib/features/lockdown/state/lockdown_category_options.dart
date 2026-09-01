import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';

/// The categories the logo menu may offer.
///
/// Active categories sorted by name. `categoriesStreamProvider` is itself
/// scoped by lockdown, so while active this is only the locked ones — the
/// exit menu never spells out the categories it is hiding.
final lockdownCategoryOptionsProvider = Provider<List<CategoryDefinition>>((
  ref,
) {
  final categories = ref.watch(categoriesStreamProvider).asData?.value ?? [];
  return categories
      .where((category) => category.active)
      .sortedBy((category) => category.name.toLowerCase());
});
