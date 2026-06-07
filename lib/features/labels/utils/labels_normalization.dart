import 'dart:collection';

import 'package:lotti/classes/entity_definitions.dart';

/// Normalizes a list of applicable category IDs for a label definition.
///
/// Trims incoming IDs and drops empties, removes duplicates (keeping first
/// occurrence), filters out IDs that [lookupCategory] cannot resolve, and
/// sorts the survivors by the category's lower-cased name.
///
/// Pure given [lookupCategory]; shared by createLabel and updateLabel.
List<String> normalizeLabelCategoryIds(
  List<String>? categoryIds, {
  required CategoryDefinition? Function(String id) lookupCategory,
}) {
  if (categoryIds == null) return const <String>[];
  // Trim incoming IDs and drop empties before validation/dedup
  final unique = LinkedHashSet<String>.from(
    categoryIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
  );

  final valid = <String>[];
  final nameById = <String, String>{};
  for (final id in unique) {
    final category = lookupCategory(id);
    if (category != null) {
      valid.add(id);
      nameById[id] = category.name.toLowerCase();
    }
  }

  valid.sort((a, b) => (nameById[a] ?? a).compareTo(nameById[b] ?? b));
  return valid;
}
